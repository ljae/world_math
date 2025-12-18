import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../theme.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../services/terms_service.dart';
import '../widgets/terms_viewer_modal.dart';
import 'login_screen.dart';
import 'main_screen.dart';

class TermsAgreementScreen extends StatefulWidget {
  const TermsAgreementScreen({super.key});

  @override
  State<TermsAgreementScreen> createState() => _TermsAgreementScreenState();
}

class _TermsAgreementScreenState extends State<TermsAgreementScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final TermsService _termsService = TermsService();

  bool _termsAgreed = false;
  bool _privacyAgreed = false;
  bool _allAgreed = false;
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  bool get _canProceed => _termsAgreed && _privacyAgreed;

  void _onTermsCheckChanged(bool? value) {
    setState(() {
      _termsAgreed = value ?? false;
      _updateAllAgreed();
    });
  }

  void _onPrivacyCheckChanged(bool? value) {
    setState(() {
      _privacyAgreed = value ?? false;
      _updateAllAgreed();
    });
  }

  void _onAllAgreedChanged(bool? value) {
    setState(() {
      _allAgreed = value ?? false;
      _termsAgreed = _allAgreed;
      _privacyAgreed = _allAgreed;
    });
  }

  void _updateAllAgreed() {
    _allAgreed = _termsAgreed && _privacyAgreed;
  }

  Future<void> _showTermsDetail(String type) async {
    String content;
    String title;

    if (type == 'terms') {
      content = await _termsService.loadServiceTerms();
      title = '서비스 이용약관';
    } else {
      content = await _termsService.loadPrivacyPolicy();
      title = '개인정보처리방침';
    }

    if (!mounted) return;

    await TermsViewerModal.show(
      context,
      title: title,
      content: content,
    );
  }

  Future<void> _proceedToNextStep() async {
    if (!_canProceed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('모든 필수 약관에 동의해주세요.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = auth.FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('로그인 정보를 찾을 수 없습니다.');
      }

      // 기존 사용자 정보 가져오기 (있으면)
      final existingUser = await _firestoreService.getUser(currentUser.uid);

      // 메타데이터 로드하여 현재 버전 가져오기
      await _termsService.loadMetadata();

      // 약관 동의 정보 업데이트
      final user = User(
        id: currentUser.uid,
        nickname: existingUser?.nickname ?? '',
        schoolName: existingUser?.schoolName ?? '',
        termsAgreed: true,
        privacyAgreed: true,
        termsAgreedAt: DateTime.now(),
        termsVersion: _termsService.getCurrentServiceTermsVersion(),
        privacyVersion: _termsService.getCurrentPrivacyPolicyVersion(),
      );

      await _firestoreService.updateUser(user);

      if (!mounted) return;

      // 기존 사용자인 경우 (schoolName이 있으면)
      if (existingUser != null && existingUser.schoolName.isNotEmpty) {
        // MainScreen으로 이동 (이미 프로필 완성)
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const MainScreen(),
          ),
        );
      } else {
        // 신규 사용자인 경우 LoginScreen으로 이동
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const LoginScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('약관 동의 처리 실패: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.paperColor,
      appBar: AppBar(
        title: const Text('약관 동의'),
        backgroundColor: AppTheme.paperColor,
        elevation: 0,
        leading: Container(), // 뒤로 가기 버튼 제거
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  const Text(
                    '서비스 이용을 위해\n약관에 동의해주세요',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '학교 대항전과 수학 챌린지를 즐기기 위해\n필수 약관에 동의가 필요합니다.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // All Agree Checkbox
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: _allAgreed
                          ? AppTheme.primaryColor.withOpacity(0.05)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _allAgreed
                            ? AppTheme.primaryColor
                            : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: CheckboxListTile(
                      value: _allAgreed,
                      onChanged: _onAllAgreedChanged,
                      title: const Text(
                        '전체 동의',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                      ),
                      activeColor: AppTheme.primaryColor,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Individual Terms
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildTermsItem(
                            title: '[필수] 서비스 이용약관',
                            value: _termsAgreed,
                            onChanged: _onTermsCheckChanged,
                            onViewDetails: () => _showTermsDetail('terms'),
                          ),
                          const SizedBox(height: 12),
                          _buildTermsItem(
                            title: '[필수] 개인정보처리방침',
                            value: _privacyAgreed,
                            onChanged: _onPrivacyCheckChanged,
                            onViewDetails: () => _showTermsDetail('privacy'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Proceed Button
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading || !_canProceed
                          ? null
                          : _proceedToNextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canProceed
                            ? AppTheme.primaryColor
                            : Colors.grey.shade300,
                        foregroundColor:
                            _canProceed ? Colors.white : Colors.grey.shade600,
                        elevation: _canProceed ? 4 : 0,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              '동의하고 계속하기',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildTermsItem({
    required String title,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required VoidCallback onViewDetails,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: value
            ? AppTheme.primaryColor.withOpacity(0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? AppTheme.primaryColor : Colors.grey.shade300,
        ),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            value: value,
            onChanged: onChanged,
            title: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textColor,
              ),
            ),
            activeColor: AppTheme.primaryColor,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 52, right: 12, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onViewDetails,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '전문 보기',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: Colors.grey.shade600,
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
}
