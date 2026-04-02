import 'package:flutter_test/flutter_test.dart';
import 'package:comfyui_remote/history_screen.dart';

void main() {
  group('HistoryEntry', () {
    test('toJson и fromJson roundtrip', () {
      final entry = HistoryEntry(
        imagePaths: ['/path/a.png', '/path/b.png'],
        seed: 12345,
        date: '15.06.2025',
        time: '14:30:00',
        generationTime: '45с',
        promptPreview: 'a beautiful scene',
        isFavorite: true,
      );

      final json = entry.toJson();
      final restored = HistoryEntry.fromJson(json);

      expect(restored.imagePaths, ['/path/a.png', '/path/b.png']);
      expect(restored.seed, 12345);
      expect(restored.date, '15.06.2025');
      expect(restored.time, '14:30:00');
      expect(restored.generationTime, '45с');
      expect(restored.promptPreview, 'a beautiful scene');
      expect(restored.isFavorite, true);
    });

    test('fromJson с пустыми данными', () {
      final entry = HistoryEntry.fromJson({});
      expect(entry.imagePaths, isEmpty);
      expect(entry.seed, 0);
      expect(entry.date, '');
      expect(entry.isFavorite, false);
    });

    test('isFavorite по умолчанию false', () {
      final entry = HistoryEntry(
        imagePaths: [],
        seed: 0,
        date: '',
        time: '',
        generationTime: '',
        promptPreview: '',
      );
      expect(entry.isFavorite, false);
    });
  });
}
