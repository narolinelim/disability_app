import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class CloudImageDescriber {
  static const String _apiKey = String.fromEnvironment('OPENAI_API_KEY');
  static const String _model = String.fromEnvironment(
    'OPENAI_VISION_MODEL',
    defaultValue: 'gpt-4.1-mini',
  );
  static const String _responsesUrl = String.fromEnvironment(
    'OPENAI_RESPONSES_URL',
    defaultValue: 'https://api.openai.com/v1/responses',
  );

  bool get isConfigured => _apiKey.trim().isNotEmpty;

  Future<String> describe(Uint8List imageBytes) async {
    if (!isConfigured) {
      throw StateError('OPENAI_API_KEY is not configured.');
    }

    final dataUri = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';
    final payload = <String, dynamic>{
      'model': _model,
      'input': <Map<String, dynamic>>[
        <String, dynamic>{
          'role': 'user',
          'content': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'input_text',
              'text':
                  'Describe the most important item in this photo using one short sentence for accessibility.',
            },
            <String, dynamic>{'type': 'input_image', 'image_url': dataUri},
          ],
        },
      ],
      'max_output_tokens': 80,
    };

    final response = await _postWithRetry(payload);

    final body = response.body.trim();
    final decoded = body.isEmpty ? <String, dynamic>{} : jsonDecode(body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _extractErrorMessage(decoded);
      throw Exception('OpenAI ${response.statusCode}: $message');
    }

    final outputText = _extractOutputText(decoded);
    if (outputText.isEmpty) {
      throw Exception('OpenAI response did not contain output text.');
    }
    return outputText;
  }

  Future<http.Response> _postWithRetry(Map<String, dynamic> payload) async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await http
            .post(
              Uri.parse(_responsesUrl),
              headers: <String, String>{
                'Authorization': 'Bearer $_apiKey',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 25));
      } on TimeoutException {
        lastError = Exception(
          'Network timeout while contacting OpenAI. Check internet and try again.',
        );
      } on SocketException catch (error) {
        final text = error.message.toLowerCase();
        if (text.contains('failed host lookup') ||
            text.contains('nodename nor servname')) {
          lastError = Exception(
            'Cannot resolve api.openai.com. Check DNS, VPN, or internet on this phone.',
          );
        } else {
          lastError = Exception(
            'Network connection failed while contacting OpenAI.',
          );
        }
      } catch (error) {
        lastError = error;
      }

      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 900));
      }
    }
    throw lastError ?? Exception('Unknown network error');
  }

  String _extractErrorMessage(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    }
    return 'Unknown API error';
  }

  String _extractOutputText(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) {
      return '';
    }

    final outputText = decoded['output_text'];
    if (outputText is String && outputText.trim().isNotEmpty) {
      return outputText.trim();
    }
    if (outputText is List) {
      final joined = outputText
          .whereType<String>()
          .map((text) => text.trim())
          .where((text) => text.isNotEmpty)
          .join(' ');
      if (joined.isNotEmpty) {
        return joined;
      }
    }

    final output = decoded['output'];
    if (output is List) {
      final buffer = <String>[];
      for (final item in output) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final content = item['content'];
        if (content is! List) {
          continue;
        }
        for (final block in content) {
          if (block is! Map<String, dynamic>) {
            continue;
          }
          final text = block['text'];
          if (text is String && text.trim().isNotEmpty) {
            buffer.add(text.trim());
          }
        }
      }
      return buffer.join(' ').trim();
    }

    return '';
  }
}
