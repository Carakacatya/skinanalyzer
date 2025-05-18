import 'package:flutter/material.dart';
import '../constants/colors.dart';

class QuizQuestion extends StatelessWidget {
  final String question;
  final Map<String, String> answers;
  final void Function(String) onAnswerSelected;

  const QuizQuestion({
    super.key,
    required this.question,
    required this.answers,
    required this.onAnswerSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          question,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        ...answers.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ElevatedButton(
              onPressed: () => onAnswerSelected(entry.key),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 233, 171, 190),
                foregroundColor: const Color.fromARGB(255, 255, 255, 255),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(16),
              ),
              child: Text(entry.value),
            ),
          );
        }).toList(),
      ],
    );
  }
}
