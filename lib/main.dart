import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const TriviaShowdownApp());
}

class TriviaShowdownApp extends StatelessWidget {
  const TriviaShowdownApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'API-to-Cloud Trivia Showdown',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        fontFamily: GoogleFonts.outfit().fontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          primary: Colors.black,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
        ),
      ),
      home: const TriviaShowdownScreen(),
    );
  }
}

class Question {
  final String questionText;
  final String correctAnswer;
  final List<String> options;
  Question({
    required this.questionText,
    required this.correctAnswer,
    required this.options,
  });
  factory Question.fromJson(Map<String, dynamic> json) {
    var incorrect = List<String>.from(json['incorrect_answers']);
    var correct = json['correct_answer'] as String;
    var allOptions = [...incorrect, correct];
    allOptions.shuffle();
    String clean(String val) {
      var text = val
          .replaceAll('&quot;', '"')
          .replaceAll('&#039;', "'")
          .replaceAll('&#39;', "'")
          .replaceAll('&apos;', "'")
          .replaceAll('&ldquo;', '“')
          .replaceAll('&rdquo;', '”')
          .replaceAll('&lsquo;', '‘')
          .replaceAll('&rsquo;', '’')
          .replaceAll('&hellip;', '…')
          .replaceAll('&mdash;', '—')
          .replaceAll('&ndash;', '–')
          .replaceAll('&eacute;', 'é')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&amp;', '&');
      text = text.replaceAllMapped(
        RegExp(r'&#x([0-9a-fA-F]+);'),
        (match) => String.fromCharCode(int.parse(match[1]!, radix: 16)),
      );
      text = text.replaceAllMapped(
        RegExp(r'&#(\d+);'),
        (match) => String.fromCharCode(int.parse(match[1]!)),
      );
      return text;
    }

    return Question(
      questionText: clean(json['question']),
      correctAnswer: clean(correct),
      options: allOptions.map(clean).toList(),
    );
  }
}

class TriviaShowdownScreen extends StatefulWidget {
  const TriviaShowdownScreen({super.key});
  @override
  State<TriviaShowdownScreen> createState() => _TriviaShowdownScreenState();
}

class _TriviaShowdownScreenState extends State<TriviaShowdownScreen> {
  List<Question> _questions = [];
  bool _isLoading = true;
  String _error = '';
  int _currentIndex = 0;
  int _score = 0;
  bool _answered = false;
  String? _selectedOption;
  bool _isSynced = false;
  bool _isSyncing = false;
  int _roundId = 0;
  Map<String, Object>? _lastPayload;
  @override
  void initState() {
    super.initState();
    _loadTriviaData();
  }

  Future<void> _loadTriviaData() async {
    final roundId = _roundId;
    try {
      final uri = Uri.parse(
        'https://opentdb.com/api.php?amount=5&category=9&difficulty=easy&type=multiple',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['response_code'] == 0) {
          final results = data['results'] as List;
          if (!mounted || roundId != _roundId) return;
          if (results.isEmpty) {
            setState(() {
              _error = 'No trivia questions were returned. Please try again.';
              _isLoading = false;
            });
            return;
          }
          setState(() {
            _questions = results.map((q) => Question.fromJson(q)).toList();
            _isLoading = false;
          });
        } else {
          if (!mounted || roundId != _roundId) return;
          setState(() {
            _error =
                'Trivia API returned response code ${data['response_code']}. Please try again.';
            _isLoading = false;
          });
        }
      } else {
        if (!mounted || roundId != _roundId) return;
        setState(() {
          _error = 'Server error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted || roundId != _roundId) return;
      setState(() {
        _error = 'Connection failed: $e';
        _isLoading = false;
      });
    }
  }

  void _answerQuestion(String option) {
    if (_answered) return;
    setState(() {
      _answered = true;
      _selectedOption = option;
      if (option == _questions[_currentIndex].correctAnswer) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    setState(() {
      if (_currentIndex < _questions.length - 1) {
        _currentIndex++;
        _answered = false;
        _selectedOption = null;
      } else {
        _currentIndex++; // triggers results screen
      }
    });
  }

  Future<void> _syncScoreToCloud() async {
    if (_isSyncing || _isSynced) return;
    final roundId = _roundId;
    final payload = <String, Object>{
      'roundId': roundId,
      'score': _score,
      'totalQuestions': _questions.length,
      'submittedAt': DateTime.now().toUtc().toIso8601String(),
    };
    setState(() {
      _isSyncing = true;
    });
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted || roundId != _roundId) return;
    setState(() {
      _isSyncing = false;
      _isSynced = true;
      _lastPayload = payload;
    });
    debugPrint('Simulated submission payload (not sent): $payload');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Simulated sync complete; no backend request was sent.',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _restart() {
    _roundId++;
    setState(() {
      _isLoading = true;
      _currentIndex = 0;
      _score = 0;
      _answered = false;
      _selectedOption = null;
      _isSynced = false;
      _isSyncing = false;
      _lastPayload = null;
    });
    _loadTriviaData();
  }

  TextStyle _labelStyle({Color? color}) => GoogleFonts.outfit(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.4,
    color: color ?? Colors.grey.shade600,
  );

  Widget _scoreChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'SCORE $_score',
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            height: 32,
            width: 32,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: 18),
          Text(
            'Fetching live questions...',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade200),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              color: Colors.red.shade400,
              size: 36,
            ),
            const SizedBox(height: 14),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 14,
                ),
              ),
              onPressed: _restart,
              child: Text(
                'Try Again',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerOption(String option, int index) {
    final isCorrect = option == _questions[_currentIndex].correctAnswer;
    final isSelected = option == _selectedOption;

    var background = Colors.white;
    var border = Colors.grey.shade300;
    var foreground = Colors.black87;
    var badgeBackground = Colors.grey.shade100;
    IconData? trailingIcon;
    Color? trailingColor;

    if (_answered && isCorrect) {
      background = Colors.green.shade50;
      border = Colors.green.shade600;
      foreground = Colors.green.shade900;
      badgeBackground = Colors.green.shade100;
      trailingIcon = Icons.check_rounded;
      trailingColor = Colors.green.shade700;
    } else if (_answered && isSelected) {
      background = Colors.red.shade50;
      border = Colors.red.shade400;
      foreground = Colors.red.shade900;
      badgeBackground = Colors.red.shade100;
      trailingIcon = Icons.close_rounded;
      trailingColor = Colors.red.shade600;
    } else if (_answered) {
      foreground = Colors.grey.shade500;
      border = Colors.grey.shade200;
      badgeBackground = Colors.grey.shade50;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: 0,
          minimumSize: const Size(double.infinity, 58),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: border, width: 1.2),
          ),
        ),
        onPressed: () => _answerQuestion(option),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: badgeBackground,
                shape: BoxShape.circle,
              ),
              child: Text(
                String.fromCharCode(65 + index),
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: foreground,
                ),
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 8),
              Icon(trailingIcon, size: 20, color: trailingColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRound() {
    final question = _questions[_currentIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'QUESTION ${_currentIndex + 1} OF ${_questions.length}',
              style: _labelStyle(),
            ),
            const Spacer(),
            _scoreChip(),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: (_currentIndex + 1) / _questions.length,
            minHeight: 4,
            backgroundColor: Colors.grey.shade200,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: Text(
                    question.questionText,
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                      letterSpacing: -0.2,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ...question.options.asMap().entries.map(
                  (entry) => _buildAnswerOption(entry.value, entry.key),
                ),
              ],
            ),
          ),
        ),
        if (_answered) ...[
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              onPressed: _nextQuestion,
              child: Text(
                _currentIndex < _questions.length - 1
                    ? 'Next Question →'
                    : 'View Final Score',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildResults() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFFAF8FD),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_outlined,
                size: 30,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Showdown Complete!',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You answered all ${_questions.length} questions.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF8FD),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text('FINAL SCORE', style: _labelStyle()),
                const SizedBox(height: 8),
                Text(
                  '$_score / ${_questions.length}',
                  style: GoogleFonts.outfit(
                    fontSize: 44,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    letterSpacing: -1,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _score == _questions.length
                      ? 'Perfect round.'
                      : 'Nice work — play again to beat it.',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (!_isSynced)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.black54,
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  shape: const StadiumBorder(),
                ),
                onPressed: _isSyncing ? null : _syncScoreToCloud,
                icon: _isSyncing
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.cloud_upload_outlined, size: 20),
                label: Text(
                  _isSyncing ? 'Simulating sync...' : 'Simulate Score Sync',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade200),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.green.shade700,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sync Simulation Complete',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'No backend request was sent.',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.green.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Payload ready · '
                          '{"score": ${_lastPayload?['score'] ?? _score}, '
                          '"total": ${_lastPayload?['totalQuestions'] ?? _questions.length}}',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _restart,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              'Play Again',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Demo only: this screen simulates the cloud write. A real submission '
            'would send the score to an endpoint and await its response.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 11,
              height: 1.4,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return _buildLoading();
    if (_error.isNotEmpty) return _buildError();
    if (_currentIndex >= _questions.length) return _buildResults();
    return _buildRound();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Cloud Trivia Showdown: API Edition',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.normal,
            color: Colors.black87,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 8.0,
              ),
              child: _buildBody(),
            ),
          ),
        ),
      ),
    );
  }
}
