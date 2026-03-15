import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:collection/collection.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuslanPredictor {
  late Interpreter _interpreter;
  final List<String> labels = [
    'A','B','C','D','E','F','G','H','I','J','K','L','M',
    'N','O','P','Q','R','S','T','U','V','W','X','Y','Z'
  ];

  final int stabilityWindow = 15;
  final int stabilityMin = 12;
  final List<String> _history = [];

  String lastLetter = '';
  String allLetters = '';
  double threshold = 0.9;

  final String openAiKey = dotenv.env['OPENAI_API_KEY'] ?? '';

  AuslanPredictor();

  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset(
      'assets/auslan_detection/model/auslan.tflite'
    );
  }


  String predictAuslan(List<double> coords) {
    var inputList = Float32List.fromList(coords);
    var input = inputList.buffer;

    var outputList = Float32List(26);
    var output = outputList.buffer;

    _interpreter.run(input, output);

    List<double> probs = outputList.map((e) => e.toDouble()).toList();
    int maxIndex = probs.indexOf(probs.reduce((a, b) => a > b ? a : b));
    double confidence = probs[maxIndex];

    String predicted = labels[maxIndex];

    _history.add(predicted);
    if (_history.length > stabilityWindow) _history.removeAt(0);

    Map<String, int> counts = {};
    for (var l in _history) {counts[l] = (counts[l] ?? 0) + 1;};
    var mostCommon = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);


    if (confidence >= threshold && (mostCommon?.value ?? 0) >= stabilityMin) {
      if (mostCommon!.key != lastLetter) {
        lastLetter = mostCommon.key;
        return lastLetter;
      }
    }

    return '';
  }

  Future<String?> guessWordPhrase() async {
    if (allLetters.isEmpty) return null;

    final prompt = """
    You normalize OCR text.
    Rules:
      1. Split merged English words.
      2. Fix simple OCR mistakes.
      3. Return uppercase words only.
      4. Do not add explanations.
      5. Interpret noisy or merged OCR text.
      6. if it's a sentence, try to make it make sense as much as possible
      7. check the sentence before giving the answer to see if it makes sense
      if it doesnt, make it make sense with the given letters
      8. also include slang stuff too
      9. humor would be nice too lol  
      
    Text: '$allLetters'
    """;

    final url = Uri.parse("https://api.openai.com/v1/chat/completions");

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $openAiKey',
      },
      body: jsonEncode({
        "model": "gpt-4o-mini",
        "messages": [
          {"role": "user", "content": prompt}
        ],
        "temperature": 0.7
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      String guess = data['choices'][0]['message']['content'].trim();
      return guess;
    } else {
      print('OpenAI request failed: ${response.statusCode}');
      return null;
    }
  }
}