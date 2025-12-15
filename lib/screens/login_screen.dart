import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:world_math/models/models.dart';
import '../theme.dart';
import '../services/firestore_service.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _schoolController = TextEditingController();
  final _nicknameFocus = FocusNode(); 
  final _loginButtonFocus = FocusNode();
  
  School? _selectedSchool;
  List<School> _latestOptions = [];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isLoading = false;

  final FirestoreService _dataService = FirestoreService();

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

    _animationController.forward().then((_) {
      // Auto-focus after animation
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _nicknameFocus.requestFocus();
      });
    });

    // Pre-fill nickname from Firebase Auth if available
    final currentUser = auth.FirebaseAuth.instance.currentUser;
    if (currentUser?.displayName != null) {
      _nicknameController.text = currentUser!.displayName!;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nicknameController.dispose();
    _schoolController.dispose();
    _nicknameFocus.dispose();
    _loginButtonFocus.dispose();
    super.dispose();
  }

  Future<void> _completeProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedSchool == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('학교를 검색하고 목록에서 선택해주세요.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final currentUser = auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인 정보가 없습니다. 다시 로그인해주세요.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = User(
        id: currentUser.uid,
        nickname: _nicknameController.text,
        schoolName: _selectedSchool!.school_name,
      );
      await _dataService.updateUser(user);
      
      // Update Firebase Auth Profile Display Name if changed
      if (currentUser.displayName != _nicknameController.text) {
        await currentUser.updateDisplayName(_nicknameController.text);
      }

      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                )),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('프로필 저장 실패: $e'),
            backgroundColor: Colors.redAccent,
          ),
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                       Text(
                        '추가 정보 입력',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '원활한 서비스 이용을 위해\n나머지 정보를 입력해주세요.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 48),

                      // Inputs
                      TextFormField(
                        controller: _nicknameController,
                        focusNode: _nicknameFocus,
                        decoration: const InputDecoration(
                          labelText: '닉네임',
                          prefixIcon: Icon(Icons.person_outline),
                          hintText: '사용할 닉네임을 입력하세요',
                        ),
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) {
                          FocusScope.of(context).nextFocus(); 
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '닉네임을 입력해주세요';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // School Autocomplete
                      Autocomplete<School>(
                        displayStringForOption: (School option) => option.school_name,
                        optionsBuilder: (TextEditingValue textEditingValue) async {
                          if (textEditingValue.text == '') {
                            setState(() {
                              _selectedSchool = null;
                              _latestOptions = [];
                            });
                            return const Iterable<School>.empty();
                          }
                          try {
                            final results = await _dataService.searchSchools(textEditingValue.text);
                            final options = results.toList();
                            
                            if (options.isEmpty) {
                              options.add(School.independent());
                            }
                            
                            setState(() {
                              _latestOptions = options;
                            });
                            return options;
                          } catch (e) {
                             setState(() => _latestOptions = []);
                            return const Iterable<School>.empty();
                          }
                        },
                        onSelected: (School selection) {
                          setState(() {
                            _selectedSchool = selection;
                          });
                          _schoolController.text = selection.school_name;
                          _loginButtonFocus.requestFocus();
                        },
                        fieldViewBuilder: (BuildContext context, TextEditingController fieldTextEditingController, FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {
                          if (!fieldFocusNode.hasListeners) {
                            fieldFocusNode.addListener(() {
                              if (!fieldFocusNode.hasFocus) {
                                if (_selectedSchool == null && _latestOptions.isNotEmpty && fieldTextEditingController.text.isNotEmpty) {
                                  final firstOption = _latestOptions.first;
                                  setState(() {
                                    _selectedSchool = firstOption;
                                  });
                                  fieldTextEditingController.text = firstOption.school_name;
                                  _loginButtonFocus.requestFocus();
                                }
                              }
                            });
                          }

                          return TextFormField(
                            controller: fieldTextEditingController,
                            focusNode: fieldFocusNode,
                            decoration: const InputDecoration(
                              labelText: '학교',
                              prefixIcon: Icon(Icons.school_outlined),
                              hintText: '학교를 검색하여 선택하세요',
                            ),
                            textInputAction: TextInputAction.done,
                            onChanged: (value) {
                              if (value != _selectedSchool?.school_name) {
                                setState(() {
                                  _selectedSchool = null;
                                });
                              }
                            },
                            onFieldSubmitted: (value) {
                              if (_selectedSchool == null && _latestOptions.isNotEmpty) {
                                final firstOption = _latestOptions.first;
                                setState(() {
                                  _selectedSchool = firstOption;
                                });
                                fieldTextEditingController.text = firstOption.school_name;
                                _loginButtonFocus.requestFocus();
                              }
                              onFieldSubmitted(); 
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '학교를 검색해주세요';
                              }
                              if (_selectedSchool == null) {
                                return '목록에 있는 학교를 선택해야 합니다.';
                              }
                              return null;
                            },
                          );
                        },
                        optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<School> onSelected, Iterable<School> options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              child: Container(
                                width: 300,
                                constraints: const BoxConstraints(maxHeight: 200),
                                color: Colors.white,
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  itemCount: options.length,
                                  shrinkWrap: true,
                                  itemBuilder: (BuildContext context, int index) {
                                    final School option = options.elementAt(index);
                                    return ListTile(
                                      title: Text(option.school_name),
                                      subtitle: Text(option.location),
                                      onTap: () {
                                        onSelected(option);
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),

                      // Button
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 56,
                        child: ElevatedButton(
                          focusNode: _loginButtonFocus,
                          onPressed: _isLoading || _selectedSchool == null ? null : _completeProfile,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: _isLoading ? 0 : 4,
                            shadowColor: AppTheme.primaryColor.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            disabledBackgroundColor: Colors.grey.shade300,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check, size: 20),
                                    SizedBox(width: 8),
                                    Text('시작하기', style: TextStyle(fontSize: 18)),
                                  ],
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
}
