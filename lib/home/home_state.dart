import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services.dart';
import '../gallery_screen.dart';
import 'dart:async';

/// Все переменные состояния HomeScreen, вынесенные отдельно
mixin HomeStateMixin<T extends StatefulWidget> on State<T> {
  final ComfyUIService service = ComfyUIService();

  final serverCtrl = TextEditingController();
  final macCtrl = TextEditingController();
  final seedCtrl = TextEditingController();
  final zimageBaseCtrl = TextEditingController();
  final zimageNegCtrl = TextEditingController();
  final ponyPosCtrl = TextEditingController();
  final ponyNegCtrl = TextEditingController();
  final handFixPosCtrl = TextEditingController();
  final handFixNegCtrl = TextEditingController();
  final refinerCtrl = TextEditingController();
  final refinerNegCtrl = TextEditingController();
  final facePosCtrl = TextEditingController();
  final faceNegCtrl = TextEditingController();

  String activeWorkflowName = 'Z-Image';
  String geminiApiKey = '';
  bool aiGenerating = false;
  int aiElapsed = 0;
  Timer? aiTimer;
  Map<String, NodeGroupInfo> nodeGroups = {};

  bool isGenerating = false;
  double progress = 0;
  String status = '';
  String currentNode = '';
  bool serverOnline = false;
  List<Uint8List> lastImages = [];
  Uint8List? previewImage;
  String lastTime = '';
  GenerationInfo? lastInfo;
  bool editingServer = false;

  int width = 1024;
  int height = 1024;

  Uint8List? img2imgBytes;
  String? img2imgName;

  Timer? timer;
  int elapsed = 0;

  int currentTab = 0;

  List<String> sectionOrder = [
    'settings',
    'loras',
    'zimage',
    'pony',
    'handfix',
    'refiner',
    'face'
  ];

  final Map<String, bool> expanded = {
    'zimage': true,
    'pony': false,
    'handfix': false,
    'refiner': false,
    'face': false,
    'settings': false,
    'loras': false,
  };

  final Map<String, bool> negOpen = {
    'zimage': false,
    'pony': false,
    'handfix': false,
    'refiner': false,
    'face': false,
  };

  final Map<String, List<String>> pinnedNegTags = {
    'zimage': [],
    'pony': [],
    'handfix': [],
    'refiner': [],
    'face': [],
  };

  List<PromptTemplate> templates = [];
  List<LoraGroup> loraGroups = [];
  final Map<String, bool> loraGroupOpen = {};
  WebSocketChannel? ws;

  static const List<Map<String, dynamic>> resPresets = [
    {'label': '1:1', 'icon': Icons.crop_square, 'w': 1024, 'h': 1024},
    {'label': '3:4', 'icon': Icons.crop_portrait, 'w': 768, 'h': 1024},
    {'label': '4:3', 'icon': Icons.crop_landscape, 'w': 1024, 'h': 768},
    {'label': '9:16', 'icon': Icons.smartphone, 'w': 576, 'h': 1024},
    {'label': '16:9', 'icon': Icons.tv, 'w': 1024, 'h': 576},
    {'label': 'HD', 'icon': Icons.hd, 'w': 1536, 'h': 1536},
    {'label': 'HD 3:4', 'icon': Icons.photo_size_select_large, 'w': 1152, 'h': 1536},
    {'label': 'HD 4:3', 'icon': Icons.photo_size_select_large, 'w': 1536, 'h': 1152},
  ];

  PromptData getPromptData() => PromptData(
    zimageBase: zimageBaseCtrl.text,
    zimageNeg: zimageNegCtrl.text,
    ponyPositive: ponyPosCtrl.text,
    ponyNegative: ponyNegCtrl.text,
    handFixPositive: handFixPosCtrl.text,
    handFixNegative: handFixNegCtrl.text,
    refiner: refinerCtrl.text,
    refinerNeg: refinerNegCtrl.text,
    facePositive: facePosCtrl.text,
    faceNegative: faceNegCtrl.text,
  );

  void loadFromTemplate(PromptTemplate t) {
    final p = t.data;
    zimageBaseCtrl.text = p.zimageBase;
    zimageNegCtrl.text = p.zimageNeg;
    ponyPosCtrl.text = p.ponyPositive;
    ponyNegCtrl.text = p.ponyNegative;
    handFixPosCtrl.text = p.handFixPositive;
    handFixNegCtrl.text = p.handFixNegative;
    refinerCtrl.text = p.refiner;
    refinerNegCtrl.text = p.refinerNeg;
    facePosCtrl.text = p.facePositive;
    faceNegCtrl.text = p.faceNegative;
  }

  String fmtTime(int s) => s >= 60 ? '${s ~/ 60}м ${s % 60}с' : '$sс';

  void disposeControllers() {
    serverCtrl.dispose();
    macCtrl.dispose();
    seedCtrl.dispose();
    zimageBaseCtrl.dispose();
    zimageNegCtrl.dispose();
    ponyPosCtrl.dispose();
    ponyNegCtrl.dispose();
    handFixPosCtrl.dispose();
    handFixNegCtrl.dispose();
    refinerCtrl.dispose();
    refinerNegCtrl.dispose();
    facePosCtrl.dispose();
    faceNegCtrl.dispose();
    timer?.cancel();
    aiTimer?.cancel();
    ws?.sink.close();
  }
}
