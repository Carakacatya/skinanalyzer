import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/colors.dart';
import 'result_screen.dart';
import '../widgets/quiz_question.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentQuestion = 0;

  final Map<String, int> _scores = {
    'Kering': 0,
    'Berminyak': 0,
    'Sensitif': 0,
    'Kombinasi': 0,
  };

  final List<Map<String, dynamic>> _questions = [
    {
      'question': 'Bagaimana kondisi kulitmu setelah mencuci muka?',
      'answers': {
        'Kering': 'Tertarik dan terasa kencang',
        'Berminyak': 'Langsung berminyak kembali',
        'Sensitif': 'Merah atau gatal',
        'Kombinasi': 'Beberapa bagian kering, yang lain berminyak',
      },
    },
    {
      'question': 'Bagaimana pori-pori di wajahmu?',
      'answers': {
        'Kering': 'Sangat kecil hampir tak terlihat',
        'Berminyak': 'Terlihat besar di seluruh wajah',
        'Sensitif': 'Ukuran sedang tapi mudah iritasi',
        'Kombinasi': 'Besar di area T-zone saja',
      },
    },
    {
      'question': 'Kulitmu bereaksi seperti apa terhadap produk baru?',
      'answers': {
        'Kering': 'Tidak banyak reaksi, tapi cepat kering',
        'Berminyak': 'Cenderung muncul jerawat',
        'Sensitif': 'Mudah kemerahan atau gatal',
        'Kombinasi': 'Beragam, tergantung area wajah',
      },
    },
    {
      'question': 'Bagaimana tampilan kulitmu di siang hari?',
      'answers': {
        'Kering': 'Kusam dan bersisik',
        'Berminyak': 'Sangat berminyak dan mengilap',
        'Sensitif': 'Kemerahan atau perih',
        'Kombinasi': 'Berminyak di T-zone, normal di area lain',
      },
    },
  ];

  void _answerQuestion(String skinType) {
    setState(() {
      _scores[skinType] = _scores[skinType]! + 1;
      _currentQuestion++;
    });

    if (_currentQuestion >= _questions.length) {
      final result = _scores.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      _saveSkinType(result);
    }
  }

  Future<void> _saveSkinType(String result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('skinType', result);

    if (context.mounted) {
      _showResult(result);
    }
  }

  void _showResult(String result) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(skinType: result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentQuestion >= _questions.length) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final current = _questions[_currentQuestion];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kuis Jenis Kulit'),
        backgroundColor: AppColors.primary,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: QuizQuestion(
          question: current['question'],
          answers: Map<String, String>.from(current['answers']),
          onAnswerSelected: _answerQuestion,
        ),
      ),
    );
  }
}