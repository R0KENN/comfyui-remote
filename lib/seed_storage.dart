// lib/seed_storage.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SavedSeed {
  final int seed;
  final String date;
  final String time;
  final String promptPreview;
  final String generationTime;

  SavedSeed({
    required this.seed,
    required this.date,
    required this.time,
    required this.promptPreview,
    required this.generationTime,
  });

  Map<String, dynamic> toJson() => {
    'seed': seed,
    'date': date,
    'time': time,
    'prompt': promptPreview,
    'genTime': generationTime,
  };

  static SavedSeed fromJson(Map<String, dynamic> j) => SavedSeed(
    seed: j['seed'] ?? 0,
    date: j['date'] ?? '',
    time: j['time'] ?? '',
    promptPreview: j['prompt'] ?? '',
    generationTime: j['genTime'] ?? '',
  );
}

class SeedStorage {
  static const _key = 'saved_seeds_v1';
  static const int maxSeeds = 100;

  static Future<List<SavedSeed>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => SavedSeed.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<SavedSeed> seeds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(seeds.map((s) => s.toJson()).toList()));
  }

  static Future<void> add(SavedSeed seed) async {
    final list = await load();
    // Не дублировать один и тот же сид
    if (list.any((s) => s.seed == seed.seed)) return;
    list.insert(0, seed);
    if (list.length > maxSeeds) list.removeLast();
    await save(list);
  }

  static Future<void> remove(int index) async {
    final list = await load();
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      await save(list);
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
