import 'package:flutter/services.dart';
import 'package:csv/csv.dart';

class LabelLoader {

  static Future<Map<int, String>> loadLabels() async {

    final raw = await rootBundle.loadString(
        "assets/yamnet_class_map.csv"
    );

    List<List<dynamic>> rows =
    const CsvToListConverter().convert(raw);

    Map<int, String> labels = {};

    for (int i = 1; i < rows.length; i++) {

      int index = rows[i][0];
      String name = rows[i][2];

      labels[index] = name;

    }

    return labels;
  }
}