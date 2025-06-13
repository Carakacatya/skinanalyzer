import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Screens
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/main_nav_screen.dart';
import 'screens/tips_screen.dart';
import 'screens/quiz_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/payment_success_screen.dart';
import 'screens/article_screen.dart';
import 'screens/product_screen.dart';
import 'screens/result_screen.dart';
import 'screens/store_single_product.dart';

// Providers & Constants
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'constants/colors.dart';

void main() {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    MultiProvider(
      providers: [
        // Initialize AuthProvider and call initialize() to check login status
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: const SkinAnalyzerApp(),
    ),
  );
}

class SkinAnalyzerApp extends StatelessWidget {
  const SkinAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Skin Analyzer',
      theme: ThemeData(
        brightness: isDarkMode ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: isDarkMode
            ? Colors.grey[900]
            : const Color.fromARGB(255, 248, 233, 235),
        fontFamily: 'Montserrat',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: isDarkMode ? Brightness.dark : Brightness.light,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/', // default ke login screen
      routes: {
        '/': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/quiz': (context) => const QuizScreen(),
        '/tips': (context) => const TipsScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/edit_profile': (context) => const EditProfileScreen(),
        '/products': (context) => const ProductScreen(),
        '/payment_success': (context) => const PaymentSuccessScreen(),
        '/articles': (context) => const ArticleScreen(),
        '/cart': (context) => const CartScreen(),
        '/login': (context) => const LoginScreen() // Kept as in original code
      },
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/productDetail':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null) {
              return MaterialPageRoute(
                builder: (_) => ProductDetailScreen(product: args),
              );
            }
            break;

          case '/checkout':
            final cart = settings.arguments as List<Map<String, dynamic>>?;
            if (cart != null) {
              return MaterialPageRoute(
                builder: (_) => CheckoutScreen(cart: cart),
              );
            }
            break;

          case '/payment':
            final total = settings.arguments as double?;
            if (total != null) {
              return MaterialPageRoute(
                builder: (_) => PaymentScreen(totalPrice: total),
              );
            }
            break;

          case '/result':
            final skinType = settings.arguments as String?;
            if (skinType != null) {
              return MaterialPageRoute(
                builder: (_) => ResultScreen(skinType: skinType),
              );
            }
            break;

          case '/main':
            final index = settings.arguments as int? ?? 0;
            return MaterialPageRoute(
              builder: (_) => MainNavScreen(initialIndex: index),
            );
        }

        // fallback route
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Halaman tidak ditemukan')),
          ),
        );
      },
    );
  }
}