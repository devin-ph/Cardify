import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/analysis_result.dart';

class NetworkService {
  NetworkService(this.apiUrl, {http.Client? client})
    : _client = client ?? http.Client();

  final String apiUrl;
  final http.Client _client;

  Future<AnalysisResult> uploadImage(Uint8List imageBytes) async {
    final uri = Uri.parse(apiUrl);
    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: 'capture.jpg',
        ),
      );

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    final payload = response.body.isNotEmpty ? jsonDecode(response.body) : {};

    if (response.statusCode == 200 && payload['data'] != null) {
      return AnalysisResult.fromJson(payload['data']);
    }

    final message =
        payload['detail'] ?? payload['message'] ?? 'AI service unavailable';
    throw Exception(message);
  }
}
