import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _loadingController;
  late AnimationController _backgroundController;

  late Animation<double> _logoFadeAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotationAnimation;

  late Animation<Offset> _titleSlideAnimation;
  late Animation<double> _titleFadeAnimation;

  late Animation<Offset> _taglineSlideAnimation;
  late Animation<double> _taglineFadeAnimation;

  late Animation<double> _loadingFadeAnimation;
  late Animation<double> _loadingScaleAnimation;

  late Animation<double> _backgroundAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Logo animations
    _logoFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _logoScaleAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
    ));

    _logoRotationAnimation = Tween<double>(
      begin: -0.5,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutBack),
    ));

    // Title animations
    _titleSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    ));

    _titleFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    ));

    // Tagline animations
    _taglineSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
    ));

    _taglineFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));

    // Loading animations
    _loadingFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _loadingController,
      curve: Curves.easeInOut,
    ));

    _loadingScaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _loadingController,
      curve: Curves.elasticOut,
    ));

    // Background animation
    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeInOut,
    ));

    // Start animations in sequence
    _startAnimations();

    // Navigate to home after all animations
    _navigateToHome();
  }

  void _startAnimations() async {
    // Start background animation immediately
    _backgroundController.forward();

    // Start logo animation after a short delay
    await Future.delayed(const Duration(milliseconds: 300));
    _logoController.forward();

    // Start text animations after logo starts
    await Future.delayed(const Duration(milliseconds: 500));
    _textController.forward();

    // Start loading animation last
    await Future.delayed(const Duration(milliseconds: 800));
    _loadingController.forward();
  }

  _navigateToHome() async {
    await Future.delayed(const Duration(seconds: 4));
    if (mounted) {
      try {
        // Check if user is already logged in, with error handling
        final isLoggedIn = AuthService.isLoggedIn;
        if (isLoggedIn) {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } catch (e) {
        // If there's an error checking login state, default to login screen
        print('Error checking login state: $e');
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _loadingController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _backgroundController,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor
                      .withOpacity(0.8 + 0.2 * _backgroundAnimation.value),
                  AppTheme.primaryDark
                      .withOpacity(0.9 + 0.1 * _backgroundAnimation.value),
                  AppTheme.primaryColor
                      .withOpacity(0.7 + 0.3 * _backgroundAnimation.value),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: Stack(
              children: [
                // Animated background elements
                _buildBackgroundElements(),

                // Main content
                SafeArea(
                  child: Column(
                    children: [
                      // Logo Section
                      Expanded(
                        flex: 3,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Animated Logo
                              AnimatedBuilder(
                                animation: _logoController,
                                builder: (context, child) {
                                  return FadeTransition(
                                    opacity: _logoFadeAnimation,
                                    child: ScaleTransition(
                                      scale: _logoScaleAnimation,
                                      child: Transform.rotate(
                                        angle: _logoRotationAnimation.value,
                                        child: Container(
                                          width: 140,
                                          height: 140,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                AppTheme.extraLargeRadius,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.3),
                                                blurRadius: 25,
                                                offset: const Offset(0, 15),
                                                spreadRadius: 5,
                                              ),
                                              BoxShadow(
                                                color: Colors.white
                                                    .withOpacity(0.1),
                                                blurRadius: 10,
                                                offset: const Offset(0, -5),
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                AppTheme.extraLargeRadius,
                                            child: _buildLogo(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(height: AppTheme.spacingXL),

                              // Animated App Name
                              AnimatedBuilder(
                                animation: _textController,
                                builder: (context, child) {
                                  return SlideTransition(
                                    position: _titleSlideAnimation,
                                    child: FadeTransition(
                                      opacity: _titleFadeAnimation,
                                      child: Text(
                                        'EduBazaar',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineLarge
                                            ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 2.0,
                                          fontSize: 36,
                                          shadows: [
                                            Shadow(
                                              color:
                                                  Colors.black.withOpacity(0.3),
                                              offset: const Offset(0, 2),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(height: AppTheme.spacingM),

                              // Animated Tagline
                              AnimatedBuilder(
                                animation: _textController,
                                builder: (context, child) {
                                  return SlideTransition(
                                    position: _taglineSlideAnimation,
                                    child: FadeTransition(
                                      opacity: _taglineFadeAnimation,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppTheme.spacingL,
                                          vertical: AppTheme.spacingS,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.1),
                                          borderRadius: AppTheme.mediumRadius,
                                          border: Border.all(
                                            color:
                                                Colors.white.withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          'Student Marketplace & Learning Community',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Loading Section
                      Expanded(
                        flex: 1,
                        child: AnimatedBuilder(
                          animation: _loadingController,
                          builder: (context, child) {
                            return FadeTransition(
                              opacity: _loadingFadeAnimation,
                              child: ScaleTransition(
                                scale: _loadingScaleAnimation,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Custom Loading Indicator
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(25),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.3),
                                          width: 2,
                                        ),
                                      ),
                                      child: const CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                        strokeWidth: 3,
                                      ),
                                    ),

                                    const SizedBox(height: AppTheme.spacingM),

                                    // Loading Text with animation
                                    Text(
                                      'Initializing...',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Footer
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppTheme.spacingL),
                        child: AnimatedBuilder(
                          animation: _loadingController,
                          builder: (context, child) {
                            return FadeTransition(
                              opacity: _loadingFadeAnimation,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.copyright,
                                    size: 16,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '2024 EduBazaar • Version 1.0.0',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 12,
                                        ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBackgroundElements() {
    return AnimatedBuilder(
      animation: _backgroundController,
      builder: (context, child) {
        return Stack(
          children: [
            // Floating circles
            Positioned(
              top: 50 + 20 * _backgroundAnimation.value,
              right: 30 + 10 * _backgroundAnimation.value,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white
                      .withOpacity(0.1 * _backgroundAnimation.value),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: 100 + 30 * _backgroundAnimation.value,
              left: 20 + 15 * _backgroundAnimation.value,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white
                      .withOpacity(0.08 * _backgroundAnimation.value),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              top: 200 + 25 * _backgroundAnimation.value,
              left: 50 + 20 * _backgroundAnimation.value,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white
                      .withOpacity(0.12 * _backgroundAnimation.value),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/images/edu2.png',
      width: 90,
      height: 90,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: AppTheme.extraLargeRadius,
          ),
          child: const Icon(
            Icons.school,
            size: 70,
            color: Colors.white,
          ),
        );
      },
    );
  }
}
