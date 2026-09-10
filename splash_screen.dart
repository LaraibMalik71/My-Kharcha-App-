// ignore_for_file: deprecated_member_use

// ignore_for_file: deprecated_member

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'signup_screen.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'income_allocation.dart';
import 'database/database_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _walletController;
  late AnimationController _textController;
  late AnimationController _loadingController;

  late Animation<double> _walletProgress;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _loadingProgress;

  // ============================================================
  // BLUE + AMBER THEME
  // ============================================================

  static const Color backgroundColor = Color(0xFF0A1B2E);

  // Primary Blue
  static const Color primaryBlue = Color(0xFF3E7CB1);

  // Amber Accent
  static const Color amber = Color(0xFFF5A623);

  // Surface
  static const Color surface = Color(0xFF10263F);

  // Extra shades for wallet depth
  static const Color darkBlue = Color(0xFF081827);
  // ignore: unused_field
  static const Color mediumBlue = Color(0xFF285C88);
  static const Color lightBlue = Color(0xFF5B9DD1);

  @override
  void initState() {
    super.initState();

    _walletController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _walletProgress = CurvedAnimation(
      parent: _walletController,
      curve: Curves.easeInOut,
    );

    _textFade = CurvedAnimation(parent: _textController, curve: Curves.easeIn);

    _textSlide = Tween<Offset>(begin: const Offset(0, 0.20), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
        );

    _loadingProgress = CurvedAnimation(
      parent: _loadingController,
      curve: Curves.easeInOut,
    );

    _startAnimations();
    _decideNextScreen();
  }

  Future<void> _startAnimations() async {
    await _walletController.forward();

    await _textController.forward();

    _loadingController.forward();
  }

  Future<void> _decideNextScreen() async {
    await Future.delayed(const Duration(milliseconds: 4000));

    final currentUser = FirebaseAuth.instance.currentUser;

    if (!mounted) return;

    Widget nextScreen;

    if (currentUser != null) {
      final setupCompleted = await DatabaseHelper.instance.isSetupCompleted();

      if (setupCompleted) {
        nextScreen = const HomeScreen();
      } else {
        nextScreen = const IncomeAllocationScreen();
      }
    } else {
      final prefs = await SharedPreferences.getInstance();

      final hasSignedUpBefore = prefs.getBool('hasSignedUpBefore') ?? false;

      if (hasSignedUpBefore) {
        nextScreen = const LoginScreen();
      } else {
        nextScreen = const SignupScreen();
      }
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => nextScreen,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }
  // Future<void> _decideNextScreen() async {
  //   await Future.delayed(const Duration(milliseconds: 4000));

  //   final prefs = await SharedPreferences.getInstance();

  //   final hasSignedUpBefore = prefs.getBool('hasSignedUpBefore') ?? false;

  //   final currentUser = FirebaseAuth.instance.currentUser;

  //   if (!mounted) return;

  //   Widget nextScreen;

  //   if (currentUser != null) {
  //     nextScreen = const HomeScreen();
  //   } else if (hasSignedUpBefore) {
  //     nextScreen = const LoginScreen();
  //   } else {
  //     nextScreen = const SignupScreen();
  //   }

  //   Navigator.of(context).pushReplacement(
  //     PageRouteBuilder(
  //       pageBuilder: (_, _, _) => nextScreen,
  //       transitionsBuilder: (_, animation, _, child) =>
  //           FadeTransition(opacity: animation, child: child),
  //       transitionDuration: const Duration(milliseconds: 400),
  //     ),
  //   );
  // }

  // @override
  // void dispose() {
  //   _walletController.dispose();
  //   _textController.dispose();
  //   _loadingController.dispose();

  //   super.dispose();
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: _walletController,
            builder: (context, child) {
              final value = _walletProgress.value;

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // =================================================
                  // WALLET ANIMATION AREA
                  // =================================================

                  SizedBox(
                    width: 270,
                    height: 230,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // =============================================
                        // BLUE BACKGROUND GLOW
                        // =============================================

                        Container(
                          width: 215,
                          height: 215,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: primaryBlue.withOpacity(0.45 * value),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primaryBlue.withOpacity(0.22 * value),
                                blurRadius: 55,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                        ),

                        // =============================================
                        // CARDS RISING FROM WALLET
                        // =============================================
                        Positioned(
                          top: 42 + (1 - value) * 25,
                          child: Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, (1 - value) * 35),
                              child: Row(
                                children: [
                                  // LEFT BLUE CARD

                                  Transform.rotate(
                                    angle: -0.12,
                                    child: _moneyCard(primaryBlue),
                                  ),

                                  // RIGHT SURFACE CARD
                                  Transform.rotate(
                                    angle: 0.10,
                                    child: _moneyCard(surface),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // =============================================
                        // AMBER RUPEE COIN
                        // =============================================
                        Positioned(
                          top: 12 + (1 - value) * 20,
                          child: Transform.scale(
                            scale: 0.7 + (value * 0.3),
                            child: _coin(),
                          ),
                        ),

                        // =============================================
                        // BACK WALLET
                        // =============================================
                        Positioned(
                          bottom: 35,
                          child: Container(
                            width: 160,
                            height: 95,
                            decoration: BoxDecoration(
                              color: darkBlue,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: primaryBlue.withOpacity(0.30),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.45),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // =============================================
                        // FRONT WALLET BODY
                        // =============================================
                        Positioned(
                          bottom: 17,
                          child: Container(
                            width: 185,
                            height: 95,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF4B8DC4), Color(0xFF285C88)],
                              ),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: lightBlue, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryBlue.withOpacity(0.40),
                                  blurRadius: 22,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),

                            child: Stack(
                              children: [
                                // WALLET STITCHING

                                Positioned(
                                  top: 15,
                                  left: 18,
                                  child: Container(
                                    width: 90,
                                    height: 2,
                                    color: Colors.white.withOpacity(0.15),
                                  ),
                                ),

                                // WALLET CLASP
                                Positioned(
                                  right: -9,
                                  top: 32,
                                  child: Container(
                                    width: 50,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: surface,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: lightBlue),
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: const BoxDecoration(
                                          color: amber,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // =============================================
                        // OPENING WALLET FLAP
                        // =============================================
                        Positioned(
                          bottom: 82,
                          child: Transform(
                            alignment: Alignment.bottomCenter,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.002)
                              ..rotateX(-1.1 * value),
                            child: Container(
                              width: 170,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF5B9DD1),
                                    Color(0xFF3E7CB1),
                                  ],
                                ),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(25),
                                ),
                                border: Border.all(color: lightBlue),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),

                  // =================================================
                  // MY KHARCHA TEXT
                  // =================================================
                  FadeTransition(
                    opacity: _textFade,
                    child: SlideTransition(
                      position: _textSlide,
                      child: Column(
                        children: [
                          const Text(
                            'MY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                            ),
                          ),

                          const Text(
                            'KHARCHA',
                            style: TextStyle(
                              color: primaryBlue,
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                            ),
                          ),

                          const SizedBox(height: 12),

                          Text(
                            'Track Smart. Spend Wise. Save More.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 38),

                  // =================================================
                  // BLUE + AMBER LOADING BAR
                  // =================================================
                  AnimatedBuilder(
                    animation: _loadingController,
                    builder: (context, child) {
                      return Container(
                        width: 150,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _loadingProgress.value,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [primaryBlue, Color(0xFF5B9DD1), amber],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MONEY / CREDIT CARD
  // ============================================================

  Widget _moneyCard(Color color) {
    return Container(
      width: 78,
      height: 90,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CARD CHIP

            Container(
              width: 20,
              height: 14,
              decoration: BoxDecoration(
                color: amber,
                borderRadius: BorderRadius.circular(3),
              ),
            ),

            const Spacer(),

            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            const SizedBox(height: 5),

            Container(
              width: 30,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // AMBER RUPEE COIN
  // ============================================================

  Widget _coin() {
    return Container(
      width: 62,
      height: 62,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,

        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.3),
          colors: [Color(0xFFFFD77A), Color(0xFFF5A623), Color(0xFFB96D00)],
        ),

        border: Border.all(color: const Color(0xFFFFE2A0), width: 3),

        boxShadow: [
          BoxShadow(
            color: amber.withValues(alpha: 0.50),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),

      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFFFE2A0), width: 1),
        ),
        child: const Text(
          '₨',
          style: TextStyle(
            color: Color(0xFF603900),
            fontSize: 38,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
