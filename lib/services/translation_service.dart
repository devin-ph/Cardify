import 'package:http/http.dart' as http;
import 'dart:convert';

class TranslationService {
  static const String _myMemoryUrl = 'https://api.mymemory.translated.net/get';
  static const String _freeDictUrl =
      'https://api.dictionaryapi.dev/api/v2/entries/en';

  /// Dịch từ tiếng Anh sang tiếng Việt sử dụng MyMemory API
  static Future<String?> translateToVietnamese(String word) async {
    if (word.isEmpty) return null;

    try {
      final response = await http
          .get(Uri.parse('$_myMemoryUrl?q=$word&langpair=en|vi'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final translatedText = json['responseData']['translatedText'];

        if (translatedText != null && translatedText.toString().isNotEmpty) {
          return translatedText.toString();
        }
      }
    } catch (e) {
      print('Translation error: $e');
    }
    return null;
  }

  /// Lấy phiên âm IPA từ từ điển công cộng
  static Future<String?> getPhonetic(String word) async {
    if (word.isEmpty) return null;

    try {
      final response = await http
          .get(Uri.parse('$_freeDictUrl/$word'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final jsonList = jsonDecode(response.body) as List;
        if (jsonList.isNotEmpty) {
          final firstEntry = jsonList[0];

          // Tìm phonetic chính từ phonetics array
          if (firstEntry['phonetics'] != null &&
              (firstEntry['phonetics'] as List).isNotEmpty) {
            for (final phonetic in firstEntry['phonetics']) {
              if (phonetic['text'] != null &&
                  phonetic['text'].toString().isNotEmpty) {
                return phonetic['text'].toString();
              }
            }
          }

          // Fallback: parse từ meanings
          if (firstEntry['meanings'] != null &&
              (firstEntry['meanings'] as List).isNotEmpty) {
            return firstEntry['meanings'][0]['definitions'][0]['definition']
                .toString();
          }
        }
      }
    } catch (e) {
      print('Phonetic lookup error: $e');
    }
    return null;
  }

  /// Lookup đầy đủ: dịch sang Việt + lấy phiên âm
  static Future<Map<String, String>> lookupWord(String word) async {
    final result = <String, String>{};

    // Lấy dịch nghĩa Việt
    final translation = await translateToVietnamese(word);
    if (translation != null) {
      result['meaning'] = translation;
    }

    // Lấy phiên âm
    final phonetic = await getPhonetic(word);
    if (phonetic != null) {
      result['phonetic'] = phonetic;
    }

    return result;
  }

  /// Dịch từ tiếng Việt sang tiếng Anh
  static Future<String?> translateToEnglish(String meaning) async {
    if (meaning.isEmpty) return null;

    try {
      final response = await http
          .get(Uri.parse('$_myMemoryUrl?q=$meaning&langpair=vi|en'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final translatedText = json['responseData']['translatedText'];

        if (translatedText != null && translatedText.toString().isNotEmpty) {
          return translatedText.toString();
        }
      }
    } catch (e) {
      print('Reverse translation error: $e');
    }
    return null;
  }

  /// Reverse lookup: từ Nghĩa Việt tìm từ Anh + phiên âm
  static Future<Map<String, String>> reverseLookup(String meaning) async {
    final result = <String, String>{};

    // Dịch từ Việt sang Anh
    final englishWord = await translateToEnglish(meaning);
    if (englishWord != null && englishWord.isNotEmpty) {
      result['word'] = englishWord;

      // Lấy phiên âm của từ Anh
      final phonetic = await getPhonetic(englishWord);
      if (phonetic != null) {
        result['phonetic'] = phonetic;
      }
    }

    return result;
  }

  /// Detect ngôn ngữ: 'vi' (Việt) hoặc 'en' (Anh)
  /// Dựa trên chứa các ký tự tiếng Việt (à, á, ả, ã, ạ, etc.)
  static String detectLanguage(String text) {
    // Regex để detect tiếng Việt (chứa dấu tiếng Việt)
    final vietnamesePattern = RegExp(
      r'[àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ]',
      caseSensitive: false,
    );

    if (vietnamesePattern.hasMatch(text)) {
      return 'vi';
    }
    return 'en';
  }

  /// Auto-translate: detect language rồi dịch sang ngôn ngữ kia
  static Future<String?> autoTranslate(String text) async {
    if (text.isEmpty) return null;

    final detectedLang = detectLanguage(text);

    try {
      final langPair = detectedLang == 'vi'
          ? 'vi|en'
          : 'en|vi'; // Source|Target
      final response = await http
          .get(
            Uri.parse(
              '$_myMemoryUrl?q=${Uri.encodeComponent(text)}&langpair=$langPair',
            ),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final translatedText = json['responseData']['translatedText'];

        if (translatedText != null && translatedText.toString().isNotEmpty) {
          return translatedText.toString();
        }
      }
    } catch (e) {
      print('Auto-translate error: $e');
    }
    return null;
  }

  /// Tìm các từ khớp (case-insensitive) trong text
  /// Returns list of {start, end, word} positions để highlight
  static List<Map<String, dynamic>> findMatchingWords(
    String text,
    List<String> keywords,
  ) {
    final matches = <Map<String, dynamic>>[];

    for (final keyword in keywords) {
      if (keyword.isEmpty) continue;

      final lowerText = text.toLowerCase();
      final lowerKeyword = keyword.toLowerCase();
      int startIndex = 0;

      while (true) {
        final index = lowerText.indexOf(lowerKeyword, startIndex);
        if (index == -1) break;

        // Check if it's a whole word match (surrounded by non-alphanumeric)
        final beforeOk = index == 0 || !_isAlphanumeric(text[index - 1]);
        final afterOk =
            index + keyword.length == text.length ||
            !_isAlphanumeric(text[index + keyword.length]);

        if (beforeOk && afterOk) {
          matches.add({
            'start': index,
            'end': index + keyword.length,
            'word': text.substring(index, index + keyword.length),
          });
        }

        startIndex = index + 1;
      }
    }

    // Sort by start position
    matches.sort((a, b) => (a['start'] as int).compareTo(b['start'] as int));

    return matches;
  }

  static bool _isAlphanumeric(String char) {
    return RegExp(r'[a-zA-Z0-9]').hasMatch(char);
  }
}
