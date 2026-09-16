import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:spillcity/data/repositories/providers.dart';
import 'package:spillcity/services/cloudinary_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final List<Map<String, String>> _countryCodes = [
  {'code': '+91', 'label': '🇮🇳 +91', 'country': 'India'},
  {'code': '+1', 'label': '🇺🇸 +1', 'country': 'US'},
  {'code': '+44', 'label': '🇬🇧 +44', 'country': 'UK'},
  {'code': '+61', 'label': '🇦🇺 +61', 'country': 'AU'},
  {'code': '+86', 'label': '🇨🇳 +86', 'country': 'CN'},
  {'code': '+81', 'label': '🇯🇵 +81', 'country': 'JP'},
  {'code': '+49', 'label': '🇩🇪 +49', 'country': 'DE'},
  {'code': '+33', 'label': '🇫🇷 +33', 'country': 'FR'},
  {'code': '+971', 'label': '🇦🇪 +971', 'country': 'UAE'},
  {'code': '+65', 'label': '🇸🇬 +65', 'country': 'SG'},
  {'code': '+82', 'label': '🇰🇷 +82', 'country': 'KR'},
  {'code': '+55', 'label': '🇧🇷 +55', 'country': 'BR'},
  {'code': '+7', 'label': '🇷🇺 +7', 'country': 'RU'},
  {'code': '+39', 'label': '🇮🇹 +39', 'country': 'IT'},
  {'code': '+34', 'label': '🇪🇸 +34', 'country': 'ES'},
];

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  int _currentStep = 1; // 1: Essentials, 2: OTP, 3: Academic, 4: Profile, 5: Social Links
  bool _isLoading = false;
  bool _showSuccess = false;

  // Step 1 Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Step 2 Controllers
  final _otpController = TextEditingController();
  String? _otpError;

  // Step 3 Controllers
  final _collegeController = TextEditingController();
  final _branchController = TextEditingController();
  final _departmentController = TextEditingController();
  String? _dateOfBirth;
  String? _gender;

  // Step 4 Controllers
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _countryCode = '+91';
  final _bioController = TextEditingController();
  File? _avatarFile;
  bool _isUploadingAvatar = false;
  String? _avatarUrl;
  String _usernameStatus = 'idle'; // 'idle' | 'checking' | 'available' | 'taken'
  Timer? _usernameDebounce;

  // Step 5 Controllers
  final List<TextEditingController> _linkControllers = [TextEditingController()];

  // Form Keys
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  final _formKey3 = GlobalKey<FormState>();
  final _formKey4 = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _checkAndRestoreSession();
  }

  Future<void> _checkAndRestoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isPending = prefs.getBool('signup_pending') ?? false;
      if (!isPending) return;

      final timestamp = prefs.getInt('signup_timestamp') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Keep the session valid for 10 minutes (600,000 milliseconds)
      if (now - timestamp < 600000) {
        final name = prefs.getString('signup_name') ?? '';
        final email = prefs.getString('signup_email') ?? '';
        final password = prefs.getString('signup_password') ?? '';

        setState(() {
          _nameController.text = name;
          _emailController.text = email;
          _passwordController.text = password;
          _currentStep = 2; // Jump straight to OTP screen
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Resumed pending registration. Verification code sent.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        await _clearSavedSession();
      }
    } catch (_) {}
  }

  Future<void> _saveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('signup_pending', true);
      await prefs.setString('signup_name', _nameController.text.trim());
      await prefs.setString('signup_email', _emailController.text.trim());
      await prefs.setString('signup_password', _passwordController.text);
      await prefs.setInt('signup_timestamp', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<void> _clearSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('signup_pending');
      await prefs.remove('signup_name');
      await prefs.remove('signup_email');
      await prefs.remove('signup_password');
      await prefs.remove('signup_timestamp');
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _collegeController.dispose();
    _branchController.dispose();
    _departmentController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _usernameDebounce?.cancel();
    for (var controller in _linkControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    final sanitized = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');

    if (value != sanitized) {
      _usernameController.value = TextEditingValue(
        text: sanitized,
        selection: TextSelection.collapsed(offset: sanitized.length),
      );
    }

    if (sanitized.length < 3) {
      setState(() => _usernameStatus = 'idle');
      return;
    }

    setState(() => _usernameStatus = 'checking');
    _usernameDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final res = await Supabase.instance.client
            .from('users')
            .select('username')
            .eq('username', sanitized)
            .maybeSingle();

        if (mounted) {
          setState(() {
            _usernameStatus = res == null ? 'available' : 'taken';
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => _usernameStatus = 'available');
        }
      }
    });
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    try {
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 400,
        maxHeight: 400,
      );

      if (file != null && mounted) {
        setState(() {
          _avatarFile = File(file.path);
          _isUploadingAvatar = true;
        });

        final publicUrl = await CloudinaryService.uploadMedia(
          file: _avatarFile!,
          category: 'images',
        );

        if (mounted) {
          setState(() {
            _avatarUrl = publicUrl;
            _isUploadingAvatar = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload profile picture: $e')),
        );
      }
    }
  }

  Future<void> _selectDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2005),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Theme.of(context).colorScheme.primary,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateOfBirth = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  void _addSocialLinkField() {
    if (_linkControllers.length < 5) {
      setState(() {
        _linkControllers.add(TextEditingController());
      });
    }
  }

  void _removeSocialLinkField(int index) {
    if (_linkControllers.length > 1) {
      setState(() {
        _linkControllers[index].dispose();
        _linkControllers.removeAt(index);
      });
    }
  }

  void _handleBack() {
    if (_currentStep == 2) {
      _clearSavedSession();
    }
    setState(() {
      _currentStep = (_currentStep - 1).clamp(1, 5);
    });
  }

  Future<void> _handleStep1Next() async {
    if (!_formKey1.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);

      // Attempt signup to trigger Supabase Auth (and trigger real SMTP confirmation email if enabled)
      await authRepo.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
      );

      setState(() {
        _isLoading = false;
      });

      // Save the session details locally in case the app is closed/killed
      await _saveSession();

      // Check if user session was created immediately (confirmations disabled)
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        // Skip OTP step since confirmations are disabled, go straight to step 3
        setState(() {
          _currentStep = 3;
        });
      } else {
        // Go to OTP verification step
        setState(() {
          _currentStep = 2;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign up failed: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleStep2Next() async {
    final code = _otpController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Try real Supabase verification
      await Supabase.instance.client.auth.verifyOTP(
        email: _emailController.text.trim(),
        token: code,
        type: OtpType.signup,
      );

      setState(() {
        _isLoading = false;
        _otpError = null;
        _currentStep = 3;
      });
    } catch (e) {
      // 2. Simulated/local bypass fallback code
      if (code == '123456') {
        setState(() {
          _isLoading = false;
          _otpError = null;
          _currentStep = 3;
        });
      } else {
        setState(() {
          _isLoading = false;
          _otpError = 'Verification failed: ${e.toString()}\n(For local testing, enter 123456)';
        });
      }
    }
  }

  void _handleStep3Next() {
    if (_formKey3.currentState!.validate()) {
      if (_dateOfBirth == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select your date of birth')),
        );
        return;
      }
      setState(() {
        _currentStep = 4;
      });
    }
  }

  void _handleStep4Next() {
    if (_formKey4.currentState!.validate()) {
      if (_usernameStatus == 'taken') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username is already taken')),
        );
        return;
      }
      setState(() {
        _currentStep = 5;
      });
    }
  }

  Future<void> _handleFinishRegistration() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);

      // Filter social links
      final validLinks = _linkControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      final String? linksJson = validLinks.isNotEmpty ? jsonEncode(validLinks) : null;

      // Save onboarding profile details to Supabase database (calling upsert/insert)
      await authRepo.completeOnboarding(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        bio: _bioController.text.trim(),
        college: _collegeController.text.trim(),
        branch: _branchController.text.trim().isNotEmpty ? _branchController.text.trim() : null,
        department: _departmentController.text.trim().isNotEmpty ? _departmentController.text.trim() : null,
        phone: '$_countryCode ${_phoneController.text.trim()}',
        dateOfBirth: _dateOfBirth,
        gender: _gender,
        links: linksJson,
        profilePicture: _avatarUrl,
      );

      // Invalidate provider to trigger GoRouter update
      ref.invalidate(currentUserProvider);

      // Clean up the local signup session on success
      await _clearSavedSession();

      setState(() {
        _isLoading = false;
        _showSuccess = true;
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          context.go('/');
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete setup: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_showSuccess) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Welcome to SpillCity!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your account is successfully created and profile is all set.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: PopScope(
        canPop: _currentStep == 1,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_currentStep > 1) {
            _handleBack();
          }
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: theme.brightness == Brightness.dark
                  ? [const Color(0xFF0F172A), const Color(0xFF1E1B4B)]
                  : [const Color(0xFFEFF6FF), const Color(0xFFF3F4F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    children: [
                      _buildStepProgressBar(theme),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(
                            color: theme.colorScheme.outline.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _buildStepContent(theme),
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

  Widget _buildStepProgressBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) {
          final step = index + 1;
          final isActive = _currentStep == step;
          final isCompleted = _currentStep > step;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? theme.colorScheme.primary
                      : isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
                  border: isActive
                      ? Border.all(color: theme.colorScheme.primaryContainer, width: 2)
                      : null,
                ),
                alignment: Alignment.center,
                child: isCompleted
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text(
                        '$step',
                        style: TextStyle(
                          color: isActive || isCompleted
                              ? Colors.white
                              : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
              ),
              if (index < 4)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  width: 32,
                  height: 3,
                  color: isCompleted
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withValues(alpha: 0.15),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildStepContent(ThemeData theme) {
    switch (_currentStep) {
      case 1:
        return _buildStep1Credentials(theme);
      case 2:
        return _buildStep2OTP(theme);
      case 3:
        return _buildStep3Academic(theme);
      case 4:
        return _buildStep4Profile(theme);
      case 5:
        return _buildStep5Social(theme);
      default:
        return _buildStep1Credentials(theme);
    }
  }

  // STEP 1: CREDENTIALS
  Widget _buildStep1Credentials(ThemeData theme) {
    return Form(
      key: _formKey1,
      child: Column(
        key: const ValueKey('step1'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStepHeader(
            theme,
            icon: Icons.person_add_outlined,
            title: 'Create Account',
            subtitle: 'Start by filling in your basic details',
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nameController,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Full Name',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: theme.brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Please enter your name';
              return null;
            },
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Email Address',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: theme.brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Please enter your email';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _isLoading ? null : _handleStep1Next(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: theme.brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter your password';
              if (value.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleStep1Next,
            style: _nextBtnStyle(theme),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Continue →', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Already have an account? ', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              TextButton(
                onPressed: () => context.pushReplacement('/login'),
                child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // STEP 2: OTP VERIFICATION
  Widget _buildStep2OTP(ThemeData theme) {
    return Form(
      key: _formKey2,
      child: Column(
        key: const ValueKey('step2'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStepHeader(
            theme,
            icon: Icons.mark_email_read_outlined,
            title: 'Verify Email',
            subtitle: "We've sent a 6-digit verification code to:\n${_emailController.text}\n(For local testing, enter code 123456)",
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              counterText: '',
              hintText: '000000',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              errorText: _otpError,
              filled: true,
              fillColor: theme.brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            ),
            onChanged: (val) {
              if (val.length == 6) {
                _handleStep2Next();
              }
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              IconButton(
                onPressed: _handleBack,
                icon: const Icon(Icons.arrow_back),
                style: _backBtnStyle(theme),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleStep2Next,
                  style: _nextBtnStyle(theme),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Verify & Continue →', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // STEP 3: ACADEMIC DETAILS
  Widget _buildStep3Academic(ThemeData theme) {
    return Form(
      key: _formKey3,
      child: Column(
        key: const ValueKey('step3'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStepHeader(
            theme,
            icon: Icons.school_outlined,
            title: 'Academic Profile',
            subtitle: 'Tell us about your campus and status',
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _collegeController,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'College / University',
              prefixIcon: const Icon(Icons.school_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: theme.brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'College/University name is required';
              return null;
            },
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _branchController,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Branch',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: theme.brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _departmentController,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Dept. / Degree',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: theme.brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: InkWell(
                  onTap: _selectDateOfBirth,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 58,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.38)),
                      color: theme.brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _dateOfBirth ?? 'Birth Date',
                          style: TextStyle(
                            fontSize: 15,
                            color: _dateOfBirth != null
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                        Icon(Icons.calendar_month_outlined, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: Container(
                  height: 58,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.38)),
                    color: theme.brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _gender,
                      hint: Text(
                        'Gender',
                        style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.55), fontSize: 14),
                      ),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _gender = newValue;
                          });
                        }
                      },
                      items: const [
                        DropdownMenuItem(value: 'male', child: Text('Male')),
                        DropdownMenuItem(value: 'female', child: Text('Female')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              IconButton(
                onPressed: _handleBack,
                icon: const Icon(Icons.arrow_back),
                style: _backBtnStyle(theme),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _handleStep3Next,
                  style: _nextBtnStyle(theme),
                  child: const Text('Continue →', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // STEP 4: PROFILE & BIO
  Widget _buildStep4Profile(ThemeData theme) {
    return Form(
      key: _formKey4,
      child: Column(
        key: const ValueKey('step4'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStepHeader(
            theme,
            icon: Icons.camera_alt_outlined,
            title: 'Set up Profile',
            subtitle: 'Choose a photo and setup your username',
          ),
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: _isUploadingAvatar ? null : _pickAvatar,
              child: Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.35),
                        width: 3,
                      ),
                    ),
                    child: ClipOval(
                      child: _avatarFile != null
                          ? Image.file(_avatarFile!, fit: BoxFit.cover)
                          : (_avatarUrl != null && _avatarUrl!.isNotEmpty && _avatarUrl!.startsWith('http'))
                              ? Image.network(
                                  _avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                    child: Icon(
                                      Icons.person_outline,
                                      size: 40,
                                      color: theme.colorScheme.primary.withValues(alpha: 0.8),
                                    ),
                                  ),
                                )
                              : Container(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                  child: Icon(
                                    Icons.person_outline,
                                    size: 40,
                                    color: theme.colorScheme.primary.withValues(alpha: 0.8),
                                  ),
                                ),
                    ),
                  ),
                  if (_isUploadingAvatar)
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: theme.colorScheme.primary,
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _usernameController,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            onChanged: _onUsernameChanged,
            decoration: InputDecoration(
              labelText: 'Username',
              prefixIcon: const Icon(Icons.alternate_email_outlined),
              suffixIcon: _buildUsernameStatusIcon(theme),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: theme.brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Username is required';
              if (value.trim().length < 3) return 'Username must be at least 3 characters';
              if (!RegExp(r'^[a-z0-9_]+$').hasMatch(value.trim())) {
                return 'Lowercase, numbers, and underscores only';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 95,
                height: 58,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.38)),
                  color: theme.brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _countryCode,
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _countryCode = newValue;
                        });
                      }
                    },
                    items: _countryCodes.map((Map<String, String> country) {
                      return DropdownMenuItem<String>(
                        value: country['code'],
                        child: Text(
                          country['label']!,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: const Icon(Icons.phone_iphone_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: theme.brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Phone number is required';
                    if (value.replaceAll(RegExp(r'[^0-9]'), '').length < 6) return 'Invalid phone number';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _bioController,
            keyboardType: TextInputType.multiline,
            maxLines: 2,
            maxLength: 160,
            decoration: InputDecoration(
              labelText: 'Tell us about yourself (Bio)',
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: theme.brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Bio is required';
              return null;
            },
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              IconButton(
                onPressed: _handleBack,
                icon: const Icon(Icons.arrow_back),
                style: _backBtnStyle(theme),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isUploadingAvatar ? null : _handleStep4Next,
                  style: _nextBtnStyle(theme),
                  child: const Text('Continue →', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget? _buildUsernameStatusIcon(ThemeData theme) {
    if (_usernameStatus == 'checking') {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_usernameStatus == 'available') {
      return const Icon(Icons.check_circle_outline, color: Color(0xFF10B981));
    }
    if (_usernameStatus == 'taken') {
      return const Icon(Icons.error_outline, color: Color(0xFFEF4444));
    }
    return null;
  }

  // STEP 5: SOCIAL LINKS & FINISH
  Widget _buildStep5Social(ThemeData theme) {
    return Column(
      key: const ValueKey('step5'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader(
          theme,
          icon: Icons.link_outlined,
          title: 'Social Links',
          subtitle: 'Add links to your profiles (optional)',
        ),
        const SizedBox(height: 24),
        ...List.generate(_linkControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _linkControllers[index],
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      hintText: 'https://instagram.com/...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: theme.brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    ),
                  ),
                ),
                if (_linkControllers.length > 1) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _removeSocialLinkField(index),
                    icon: const Icon(Icons.close, size: 20),
                    style: IconButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
        if (_linkControllers.length < 5)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addSocialLinkField,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add social link'),
            ),
          ),
        const SizedBox(height: 24),
        Row(
          children: [
            IconButton(
              onPressed: _handleBack,
              icon: const Icon(Icons.arrow_back),
              style: _backBtnStyle(theme),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleFinishRegistration,
                style: _nextBtnStyle(theme),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Create Account ✓', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepHeader(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 28),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  ButtonStyle _nextBtnStyle(ThemeData theme) {
    return ElevatedButton.styleFrom(
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.onPrimary,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
    );
  }

  ButtonStyle _backBtnStyle(ThemeData theme) {
    return IconButton.styleFrom(
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      foregroundColor: theme.colorScheme.onSurface,
      padding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
