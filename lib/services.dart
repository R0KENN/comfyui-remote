import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

/// HTTP-запрос с retry и exponential backoff
Future<http.Response> httpGetWithRetry(
    String url, {
      int maxRetries = 3,
      Duration timeout = const Duration(seconds: 10),
    }) async {
  for (int i = 0; i < maxRetries; i++) {
    try {
      final resp = await http
          .get(Uri.parse(url))
          .timeout(timeout);
      if (resp.statusCode == 200) return resp;
      if (i == maxRetries - 1) return resp;
    } catch (e) {
      if (i == maxRetries - 1) rethrow;
      await Future.delayed(Duration(seconds: (i + 1) * 2));
    }
  }
  throw Exception('Не удалось подключиться к $url');
}

// ─── PromptData ───────────────────────────────────────────────

class PromptData {
  String zimageBase;
  String zimageNeg;
  String ponyPositive;
  String ponyNegative;
  String handFixPositive;
  String handFixNegative;
  String refiner;
  String refinerNeg;
  String facePositive;
  String faceNegative;

  PromptData({
    this.zimageBase = '',
    this.zimageNeg = '',
    this.ponyPositive = '',
    this.ponyNegative = '',
    this.handFixPositive = '',
    this.handFixNegative = '',
    this.refiner = '',
    this.refinerNeg = '',
    this.facePositive = '',
    this.faceNegative = '',
  });

  Map<String, String> toMap() => {
    'zimage_base': zimageBase,
    'zimage_neg': zimageNeg,
    'pony_pos': ponyPositive,
    'pony_neg': ponyNegative,
    'handfix_pos': handFixPositive,
    'handfix_neg': handFixNegative,
    'refiner': refiner,
    'refiner_neg': refinerNeg,
    'face_pos': facePositive,
    'face_neg': faceNegative,
  };

  static PromptData fromPrefs(SharedPreferences prefs) => PromptData(
    zimageBase: prefs.getString('zimage_base') ?? '',
    zimageNeg: prefs.getString('zimage_neg') ?? '',
    ponyPositive: prefs.getString('pony_pos') ?? '',
    ponyNegative: prefs.getString('pony_neg') ?? '',
    handFixPositive: prefs.getString('handfix_pos') ?? '',
    handFixNegative: prefs.getString('handfix_neg') ?? '',
    refiner: prefs.getString('refiner') ?? '',
    refinerNeg: prefs.getString('refiner_neg') ?? '',
    facePositive: prefs.getString('face_pos') ?? '',
    faceNegative: prefs.getString('face_neg') ?? '',
  );

  static PromptData fromMap(Map<String, dynamic> d) => PromptData(
    zimageBase: d['zimage_base'] ?? '',
    zimageNeg: d['zimage_neg'] ?? '',
    ponyPositive: d['pony_pos'] ?? '',
    ponyNegative: d['pony_neg'] ?? '',
    handFixPositive: d['handfix_pos'] ?? '',
    handFixNegative: d['handfix_neg'] ?? '',
    refiner: d['refiner'] ?? '',
    refinerNeg: d['refiner_neg'] ?? '',
    facePositive: d['face_pos'] ?? '',
    faceNegative: d['face_neg'] ?? '',
  );

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final map = toMap();
    for (var entry in map.entries) {
      await prefs.setString(entry.key, entry.value);
    }
  }
}

// ─── PromptTemplate ───────────────────────────────────────────

class PromptTemplate {
  String name;
  PromptData data;
  PromptTemplate({required this.name, required this.data});

  Map<String, dynamic> toJson() => {'name': name, 'data': data.toMap()};

  static PromptTemplate fromJson(Map<String, dynamic> json) {
    final d = json['data'] as Map<String, dynamic>;
    return PromptTemplate(name: json['name'], data: PromptData.fromMap(d));
  }
}

// ─── TemplateStorage ──────────────────────────────────────────

class TemplateStorage {
  static Future<List<PromptTemplate>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('templates');
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => PromptTemplate.fromJson(e)).toList();
  }

  static Future<void> save(List<PromptTemplate> templates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'templates', jsonEncode(templates.map((t) => t.toJson()).toList()));
  }
}

// ─── LoraInfo / LoraGroup ─────────────────────────────────────

class LoraInfo {
  String name;
  bool enabled;
  double strength;
  String nodeId;
  LoraInfo({
    required this.name,
    this.enabled = false,
    this.strength = 1.0,
    required this.nodeId,
  });
}

class LoraGroup {
  final String nodeId;
  final String title;
  final List<LoraInfo> loras;
  LoraGroup({required this.nodeId, required this.title, required this.loras});
}

// ─── NodeGroupInfo ────────────────────────────────────────────

class NodeGroupInfo {
  final String sectionKey;
  final List<String> nodeIds;
  bool enabled;
  NodeGroupInfo({
    required this.sectionKey,
    required this.nodeIds,
    required this.enabled,
  });
}

// ─── ComfyUIService ──────────────────────────────────────────

class ComfyUIService {
  String serverUrl = '';
  final Map<String, String> nodeNames = {};
  String? _workflowRaw;
  String _activeWorkflowId = 'default';
  int lastSeed = 0;
  Map<String, bool> nodeEnabled = {};
  String? _lastPromptId;

  /// Секции, реально присутствующие в текущем воркфлоу
  Set<String> availableSections = {};

  String get activeWorkflowId => _activeWorkflowId;

  /// Переключить чекпоинт в текущем воркфлоу
  void setCheckpointInWorkflow(String checkpointName) {
    if (_workflowRaw == null) return;
    Map<String, dynamic> wf = jsonDecode(_workflowRaw!);
    wf.forEach((id, node) {
      if (node is! Map) return;
      if (node['class_type'] == 'CheckpointLoaderSimple') {
        node['inputs']['ckpt_name'] = checkpointName;
      }
    });
    _workflowRaw = jsonEncode(wf);
  }

  /// Переключить VAE в текущем воркфлоу
  void setVaeInWorkflow(String vaeName) {
    if (_workflowRaw == null) return;
    Map<String, dynamic> wf = jsonDecode(_workflowRaw!);
    wf.forEach((id, node) {
      if (node is! Map) return;
      if (node['class_type'] == 'VAELoader') {
        node['inputs']['vae_name'] = vaeName;
      }
    });
    _workflowRaw = jsonEncode(wf);
  }

  /// Получить текущий чекпоинт из воркфлоу
  String? getCurrentCheckpoint() {
    if (_workflowRaw == null) return null;
    final wf = jsonDecode(_workflowRaw!) as Map<String, dynamic>;
    for (final node in wf.values) {
      if (node is Map && node['class_type'] == 'CheckpointLoaderSimple') {
        return node['inputs']?['ckpt_name']?.toString();
      }
    }
    return null;
  }

  // ── Загрузка воркфлоу ────────────────────────────────────

  Future<void> loadWorkflow() async {
    _workflowRaw = await rootBundle.loadString('assets/workflow_api.json');
    _activeWorkflowId = 'default';
    nodeEnabled.clear();
    _parseWorkflow();
  }

  Future<void> loadWorkflow2() async {
    _workflowRaw = await rootBundle.loadString('assets/workflow_api_2.json');
    _activeWorkflowId = 'workflow2';
    nodeEnabled.clear();
    _parseWorkflow();
  }

  Future<void> loadWorkflowFromFile(String filePath) async {
    final file = File(filePath);
    _workflowRaw = await file.readAsString();
    _activeWorkflowId = 'custom';
    nodeEnabled.clear();
    _parseWorkflow();
  }

  Future<void> loadWorkflowFromString(String jsonString) async {
    _workflowRaw = jsonString;
    nodeEnabled.clear();
    _parseWorkflow();
  }

  void _parseWorkflow() {
    nodeNames.clear();
    try {
      final wf = jsonDecode(_workflowRaw!) as Map<String, dynamic>;
      wf.forEach((id, node) {
        if (node is Map && node.containsKey('class_type')) {
          nodeNames[id] = node['class_type'];
        }
      });
    } catch (_) {}
  }

  String? get workflowRaw => _workflowRaw;

  // ── Сервер ───────────────────────────────────────────────

  Future<bool> checkServer() async {
    try {
      final r = await http
          .get(Uri.parse('$serverUrl/system_stats'))
          .timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) {
        // Кэшируем последние stats для offline просмотра
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_system_stats', r.body);
        return true;
      }
      return false;
    } on SocketException {
      return false;
    } on HttpException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Получить кэшированные stats (для offline)
  static Future<Map<String, dynamic>> getCachedStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cached_system_stats');
    if (raw != null) {
      try {
        return jsonDecode(raw);
      } catch (_) {}
    }
    return {};
  }


  String getNodeDisplayName(String nodeId) {
    final name = nodeNames[nodeId];
    if (name == null) return 'Нода #$nodeId';
    return '$name (#$nodeId)';
  }

  // ── Лора-группы ──────────────────────────────────────────

  List<LoraGroup> extractLoraGroups() {
    if (_workflowRaw == null) return [];
    final wf = jsonDecode(_workflowRaw!) as Map<String, dynamic>;
    final List<LoraGroup> groups = [];

    final Map<String, String> nodeToStage;
    if (_activeWorkflowId == 'workflow2') {
      nodeToStage = {
        '658': '1. Z-Image База',
        '652': '2. Pony',
        '659': '3. HandFix',
        '674': '5. Refiner',
        '660': '6. FaceDetailer',
      };
    } else {
      nodeToStage = {
        '36': '1. Z-Image База',
        '234': '3. HandFix',
        '354': '5. Refiner',
        '359': '6. FaceDetailer',
      };
    }

    wf.forEach((id, node) {
      if (node is! Map) return;
      if (node['class_type'] == 'Power Lora Loader (rgthree)') {
        final inputs = node['inputs'] as Map<String, dynamic>;
        final List<LoraInfo> loras = [];
        inputs.forEach((key, value) {
          if (key.startsWith('lora_')) {
            String loraName = '';
            bool enabled = false;
            double strength = 1.0;
            if (value is Map) {
              loraName = value['lora']?.toString() ?? '';
              enabled = value['on'] == true;
              strength = (value['strength'] ?? 1.0).toDouble();
            } else if (value is String) {
              loraName = value;
              enabled = true;
            }
            if (loraName.isNotEmpty) {
              loras.add(LoraInfo(
                name: loraName,
                enabled: enabled,
                strength: strength,
                nodeId: id,
              ));
            }
          }
        });
        if (loras.isNotEmpty) {
          final title = nodeToStage[id] ?? 'Нода #$id';
          groups.add(LoraGroup(nodeId: id, title: title, loras: loras));
        }
      }
    });
    return groups;
  }

  // ── Группы нод (авто-определение секций) ─────────────────

  /// Все известные ID нод для каждой секции (оба воркфлоу)
  static const Map<String, List<String>> _allKnownNodes = {
    'zimage': [
      '606', '608', '610', '658', '672', '678', '679', // workflow2
      '34', '35', '36', '31', '30', '33', '98',        // default
    ],
    'pony': [
      '639', '629', '652', '653', '651', '654', '655', '576', '599', // workflow2
      '4', '5', '6', '7', '8', '10', '1',                            // default
    ],
    'handfix': [
      '630', '612', '614', '659', '603', '602', '604', // workflow2
      '322', '323', '324', '325', '234', '233', '232', // default
    ],
    'refiner': [
      '657', '620', '674', '675', '680', '621', '625', // workflow2
      '134', '354', '357', '358', '349', '128',        // default
    ],
    'face': [
      '662', '660', '676', '661', '569',               // workflow2
      '48', '45', '235', '231', '359', '47', '251',    // default
    ],
  };

  Map<String, NodeGroupInfo> extractNodeGroups() {
    if (_workflowRaw == null) return {};
    final wf = jsonDecode(_workflowRaw!) as Map<String, dynamic>;
    final Map<String, NodeGroupInfo> groups = {};

    availableSections.clear();

    _allKnownNodes.forEach((section, allNodeIds) {
      // Оставляем только ноды, которые реально есть в воркфлоу
      final existingIds =
      allNodeIds.where((id) => wf.containsKey(id)).toList();

      if (existingIds.isEmpty) {
        // Секции нет в воркфлоу — принудительно выключаем
        nodeEnabled[section] = false;
        return;
      }

      // Секция найдена
      availableSections.add(section);

      final mainNodeId = existingIds.first;
      final node = wf[mainNodeId];
      final mode = (node is Map) ? (node['mode'] ?? 0) : 0;
      final enabled = mode == 0;

      groups[section] = NodeGroupInfo(
        sectionKey: section,
        nodeIds: existingIds,
        enabled: enabled,
      );

      // Устанавливаем nodeEnabled только если ещё не задан вручную
      if (!nodeEnabled.containsKey(section)) {
        nodeEnabled[section] = enabled;
      }
    });

    // Дополнительная проверка по class_type
    _autoDetectUnknownSections(wf);

    return groups;
  }

  /// Проверяем наличие ключевых class_type, если секция
  /// не была найдена по известным ID нод
  void _autoDetectUnknownSections(Map<String, dynamic> wf) {
    bool hasFaceDetailer = false;

    wf.forEach((id, node) {
      if (node is! Map) return;
      final ct = node['class_type']?.toString() ?? '';
      if (ct == 'FaceDetailer') hasFaceDetailer = true;
    });

    // Если нет FaceDetailer ноды — face точно недоступен
    if (!hasFaceDetailer) {
      availableSections.remove('face');
    }
  }

  /// Проверить, доступна ли секция в текущем воркфлоу
  bool isSectionAvailable(String sectionKey) {
    return availableSections.contains(sectionKey);
  }

  // ── Сборка воркфлоу ─────────────────────────────────────

  Map<String, dynamic> buildWorkflow(
      PromptData prompts, {
        int? width,
        int? height,
        int? customSeed,
        List<LoraGroup>? loraGroups,
      }) {
    if (_workflowRaw == null) throw Exception('Воркфлоу не загружен');
    Map<String, dynamic> wf = jsonDecode(_workflowRaw!);

    // ── Динамическое построение sectionNodes ──
    // Берём только те ID, которые реально есть в воркфлоу
    final sectionNodes = <String, List<String>>{};
    _allKnownNodes.forEach((section, allIds) {
      final existing = allIds.where((id) => wf.containsKey(id)).toList();
      if (existing.isNotEmpty) {
        sectionNodes[section] = existing;
      }
    });

    // Применяем включение/выключение нод
    nodeEnabled.forEach((section, enabled) {
      final ids = sectionNodes[section];
      if (ids != null) {
        for (var id in ids) {
          if (wf.containsKey(id) && wf[id] is Map) {
            wf[id]['mode'] = enabled ? 0 : 4;
          }
        }
      }
    });

    // ── Seed ──
    final seed = customSeed ?? Random().nextInt(2147483647);
    lastSeed = seed;

    wf.forEach((id, node) {
      if (node is! Map) return;
      final ct = node['class_type'];
      if (ct == 'KSampler' ||
          ct == 'FaceDetailer' ||
          ct == 'ImageAddNoise' ||
          ct == 'Seed (rgthree)') {
        if (node['inputs']?['seed'] is int ||
            node['inputs']?['seed'] is double) {
          node['inputs']['seed'] = seed;
        }
      }
    });

    // ── Размеры ──
    if (width != null || height != null) {
      wf.forEach((id, node) {
        if (node is! Map) return;
        final ct = node['class_type'];
        if (ct == 'EmptyLatentImage') {
          if (width != null) node['inputs']['width'] = width;
          if (height != null) node['inputs']['height'] = height;
        }
        if (ct == 'SDXL Empty Latent Image (rgthree)') {
          final w = width ?? 1024;
          final h = height ?? 1024;
          String orient = 'square';
          if (w > h) orient = 'landscape';
          if (h > w) orient = 'portrait';
          node['inputs']['dimensions'] = ' $w x $h  ($orient)';
        }
      });
    }

    // ── Лоры ──
    if (loraGroups != null && loraGroups.isNotEmpty) {
      for (var group in loraGroups) {
        if (wf.containsKey(group.nodeId)) {
          final inputs = wf[group.nodeId]['inputs'] as Map<String, dynamic>;
          inputs.forEach((key, value) {
            if (key.startsWith('lora_') && value is Map) {
              final loraName = value['lora']?.toString() ?? '';
              for (var lora in group.loras) {
                if (lora.name == loraName) {
                  value['on'] = lora.enabled;
                  value['strength'] = lora.strength;
                  break;
                }
              }
            }
          });
        }
      }
    }

    // ── Подстановка промптов (динамическая) ──
    _applyPrompts(wf, prompts);

    return wf;
  }

  /// Подставляет промпты в ноды по ID.
  /// Ноды определяются из _allKnownNodes + маппинг ID → поле промпта.
  void _applyPrompts(Map<String, dynamic> wf, PromptData prompts) {
    // Маппинг: ID ноды → (поле промпта, является ли негативным)
    // workflow2
    const w2 = {
      '678': ('zimageBase', false),
      '679': ('zimageNeg', true),
      '675': ('refiner', false),
      '680': ('refinerNeg', true),
      '653': ('ponyPositive', false),
      '651': ('ponyNegative', true),
      '676': ('facePositive', false),
      '661': ('faceNegative', true),
      '603': ('handFixPositive', false),
      '602': ('handFixNegative', true),
    };

    // default
    const w1 = {
      '34': ('zimageBase', false),
      '35': ('zimageNeg', true),
      '358': ('refiner', false),
      '357': ('refinerNeg', true),
      '7': ('ponyPositive', false),
      '5': ('ponyNegative', true),
      '235': ('facePositive', false),
      '231': ('faceNegative', true),
      '325': ('handFixPositive', false),
      '324': ('handFixNegative', true),
    };

    // Объединяем оба маппинга — используются только те ID,
    // которые реально есть в wf
    final allMappings = <String, (String, bool)>{...w1, ...w2};

    // Получаем значение поля промпта по имени
    String getField(String fieldName) {
      switch (fieldName) {
        case 'zimageBase': return prompts.zimageBase;
        case 'zimageNeg': return prompts.zimageNeg;
        case 'ponyPositive': return prompts.ponyPositive;
        case 'ponyNegative': return prompts.ponyNegative;
        case 'handFixPositive': return prompts.handFixPositive;
        case 'handFixNegative': return prompts.handFixNegative;
        case 'refiner': return prompts.refiner;
        case 'refinerNeg': return prompts.refinerNeg;
        case 'facePositive': return prompts.facePositive;
        case 'faceNegative': return prompts.faceNegative;
        default: return '';
      }
    }

    // Фоллбэк: если refiner пуст — подставляем zimage
    String getFallback(String fieldName) {
      switch (fieldName) {
        case 'refiner': return prompts.zimageBase;
        case 'refinerNeg': return prompts.zimageNeg;
        default: return '';
      }
    }

    allMappings.forEach((nodeId, mapping) {
      if (!wf.containsKey(nodeId)) return;

      final fieldName = mapping.$1;
      var value = getField(fieldName);

      // Фоллбэк для refiner
      if (value.isEmpty) {
        value = getFallback(fieldName);
      }

      if (value.isNotEmpty) {
        wf[nodeId]['inputs']['text'] = value;
      }
    });
  }

  // ── Отправка / Отмена / WebSocket ───────────────────────

  Future<String> submitPrompt(Map<String, dynamic> workflow) async {
    final resp = await http.post(
      Uri.parse('$serverUrl/prompt'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'prompt': workflow, 'client_id': 'mobile-app'}),
    );
    if (resp.statusCode != 200) {
      throw Exception('Ошибка сервера: ${resp.body}');
    }
    _lastPromptId = jsonDecode(resp.body)['prompt_id'];
    return _lastPromptId!;
  }

  Future<bool> cancelGeneration() async {
    try {
      final resp = await http.post(
        Uri.parse('$serverUrl/interrupt'),
        headers: {'Content-Type': 'application/json'},
      );
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  WebSocketChannel connectWebSocket() {
    final wsUrl = serverUrl.replaceFirst('http', 'ws');
    return WebSocketChannel.connect(
        Uri.parse('$wsUrl/ws?clientId=mobile-app'));
  }

  // ── Результаты ──────────────────────────────────────────

  Future<List<Uint8List>> fetchResults(String promptId) async {
    List<Uint8List> images = [];
    for (int i = 0; i < 60; i++) { // Макс 2 минуты вместо 30
      await Future.delayed(const Duration(seconds: 2));
      try {
        final resp =
        await http.get(Uri.parse('$serverUrl/history/$promptId'))
            .timeout(const Duration(seconds: 10));
        if (resp.statusCode == 200) {
          final history = jsonDecode(resp.body);
          if (history.containsKey(promptId)) {
            final outputs = history[promptId]['outputs'];
            if (outputs != null) {
              for (var nodeId in outputs.keys) {
                final nodeOut = outputs[nodeId];
                if (nodeOut != null && nodeOut['images'] != null) {
                  for (var img in nodeOut['images']) {
                    final fn = img['filename'];
                    final sub = img['subfolder'] ?? '';
                    final type = img['type'] ?? 'output';
                    if (type == 'temp') continue;
                    final imgResp = await http.get(Uri.parse(
                        '$serverUrl/view?filename=$fn&subfolder=$sub&type=$type'))
                        .timeout(const Duration(seconds: 30));
                    if (imgResp.statusCode == 200) {
                      images.add(imgResp.bodyBytes);
                    }
                  }
                }
              }
            }
            break;
          }
        }
      } catch (_) {}
    }
    return images;
  }

  // ── Загрузка / сохранение изображений ───────────────────

  Future<String> uploadImage(Uint8List imageBytes, String filename) async {
    var request = http.MultipartRequest(
        'POST', Uri.parse('$serverUrl/upload/image'));
    request.files.add(http.MultipartFile.fromBytes('image', imageBytes,
        filename: filename));
    request.fields['overwrite'] = 'true';
    final resp = await request.send();
    final body = await resp.stream.bytesToString();
    if (resp.statusCode != 200) throw Exception('Ошибка загрузки: $body');
    final data = jsonDecode(body);
    return data['name'];
  }

  static Future<String> saveImage(Uint8List imageBytes) async {
    final dir = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final comfyDir = Directory('${dir.path}/ComfyUI_Remote');
    if (!await comfyDir.exists()) await comfyDir.create(recursive: true);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File('${comfyDir.path}/comfyui_$ts.png');
    await file.writeAsBytes(imageBytes);
    return file.path;
  }

  // ── Wake-on-LAN ─────────────────────────────────────────

  static Future<void> sendWakeOnLan(String macAddress) async {
    final mac = macAddress.replaceAll(RegExp(r'[:-]'), '').toUpperCase();
    if (mac.length != 12) throw Exception('Неверный MAC-адрес');
    final macBytes = List.generate(
        6, (i) => int.parse(mac.substring(i * 2, i * 2 + 2), radix: 16));
    final packet = <int>[];
    packet.addAll(List.filled(6, 0xFF));
    for (int i = 0; i < 16; i++) {
      packet.addAll(macBytes);
    }
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      socket.send(
          Uint8List.fromList(packet), InternetAddress('255.255.255.255'), 9);
      socket.send(
          Uint8List.fromList(packet), InternetAddress('255.255.255.255'), 7);
    } finally {
      socket?.close();
    }
  }

  // ── Модели с сервера (object_info) ──────────────────────

  /// Кэш object_info чтобы не дёргать сервер каждый раз
  Map<String, dynamic>? _objectInfoCache;

  /// Загрузить object_info с сервера (все ноды и их параметры)
  Future<Map<String, dynamic>> getObjectInfo() async {
    if (_objectInfoCache != null) return _objectInfoCache!;
    try {
      final resp = await http
          .get(Uri.parse('$serverUrl/object_info'))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        _objectInfoCache = jsonDecode(resp.body);
        return _objectInfoCache!;
      }
    } catch (_) {}
    return {};
  }

  /// Сбросить кэш (при смене сервера)
  void clearObjectInfoCache() {
    _objectInfoCache = null;
  }

  /// Получить список чекпоинтов с сервера
  Future<List<String>> getCheckpoints() async {
    final info = await getObjectInfo();
    return _extractModelList(info, 'CheckpointLoaderSimple', 'ckpt_name');
  }

  /// Получить список LoRA с сервера
  Future<List<String>> getServerLoras() async {
    final info = await getObjectInfo();
    // Пробуем несколько вариантов нод
    var list = _extractModelList(info, 'LoraLoader', 'lora_name');
    if (list.isEmpty) {
      list = _extractModelList(info, 'Power Lora Loader (rgthree)', 'lora_name');
    }
    return list;
  }

  /// Получить список VAE с сервера
  Future<List<String>> getVaeModels() async {
    final info = await getObjectInfo();
    return _extractModelList(info, 'VAELoader', 'vae_name');
  }

  /// Получить список сэмплеров
  Future<List<String>> getSamplers() async {
    final info = await getObjectInfo();
    return _extractModelList(info, 'KSampler', 'sampler_name');
  }

  /// Получить список шедулеров
  Future<List<String>> getSchedulers() async {
    final info = await getObjectInfo();
    return _extractModelList(info, 'KSampler', 'scheduler');
  }

  /// Универсальный метод извлечения списка из object_info
  List<String> _extractModelList(
      Map<String, dynamic> info, String nodeClass, String inputName) {
    try {
      final nodeInfo = info[nodeClass];
      if (nodeInfo == null) return [];
      final inputs = nodeInfo['input'];
      if (inputs == null) return [];

      // Проверяем required и optional
      for (final section in ['required', 'optional']) {
        final sectionData = inputs[section];
        if (sectionData is Map && sectionData.containsKey(inputName)) {
          final fieldInfo = sectionData[inputName];
          if (fieldInfo is List && fieldInfo.isNotEmpty && fieldInfo[0] is List) {
            return (fieldInfo[0] as List).map((e) => e.toString()).toList();
          }
        }
      }
    } catch (_) {}
    return [];
  }

  // ── Системные запросы ───────────────────────────────────

  Future<Map<String, dynamic>> getSystemStats() async {
    try {
      final resp = await http
          .get(Uri.parse('$serverUrl/system_stats'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        // Кэшируем
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_system_stats', resp.body);
        return data;
      }
    } on SocketException {
      // Offline — возвращаем кэш
      return await getCachedStats();
    } catch (_) {}
    return await getCachedStats();
  }

  Future<Map<String, dynamic>> getHistory({int maxItems = 20}) async {
    try {
      final resp = await http
          .get(Uri.parse('$serverUrl/history'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) return jsonDecode(resp.body);
    } catch (_) {}
    return {};
  }
}
