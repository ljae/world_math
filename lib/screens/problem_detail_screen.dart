import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart'; 
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../widgets/success_animation.dart';
import 'dart:io';
import 'dart:async';

class ProblemDetailScreen extends StatefulWidget {
  final Problem problem;

  const ProblemDetailScreen({super.key, required this.problem});

  @override
  State<ProblemDetailScreen> createState() => _ProblemDetailScreenState();
}

class _ProblemDetailScreenState extends State<ProblemDetailScreen> with SingleTickerProviderStateMixin {
  final _answerController = TextEditingController();
  bool _isSubmitted = false;
  bool _isCorrect = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Timer state
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isTimerRunning = false;

  final FirestoreService _dataService = FirestoreService();

  @override
  void initState() {
    super.initState();

    // Setup animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
    _checkIfSolved();
    _startTimer();
  }
  
  void _startTimer() {
    if (_isTimerRunning) return;
    _isTimerRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }
  
  void _stopTimer() {
    _timer?.cancel();
    _isTimerRunning = false;
  }

  Future<void> _checkIfSolved() async {
    final userId = 'mock_user_id';
    final hasSolved = await _dataService.hasSolved(userId, widget.problem.id);
    if (mounted && hasSolved) {
      setState(() {
        _isSubmitted = true;
        _isCorrect = true;
        _isTimerRunning = false;
      });
    }
  }

  @override
  void dispose() {
    _stopTimer();
    _animationController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_answerController.text.isEmpty) return;
    _stopTimer();

    final userId = 'mock_user_id';
    final isCorrect = _answerController.text == widget.problem.correctAnswer;
    await _dataService.recordAttempt(
      userId,
      widget.problem.id, 
      isCorrect,
      timeTakenSeconds: _elapsedSeconds,
    );

    setState(() {
      _isSubmitted = true;
      _isCorrect = isCorrect;
    });

    if (isCorrect) {
      _showResultDialog('정답입니다!', true);
    } else {
      _showResultDialog('오답입니다. 다시 풀어보세요.', false);
      setState(() {
        _isSubmitted = false;
        _startTimer();
      });
    }
  }

  void _showResultDialog(String message, bool success) {
    if (success) {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withAlpha((255 * 0.7).toInt()),
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: SuccessAnimation(
            onComplete: () {
              Navigator.pop(context);
              _showSuccessMessage();
            },
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange),
              SizedBox(width: 8),
              Text('아쉬워요'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
              child: const Text('다시 도전'),
            ),
          ],
        ),
      );
    }
  }

  void _showSuccessMessage() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.celebration, color: Colors.green),
            SizedBox(width: 8),
            Text('축하합니다!'),
          ],
        ),
        content: const Text('정답입니다! 해설을 확인해보세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchNewsUrl() async {
    final urlString = widget.problem.newsUrl?.trim();
    if (urlString != null && urlString.isNotEmpty) {
      final Uri? url = Uri.tryParse(urlString);
      if (url != null && url.hasScheme) {
        if (!await launchUrl(url)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('뉴스 링크를 열 수 없습니다.')),
            );
          }
        }
      } else {
         if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('유효하지 않은 링크입니다.')),
          );
        }
      }
    }
  }

  String _getDayOfWeek() {
    final weekday = widget.problem.date.weekday;
    const days = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    return days[weekday - 1];
  }

  /// Helper to convert dynamic value (String or List) to String
  String _convertToString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is List) return value.map((e) => e.toString()).join('\n');
    return value.toString();
  }

  // --- Sanitization & Markdown Rendering ---

  String _sanitizeText(String text) {
    String result = text;

    if (result.trim().isEmpty) {
      return result; // Don't process empty strings
    }

    // 1. Remove JSON-like metadata artifacts that are leaking into the display
    // These appear as inline text within explanations

    // Remove everything from ", description:" to the end of the brace or line
    // This handles: ...content..., description: some text}
    result = result.replaceAll(RegExp(r',\s*description:\s*[^}]+\}', multiLine: true), '');
    result = result.replaceAll(RegExp(r',\s*description:\s*[^\n}]+(?=\n|$)', multiLine: true), '');

    // Remove {step: N, calculation: ...} patterns but keep the calculation content
    // Match: {step: 2, calculation: actual_content}
    result = result.replaceAllMapped(
      RegExp(r'\{step:\s*\d+,\s*calculation:\s*([^}]+)\}', multiLine: true),
      (match) => match.group(1) ?? '',
    );

    // Remove {step: N, description: ...} entirely
    result = result.replaceAll(RegExp(r'\{step:\s*\d+,\s*description:\s*[^}]+\}', multiLine: true), '');

    // Remove standalone description fields
    result = result.replaceAll(RegExp(r',\s*description:\s*[^,}\n]+', multiLine: true), '');

    // Clean up any leftover JSON artifacts
    result = result.replaceAll(RegExp(r'\{step:\s*\d+[^}]*\}', multiLine: true), '');
    result = result.replaceAll(RegExp(r',\s*\}'), '');
    result = result.replaceAll(RegExp(r'^\s*\}\s*$', multiLine: true), '');

    return result;
  }

  Widget _buildMarkdown(String content, {bool boldText = false}) {
    String processedContent = _sanitizeText(content);

    return MarkdownBody(
      data: processedContent,
      selectable: false, // Disabled selection as requested
      builders: {
        'latex': MathMarkdownBuilder(),
      },
      extensionSet: md.ExtensionSet(
        [
          ...md.ExtensionSet.gitHubFlavored.blockSyntaxes,
          BlockLatexSyntax(),
        ],
        [
          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
          LatexSyntax(),
        ],
      ),
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          fontFamily: 'Paperlogy',
          fontSize: 17,
          height: 1.6,
          color: Colors.black87,
          fontWeight: boldText ? FontWeight.bold : FontWeight.normal, // Bold for questions
        ),
        h1: const TextStyle(fontFamily: 'Paperlogy', fontSize: 24, fontWeight: FontWeight.bold),
        h2: const TextStyle(fontFamily: 'Paperlogy', fontSize: 22, fontWeight: FontWeight.bold),
        h3: const TextStyle(fontFamily: 'Paperlogy', fontSize: 20, fontWeight: FontWeight.bold),
        strong: const TextStyle(fontFamily: 'Paperlogy', fontWeight: FontWeight.bold),
        blockquote: const TextStyle(
          fontFamily: 'Paperlogy',
          fontSize: 16,
          color: Colors.black87,
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          color: Colors.blue.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: Colors.blue.withAlpha(100), width: 4)),
        ),
      ),
    );
  }

  Widget _buildProblemContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.problem.imageUrl != null && widget.problem.imageUrl!.isNotEmpty) ...[
          Center(
             child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 1),
              ),
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 1.0,
                maxScale: 4.0,
                child: _buildImageWidget(widget.problem.imageUrl!),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (widget.problem.content.isNotEmpty)
          _buildMarkdown(widget.problem.content.replaceAll('[[IMAGE]]', '')), // Remove marker if present

        // DEBUG: After content (where we know text renders)
        const SizedBox(height: 16),
        Text('━━━ DEBUG ━━━', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text('Question length: ${widget.problem.question.length}'),
        Text('Question isEmpty: ${widget.problem.question.isEmpty}'),
        Text('Question text: "${widget.problem.question}"'),
        Text('Choices count: ${widget.problem.choices.length}'),
        Text('━━━━━━━━━━━━━', style: TextStyle(fontSize: 20)),

        // FORCE SHOW QUESTION - Remove isEmpty check to see if it's a data or rendering issue
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Q. ', style: TextStyle(fontFamily: 'Paperlogy', fontSize: 20, fontWeight: FontWeight.w900, color: Colors.blue)),
            Expanded(child: Text('QUESTION: ${widget.problem.question} | LENGTH: ${widget.problem.question.length}',
              style: TextStyle(fontSize: 14))), // Plain Text instead of markdown
          ],
        ),

        // FORCE SHOW CHOICES
        const SizedBox(height: 24),
        Text('CHOICES (${widget.problem.choices.length}):'),
        ...widget.problem.choices.map((choice) => Text('  - $choice')),
      ],
    );
  }

  Widget _buildChoices() {
    return Column(
      children: widget.problem.choices.map((choice) {
        final choiceValue = choice.substring(0, 1); // Get ①
        final choiceMap = {'①': '1', '②': '2', '③': '3', '④': '4', '⑤': '5'};
        final answerVal = choiceMap[choiceValue] ?? '';
        final isSelected = _answerController.text == answerVal;

        return GestureDetector(
          onTap: () {
            if (!_isSubmitted) {
              setState(() {
                _answerController.text = answerVal;
              });
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue.withAlpha(20) : Colors.white,
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  choiceValue,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.blue : Colors.black87,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMarkdown(choice.substring(1).trim()),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExplanationContent() {
    // Check if we have structured solution data
    if (widget.problem.solutionData != null) {
      return _buildStructuredSolution();
    }

    // Fallback to simple explanation
    final explanation = widget.problem.explanation.trim();

    if (explanation.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          '해설이 아직 준비되지 않았습니다.',
          style: TextStyle(
            fontFamily: 'Paperlogy',
            fontSize: 16,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return _buildMarkdown(explanation);
  }

  Widget _buildStructuredSolution() {
    final solution = widget.problem.solutionData!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Approach section
        if (solution['approach'] != null && solution['approach'].toString().isNotEmpty) ...[
          Text(
            '접근 방법',
            style: TextStyle(
              fontFamily: 'Paperlogy',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 8),
          _buildMarkdown(solution['approach']),
          const SizedBox(height: 24),
        ],

        // Steps section
        if (solution['steps'] != null && solution['steps'] is List) ...[
          Text(
            '풀이 과정',
            style: TextStyle(
              fontFamily: 'Paperlogy',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 12),
          ..._buildSolutionSteps(solution['steps']),
          const SizedBox(height: 24),
        ],

        // Derivation section (alternative to steps)
        if (solution['derivation'] != null && solution['derivation'] is List) ...[
          Text(
            '유도 과정',
            style: TextStyle(
              fontFamily: 'Paperlogy',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 12),
          ..._buildDerivationSteps(solution['derivation']),
          const SizedBox(height: 24),
        ],

        // Case-based solution
        if (solution['case_a'] != null) ...[
          _buildCaseSolution('Case A', solution['case_a']),
          const SizedBox(height: 16),
        ],
        if (solution['case_b'] != null) ...[
          _buildCaseSolution('Case B', solution['case_b']),
          const SizedBox(height: 16),
        ],
        if (solution['final_calculation'] != null) ...[
          _buildFinalCalculation(solution['final_calculation']),
          const SizedBox(height: 16),
        ],

        // Verification section
        if (solution['verification'] != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(12),
              border: Border.all(color: Colors.blue.withAlpha(100), width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.verified_outlined, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '검증',
                      style: TextStyle(
                        fontFamily: 'Paperlogy',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildVerificationContent(solution['verification']),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Final answer
        if (solution['answer'] != null && solution['answer'].toString().isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(25),
              border: Border.all(color: Colors.green, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '최종 답안',
                        style: TextStyle(
                          fontFamily: 'Paperlogy',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildMarkdown(solution['answer'].toString()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCalculationContent(String content) {
    return _buildMarkdown(content);
  }

  List<Widget> _buildSolutionSteps(List<dynamic> steps) {
    return steps.asMap().entries.map((entry) {
      final step = entry.value;
      if (step is! Map) return const SizedBox.shrink();

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step number and title
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${step['step'] ?? entry.key + 1}',
                      style: const TextStyle(
                        fontFamily: 'Paperlogy',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step['title'] ?? step['description'] ?? '',
                    style: const TextStyle(
                      fontFamily: 'Paperlogy',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),

            if (step['description'] != null && step['title'] != null) ...[
              const SizedBox(height: 12),
              _buildMarkdown(_convertToString(step['description'])),
            ],

            if (step['calculation'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: _buildCalculationContent(_convertToString(step['calculation'])),
              ),
            ],

            if (step['explanation'] != null) ...[
              const SizedBox(height: 8),
              _buildMarkdown(_convertToString(step['explanation'])),
            ],

            if (step['note'] != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.withAlpha(100), width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber.shade800),
                    const SizedBox(width: 8),
                    Expanded(child: _buildMarkdown(_convertToString(step['note']))),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildDerivationSteps(List<dynamic> derivation) {
    return derivation.map((item) {
      if (item is! Map) return const SizedBox.shrink();

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['step'] ?? '',
              style: const TextStyle(
                fontFamily: 'Paperlogy',
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            if (item['details'] != null && item['details'] is List) ...[
              const SizedBox(height: 12),
              ...((item['details'] as List).map((detail) {
                if (detail is! Map) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (detail['description'] != null) _buildMarkdown(_convertToString(detail['description'])),
                      if (detail['equation'] != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: _buildMarkdown(_convertToString(detail['equation'])),
                        ),
                      ],
                      if (detail['equation2'] != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: _buildMarkdown(_convertToString(detail['equation2'])),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList()),
            ],
          ],
        ),
      );
    }).toList();
  }

  Widget _buildCaseSolution(String caseLabel, Map<String, dynamic> caseData) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha(12),
        border: Border.all(color: Colors.blue.withAlpha(100), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$caseLabel: ${caseData['period'] ?? ''}',
            style: TextStyle(
              fontFamily: 'Paperlogy',
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 12),
          if (caseData['steps'] != null && caseData['steps'] is List)
            ..._buildSolutionSteps(caseData['steps']),
          if (caseData['net_profit'] != null) ...[
            const SizedBox(height: 8),
            Text(
              '순수익: ${caseData['net_profit']}억 원',
              style: const TextStyle(
                fontFamily: 'Paperlogy',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinalCalculation(Map<String, dynamic> calculation) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.withAlpha(12),
        border: Border.all(color: Colors.purple.withAlpha(100), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            calculation['title'] ?? '최종 계산',
            style: TextStyle(
              fontFamily: 'Paperlogy',
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.purple.shade700,
            ),
          ),
          const SizedBox(height: 12),
          if (calculation['calculation'] != null)
            _buildMarkdown(_convertToString(calculation['calculation'])),
        ],
      ),
    );
  }

  Widget _buildVerificationContent(dynamic verification) {
    if (verification is String) {
      return _buildMarkdown(verification);
    } else if (verification is Map) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: verification.entries.map((entry) {
          final value = entry.value;

          // Handle nested maps recursively
          if (value is Map) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontFamily: 'Paperlogy',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: value.entries.map((subEntry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _buildMarkdown('**${subEntry.key}:** ${_convertToString(subEntry.value)}'),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          }

          // Handle simple key-value pairs
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key,
                  style: const TextStyle(
                    fontFamily: 'Paperlogy',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                _buildMarkdown(_convertToString(value)),
              ],
            ),
          );
        }).toList(),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildEconomicInsight() {
    final insight = widget.problem.economicInsightData!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(12),
        border: Border.all(color: Colors.orange, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.orange.shade700, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  insight['title'] ?? '경제 인사이트',
                  style: TextStyle(
                    fontFamily: 'Paperlogy',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main point
          if (insight['main_point'] != null && insight['main_point'].toString().isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(25),
                borderRadius: BorderRadius.circular(6),
              ),
              child: _buildMarkdown('**핵심 포인트**\n\n${insight['main_point']}'),
            ),
            const SizedBox(height: 16),
          ],

          // Key insights
          if (insight['key_insights'] != null) ...[
            if (insight['key_insights'] is List) ...[
              Text(
                '주요 인사이트',
                style: TextStyle(
                  fontFamily: 'Paperlogy',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
              const SizedBox(height: 8),
              ...(insight['key_insights'] as List).map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade700,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _buildMarkdown(item.toString())),
                    ],
                  ),
                );
              }),
            ] else if (insight['key_insights'] is String) ...[
              _buildMarkdown(insight['key_insights']),
            ],
          ],

          // Key findings (alternative structure)
          if (insight['key_findings'] != null && insight['key_findings'] is List) ...[
            const SizedBox(height: 12),
            Text(
              '주요 발견사항',
              style: TextStyle(
                fontFamily: 'Paperlogy',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade900,
              ),
            ),
            const SizedBox(height: 8),
            ...(insight['key_findings'] as List).map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline, size: 18, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(child: _buildMarkdown(item.toString())),
                  ],
                ),
              );
            }),
          ],

          // Reality check
          if (insight['reality_check'] != null && insight['reality_check'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade400, width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.grey.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '현실 적용',
                          style: TextStyle(
                            fontFamily: 'Paperlogy',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildMarkdown(insight['reality_check']),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Investment lesson
          if (insight['investment_lesson'] != null && insight['investment_lesson'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(25),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.withAlpha(100), width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.school_outlined, size: 20, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '투자 교훈',
                          style: TextStyle(
                            fontFamily: 'Paperlogy',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildMarkdown(insight['investment_lesson']),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetadataInfo() {
    // ORIGINAL STYLED VERSION - restored for local app
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildMetaItem('학년', widget.problem.gradeLevel, Icons.school),
              const SizedBox(width: 16),
              _buildMetaItem('난이도', widget.problem.difficulty.isNotEmpty ? widget.problem.difficulty : '미정', Icons.stars),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetaItem('수학 주제', widget.problem.mathTopic, Icons.calculate),
              ),
            ],
          ),
          if (widget.problem.economicTheme.isNotEmpty) ...[
            const SizedBox(height: 12),
             Row(
              children: [
                Expanded(
                  child: _buildMetaItem('경제 테마', widget.problem.economicTheme, Icons.monetization_on),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    /* TEST CODE REMOVED
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(100), // BRIGHT RED to make it obvious!
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(100), // BRIGHT RED to make it obvious!
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red, width: 5),
      ),
      child: Column(
        children: [
          // DEBUG: Show raw metadata values
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(30),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DEBUG - Raw Values:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                Text('gradeLevel: "${widget.problem.gradeLevel}"', style: TextStyle(fontSize: 10)),
                Text('difficulty: "${widget.problem.difficulty}"', style: TextStyle(fontSize: 10)),
                Text('mathTopic: "${widget.problem.mathTopic}"', style: TextStyle(fontSize: 10)),
                Text('economicTheme: "${widget.problem.economicTheme}"', style: TextStyle(fontSize: 10)),
              ],
            ),
          ),
          Row(
            children: [
              _buildMetaItem('학년', widget.problem.gradeLevel, Icons.school),
              const SizedBox(width: 16),
              _buildMetaItem('난이도', widget.problem.difficulty.isNotEmpty ? widget.problem.difficulty : '미정', Icons.stars),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetaItem('수학 주제', widget.problem.mathTopic, Icons.calculate),
              ),
            ],
          ),
          if (widget.problem.economicTheme.isNotEmpty) ...[
            const SizedBox(height: 12),
             Row(
              children: [
                Expanded(
                  child: _buildMetaItem('경제 테마', widget.problem.economicTheme, Icons.monetization_on),
                ),
              ],
            ),
          ],
        ],
      ),
    );
    */ // END ORIGINAL CODE
  }

  Widget _buildMetaItem(String label, String value, IconData icon) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontFamily: 'Paperlogy',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'Paperlogy',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        title: Text(
          '${widget.problem.date.year + 1}학년도 대학수학능력시험 대비',
          style: const TextStyle(
            fontFamily: 'Paperlogy',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFFDFBF7),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2.0),
          child: Container(color: Colors.black, height: 2.0),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            bottom: 120, // Space for bottom bar
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Timer
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer, color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                '${(_elapsedSeconds ~/ 60).toString().padLeft(2, '0')}:${(_elapsedSeconds % 60).toString().padLeft(2, '0')}',
                                style: const TextStyle(fontFamily: 'Courier', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Day Indicator
                      Center(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [Colors.blue.shade700, Colors.blue.shade500]),
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [BoxShadow(color: Colors.blue.withAlpha(100), blurRadius: 12, offset: const Offset(0, 4))],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Text(_getDayOfWeek(), style: const TextStyle(fontFamily: 'Paperlogy', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Metadata Row
                      _buildMetadataInfo(),
                      const SizedBox(height: 24),

                      // Divider
                      Container(height: 2, color: Colors.black),
                      const SizedBox(height: 24),

                      // Problem Content
                      _buildProblemContent(),

                      const SizedBox(height: 40),

                      // News Link
                      if (widget.problem.newsTitle != null) ...[
                        Container(height: 2, color: Colors.black26),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: _launchNewsUrl,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.black, width: 2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.newspaper, color: Colors.blue.shade700, size: 20),
                                    const SizedBox(width: 8),
                                    Text('관련 경제 뉴스', style: TextStyle(fontFamily: 'Paperlogy', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(widget.problem.newsTitle!, style: const TextStyle(fontFamily: 'Paperlogy', fontSize: 15, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                              ],
                            ),
                          ),
                        ),
                      ],

                      // Explanation if Correct
                      if (_isSubmitted && _isCorrect) ...[
                        const SizedBox(height: 40),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.green.withAlpha(12),
                            border: Border.all(color: Colors.green, width: 2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green.shade700),
                                  const SizedBox(width: 8),
                                  Text('정답 및 해설', style: TextStyle(fontFamily: 'Paperlogy', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildExplanationContent(),
                            ],
                          ),
                        ),
                      ],

                      // Economic Insight Section (shown at the bottom after explanation)
                      if (_isSubmitted && _isCorrect && widget.problem.economicInsightData != null) ...[
                        const SizedBox(height: 24),
                        _buildEconomicInsight(),
                      ],
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Bottom Bar
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 10, offset: const Offset(0, -5))],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isSubmitted || !_isCorrect)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _answerController,
                              decoration: InputDecoration(
                                hintText: '정답을 입력하세요',
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                prefixIcon: const Icon(Icons.create),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              onSubmitted: (_) => _submit(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Material(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              onTap: _submit,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                child: const Row(
                                  children: [
                                    Icon(Icons.send, color: Colors.white, size: 18),
                                    SizedBox(width: 8),
                                    Text('제출', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (_isSubmitted && _isCorrect)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                          child: const Text('목록으로'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWidget(String imageUrl) {
    if (kIsWeb) {
      if (imageUrl.startsWith('assets/')) {
        return Image.asset(imageUrl, fit: BoxFit.contain);
      } else {
        return Container(padding: const EdgeInsets.all(20), color: Colors.grey[200], child: const Text('이미지를 불러올 수 없습니다'));
      }
    }
    if (File(imageUrl).existsSync()) {
      return Image.file(File(imageUrl), fit: BoxFit.contain);
    } else if (imageUrl.startsWith('assets/')) {
      return Image.asset(imageUrl, fit: BoxFit.contain);
    } else {
      return Container(padding: const EdgeInsets.all(20), color: Colors.grey[200], child: const Text('이미지를 불러올 수 없습니다'));
    }
  }
}

class MathMarkdownBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    var math = element.textContent;
    if (math.isEmpty) return const SizedBox.shrink();

    // Fix for potential double-escaping or formatting from markdown parser
    math = math.trim();

    final isDisplay = element.attributes['type'] == 'display';

    final mathWidget = Math.tex(
      math,
      textStyle: const TextStyle(
        fontSize: 17,
        fontFamily: 'Paperlogy',
        color: Colors.black,
      ),
      mathStyle: isDisplay ? MathStyle.display : MathStyle.text,
      onErrorFallback: (error) => Text(math, style: const TextStyle(color: Colors.red)),
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isDisplay ? 8.0 : 0.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: mathWidget,
      ),
    );
  }
}


// For $$...$$ and \[...\ ] block math
class BlockLatexSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^\$\$([\s\S]+?)\$\$$', multiLine: true);

  BlockLatexSyntax();

  @override
  md.Node? parse(md.BlockParser parser) {
    final match = pattern.firstMatch(parser.current.content);
    if (match == null) return null;
    
    final content = match.group(1)!;
    if (content.isEmpty) return null;

    final el = md.Element('latex', [md.Text(content)]);
    el.attributes['type'] = 'display';

    parser.advance();
    return md.Element('p', [el]);
  }
}

// For $...$ and \(...\) inline math
class LatexSyntax extends md.InlineSyntax {
  LatexSyntax() : super(r'(?<!\$)\$([^\$\n]+?)\$(?!\$)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final content = match.group(1)!.trim();
    if (content.isEmpty) return false;
    
    final el = md.Element('latex', [md.Text(content)]);
    el.attributes['type'] = 'inline';
    
    parser.addNode(el);
    return true;
  }
}