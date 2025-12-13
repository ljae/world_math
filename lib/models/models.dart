export 'school.dart';

class Problem {
  final String id;
  final DateTime date;
  final String title;
  final String content;
  final String question;
  final List<String> choices;
  final String correctAnswer;
  final String explanation;
  final String? imageUrl;
  final String? newsTitle;
  final String? newsUrl;
  final String mathTopic;
  final String economicTheme;
  final String gradeLevel;
  final String difficulty;

  // Extended fields for rich content
  final Map<String, dynamic>? solutionData;
  final Map<String, dynamic>? economicInsightData;
  final Map<String, dynamic>? newsReferenceData;
  final String scenarioText;

  Problem({
    required this.id,
    required this.date,
    required this.title,
    required this.content,
    required this.question,
    required this.choices,
    required this.correctAnswer,
    required this.explanation,
    this.imageUrl,
    this.newsTitle,
    this.newsUrl,
    required this.mathTopic,
    required this.economicTheme,
    this.gradeLevel = '고3', // Default
    this.difficulty = '',
    this.solutionData,
    this.economicInsightData,
    this.newsReferenceData,
    this.scenarioText = '',
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'problemId': id,
      'problem_id': id,
      'date': date.toIso8601String().split('T')[0],
      'title': title,
      'content': content,
      'question': question,
      'choices': choices,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
      'imageUrl': imageUrl,
      'newsReference': {
        'title': newsTitle,
        'url': newsUrl,
      },
      'metadata': {
        'topic': mathTopic,
        'economicTheme': economicTheme,
        'economic_theme': economicTheme,
        'gradeLevel': gradeLevel,
        'grade_level': gradeLevel,
        'difficulty': difficulty,
      },
      'scenarioText': scenarioText,
    };

    // Include extended data if available
    if (solutionData != null) {
      map['solution'] = solutionData;
    }
    if (economicInsightData != null) {
      map['economic_insight'] = economicInsightData;
    }
    if (newsReferenceData != null) {
      map['news_reference'] = newsReferenceData;
    }

    return map;
  }

  factory Problem.fromMap(Map<String, dynamic> map) {
    // Debug: Print raw map data to diagnose web vs local differences
    print('Problem.fromMap called with keys: ${map.keys.toList()}');
    if (map.containsKey('metadata')) {
      print('Metadata keys: ${(map['metadata'] as Map?)?.keys.toList()}');
    }

    // Helper to safely extract nested values
    dynamic getNested(List<String> keys) {
      dynamic current = map;
      for (var key in keys) {
        if (current is Map<String, dynamic> && current.containsKey(key)) {
          current = current[key];
        } else {
          return null;
        }
      }
      return current;
    }

    // Extract solution data
    final solutionRaw = getNested(['solution']);
    Map<String, dynamic>? solutionData;
    String explanationString = '';

    if (solutionRaw is Map) {
      solutionData = Map<String, dynamic>.from(solutionRaw);

      // Create a simple text explanation as fallback
      final approach = solutionRaw['approach'] ?? '';
      final answer = solutionRaw['answer'] ?? '';
      explanationString = '$approach\n\n$answer';
    }

    // Fallback for explanation if not in solution
    if (explanationString.isEmpty) {
      explanationString = getNested(['body', 'explanation']) ?? '';
    }

    // Extract problem data
    final problemData = getNested(['problem']) ?? {};
    final scenarioText = problemData['scenario_text'] ?? getNested(['body', 'content']) ?? getNested(['content']) ?? '';

    // Extract question from problem.questions array
    String question = '';
    List<dynamic> choices = [];
    String correctAnswer = '';

    if (problemData['questions'] is List && (problemData['questions'] as List).isNotEmpty) {
      final firstQuestion = problemData['questions'][0];
      question = firstQuestion['question'] ?? '';
      choices = firstQuestion['choices'] ?? [];
      correctAnswer = firstQuestion['correct_answer'] ?? firstQuestion['correctAnswer'] ?? '';
    } else {
      // Fallback to old structure
      question = getNested(['body', 'question']) ?? getNested(['question']) ?? '';
      choices = getNested(['body', 'choices']) ?? getNested(['choices']) ?? [];
      correctAnswer = getNested(['body', 'correctAnswer']) ?? getNested(['correctAnswer']) ?? '';
    }

    // Extract economic insight data
    final economicInsightRaw = getNested(['economic_insight']);
    Map<String, dynamic>? economicInsightData;
    if (economicInsightRaw is Map) {
      economicInsightData = Map<String, dynamic>.from(economicInsightRaw);
    }

    // Extract news reference data
    final newsReferenceRaw = getNested(['news_reference']);
    Map<String, dynamic>? newsReferenceData;
    String? newsTitle;
    String? newsUrl;

    if (newsReferenceRaw is Map) {
      newsReferenceData = Map<String, dynamic>.from(newsReferenceRaw);

      // Try to extract title and url from various structures
      if (newsReferenceRaw['primary_source'] != null) {
        newsTitle = newsReferenceRaw['primary_source']['title'];
        newsUrl = newsReferenceRaw['primary_source']['url'];
      } else {
        newsTitle = newsReferenceRaw['title'];
        newsUrl = newsReferenceRaw['url'];
      }
    } else {
      // Fallback to old structure
      newsTitle = getNested(['newsReference', 'title']);
      newsUrl = getNested(['newsReference', 'url']);
    }

    // Extract difficulty from metadata or question
    String difficulty = getNested(['metadata', 'difficulty']) ?? '';
    if (difficulty.isEmpty) {
      final scoreMatch = RegExp(r'\[(\d+)점\]').firstMatch(question);
      if (scoreMatch != null) {
        difficulty = '${scoreMatch.group(1)}점';
      }
    }

    return Problem(
      id: map['problem_id'] ?? map['problemId'] ?? map['id'] ?? 'unknown',
      date: map['date'] == null ? DateTime.now() : DateTime.parse(map['date']),
      title: map['title'] ?? '제목 없음',
      content: scenarioText,
      question: question,
      choices: List<String>.from(choices),
      correctAnswer: correctAnswer.toString(),
      explanation: explanationString,
      imageUrl: getNested(['imageUrl']),
      newsTitle: newsTitle,
      newsUrl: newsUrl,
      mathTopic: getNested(['metadata', 'topic']) ?? '',
      economicTheme: getNested(['metadata', 'economicTheme']) ?? getNested(['metadata', 'economic_theme']) ?? '',
      gradeLevel: getNested(['metadata', 'gradeLevel']) ?? getNested(['metadata', 'grade_level']) ?? '고3',
      difficulty: difficulty,
      solutionData: solutionData,
      economicInsightData: economicInsightData,
      newsReferenceData: newsReferenceData,
      scenarioText: scenarioText,
    );
  }
}

class User {
  final String id;
  final String nickname;
  final String schoolName;

  User({
    required this.id,
    required this.nickname,
    required this.schoolName,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      nickname: map['nickname'],
      schoolName: map['schoolName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nickname': nickname,
      'schoolName': schoolName,
    };
  }
}

class Attempt {
  final String problemId;
  final bool isCorrect;
  final DateTime solvedAt;
  final int timeTakenSeconds;

  Attempt({
    required this.problemId,
    required this.isCorrect,
    required this.solvedAt,
    this.timeTakenSeconds = 0,
  });

  factory Attempt.fromMap(Map<String, dynamic> map) {
    return Attempt(
      problemId: map['problemId'],
      isCorrect: map['isCorrect'] ?? false,
      solvedAt: DateTime.parse(map['solvedAt']),
      timeTakenSeconds: map['timeTakenSeconds'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'problemId': problemId,
      'isCorrect': isCorrect,
      'solvedAt': solvedAt.toIso8601String(),
      'timeTakenSeconds': timeTakenSeconds,
    };
  }
}

class RankingItem {
  final String userId;
  final String nickname;
  final String schoolName;
  final int solvedCount;
  final int rank;

  RankingItem({
    required this.userId,
    required this.nickname,
    required this.schoolName,
    required this.solvedCount,
    required this.rank,
  });
}

class SchoolRankingItem {
  final String schoolName;
  final int totalSolvedCount;
  final int studentCount;
  final int rank;

  SchoolRankingItem({
    required this.schoolName,
    required this.totalSolvedCount,
    required this.studentCount,
    required this.rank,
  });
}
