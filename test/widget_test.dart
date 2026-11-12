import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inclass_15/main.dart';

void main() {
  group('Question', () {
    test('parses JSON, decodes entities, and combines all four options', () {
      final question = Question.fromJson({
        'question': 'Who wrote &quot;Hamlet&quot;? &ldquo;Indeed&rdquo;',
        'correct_answer': 'Shakespeare &amp; Co.',
        'incorrect_answers': ['Dickens', 'Tolstoy', '&#x27;Anonymous&#x27;'],
      });

      expect(question.questionText, 'Who wrote "Hamlet"? “Indeed”');
      expect(question.correctAnswer, 'Shakespeare & Co.');
      expect(question.options.length, 4);
      expect(question.options, contains('Shakespeare & Co.'));
      expect(question.options, contains("'Anonymous'"));
    });
  });

  testWidgets('shows the loading state before the request resolves', (
    tester,
  ) async {
    await tester.pumpWidget(const TriviaShowdownApp());

    expect(find.text('Trivia'), findsOneWidget);
    expect(find.text('Fetching live questions...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let the network request settle into an error state in the test harness.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Server error'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
  });
}
