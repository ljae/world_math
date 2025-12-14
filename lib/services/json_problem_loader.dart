import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import '../models/models.dart';

class JsonProblemLoader {
  static final JsonProblemLoader _instance = JsonProblemLoader._internal();
  factory JsonProblemLoader() => _instance;
  JsonProblemLoader._internal();

  final Map<String, Problem> _cache = {};

  /// Load a problem from JSON file in db/ directory
  Future<Problem?> loadProblem(String problemId) async {
    // Check cache first
    if (_cache.containsKey(problemId)) {
      return _cache[problemId];
    }

    try {
      String jsonString;
      if (kIsWeb) {
        // For web, fetch via HTTP
        final response = await http.get(Uri.parse('assets/db/$problemId.json'));
        if (response.statusCode == 200) {
          jsonString = utf8.decode(response.bodyBytes);
        } else {
          throw Exception('Failed to load problem from web');
        }
      } else {
        // For mobile/desktop, load from asset bundle
        jsonString = await rootBundle.loadString('db/$problemId.json');
      }

      final jsonData = json.decode(jsonString) as Map<String, dynamic>;

      // Convert JSON to Problem object
      final problem = _convertJsonToProblem(jsonData);

      // Cache it
      _cache[problemId] = problem;

      return problem;
    } catch (e) {
      print('Error loading problem $problemId: $e');
      return null;
    }
  }

  /// Convert JSON data to Problem object
  Problem _convertJsonToProblem(Map<String, dynamic> json) {
    // Extract basic fields
    final problemId = json['id'] as String;
    final dateStr = json['date'] as String;
    final date = DateTime.parse(dateStr);
    final title = json['title'] as String;

    // Extract problem content
    final problemData = json['problem'] as Map<String, dynamic>;
    final scenarioText = problemData['scenario_text'] as String? ?? '';

    // Extract first question (assuming single question format for now)
    final questions = problemData['questions'] as List<dynamic>;
    final firstQuestion = questions.isNotEmpty ? questions[0] as Map<String, dynamic> : {};

    final questionText = firstQuestion['question'] as String? ?? '';
    final choices = (firstQuestion['choices'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList() ?? [];
    final correctAnswerText = firstQuestion['correct_answer'] as String? ?? '';

    // Parse correct answer number (e.g., "5" or "③ (1) 3.79...")
    String correctAnswer = '1'; // default
    if (correctAnswerText.isNotEmpty) {
      // Try to extract number
      final match = RegExp(r'^(\d+)').firstMatch(correctAnswerText);
      if (match != null) {
        correctAnswer = match.group(1)!;
      } else {
        // Try to find ①②③④⑤
        const circledNumbers = {'①': '1', '②': '2', '③': '3', '④': '4', '⑤': '5'};
        for (var entry in circledNumbers.entries) {
          if (correctAnswerText.startsWith(entry.key)) {
            correctAnswer = entry.value;
            break;
          }
        }
      }
    }

    // Extract metadata
    final metadata = json['metadata'] as Map<String, dynamic>? ?? {};
    final newsRef = json['news_reference'] as Map<String, dynamic>?;
    final solution = json['solution'] as Map<String, dynamic>?;
    final economicInsight = json['economic_insight'] as Map<String, dynamic>?;

    // Extract news reference fields
    String? newsTitle;
    String? newsUrl;
    if (newsRef != null) {
      if (newsRef['primary_source'] != null) {
        final primarySource = newsRef['primary_source'] as Map<String, dynamic>;
        newsTitle = primarySource['title'] as String?;
        newsUrl = primarySource['url'] as String?;
      } else {
        newsTitle = newsRef['title'] as String?;
        newsUrl = newsRef['url'] as String?;
      }
    }

    return Problem(
      id: problemId,
      date: date,
      title: title,
      content: scenarioText,
      question: questionText,
      choices: choices,
      correctAnswer: correctAnswer,
      mathTopic: metadata['topic'] as String? ?? '',
      economicTheme: metadata['economic_theme'] as String? ?? '',
      difficulty: metadata['difficulty'] as String? ?? '',
      gradeLevel: metadata['grade_level'] as String? ?? '',
      newsTitle: newsTitle,
      newsUrl: newsUrl,
      solutionData: solution,
      economicInsightData: economicInsight,
      newsReferenceData: newsRef,
      scenarioText: scenarioText,
    );
  }
}
