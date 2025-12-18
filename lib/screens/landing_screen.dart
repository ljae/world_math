import 'package:flutter/material.dart';
import 'package:world_math/services/auth_service.dart';
import 'package:world_math/services/firestore_service.dart';
import 'package:world_math/theme.dart';
import 'login_screen.dart'; // Will serve as Profile Setup
import 'main_screen.dart';
import 'terms_agreement_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();
    _checkCurrentUser();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkCurrentUser() async {
    final user = _authService.currentUser;
    if (user != null) {
      // Already logged in, check profile
      await _navigateBasedOnProfile(user.uid);
    }
  }

  Future<void> _navigateBasedOnProfile(String uid) async {
    setState(() => _isLoading = true);
    try {
      final userDoc = await _firestoreService.getUser(uid);
      if (!mounted) return;

      // 디버깅 로그
      print('=== 약관 동의 확인 ===');
      print('userDoc: ${userDoc != null ? "존재" : "null"}');
      if (userDoc != null) {
        print('termsAgreed: ${userDoc.termsAgreed}');
        print('privacyAgreed: ${userDoc.privacyAgreed}');
        print('schoolName: ${userDoc.schoolName}');
      }

      // 신규 사용자 또는 약관 미동의
      if (userDoc == null ||
          userDoc.termsAgreed != true ||
          userDoc.privacyAgreed != true) {
        print('→ TermsAgreementScreen으로 이동');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TermsAgreementScreen()),
        );
        return;
      }

      // 약관 동의 완료, 프로필 미완성
      if (userDoc.schoolName.isEmpty) {
        print('→ LoginScreen으로 이동');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }

      // 모든 프로필 완성
      print('→ MainScreen으로 이동');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } catch (e) {
      print('프로필 확인 중 에러: $e');
      // Error checking profile, maybe stay here or go to login?
      // If error, assume profile incomplete or just let them stay to try again
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSocialLogin(Future<dynamic> Function() signInMethod) async {
    setState(() => _isLoading = true);
    try {
      final credential = await signInMethod();
      if (credential != null) {
        // Login success
        await _navigateBasedOnProfile(credential.user!.uid);
      } else {
         // Cancelled
         setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 실패: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.paperColor,
              AppTheme.paperColor,
              AppTheme.primaryColor.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            width: 250,
                            height: 250,
                            padding: const EdgeInsets.all(20.0),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '대치동 김부장 아들의\n세상수학',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '현실감각 체험수학',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.accentColor,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.1,
                          ),
                    ),
                    const SizedBox(height: 60),

                     if (_isLoading)
                      const CircularProgressIndicator()
                    else ...[
                      // Kakao Login
                      _SocialLoginButton(
                        text: '카카오로 시작하기',
                        textColor: const Color(0xFF3C1E1E), // Kakao Label Color
                        color: const Color(0xFFFEE500), // Kakao Yellow
                        icon: Icons.chat_bubble, // Placeholder for Kakao Icon
                        onPressed: () => _handleSocialLogin(_authService.signInWithKakao),
                      ),
                      const SizedBox(height: 16),
                      
                      // Google Login
                      _SocialLoginButton(
                        text: 'Google로 시작하기',
                        textColor: Colors.black54,
                        color: Colors.white,
                        icon: Icons.g_mobiledata, // Placeholder
                        borderColor: Colors.grey.shade300,
                        onPressed: () => _handleSocialLogin(_authService.signInWithGoogle),
                      ),
                      const SizedBox(height: 16),
                      
                      // Apple Login
                      _SocialLoginButton(
                        text: 'Apple로 시작하기',
                        textColor: Colors.white,
                        color: Colors.black,
                        icon: Icons.apple,
                        onPressed: () => _handleSocialLogin(_authService.signInWithApple),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialLoginButton extends StatelessWidget {
  final String text;
  final Color textColor;
  final Color color;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? borderColor;

  const _SocialLoginButton({
    required this.text,
    required this.textColor,
    required this.color,
    required this.icon,
    required this.onPressed,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: borderColor != null ? BorderSide(color: borderColor!) : BorderSide.none,
          ),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: textColor),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
