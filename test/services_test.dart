import 'package:flutter_test/flutter_test.dart';
import 'package:comfyui_remote/services.dart';

void main() {
  group('PromptData', () {
    test('toMap и fromMap roundtrip', () {
      final original = PromptData(
        zimageBase: 'a girl in a park',
        zimageNeg: 'bad quality',
        ponyPositive: 'score_99, 1girl',
        ponyNegative: 'tattoo',
        handFixPositive: 'detailed hands',
        handFixNegative: '',
        refiner: 'refiner text',
        refinerNeg: 'refiner neg',
        facePositive: 'beautiful face',
        faceNegative: 'ugly',
      );

      final map = original.toMap();
      final restored = PromptData.fromMap(map);

      expect(restored.zimageBase, original.zimageBase);
      expect(restored.zimageNeg, original.zimageNeg);
      expect(restored.ponyPositive, original.ponyPositive);
      expect(restored.ponyNegative, original.ponyNegative);
      expect(restored.handFixPositive, original.handFixPositive);
      expect(restored.handFixNegative, original.handFixNegative);
      expect(restored.refiner, original.refiner);
      expect(restored.refinerNeg, original.refinerNeg);
      expect(restored.facePositive, original.facePositive);
      expect(restored.faceNegative, original.faceNegative);
    });

    test('fromMap с пустой картой возвращает пустые строки', () {
      final data = PromptData.fromMap({});
      expect(data.zimageBase, '');
      expect(data.refiner, '');
    });

    test('fromMap с null значениями возвращает пустые строки', () {
      final data = PromptData.fromMap({
        'zimage_base': null,
        'pony_pos': null,
      });
      expect(data.zimageBase, '');
      expect(data.ponyPositive, '');
    });
  });

  group('PromptTemplate', () {
    test('toJson и fromJson roundtrip', () {
      final template = PromptTemplate(
        name: 'Test Template',
        data: PromptData(zimageBase: 'test prompt', ponyPositive: 'score_99'),
      );

      final json = template.toJson();
      final restored = PromptTemplate.fromJson(json);

      expect(restored.name, 'Test Template');
      expect(restored.data.zimageBase, 'test prompt');
      expect(restored.data.ponyPositive, 'score_99');
    });
  });

  group('LoraInfo', () {
    test('создаётся с правильными defaults', () {
      final lora = LoraInfo(name: 'test_lora', nodeId: '36');
      expect(lora.enabled, false);
      expect(lora.strength, 1.0);
      expect(lora.name, 'test_lora');
    });
  });

  group('ComfyUIService', () {
    late ComfyUIService service;

    setUp(() {
      service = ComfyUIService();
    });

    test('начальное состояние', () {
      expect(service.serverUrl, '');
      expect(service.nodeNames, isEmpty);
      expect(service.workflowRaw, isNull);
      expect(service.lastSeed, 0);
    });

    test('getNodeDisplayName без загруженного воркфлоу', () {
      expect(service.getNodeDisplayName('123'), 'Нода #123');
    });

    test('extractLoraGroups без воркфлоу возвращает пустой список', () {
      expect(service.extractLoraGroups(), isEmpty);
    });

    test('extractNodeGroups без воркфлоу возвращает пустую map', () {
      expect(service.extractNodeGroups(), isEmpty);
    });

    test('isSectionAvailable возвращает false без воркфлоу', () {
      expect(service.isSectionAvailable('zimage'), false);
      expect(service.isSectionAvailable('pony'), false);
    });

    test('buildWorkflow бросает исключение без воркфлоу', () {
      expect(
            () => service.buildWorkflow(PromptData()),
        throwsException,
      );
    });

    test('loadWorkflowFromString и парсинг', () async {
      const testWf = '{"1": {"class_type": "KSampler", "inputs": {"seed": 42}}}';
      await service.loadWorkflowFromString(testWf);

      expect(service.workflowRaw, isNotNull);
      expect(service.nodeNames['1'], 'KSampler');
    });

    test('buildWorkflow подставляет seed', () async {
      const testWf =
          '{"1": {"class_type": "KSampler", "inputs": {"seed": 42}}}';
      await service.loadWorkflowFromString(testWf);

      final wf = service.buildWorkflow(
        PromptData(zimageBase: 'test'),
        customSeed: 999,
      );

      expect(wf['1']['inputs']['seed'], 999);
      expect(service.lastSeed, 999);
    });

    test('buildWorkflow с рандомным seed генерирует валидное значение',
            () async {
          const testWf =
              '{"1": {"class_type": "KSampler", "inputs": {"seed": 0}}}';
          await service.loadWorkflowFromString(testWf);

          final wf = service.buildWorkflow(PromptData());
          final seed = wf['1']['inputs']['seed'] as int;
          expect(seed, greaterThan(0));
          expect(seed, lessThan(2147483647));
        });

    test('buildWorkflow подставляет размеры в EmptyLatentImage', () async {
      const testWf =
          '{"1": {"class_type": "EmptyLatentImage", "inputs": {"width": 512, "height": 512}}}';
      await service.loadWorkflowFromString(testWf);

      final wf = service.buildWorkflow(
        PromptData(),
        width: 1024,
        height: 768,
      );

      expect(wf['1']['inputs']['width'], 1024);
      expect(wf['1']['inputs']['height'], 768);
    });

    test('clearObjectInfoCache сбрасывает кэш', () {
      service.clearObjectInfoCache();
      // Не бросает исключение
    });
  });
}
