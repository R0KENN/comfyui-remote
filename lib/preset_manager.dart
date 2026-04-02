import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'services.dart';

class Preset {
  String name;
  final DateTime created;
  final PromptData prompts;
  final int width;
  final int height;
  final String seed;
  final Map<String, bool> nodeEnabled;
  final Map<String, List<String>> pinnedNegTags;
  final List<Map<String, dynamic>> loraStates;

  Preset({
    required this.name,
    required this.created,
    required this.prompts,
    required this.width,
    required this.height,
    required this.seed,
    required this.nodeEnabled,
    required this.pinnedNegTags,
    required this.loraStates,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'created': created.toIso8601String(),
    'prompts': prompts.toMap(),
    'width': width,
    'height': height,
    'seed': seed,
    'nodeEnabled': nodeEnabled,
    'pinnedNegTags': pinnedNegTags,
    'loraStates': loraStates,
  };

  static Preset fromJson(Map<String, dynamic> j) => Preset(
    name: j['name'] ?? '',
    created: DateTime.tryParse(j['created'] ?? '') ?? DateTime.now(),
    prompts: PromptData.fromMap(j['prompts'] ?? {}),
    width: j['width'] ?? 1024,
    height: j['height'] ?? 1024,
    seed: j['seed'] ?? '-1',
    nodeEnabled: Map<String, bool>.from(j['nodeEnabled'] ?? {}),
    pinnedNegTags: (j['pinnedNegTags'] as Map? ?? {}).map(
            (k, v) => MapEntry(k.toString(), List<String>.from(v ?? []))),
    loraStates: (j['loraStates'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList(),
  );
}

class PresetStorage {
  static const _key = 'user_presets';

  static Future<List<Preset>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Preset.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<Preset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(presets.map((p) => p.toJson()).toList()));
  }

  static Future<void> add(Preset preset) async {
    final list = await load();
    list.insert(0, preset);
    if (list.length > 30) list.removeLast();
    await save(list);
  }

  static Future<void> remove(int index) async {
    final list = await load();
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      await save(list);
    }
  }
}
