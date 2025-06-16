import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import 'result_screen.dart';
import '../widgets/quiz_question.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with TickerProviderStateMixin {
  int _currentQuestion = 0;
  bool _isTransitioning = false;
  bool _showWelcome = true;

  final Map<String, int> _scores = {
    'Kering': 0,
    'Berminyak': 0,
    'Sensitif': 0,
    'Kombinasi': 0,
  };

  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _progressController;
  late AnimationController _welcomeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _welcomeAnimation;
  late Animation<double> _pulseAnimation;

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

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _welcomeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
    
    _welcomeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _welcomeController,
      curve: Curves.elasticOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _welcomeController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _progressController.dispose();
    _welcomeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _startQuiz() {
    setState(() {
      _showWelcome = false;
    });
    _fadeController.forward();
    _updateProgress();
  }

  void _updateProgress() {
    final progress = (_currentQuestion + 1) / _questions.length;
    _progressController.animateTo(progress);
  }

  void _answerQuestion(String skinType) {
    if (_isTransitioning) return;
    
    setState(() {
      _isTransitioning = true;
      _scores[skinType] = _scores[skinType]! + 1;
    });

    // Fade out current question
    _fadeController.reverse().then((_) {
      setState(() {
        _currentQuestion++;
        _isTransitioning = false;
      });
      
      _updateProgress();

      if (_currentQuestion >= _questions.length) {
        _showResults();
      } else {
        // Fade in next question
        _fadeController.forward();
      }
    });
  }

  Future<void> _showResults() async {
    // Show loading animation - FIXED CENTERED LAYOUT FOR MOBILE
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 40), // MOBILE OPTIMIZED MARGINS
          padding: const EdgeInsets.all(24), // COMPACT PADDING
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                const Color(0xFFFCE4EC),
              ],
            ),
            borderRadius: BorderRadius.circular(20), // COMPACT RADIUS
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center, // CENTER ALIGNMENT
            crossAxisAlignment: CrossAxisAlignment.center, // CENTER ALIGNMENT
            children: [
              // Icon Container - CENTERED
              Container(
                width: 70, // COMPACT SIZE FOR MOBILE
                height: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFF48FB1),
                      const Color(0xFFEC407A),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEC407A).withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.analytics,
                  color: Colors.white,
                  size: 35, // COMPACT ICON SIZE
                ),
              ),
              const SizedBox(height: 20), // COMPACT SPACING
              
              // Main Title - PERFECTLY CENTERED
              Text(
                'Menganalisis Kulit Anda',
                style: GoogleFonts.poppins(
                  fontSize: 18, // COMPACT FONT SIZE FOR MOBILE
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center, // EXPLICIT CENTER ALIGNMENT
              ),
              const SizedBox(height: 8), // COMPACT SPACING
              
              // Subtitle - PERFECTLY CENTERED
              Text(
                'Mohon tunggu sebentar...',
                style: GoogleFonts.poppins(
                  fontSize: 13, // COMPACT FONT SIZE FOR MOBILE
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center, // EXPLICIT CENTER ALIGNMENT
              ),
              const SizedBox(height: 20), // COMPACT SPACING
              
              // Loading Indicator - CENTERED
              Container(
                width: 35, // COMPACT SIZE
                height: 35,
                child: CircularProgressIndicator(
                  color: const Color(0xFFEC407A),
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Simulate analysis time
    await Future.delayed(const Duration(seconds: 3));

    final result = _scores.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    await _saveSkinType(result);

    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading dialog
      _navigateToResult(result);
    }
  }

  Future<void> _saveSkinType(String result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('skinType', result);
  }

  void _navigateToResult(String result) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
            ResultScreen(skinType: result, analysisResult: _scores),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFFCE4EC),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFFCE4EC),
                const Color(0xFFF8BBD0),
              ],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ScaleTransition(
                scale: _welcomeAnimation,
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 30,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFF48FB1),
                                const Color(0xFFEC407A),
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEC407A).withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.face_retouching_natural,
                            color: Colors.white,
                            size: 50,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Analisis Kulit',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Temukan jenis kulit Anda dengan\nkuis interaktif kami',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFCE4EC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFEC407A).withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEC407A),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.quiz,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '4 Pertanyaan Singkat',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEC407A),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.recommend,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Rekomendasi Personal',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFF48FB1),
                              const Color(0xFFEC407A),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEC407A).withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _startQuiz,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Mulai Kuis',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showWelcome) {
      return _buildWelcomeScreen();
    }

    if (_currentQuestion >= _questions.length) {
      return Scaffold(
        backgroundColor: const Color(0xFFFCE4EC),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20), // MOBILE PADDING
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center, // CENTER ALIGNMENT
              children: [
                Container(
                  width: 70, // COMPACT SIZE FOR MOBILE
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFF48FB1),
                        const Color(0xFFEC407A),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.analytics,
                    color: Colors.white,
                    size: 35, // COMPACT ICON
                  ),
                ),
                const SizedBox(height: 20), // COMPACT SPACING
                Text(
                  'Menganalisis hasil kuis...',
                  style: GoogleFonts.poppins(
                    fontSize: 16, // COMPACT FONT FOR MOBILE
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center, // EXPLICIT CENTER ALIGNMENT
                ),
                const SizedBox(height: 16),
                const CircularProgressIndicator(
                  color: Color(0xFFEC407A),
                  strokeWidth: 3,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final current = _questions[_currentQuestion];

    return Scaffold(
      backgroundColor: const Color(0xFFFCE4EC),
      appBar: AppBar(
        title: Text(
          'Kuis Analisis Kulit',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFF8BBD0),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Enhanced Progress Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  const Color(0xFFFCE4EC),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pertanyaan ${_currentQuestion + 1} dari ${_questions.length}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFF48FB1),
                            const Color(0xFFEC407A),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${((_currentQuestion + 1) / _questions.length * 100).round()}%',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _progressAnimation.value,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFF48FB1),
                                const Color(0xFFEC407A),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEC407A).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Question Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: QuizQuestion(
                key: ValueKey(_currentQuestion),
                question: current['question'],
                answers: Map<String, String>.from(current['answers']),
                onAnswerSelected: _answerQuestion,
              ),
            ),
          ),
        ],
      ),
    );
  }
}