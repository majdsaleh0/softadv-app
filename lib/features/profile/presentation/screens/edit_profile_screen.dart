import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/validators.dart';
import '../../application/profile_controller.dart';
import '../../data/profile_repository.dart';
import '../../domain/profile.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _businessNameController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _initialized = false;

  void _initializeFrom(Profile profile) {
    if (_initialized) return;
    _nameController.text = profile.name;
    _businessNameController.text = profile.businessName ?? '';
    _initialized = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _businessNameController.dispose();
    super.dispose();
  }

  Future<void> _submit(Profile profile) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            userId: profile.id,
            name: _nameController.text.trim(),
            businessName: profile.role == UserRole.provider ? _businessNameController.text.trim() : null,
          );
      ref.invalidate(currentProfileProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() => _errorMessage = 'Could not save profile. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) return const Center(child: Text('Not signed in.'));
          _initializeFrom(profile);
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Full name'),
                        validator: (v) => Validators.required(v, fieldName: 'Name'),
                      ),
                      if (profile.role == UserRole.provider) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _businessNameController,
                          decoration: const InputDecoration(labelText: 'Business name'),
                          validator: (v) => Validators.required(v, fieldName: 'Business name'),
                        ),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _isSubmitting ? null : () => _submit(profile),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save changes'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        error: (error, stackTrace) => Center(child: Text('Could not load profile: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
