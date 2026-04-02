import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:typed_data';

class AiPromptResult {
  final String zimageBase;
  final String ponyPositive;
  final String ponyNegativeAdd;
  final String faceDetailer;
  final String faceDetailerNegAdd;
  final String handFixAdd;
  final String refinerNote;

  AiPromptResult({
    required this.zimageBase,
    required this.ponyPositive,
    required this.ponyNegativeAdd,
    required this.faceDetailer,
    required this.faceDetailerNegAdd,
    this.handFixAdd = '',
    this.refinerNote = '',
  });
}

class AiPromptService {
  final String apiKey;
  final String model;

  final bool useMethodichka;

  AiPromptService({
    required this.apiKey,
    this.model = 'google/gemini-2.5-flash',
    this.useMethodichka = true,
  });

  static const String _freeSystemPrompt = '''
Ты — эксперт по написанию промптов для Stable Diffusion / ComfyUI.
Пользователь описывает сцену на русском. Ты генерируешь качественные промпты на английском.

ФОРМАТ ОТВЕТА — строго JSON, без markdown, без комментариев:
{
  "zimage_base": "подробное описание сцены на английском, 80-250 слов, натуральный язык, без Danbooru-тегов",
  "pony_positive": "Danbooru-теги: score_99, score_average, rating_safe/questionable/explicit, далее теги стиля, одежды, позы",
  "pony_negative_add": "теги негативного промпта для Pony",
  "face_detailer": "описание лица на английском, 20-60 слов",
  "face_detailer_neg_add": "негативные теги для лица",
  "handfix_add": "описание предмета в руках или пустая строка",
  "refiner_note": "копия Z-Image базы"
}

Все промпты должны описывать ОДНУ И ТУ ЖЕ СЦЕНУ.
Отвечай ТОЛЬКО JSON. Никакого текста до или после JSON.
''';

  static const String _systemPrompt = '''
Ты — эксперт по написанию промптов для ComfyUI workflow.
Workflow состоит из этапов: Z-Image База, Pony Refine, HandFix, Upscale, Z-Image Refiner, FaceDetailer, CRT Post-Process.

ПЕРСОНАЖ: nabioli1
- Азиатская девушка, 20-25 лет
- Светлая/бледная кожа (fair skin / pale skin)
- Тёмные волнистые волосы чуть ниже плеч, с рваной чёлкой и прядями на лоб (dark wavy hair falling just below the shoulders with messy curtain bangs and loose strands across forehead)
- Стройное телосложение (slender figure)
- Грудь чуть больше среднего (medium-large breasts / slightly above average breasts)
- Полные естественные губы (full natural lips)
- Натуральный вид, без макияжа или минимальный макияж
- Никаких тату — кожа чистая (clean skin with no tattoos)

ПРАВИЛА Z-IMAGE (этапы 1, 5, 6):
- Триггер nabioli1 ВСЕГДА в начале
- ТОЛЬКО натуральный язык — НИКАКИХ Danbooru-тегов, НИКАКИХ скобок с весами
- 80-250 слов для Базы, 60-150 слов для Refiner
- Описывать: камеру, тип кадра, субъект, одежду, позу, окружение, освещение, текстуру кожи, ограничения
- ВСЕГДА включать: clean skin with no tattoos, natural skin texture with visible pores, no retouching, no airbrushing
- ВСЕГДА включать размер груди: slightly above average breasts / medium-large natural breasts
- ВСЕГДА включать описание волос и губ
- В конце: no tattoos anywhere on her body, no text, no watermark, correct anatomy, sharp focus

ПРАВИЛА PONY (этап 2):
- Триггер nabioli1 НЕ ставить!
- Формат: Danbooru-теги + натуральный язык, скобки с весами допустимы
- Score-теги ОБЯЗАТЕЛЬНО первыми: score_99, score_average, rating_[тип]
- rating_safe для SFW, rating_questionable для полу, rating_explicit для NSFW
- Далее: photo of a woman, 1girl, solo
- Грудь: (medium-large breasts:1.2)
- Одежда: (описание:1.2-1.3)
- Текстура: (natural skin pores texture:1.3), (visible pores:1.2), (real human skin:1.3)
- Максимум весов 1.5, максимум 4-6 элементов с усиленным весом
- ВСЕГДА: no tattoos
- В конце: raw unedited, unretouched, photorealistic

ПРАВИЛА FACEDETAILER (этап 6):
- Триггер nabioli1 — ДА
- 20-60 слов
- ТОЛЬКО лицо и шея — НЕ описывать тело, одежду, окружение
- Описывать: выражение лица, волосы вокруг лица, губы, текстуру кожи
- ВСЕГДА: clean skin on face and neck with no tattoos, visible pores, real human skin
- sharp focus on eyes, unretouched

НЕГАТИВЫ:
- Pony негатив ВСЕГДА добавлять: tattoo, neck tattoo, chest tattoo, face tattoo, tribal tattoo, body tattoo, arm tattoo
- FaceDetailer негатив: tattoo, face tattoo, neck tattoo
- Ситуативно добавлять: airbrushed, plastic skin, glamour, perfect skin, heavy makeup, glasses, piercing и т.д.

ФОРМАТ ОТВЕТА — строго JSON, без markdown, без комментариев:
{
  "zimage_base": "nabioli1, ...",
  "pony_positive": "score_99, score_average, rating_..., photo of a woman, 1girl, solo, ...",
  "pony_negative_add": "tattoo, neck tattoo, chest tattoo, face tattoo, tribal tattoo, body tattoo, arm tattoo",
  "face_detailer": "nabioli1, ...",
  "face_detailer_neg_add": "tattoo, face tattoo, neck tattoo",
  "handfix_add": "",
  "refiner_note": "копия Z-Image базы"
}

handfix_add — пустая строка если руки пустые, или описание предмета в руках.
refiner_note — "копия Z-Image базы" или корректировка если нужна.

ВСЕ промпты должны описывать ОДНУ И ТУ ЖЕ СЦЕНУ и быть согласованы.
Отвечай ТОЛЬКО JSON. Никакого текста до или после JSON.
''';

  AiPromptResult _parseResponse(String responseBody) {
    final data = jsonDecode(responseBody);
    final text = data['choices']?[0]?['message']?['content'];

    if (text == null) {
      throw Exception('Empty response from OpenRouter');
    }

    String cleanText = text.toString().trim();
    if (cleanText.startsWith('```json')) {
      cleanText = cleanText.substring(7);
    }
    if (cleanText.startsWith('```')) {
      cleanText = cleanText.substring(3);
    }
    if (cleanText.endsWith('```')) {
      cleanText = cleanText.substring(0, cleanText.length - 3);
    }
    cleanText = cleanText.trim();

    final Map<String, dynamic> parsed = jsonDecode(cleanText);

    return AiPromptResult(
      zimageBase: parsed['zimage_base'] ?? '',
      ponyPositive: parsed['pony_positive'] ?? '',
      ponyNegativeAdd: parsed['pony_negative_add'] ?? 'tattoo, neck tattoo, chest tattoo, face tattoo, tribal tattoo, body tattoo, arm tattoo',
      faceDetailer: parsed['face_detailer'] ?? '',
      faceDetailerNegAdd: parsed['face_detailer_neg_add'] ?? 'tattoo, face tattoo, neck tattoo',
      handFixAdd: parsed['handfix_add'] ?? '',
      refinerNote: parsed['refiner_note'] ?? '',
    );
  }

  Future<http.Response> _sendRequest(Map<String, dynamic> requestBody) async {
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        'HTTP-Referer': 'https://comfygo.app',
        'X-Title': 'ComfyGo',
      },
      body: jsonEncode(requestBody),
    ).timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      throw Exception('OpenRouter API error ${response.statusCode}: ${response.body}');
    }
    return response;
  }

  Future<AiPromptResult?> generatePrompts(String userRequest) async {
    final response = await _sendRequest({
      'model': model,
      'messages': [
        {'role': 'system', 'content': useMethodichka ? _systemPrompt : _freeSystemPrompt},
        {'role': 'user', 'content': userRequest},
      ],
      'temperature': 0.8,
      'max_tokens': 4096,
      'response_format': {'type': 'json_object'},
    });
    return _parseResponse(response.body);
  }

  Future<AiPromptResult?> generatePromptsFromImage(String userRequest, Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);

    final response = await _sendRequest({
      'model': model,
      'messages': [
        {'role': 'system', 'content': useMethodichka ? _systemPrompt : _freeSystemPrompt},
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': userRequest.isNotEmpty
                  ? 'Проанализируй это изображение и сгенерируй промпты для воссоздания похожей сцены. Учти пожелания пользователя: $userRequest'
                  : 'Проанализируй это изображение и сгенерируй промпты для воссоздания похожей сцены с персонажем nabioli1. Опиши позу, одежду, окружение, освещение максимально точно.',
            },
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/jpeg;base64,$base64Image',
              },
            },
          ],
        },
      ],
      'temperature': 0.8,
      'max_tokens': 4096,
      'response_format': {'type': 'json_object'},
    });
    return _parseResponse(response.body);
  }
}
