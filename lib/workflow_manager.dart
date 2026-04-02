import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class WorkflowInfo {
  final String name;
  final String filePath;
  final bool isBuiltIn;
  final DateTime? addedDate;

  WorkflowInfo({
    required this.name,
    required this.filePath,
    this.isBuiltIn = false,
    this.addedDate,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'filePath': filePath,
    'isBuiltIn': isBuiltIn,
    'addedDate': addedDate?.toIso8601String(),
  };

  static WorkflowInfo fromJson(Map<String, dynamic> json) => WorkflowInfo(
    name: json['name'] ?? '',
    filePath: json['filePath'] ?? '',
    isBuiltIn: json['isBuiltIn'] ?? false,
    addedDate: json['addedDate'] != null
        ? DateTime.tryParse(json['addedDate'])
        : null,
  );
}

class WorkflowManager {
  static const String _prefsKey = 'saved_workflows';
  static const String _activeKey = 'active_workflow';

  static Future<Directory> _getWorkflowDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/workflows');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<List<WorkflowInfo>> getWorkflows() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    final List<WorkflowInfo> list = [
      WorkflowInfo(
        name: 'Z-Image (без Pony)',
        filePath: 'built_in',
        isBuiltIn: true,
      ),
      WorkflowInfo(
        name: 'Z-Image + Pony',
        filePath: 'built_in_2',
        isBuiltIn: true,
      ),
    ];
    if (raw != null) {
      final saved = jsonDecode(raw) as List;
      for (var item in saved) {
        final wf = WorkflowInfo.fromJson(item);
        if (File(wf.filePath).existsSync()) {
          list.add(wf);
        }
      }
    }
    return list;
  }

  static Future<void> _saveList(List<WorkflowInfo> workflows) async {
    final prefs = await SharedPreferences.getInstance();
    final custom = workflows.where((w) => !w.isBuiltIn).toList();
    await prefs.setString(
        _prefsKey, jsonEncode(custom.map((w) => w.toJson()).toList()));
  }

  static Future<String?> getActiveWorkflowPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeKey);
  }

  static Future<void> setActiveWorkflow(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null || path == 'built_in') {
      await prefs.remove(_activeKey);
    } else {
      await prefs.setString(_activeKey, path);
    }
  }

  static Future<WorkflowInfo?> importWorkflow() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return null;
    final pickedFile = result.files.first;
    if (pickedFile.path == null) return null;

    final sourceFile = File(pickedFile.path!);
    final content = await sourceFile.readAsString();

    // Проверяем что это валидный JSON
    try {
      final parsed = jsonDecode(content);
      if (parsed is! Map) throw Exception('Не является workflow');
    } catch (e) {
      throw Exception('Невалидный JSON файл: $e');
    }

    final dir = await _getWorkflowDir();
    final name = pickedFile.name.replaceAll('.json', '');
    final destPath = '${dir.path}/${pickedFile.name}';
    await sourceFile.copy(destPath);

    final info = WorkflowInfo(
      name: name,
      filePath: destPath,
      addedDate: DateTime.now(),
    );

    final workflows = await getWorkflows();
    workflows.add(info);
    await _saveList(workflows);

    return info;
  }

  static Future<void> deleteWorkflow(WorkflowInfo workflow) async {
    if (workflow.isBuiltIn) return;
    try {
      final file = File(workflow.filePath);
      if (await file.exists()) await file.delete();
    } catch (_) {}

    final workflows = await getWorkflows();
    workflows.removeWhere((w) => w.filePath == workflow.filePath);
    await _saveList(workflows);

    final active = await getActiveWorkflowPath();
    if (active == workflow.filePath) {
      await setActiveWorkflow(null);
    }
  }
}
