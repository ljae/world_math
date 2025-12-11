import 'package:flutter/material.dart';
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
  final _loginButtonFocus = FocusNode(); // Added for login button focus
  
  School? _selectedSchool;
  List<School> _latestOptions = []; // Cache for auto-selection

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

  // ... (previous _login code remains same, skipping update here as it's outside the target lines roughly or sticking to minimal edit) ...
  // Actually, I need to keep the _login method. The tool replaces a block.
  // I will assume the prompt implies I should perform the minimal necessary edits or if replacing a large block, include needed parts.
  // Let's replace from start of state class to end of Autocomplete to be safe and clean.
  
  Future<void> _login() async {
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

    setState(() => _isLoading = true);

    final userId = 'mock_user_id'; 
    final user = User(
      id: userId,
      nickname: _nicknameController.text,
      schoolName: _selectedSchool!.school_name,
    );
    await _dataService.updateUser(user);

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
                      // Logo
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Container(
                              width: 270,
                              height: 270,
                              padding: const EdgeInsets.all(20.0),
                              decoration: const BoxDecoration(
                                color: Colors.transparent,
                              ),
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),

                      // Title
                      Text(
                        '대치동 김부장 아들의\n세상수학',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              color: AppTheme.primaryColor,
                              height: 1.3,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '현실감각 체험수학',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.accentColor,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                      ),
                      const SizedBox(height: 48),

                      // Inputs
                      TextFormField(
                        controller: _nicknameController,
                        focusNode: _nicknameFocus, // Attached FocusNode
                        decoration: const InputDecoration(
                          labelText: '닉네임',
                          prefixIcon: Icon(Icons.person_outline),
                          hintText: '사용할 닉네임을 입력하세요',
                        ),
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) {
                          FocusScope.of(context).nextFocus(); // Move focus to School field
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
                            // Search schools
                            final results = await _dataService.searchSchools(textEditingValue.text);
                            final options = results.toList();
                            
                            // If no results, provide "Independent" option
                            if (options.isEmpty) {
                              options.add(School.independent());
                            }
                            
                            setState(() {
                              _latestOptions = options;
                            });
                            return options;
                          } catch (e) {
                            print('Error searching schools: $e');
                             // Fallback to independent on error? OR just empty
                             setState(() => _latestOptions = []);
                            return const Iterable<School>.empty();
                          }
                        },
                        onSelected: (School selection) {
                          setState(() {
                            _selectedSchool = selection;
                          });
                          _schoolController.text = selection.school_name;
                          _loginButtonFocus.requestFocus(); // Focus button on selection
                        },
                        fieldViewBuilder: (BuildContext context, TextEditingController fieldTextEditingController, FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {
                          // Ensure we only add the listener once. 
                          // However, fieldViewBuilder can be rebuilt. 
                          // A cleaner way is to use a StatefulWidget wrapper or just add/remove listener carefully.
                          // Since FocusNode is passed in, we can just use a Focus widget or add listener.
                          // Let's add a listener that checks on focus loss.
                          if (!fieldFocusNode.hasListeners) {
                            fieldFocusNode.addListener(() {
                              if (!fieldFocusNode.hasFocus) {
                                // Lost focus (e.g. Tab pressed)
                                if (_selectedSchool == null && _latestOptions.isNotEmpty && fieldTextEditingController.text.isNotEmpty) {
                                  final firstOption = _latestOptions.first;
                                  // We need to call onSelected logic. 
                                  // Since we don't have direct access to onSelected callback here easily without passing it down or calling it via controller update + manual state set.
                                  // But we can just set the state and text.
                                  // Note: The Autocomplete widget's internal state might not update if we just set our local state, 
                                  // but setting the controller text usually triggers the options builder again or validates it.
                                  // Actually, the cleanest is to update the controller text and our local state.
                                  // AND we should probably verify if the current text matches the first option partially or just force it.
                                  // The requirement is "automatically select first list".
                                  
                                  // We need to be careful about setState during build/layout, but this is a callback.
                                  setState(() {
                                    _selectedSchool = firstOption;
                                  });
                                  fieldTextEditingController.text = firstOption.school_name;
                                  _loginButtonFocus.requestFocus(); // Focus button on auto-select (focus loss)
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
                                _loginButtonFocus.requestFocus(); // Focus button on auto-select (Enter)
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
                          // _selectedSchool이 null이면 버튼 비활성화
                          focusNode: _loginButtonFocus, // Attached FocusNode
                          onPressed: _isLoading || _selectedSchool == null ? null : _login,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: _isLoading ? 0 : 4,
                            shadowColor: AppTheme.primaryColor.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            // _selectedSchool이 null일 때의 비활성화 스타일
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
                                    Icon(Icons.login, size: 20),
                                    SizedBox(width: 8),
                                    Text('입장하기', style: TextStyle(fontSize: 18)),
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
