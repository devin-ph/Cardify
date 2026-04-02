import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class VoiceChatReply {
  VoiceChatReply({
    required this.topic,
    required this.intentType,
    required this.englishTerm,
    required this.phonetic,
    required this.vietnameseMeaning,
    required this.exampleSentence,
    required this.response,
  });

  final String topic;
  final String intentType;
  final String englishTerm;
  final String phonetic;
  final String vietnameseMeaning;
  final String exampleSentence;
  final String response;

  factory VoiceChatReply.fromJson(Map<String, dynamic> json) {
    return VoiceChatReply(
      topic: json['topic']?.toString() ?? 'General',
      intentType: json['intent_type']?.toString() ?? 'other',
      englishTerm: json['english_term']?.toString() ?? '',
      phonetic: json['phonetic']?.toString() ?? '',
      vietnameseMeaning: json['vietnamese_meaning']?.toString() ?? '',
      exampleSentence: json['example_sentence']?.toString() ?? '',
      response: json['response']?.toString() ?? '',
    );
  }

  bool get isSavableWord {
    return englishTerm.trim().isNotEmpty && intentType.toLowerCase() != 'other';
  }
}

class VoiceChatService {
  VoiceChatService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String _resolveChatEndpoint() {
    final direct = dotenv.maybeGet('HF_CHAT_ENDPOINT')?.trim() ?? '';
    if (direct.isNotEmpty) {
      return direct;
    }

    final analyze = dotenv.maybeGet('HF_ANALYZE_ENDPOINT')?.trim() ?? '';
    if (analyze.isNotEmpty && analyze.endsWith('/analyze-image')) {
      return analyze.replaceFirst('/analyze-image', '/chat/respond');
    }

    throw Exception('Thieu HF_CHAT_ENDPOINT trong .env');
  }

  Future<VoiceChatReply> askAI({
    required String message,
    List<Map<String, String>> history = const [],
  }) async {
    final endpoint = _resolveChatEndpoint();
    final uri = Uri.parse(endpoint);

    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'message': message, 'history': history}),
    );

    final payload = response.body.isNotEmpty
        ? jsonDecode(response.body) as Map<String, dynamic>
        : {};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = payload['data'];
      if (data is Map<String, dynamic>) {
        final reply = VoiceChatReply.fromJson(data);
        if (reply.response.trim().isNotEmpty) {
          return reply;
        }
      }
      final reply = payload['response']?.toString().trim() ?? '';
      if (reply.isNotEmpty) {
        return VoiceChatReply(
          topic: 'General',
          intentType: 'other',
          englishTerm: '',
          phonetic: '',
          vietnameseMeaning: '',
          exampleSentence: '',
          response: reply,
        );
      }
      throw Exception('AI tra ve rong');
    }

    final detail =
        payload['detail'] ?? payload['message'] ?? 'Khong the ket noi AI';
    throw Exception(detail.toString());
  }
}
