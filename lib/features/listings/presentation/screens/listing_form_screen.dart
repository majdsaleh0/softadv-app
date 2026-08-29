import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/utils/validators.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/listing_controller.dart';
import '../../data/listing_repository.dart';
import '../../domain/listing.dart';
import '../../domain/listing_image.dart';
import '../../domain/listing_time_slot.dart';
import '../widgets/category_dropdown.dart';
import '../widgets/listing_image_picker.dart';
import '../widgets/time_slot_editor.dart';

class ListingFormScreen extends ConsumerStatefulWidget {
  const ListingFormScreen({super.key, this.listingId});

  final String? listingId;

  @override
  ConsumerState<ListingFormScreen> createState() => _ListingFormScreenState();
}

class _ListingFormScreenState extends ConsumerState<ListingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();

  ListingCategory _category = ListingCategory.other;
  List<ListingImage> _existingImages = [];
  final List<PendingImage> _pendingImages = [];
  List<ListingTimeSlot> _slots = [];

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.listingId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_isEditing) {
      setState(() => _isLoading = false);
      return;
    }
    final repo = ref.read(listingRepositoryProvider);
    final listing = await repo.fetchListing(widget.listingId!);
    final images = await repo.fetchImages(widget.listingId!);
    final slots = await repo.fetchTimeSlots(widget.listingId!);
    if (!mounted) return;
    _titleController.text = listing.title;
    _descriptionController.text = listing.description;
    _locationController.text = listing.location;
    _priceController.text = listing.price.toStringAsFixed(2);
    setState(() {
      _category = listing.category;
      _existingImages = images;
      _slots = slots;
      _isLoading = false;
    });
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final extension = picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
    if (!mounted) return;
    setState(() => _pendingImages.add(PendingImage(bytes: bytes, extension: extension)));
  }

  Future<void> _removeExistingImage(ListingImage image) async {
    await ref.read(listingRepositoryProvider).deleteImage(image);
    if (!mounted) return;
    setState(() => _existingImages.remove(image));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final repo = ref.read(listingRepositoryProvider);
      final price = double.parse(_priceController.text);
      final listing = _isEditing
          ? await repo.updateListing(
              id: widget.listingId!,
              title: _titleController.text.trim(),
              description: _descriptionController.text.trim(),
              category: _category,
              location: _locationController.text.trim(),
              price: price,
            )
          : await repo.createListing(
              providerId: user.id,
              title: _titleController.text.trim(),
              description: _descriptionController.text.trim(),
              category: _category,
              location: _locationController.text.trim(),
              price: price,
            );

      for (final pending in _pendingImages) {
        await repo.uploadImage(providerId: user.id, listingId: listing.id, bytes: pending.bytes, fileExtension: pending.extension);
      }
      await repo.replaceTimeSlots(listing.id, _slots);

      ref.invalidate(myListingsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _errorMessage = 'Could not save listing. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Listing' : 'Create Listing')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(labelText: 'Title'),
                          validator: (v) => Validators.required(v, fieldName: 'Title'),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(labelText: 'Description'),
                          maxLines: 4,
                          validator: (v) => Validators.required(v, fieldName: 'Description'),
                        ),
                        const SizedBox(height: 16),
                        CategoryDropdown(value: _category, onChanged: (category) => setState(() => _category = category)),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _locationController,
                          decoration: const InputDecoration(labelText: 'Location / service area'),
                          validator: (v) => Validators.required(v, fieldName: 'Location'),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _priceController,
                          decoration: const InputDecoration(labelText: 'Price', prefixText: '\$'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Price is required';
                            final parsed = double.tryParse(v);
                            if (parsed == null || parsed < 0) return 'Enter a valid price';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        Text('Photos', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        ListingImagePicker(
                          existingImages: _existingImages,
                          pendingImages: _pendingImages,
                          onAdd: _pickImage,
                          onRemoveExisting: _removeExistingImage,
                          onRemovePending: (image) => setState(() => _pendingImages.remove(image)),
                        ),
                        const SizedBox(height: 24),
                        Text('Availability', style: Theme.of(context).textTheme.titleMedium),
                        TimeSlotEditor(
                          slots: _slots,
                          onAdd: (slot) => setState(() => _slots = [..._slots, slot]),
                          onRemove: (index) => setState(() => _slots = [..._slots]..removeAt(index)),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _isSubmitting ? null : _submit,
                          child: _isSubmitting
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(_isEditing ? 'Save changes' : 'Create listing'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
