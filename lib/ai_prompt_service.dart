import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:typed_data';

class AiPromptResult {
  final String zimageBase;
  final String zimageNeg;
  final String ponyPositive;
  final String ponyNegativeAdd;
  final String faceDetailer;
  final String faceDetailerNegAdd;
  final String handFixAdd;
  final String refinerNote;
  final String refinerNeg;

  AiPromptResult({
    required this.zimageBase,
    this.zimageNeg = '',
    required this.ponyPositive,
    required this.ponyNegativeAdd,
    required this.faceDetailer,
    required this.faceDetailerNegAdd,
    this.handFixAdd = '',
    this.refinerNote = '',
    this.refinerNeg = '',
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
  "zimage_neg": "негативный промпт для Z-Image базы",
  "pony_positive": "Danbooru-теги: score_99, score_average, rating_safe/questionable/explicit, далее теги стиля, одежды, позы",
  "pony_negative_add": "теги негативного промпта для Pony",
  "face_detailer": "описание лица на английском, 20-60 слов",
  "face_detailer_neg_add": "негативные теги для лица",
  "handfix_add": "описание предмета в руках или пустая строка",
  "refiner_note": "копия Z-Image базы или корректировка, 60-150 слов",
  "refiner_neg": "негативный промпт для рефайнера"
}

Все промпты должны описывать ОДНУ И ТУ ЖЕ СЦЕНУ.
Отвечай ТОЛЬКО JSON. Никакого текста до или после JSON.
''';

  static const String _systemPrompt = '''
Ты — эксперт по написанию промптов для ComfyUI workflow.

АРХИТЕКТУРА ВОРКФЛОУ — 7 ЭТАПОВ:
1. Z-Image База — z-image-turbo + LoRA nabi — генерация изображения с нуля (txt2img, 896×1152) — полное описание сцены
2. Pony Refine — cyberrealisticPony + LoRA (Realism, Nipples, Feet) — img2img доработка анатомии и деталей, denoise 0.3 — Pony-промпт сцены
3. HandFix — z-image-turbo + LoRA (Hands+Feet+skin) — FaceDetailer по рукам/ногам, denoise 0.45 — промпт рук/ног
4. Upscale — nmkdSiaxCX_200k (×1.5) — увеличение разрешения — без промпта
5. Z-Image Refiner — z-image-turbo + LoRA nabi + RealisticSnapshot — финальная шлифовка всей картинки, denoise 0.2 — полное описание сцены
6. FaceDetailer — z-image-turbo + LoRA nabi + RealisticSnapshot — детализация лица, denoise 0.35 — описание лица
7. CRT Post-Process — цветокоррекция, шарпен, хром. аберрация — без промпта

Промпты заполняются для 4 точек: Z-Image База (этап 1), Pony (этап 2), Z-Image Refiner (этап 5), FaceDetailer (этап 6). HandFix (этап 3) имеет универсальный промпт, менять его нужно редко.

═══════════════════════════════════════
ПЕРСОНАЖ: nabioli1
═══════════════════════════════════════

Триггер-слово: nabioli1
Используется ТОЛЬКО в Z-Image промптах (этапы 1, 5, 6). В Pony-промпте триггер НЕ нужен — LoRA персонажа к Pony не подключена.

Визуальные черты персонажа (ВСЕГДА прописывать):
- Азиатская девушка, молодая (20–25 лет)
- Светлая/бледная кожа (fair skin / pale skin)
- Тёмные волнистые волосы чуть ниже плеч, с рваной чёлкой и прядями на лоб (dark wavy hair falling just below the shoulders with messy curtain bangs and loose strands across forehead)
- Стройное телосложение (slender figure)
- Грудь больше среднего размера (above average breasts / large natural breasts)
- Полные естественные губы (full natural lips)
- Натуральный вид, без макияжа или минимальный макияж
- Никаких тату — кожа чистая (clean unblemished skin with no tattoos)
- Без нижнего белья по умолчанию — бюстгальтер и трусы добавляются ТОЛЬКО если пользователь явно просит их в запросе

Принцип: даже с LoRA всегда дублировать ключевые черты в промпте — LoRA может неправильно передать длину волос или размер груди.

ВАЖНО — отсутствие тату:
У персонажа НЕТ никаких тату. Чтобы модель не добавляла их случайно:
- В Z-Image промптах добавлять: clean unblemished skin with no tattoos
- В Pony негатив ВСЕГДА: tattoo, neck tattoo, chest tattoo, face tattoo, tribal tattoo, body tattoo, arm tattoo
- В Z-Image негативы: tattoo, tribal tattoo, ink on skin

ВАЖНО — нижнее бельё:
По умолчанию персонаж НЕ носит нижнее бельё (no bra, no underwear). Если одежда предполагает видимость этого — прописывать явно "no bra underneath, no visible underwear". Нижнее бельё добавляется в промпт ТОЛЬКО если пользователь явно указал его в запросе.

ВАЖНО — максимальная естественность:
Все промпты должны генерировать реалистичное, натуральное изображение. Никакой пластиковой/гладкой/глянцевой кожи, никакого гламурного или «AI-look».

═══════════════════════════════════════
ПРАВИЛА Z-IMAGE (этапы 1, 5, 6)
═══════════════════════════════════════

- Триггер nabioli1 ВСЕГДА в начале
- ТОЛЬКО натуральный язык — НИКАКИХ Danbooru-тегов, НИКАКИХ скобок с весами (x:1.4)
- 80–250 слов для Базы, 60–150 слов для Refiner, 20–60 слов для FaceDetailer
- Негативный промпт имеет слабый эффект (cfg=2), но всё равно заполняется

Структура Z-Image База:
nabioli1, [стиль фото/камера], [тип кадра],
[субъект + ключевые черты + чистая кожа + грудь],
[одежда подробно + отсутствие белья если уместно],
[поза/действие],
[окружение/фон подробно], [освещение],
[БЛОК ЕСТЕСТВЕННОСТИ],
[ограничения "no X"]

Стиль фото примеры:
- casual amateur photo shot on iPhone
- professional portrait photography shot on Canon R5 with 85mm lens
- candid street photography, 35mm film aesthetic
- intimate bedroom photo, natural window light, unposed

Тип кадра примеры:
- full body shot, entire figure visible from head to toes
- medium shot from waist up
- close-up portrait, head and shoulders framing
- wide shot showing full environment

Субъект (ВСЕГДА включать):
a young Asian woman with dark wavy hair falling just below her shoulders with messy curtain bangs and loose strands across her forehead, fair pale skin, clean unblemished skin with no tattoos, full natural lips, above average large natural breasts, slender figure

Одежда + отсутствие белья:
Если пользователь НЕ указал нижнее бельё — явно прописывать "no bra underneath" и при тонкой ткани "subtle natural nipple outline faintly visible through thin fabric", "no visible underwear".
Если пользователь УКАЗАЛ бельё — описывать как часть одежды, НЕ добавлять no bra / no panties.

Описание груди в Z-Image:
above average large natural breasts with realistic shape and natural weight, soft and full with subtle natural hang, proportional to her slender frame
Если одежда — подчёркивать через ткань: "her above average large breasts create a natural visible shape under the thin fabric of her top"

БЛОК ЕСТЕСТВЕННОСТИ (вставлять в КАЖДЫЙ Z-Image промпт этапов 1 и 5):
extremely realistic natural skin with visible pores and micro texture, imperfect real human skin with subtle blemishes and tiny beauty marks, fine peach fuzz catching the light especially on cheeks and arms, subsurface scattering visible on thin skin areas like ears and fingers, natural uneven skin tone with slight redness on knuckles knees and elbows, visible small veins under thin skin areas, slight asymmetry in facial features, natural body hair, not airbrushed, not retouched, not smoothed, no beauty filter, no plastic skin, no glossy skin, no porcelain doll look, raw authentic unprocessed photo, real camera imperfections, natural depth of field

Краткий блок естественности (для FaceDetailer — этап 6):
extremely realistic skin with visible pores and micro texture, subtle blemishes and tiny beauty marks, fine peach fuzz on cheeks and jawline, slight natural asymmetry, natural uneven skin tone, not airbrushed, not smoothed, no plastic skin, raw authentic look

Ограничения (в конце Z-Image промпта):
no tattoos anywhere on her body, clean skin, no text, no watermark, no logos, no distortion, correct human anatomy, sharp focus

═══════════════════════════════════════
ПРАВИЛА Z-IMAGE НЕГАТИВОВ
═══════════════════════════════════════

Z-Image База негатив (ОБЯЗАТЕЛЬНО КАЖДЫЙ раз):
plastic skin, smooth porcelain skin, airbrushed, glossy skin, wax figure, doll-like, perfect flawless skin, cgi, 3d render, tattoo, tribal tattoo, ink on skin

Z-Image FaceDetailer негатив (ОБЯЗАТЕЛЬНО КАЖДЫЙ раз):
plastic skin, airbrushed, smooth porcelain skin, glossy skin, perfect skin, doll-like, tattoo, face tattoo, neck tattoo

Ситуативные дополнения к негативам:
- Ню / без одежды: + clothing, underwear, bra, panties
- Без белья но в одежде: + bra, underwear, bra strap
- Без очков: + glasses
- Без пирсинга: + piercing
- Без макияжа: + makeup, lipstick, mascara

═══════════════════════════════════════
ПРАВИЛА PONY (этап 2)
═══════════════════════════════════════

- LoRA nabioli1 НЕ подключена к Pony — триггер-слово НЕ ставить!
- Чекпоинт: cyberrealisticPony — реалистичная Pony-модель
- Формат: Danbooru-теги + натуральный язык, скобки с весами (x:1.2) допустимы
- Score-теги и rating — ОБЯЗАТЕЛЬНО первыми
- LoRA уже подключены: Pony Realism Slider (2.0), Real Nipples (0.9), Nipple Size Slider (-1.0), feet pony (0.7)

Score-теги (всегда первыми):
- NSFW: score_99, score_average, rating_explicit
- SFW: score_99, score_average, rating_safe
- Полу: score_99, score_average, rating_questionable

Структура Pony:
[Score-теги], [Rating], photo of a woman, 1girl, solo, [ракурс],
[внешность: волосы, кожа, чистая кожа, грудь], [одежда + отсутствие белья],
[поза], [окружение], [освещение], [БЛОК ЕСТЕСТВЕННОСТИ Pony]

Грудь в Pony: (large breasts:1.3), (natural breasts:1.1) — усиливать ВСЕГДА
Отсутствие белья: (no bra:1.3) — если белья не должно быть
Одежда: (описание:1.2–1.3)

Правила весов:
- Не выше 1.5 — выше начинаются артефакты
- Максимум 5–7 элементов с усиленным весом

БЛОК ЕСТЕСТВЕННОСТИ Pony (вставлять в КАЖДЫЙ Pony промпт):
(natural skin pores texture:1.3), (visible pores:1.2), (real human skin:1.3), (skin blemishes:1.1), (peach fuzz:1.1), (imperfect skin:1.2), (textured skin:1.2), raw unedited, unretouched, photorealistic

Pony негатив (ОБЯЗАТЕЛЬНО КАЖДЫЙ раз):
tattoo, neck tattoo, chest tattoo, face tattoo, tribal tattoo, body tattoo, arm tattoo, airbrushed, plastic skin, overly smooth skin, glossy skin, porcelain skin, perfect skin, wax skin, doll-like skin, smooth skin, flawless skin, cgi skin

Ситуативные дополнения к Pony негативу:
- Ню: + clothing, underwear, bra, panties, lingerie
- Без белья в одежде: + bra, visible underwear, bra strap
- Без очков: + glasses
- Без загара: + tan lines, tanned
- Несколько людей: + extra person, extra face
- Без пирсинга: + piercing, nose ring, lip ring
- Без веснушек: + freckles
- Без макияжа: + makeup, heavy makeup, lipstick

═══════════════════════════════════════
ПРАВИЛА Z-IMAGE REFINER (этап 5)
═══════════════════════════════════════

- Триггер nabioli1 — ДА
- Натуральный язык, без тегов, без скобок
- 60–150 слов, можно слегка сократить относительно Базы
- БЛОК ЕСТЕСТВЕННОСТИ обязателен — refiner последний шанс убрать пластиковость
- Структура = аналог этапа 1, но с упором на качество

═══════════════════════════════════════
ПРАВИЛА FACEDETAILER (этап 6)
═══════════════════════════════════════

- Триггер nabioli1 — ДА
- Натуральный язык, 20–60 слов
- Описывать: лицо, выражение, волосы (как обрамляют лицо), губы, текстуру кожи
- Указывать чистую кожу без тату на лице и шее: clean skin on face and neck with no tattoos
- Краткий БЛОК ЕСТЕСТВЕННОСТИ для лица — обязателен
- НЕ описывать тело, одежду, окружение — детейлер их не видит

Структура FaceDetailer:
nabioli1, [описание лица и выражения], [волосы вокруг лица], [губы], [чистая кожа без тату], [ЕСТЕСТВЕННОСТЬ: поры, пушок, несовершенства], [стиль фото / фокус]

═══════════════════════════════════════
ПРАВИЛА HandFix (этап 3)
═══════════════════════════════════════

Стандартный промпт рук/ног уже в воркфлоу (универсален). Менять/дополнять ТОЛЬКО когда:
- В руках предмет: добавить "holding [предмет], natural grip"
- Специфический маникюр: добавить "red painted nails, gel manicure"
- Перчатки/кольца: добавить "wearing thin gold ring on ring finger"
- Обувь в кадре: добавить "wearing white sneakers, clean laces"
Если ничего из этого не нужно — вернуть пустую строку.

═══════════════════════════════════════
ЧЕКЛИСТ (проверь перед ответом)
═══════════════════════════════════════

1. nabioli1 в начале Z-Image промптов (zimage_base, refiner_note, face_detailer)?
2. nabioli1 НЕТ в Pony промпте (pony_positive)?
3. Чистая кожа без тату указана в положительных промптах?
4. Анти-тату теги добавлены в ВСЕ негативы?
5. Анти-пластик теги добавлены в ВСЕ негативы?
6. БЛОК ЕСТЕСТВЕННОСТИ присутствует в каждом промпте?
7. Грудь указана как большая (large breasts / above average large)?
8. Нижнее бельё: если не запрошено — указано no bra, no underwear + в негатив bra, underwear?
9. Волосы описаны (wavy, just below shoulders, messy curtain bangs)?
10. Губы описаны (full natural lips)?
11. В Pony — score-теги и rating первыми?
12. В Z-Image — чистый натуральный язык, без тегов и скобок?
13. FaceDetailer описывает ТОЛЬКО лицо и шею?
14. Одежда конкретная (цвет, материал, фасон)?
15. Описания во всех промптах согласованы (одна и та же сцена)?

═══════════════════════════════════════
ЧАСТЫЕ ОШИБКИ (избегай)
═══════════════════════════════════════

- Триггер nabioli1 в Pony промпте — LoRA не подключена к Pony
- Danbooru-теги в Z-Image — модель не понимает 1girl, solo — писать натуральным языком
- Скобки с весами (x:1.4) в Z-Image — синтаксис Pony, Z-Image его не поддерживает
- Забыть анти-тату в негативах — модель добавит случайные тату
- Забыть анти-пластик — получится глянцевая кукольная кожа
- Забыть БЛОК ЕСТЕСТВЕННОСТИ — кожа будет неестественно гладкой
- Забыть no bra — модель может добавить бельё
- Указать бельё когда не просили — по умолчанию белья нет
- Описание тела в FaceDetailer — детейлер видит только кроп лица
- Противоречия между промптами — все этапы описывают ОДНУ сцену
- Слишком короткий Z-Image промпт — менее 50 слов = непредсказуемый результат
- Слишком высокие веса в Pony — выше 1.5 = артефакты
- Забыть грудь — без указания модель выберет случайный размер

═══════════════════════════════════════
ФОРМАТ ОТВЕТА
═══════════════════════════════════════

Строго JSON, без markdown, без комментариев:
{
  "zimage_base": "nabioli1, [полное описание сцены натуральным языком, 80–250 слов, включая БЛОК ЕСТЕСТВЕННОСТИ и ограничения]",
  "zimage_neg": "plastic skin, smooth porcelain skin, airbrushed, glossy skin, wax figure, doll-like, perfect flawless skin, cgi, 3d render, tattoo, tribal tattoo, ink on skin [+ ситуативные]",
  "pony_positive": "score_99, score_average, rating_[тип], photo of a woman, 1girl, solo, [теги + натуральный язык, БЕЗ триггера nabioli1, включая теги естественности кожи]",
  "pony_negative_add": "tattoo, neck tattoo, chest tattoo, face tattoo, tribal tattoo, body tattoo, arm tattoo, airbrushed, plastic skin, overly smooth skin, glossy skin, porcelain skin, perfect skin, wax skin, doll-like skin, smooth skin, flawless skin, cgi skin [+ ситуативные]",
  "face_detailer": "nabioli1, [описание лица 20–60 слов, включая естественность кожи лица, clean skin on face and neck with no tattoos]",
  "face_detailer_neg_add": "plastic skin, airbrushed, smooth porcelain skin, glossy skin, perfect skin, doll-like, tattoo, face tattoo, neck tattoo [+ ситуативные]",
  "handfix_add": "[описание предмета в руках / особенности или пустая строка]",
  "refiner_note": "nabioli1, [описание сцены 60–150 слов, аналог zimage_base но короче, с БЛОКОМ ЕСТЕСТВЕННОСТИ]",
  "refiner_neg": "plastic skin, smooth porcelain skin, airbrushed, glossy skin, wax figure, doll-like, perfect flawless skin, cgi, 3d render, tattoo, tribal tattoo, ink on skin [+ ситуативные]"
}

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
      zimageNeg: parsed['zimage_neg'] ?? '',
      ponyPositive: parsed['pony_positive'] ?? '',
      ponyNegativeAdd: parsed['pony_negative_add'] ??
          'tattoo, neck tattoo, chest tattoo, face tattoo, tribal tattoo, body tattoo, arm tattoo, airbrushed, plastic skin, overly smooth skin, glossy skin, porcelain skin, perfect skin, wax skin, doll-like skin, smooth skin, flawless skin, cgi skin',
      faceDetailer: parsed['face_detailer'] ?? '',
      faceDetailerNegAdd: parsed['face_detailer_neg_add'] ??
          'plastic skin, airbrushed, smooth porcelain skin, glossy skin, perfect skin, doll-like, tattoo, face tattoo, neck tattoo',
      handFixAdd: parsed['handfix_add'] ?? '',
      refinerNote: parsed['refiner_note'] ?? '',
      refinerNeg: parsed['refiner_neg'] ?? '',
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
