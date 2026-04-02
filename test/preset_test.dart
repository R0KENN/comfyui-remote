import 'package:flutter_test/flutter_test.dart';
import 'package:comfyui_remote/preset_manager.dart';
import 'package:comfyui_remote/services.dart';

void main() {
  group('Preset', () {
    test('toJson и fromJson roundtrip', () {
      final preset = Preset(
        name: 'My Preset',
        created: DateTime(2025, 6, 15),
        prompts: PromptData(
          zimageBase: 'girl in park',
          ponyPositive: 'score_99',
        ),
        width: 1024,
        height: 768,
        seed: '42',
        nodeEnabled: {'zimage': true, 'pony': false},
        pinnedNegTags: {
          'zimage': ['bad', 'ugly']
        },
        loraStates: [
          {
            'nodeId': '36',
            'name': 'test_lora',
            'enabled': true,
            'strength': 0.8
          }
        ],
      );

      final json = preset.toJson();
      final restored = Preset.fromJson(json);

      expect(restored.name, 'My Preset');
      expect(restored.width, 1024);
      expect(restored.height, 768);
      expect(restored.seed, '42');
      expect(restored.prompts.zimageBase, 'girl in park');
      expect(restored.prompts.ponyPositive, 'score_99');
      expect(restored.nodeEnabled['zimage'], true);
      expect(restored.nodeEnabled['pony'], false);
      expect(restored.pinnedNegTags['zimage'], ['bad', 'ugly']);
      expect(restored.loraStates.length, 1);
      expect(restored.loraStates[0]['name'], 'test_lora');
      expect(restored.loraStates[0]['enabled'], true);
      expect(restored.loraStates[0]['strength'], 0.8);
    });

    test('fromJson с пустыми данными не падает', () {
      final preset = Preset.fromJson({});
      expect(preset.name, '');
      expect(preset.width, 1024);
      expect(preset.height, 1024);
      expect(preset.seed, '-1');
      expect(preset.loraStates, isEmpty);
    });

    test('fromJson c null полями', () {
      final preset = Preset.fromJson({
        'name': null,
        'prompts': null,
        'nodeEnabled': null,
        'pinnedNegTags': null,
      });
      expect(preset.name, '');
      expect(preset.prompts.zimageBase, '');
      expect(preset.nodeEnabled, isEmpty);
    });
  });
}
