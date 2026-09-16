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

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _currentStep = 1; // 1 to 4 matching web steps
  bool _isLoading = false;
  bool _showSuccess = false;

  // Step 1 Controllers
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _countryCode = '+91';

  // Step 2 Controllers
  final _collegeController = TextEditingController();
  final _branchController = TextEditingController();
  final _departmentController = TextEditingController();
  String? _dateOfBirth; // YYYY-MM-DD format
  String? _gender; // 'male' | 'female' | 'other'

  // Step 3 Controllers
  File? _avatarFile;
  bool _isUploadingAvatar = false;
  String? _avatarUrl;

  // Step 4 Controllers
  final _bioController = TextEditingController();
  final List<TextEditingController> _linkControllers = [TextEditingController()];

  // Form states & Errors
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  final _formKey4 = GlobalKey<FormState>();

  // Username status check states
  String _usernameStatus = 'idle'; // 'idle' | 'checking' | 'available' | 'taken'
  Timer? _usernameDebounce;

  @override
  void initState() {
    super.initState();
    // Prefill name and avatar from current user profile if available
    Future.microtask(() async {
      final userModel = await ref.read(authRepositoryProvider).getCurrentUserProfile();
      if (userModel != null && mounted) {
        setState(() {
          if (userModel.name.isNotEmpty && userModel.name != 'New User') {
            _nameController.text = userModel.name;
          }
          _avatarUrl = (userModel.profilePicture != null && userModel.profilePicture!.isNotEmpty)
              ? userModel.profilePicture
              : (userModel.avatar != null && userModel.avatar!.isNotEmpty && userModel.avatar != '👤')
                  ? userModel.avatar
                  : null;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _collegeController.dispose();
    _branchController.dispose();
    _departmentController.dispose();
    _bioController.dispose();
    _usernameDebounce?.cancel();
    for (var controller in _linkControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // ─── Username Availability Check ───
  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    final sanitized = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    
    // Update text field value programmatically if sanitization changed anything
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
        final supabaseClient = Supabase.instance.client;
        final res = await supabaseClient
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

  // ─── Pick & Upload Avatar ───
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

        // Upload image to Cloudinary
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

  // ─── Date of Birth Selector ───
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

  // ─── Step Navigation & Validations ───
  bool _validateCurrentStep() {
    if (_currentStep == 1) {
      if (!_formKey1.currentState!.validate()) return false;
      if (_usernameStatus == 'taken') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username is already taken')),
        );
        return false;
      }
      return true;
    }
    if (_currentStep == 2) {
      if (!_formKey2.currentState!.validate()) return false;
      if (_dateOfBirth == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select your date of birth')),
        );
        return false;
      }
      return true;
    }
    return true;
  }

  void _handleNext() {
    if (_validateCurrentStep()) {
      setState(() {
        _currentStep = (_currentStep + 1).clamp(1, 4);
      });
    }
  }

  void _handleBack() {
    setState(() {
      _currentStep = (_currentStep - 1).clamp(1, 4);
    });
  }

  // ─── Dynamic Social Links Management ───
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

  // ─── Complete Onboarding Submission ───
  Future<void> _handleFinishOnboarding() async {
    if (!_formKey4.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      
      // Filter empty links and serialize list to JSON-string format matching Next.js actions
      final validLinks = _linkControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      final String? linksJson = validLinks.isNotEmpty ? jsonEncode(validLinks) : null;

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

      // Invalidate current user provider to sync auth routes
      ref.invalidate(currentUserProvider);

      setState(() {
        _isLoading = false;
        _showSuccess = true;
      });

      // Navigate to homepage after showing success animation
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
            content: Text('Failed to complete setup: $e'),
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
                  'Your profile is all set. Redirecting you to your feed...',
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
      body: Container(
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
                    // Step progress indicators matching web page
                    _buildStepProgressBar(theme),
                    const SizedBox(height: 12),
                    
                    // Main Onboarding Step Card
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
    );
  }

  // ─── Step progress indicators bar ───
  Widget _buildStepProgressBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          final step = index + 1;
          final isActive = _currentStep == step;
          final isCompleted = _currentStep > step;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                width: 32,
                height: 32,
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
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : Text(
                        '$step',
                        style: TextStyle(
                          color: isActive || isCompleted
                              ? Colors.white
                              : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
              ),
              if (index < 3)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  width: 44,
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

  // ─── Switch Steps Render ───
  Widget _buildStepContent(ThemeData theme) {
    switch (_currentStep) {
      case 1:
        return _buildStep1Essentials(theme);
      case 2:
        return _buildStep2Academy(theme);
      case 3:
        return _buildStep3Look(theme);
      case 4:
        return _buildStep4Personality(theme);
      default:
        return _buildStep1Essentials(theme);
    }
  }

  // ─── STEP 1: ESSENTIALS ───
  Widget _buildStep1Essentials(ThemeData theme) {
    return Form(
      key: _formKey1,
      child: Column(
        key: const ValueKey('step1'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Step Header
          _buildStepHeader(
            theme,
            icon: Icons.person_add_outlined,
            title: 'Essentials',
            subtitle: "Let's start with the basics",
          ),
          const SizedBox(height: 24),

          // Full Name
          TextFormField(
            controller: _nameController,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Full Name',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Full name is required';
              return null;
            },
          ),
          const SizedBox(height: 18),

          // Username Field (checking live availability)
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

          // Phone Number (Country Code selector row)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 105,
                height: 58,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.38)),
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF8FAFC),
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
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleNext(),
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: const Icon(Icons.phone_iphone_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
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
          const SizedBox(height: 24),

          // Actions
          ElevatedButton(
            onPressed: _handleNext,
            style: _nextBtnStyle(theme),
            child: const Text('Continue →', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  // ─── STEP 2: ACADEMY ───
  Widget _buildStep2Academy(ThemeData theme) {
    return Form(
      key: _formKey2,
      child: Column(
        key: const ValueKey('step2'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStepHeader(
            theme,
            icon: Icons.school_outlined,
            title: 'Academy',
            subtitle: 'Your campus and identification',
          ),
          const SizedBox(height: 24),

          // College Field
          TextFormField(
            controller: _collegeController,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'College / University',
              prefixIcon: const Icon(Icons.school_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'College/University name is required';
              return null;
            },
          ),
          const SizedBox(height: 18),

          // Branch & Department Row
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
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Date of Birth & Gender Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date of birth selector
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
              // Gender Dropdown
              Expanded(
                flex: 4,
                child: Container(
                  height: 58,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.38)),
                    color: theme.brightness == Brightness.dark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF8FAFC),
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

          // Navigation buttons
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
                  onPressed: _handleNext,
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

  // ─── STEP 3: PICK YOUR LOOK ───
  Widget _buildStep3Look(ThemeData theme) {
    return Column(
      key: const ValueKey('step3'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader(
          theme,
          icon: Icons.camera_alt_outlined,
          title: 'Pick your Look',
          subtitle: 'Choose a photo that represents you best',
        ),
        const SizedBox(height: 32),

        // Photo Uploader Box
        Center(
          child: GestureDetector(
            onTap: _isUploadingAvatar ? null : _pickAvatar,
            child: Stack(
              children: [
                Container(
                  width: 130,
                  height: 130,
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
                                    size: 56,
                                    color: theme.colorScheme.primary.withValues(alpha: 0.8),
                                  ),
                                ),
                              )
                            : Container(
                                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                child: Icon(
                                  Icons.person_outline,
                                  size: 56,
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
                    radius: 20,
                    backgroundColor: theme.colorScheme.primary,
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 36),

        // Navigation actions
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
                onPressed: _isUploadingAvatar ? null : _handleNext,
                style: _nextBtnStyle(theme),
                child: _isUploadingAvatar
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Continue →', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── STEP 4: PERSONALITY ───
  Widget _buildStep4Personality(ThemeData theme) {
    return Form(
      key: _formKey4,
      child: Column(
        key: const ValueKey('step4'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStepHeader(
            theme,
            icon: Icons.people_outline,
            title: 'Personality',
            subtitle: 'Share a bit about yourself',
          ),
          const SizedBox(height: 24),

          // Bio
          TextFormField(
            controller: _bioController,
            keyboardType: TextInputType.multiline,
            maxLines: 3,
            maxLength: 160,
            decoration: InputDecoration(
              labelText: 'Tell us about yourself',
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Bio is required';
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Social Links section matching web dynamic add/remove links
          Text(
            'Social Links (Optional)',
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          
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

          // Navigation buttons
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
                  onPressed: _isLoading ? null : _handleFinishOnboarding,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Finish ✓',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Button & Layout Style Helpers ───
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
