import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spillcity/data/repositories/providers.dart';
import 'package:spillcity/services/cloudinary_service.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';

// ════════════════════════════════════════════
//  MAIN SETTINGS SCREEN — Matches page.tsx
// ════════════════════════════════════════════
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => EditProfilePageState();
}

class EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _collegeController = TextEditingController();
  final _branchController = TextEditingController();
  final _departmentController = TextEditingController();
  final _phoneController = TextEditingController();
  List<TextEditingController> _linkControllers = [TextEditingController()];

  String _activeTab = 'profile';
  String? _avatarUrl;
  String _email = '';
  String _gender = '';
  String _dateOfBirth = '';
  bool _isSaving = false;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _usernameController.addListener(_sanitizeUsername);
  }

  void _sanitizeUsername() {
    final value = _usernameController.text;
    final sanitized = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (value != sanitized) {
      _usernameController.value = TextEditingValue(
        text: sanitized,
        selection: TextSelection.collapsed(offset: sanitized.length),
      );
    }
  }

  @override
  void dispose() {
    _usernameController.removeListener(_sanitizeUsername);
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _collegeController.dispose();
    _branchController.dispose();
    _departmentController.dispose();
    _phoneController.dispose();
    for (final controller in _linkControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user =
        await ref.read(authRepositoryProvider).getCurrentUserProfile();
    if (user != null && mounted) {
      setState(() {
        _nameController.text = user.name;
        _usernameController.text = user.username ?? '';
        _bioController.text = user.bio ?? '';
        _collegeController.text = user.college ?? '';
        _avatarUrl = (user.profilePicture != null && user.profilePicture!.isNotEmpty)
            ? user.profilePicture
            : (user.avatar != null && user.avatar!.isNotEmpty && user.avatar != '👤')
                ? user.avatar
                : null;
        _email = user.email ?? '';
        _branchController.text = user.branch ?? '';
        _departmentController.text = user.department ?? '';
        _phoneController.text = user.phone ?? '';
        _gender = user.gender ?? '';
        _dateOfBirth = user.dateOfBirth ?? '';
        if (user.links != null && user.links!.isNotEmpty) {
          try {
            final List<dynamic> list = jsonDecode(user.links!);
            _linkControllers = list
                .map((l) => TextEditingController(text: l.toString()))
                .toList();
          } catch (_) {
            _linkControllers = [TextEditingController()];
          }
        } else {
          _linkControllers = [TextEditingController()];
        }
      });
    }
  }

  void _addLinkField() {
    if (_linkControllers.length < 5) {
      setState(() {
        _linkControllers.add(TextEditingController());
      });
    }
  }

  void _removeLinkField(int index) {
    if (_linkControllers.length > 1) {
      setState(() {
        _linkControllers[index].dispose();
        _linkControllers.removeAt(index);
      });
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    // Compress image quality and dimensions to match onboarding screen
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 400,
      maxHeight: 400,
    );
    if (picked != null && mounted) {
      setState(() {
        _isUploadingAvatar = true;
      });
      try {
        final file = File(picked.path);
        final publicUrl = await CloudinaryService.uploadMedia(
          file: file,
          category: 'images',
        );
        setState(() {
          _avatarUrl = publicUrl;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload image: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isUploadingAvatar = false;
          });
        }
      }
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    if (name.isEmpty) {
      throw Exception('Name cannot be empty');
    }
    if (username.isEmpty) {
      throw Exception('Username cannot be empty');
    }
    if (username.length < 3) {
      throw Exception('Username must be at least 3 characters');
    }

    setState(() => _isSaving = true);
    try {
      final linksList = _linkControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      final linksJson = linksList.isNotEmpty ? jsonEncode(linksList) : null;

      await ref.read(authRepositoryProvider).completeOnboarding(
        name: name,
        username: username,
        bio: _bioController.text.trim(),
        college: _collegeController.text.trim(),
        branch: _branchController.text.trim().isNotEmpty ? _branchController.text.trim() : null,
        department: _departmentController.text.trim().isNotEmpty ? _departmentController.text.trim() : null,
        phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        dateOfBirth: _dateOfBirth.isNotEmpty ? _dateOfBirth : null,
        gender: _gender.isNotEmpty ? _gender : null,
        links: linksJson,
        profilePicture: _avatarUrl,
      );

      ref.invalidate(currentUserProvider);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showConfirmSave() {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username cannot be empty')),
      );
      return;
    }
    if (username.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username must be at least 3 characters')),
      );
      return;
    }

    final theme = Theme.of(context);
    bool dialogSuccess = false;
    bool dialogSaving = false;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: dialogSuccess
                      ? Column(
                          key: const ValueKey('success'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Success!',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your profile has been updated successfully.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                height: 1.5,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          key: const ValueKey('confirm'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFF00B4FF).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.edit_outlined,
                                color: Color(0xFF00B4FF),
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Confirm Changes',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Are you sure you want to update your profile information?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: dialogSaving ? null : () => Navigator.pop(dialogContext),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                      foregroundColor: theme.colorScheme.onSurface,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      elevation: 0,
                                    ),
                                    child: const Text(
                                      'Not yet',
                                      style: TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: dialogSaving
                                        ? null
                                        : () async {
                                            final navigator = Navigator.of(context);
                                            final dialogNavigator = Navigator.of(dialogContext);
                                            final messenger = ScaffoldMessenger.of(context);
                                            setDialogState(() {
                                              dialogSaving = true;
                                            });
                                            try {
                                              await _saveProfile();
                                              setDialogState(() {
                                                dialogSuccess = true;
                                              });
                                              Future.delayed(const Duration(milliseconds: 1500), () {
                                                dialogNavigator.pop();
                                                navigator.pop();
                                              });
                                            } catch (e) {
                                              setDialogState(() {
                                                dialogSaving = false;
                                              });
                                              messenger.showSnackBar(
                                                SnackBar(content: Text('Failed to save profile: $e')),
                                              );
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00B4FF),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      elevation: 0,
                                    ),
                                    child: Text(
                                      dialogSaving ? 'Saving...' : 'Yes, Update',
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                // Header — ref-header
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(Icons.chevron_left,
                              size: 28, color: theme.colorScheme.onSurface),
                        ),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Edit Profile',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      // Avatar Section
                      Center(
                        child: GestureDetector(
                          onTap: _isSaving || _isUploadingAvatar ? null : _pickAvatar,
                          child: Stack(
                            children: [
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  border: Border.all(
                                      color: theme.cardColor, width: 4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: 0.1),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _isUploadingAvatar
                                    ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : _avatarUrl != null &&
                                            _avatarUrl!.isNotEmpty
                                        ? Image.network(_avatarUrl!,
                                            fit: BoxFit.cover,
                                            width: 96,
                                            height: 96)
                                        : const Center(
                                            child: Text('👤',
                                                style:
                                                    TextStyle(fontSize: 40))),
                              ),
                              // Camera badge
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00B4FF),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: theme.cardColor, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00B4FF)
                                            .withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.camera_alt,
                                      color: Colors.white, size: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Tab Switcher — ref-tabs-container
                      Container(
                        height: 48,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: theme.colorScheme.outline
                                  .withValues(alpha: 0.1)),
                        ),
                        child: Stack(
                          children: [
                            AnimatedAlign(
                              alignment: _activeTab == 'profile'
                                  ? Alignment.centerLeft
                                  : Alignment.centerRight,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.elasticOut,
                              child: FractionallySizedBox(
                                widthFactor: 0.5,
                                child: Container(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00B4FF),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(
                                        () => _activeTab = 'profile'),
                                    child: Center(
                                      child: Text(
                                        'Profile',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: _activeTab == 'profile'
                                              ? Colors.white
                                              : theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.4),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(
                                        () => _activeTab = 'personal'),
                                    child: Center(
                                      child: Text(
                                        'Private',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: _activeTab == 'personal'
                                              ? Colors.white
                                              : theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.4),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Form content
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _activeTab == 'profile'
                            ? _buildProfileTab(theme)
                            : _buildPersonalTab(theme),
                      ),

                      // Save Button
                      Padding(
                        padding: const EdgeInsets.only(top: 32, bottom: 40),
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _showConfirmSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00B4FF),
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 4,
                            shadowColor: const Color(0xFF00B4FF)
                                .withValues(alpha: 0.3),
                          ),
                          child: Text(
                            _isSaving ? 'Saving...' : 'Save Profile',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTab(ThemeData theme) {
    return Column(
      key: const ValueKey('profile'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Identity', theme),
        _buildInputField(
            controller: _nameController,
            placeholder: 'Full Name',
            keyboardType: TextInputType.name,
            theme: theme),
        const SizedBox(height: 10),
        _buildInputField(
            controller: _usernameController,
            placeholder: 'username',
            keyboardType: TextInputType.text,
            theme: theme,
            prefix: '@'),
        const SizedBox(height: 10),
        _buildTextAreaField(
            controller: _bioController,
            placeholder: 'Tell us about yourself (Bio)',
            theme: theme),
        const SizedBox(height: 10),
        _buildSectionLabel('Education', theme),
        _buildInputField(
            controller: _collegeController,
            placeholder: 'University / College',
            keyboardType: TextInputType.text,
            theme: theme),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: _buildInputField(
                    controller: _branchController,
                    placeholder: 'Branch',
                    theme: theme)),
            const SizedBox(width: 8),
            Expanded(
                child: _buildInputField(
                    controller: _departmentController,
                    placeholder: 'Department',
                    theme: theme)),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionLabel('Socials', theme),
        ..._linkControllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    controller: controller,
                    placeholder: 'https://...',
                    theme: theme,
                  ),
                ),
                if (_linkControllers.length > 1) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _removeLinkField(index),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Color(0xFFEF4444),
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
        if (_linkControllers.length < 5) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addLinkField,
              icon: const Icon(Icons.add, size: 16, color: Color(0xFF00B4FF)),
              label: const Text(
                'Add Social Link',
                style: TextStyle(
                  color: Color(0xFF00B4FF),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: Color(0xFF00B4FF), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPersonalTab(ThemeData theme) {
    return Column(
      key: const ValueKey('personal'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildSectionLabel('Private Info', theme),
            const SizedBox(width: 8),
            Icon(Icons.lock_outline,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.08)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _gender.isNotEmpty ? _gender : null,
                    hint: Text(
                      'Gender',
                      style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                          fontSize: 15,
                          fontWeight: FontWeight.w500),
                    ),
                    isExpanded: true,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    dropdownColor: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                      DropdownMenuItem(value: 'non-binary', child: Text('Non-binary')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _gender = val ?? '';
                      });
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final initialDate = _dateOfBirth.isNotEmpty
                      ? DateTime.tryParse(_dateOfBirth) ?? DateTime.now()
                      : DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initialDate,
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      _dateOfBirth = picked.toIso8601String().split('T')[0];
                    });
                  }
                },
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.08)),
                  ),
                  child: Text(
                    _dateOfBirth.isNotEmpty ? _dateOfBirth : 'Date of Birth',
                    style: TextStyle(
                      color: _dateOfBirth.isNotEmpty
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withValues(alpha: 0.35),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildInputField(
            controller: _phoneController,
            placeholder: 'Phone (e.g. +91 98765 43210)',
            keyboardType: TextInputType.phone,
            theme: theme),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _email.isNotEmpty ? _email : 'Email',
                  style: TextStyle(
                    fontSize: 15,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
              Icon(Icons.lock_outline,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1)),
          ),
          child: Text(
            '🔒 Private Information: This data is only visible to you and used for account management.',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.onSurface,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String placeholder,
    required ThemeData theme,
    String? prefix,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.08)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35)),
          prefixText: prefix,
          prefixStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildTextAreaField({
    required TextEditingController controller,
    required String placeholder,
    required ThemeData theme,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.08)),
      ),
      child: TextField(
        controller: controller,
        maxLines: 3,
        maxLength: 160,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35)),
          contentPadding: const EdgeInsets.all(16),
          border: InputBorder.none,
          counterStyle: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
//  NOTIFICATIONS PAGE — Matches notifications/page.tsx
// ════════════════════════════════════════════
