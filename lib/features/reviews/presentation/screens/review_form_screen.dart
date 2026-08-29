import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/review_controller.dart';
import '../../data/review_repository.dart';
import '../../domain/review.dart';

class ReviewFormScreen extends ConsumerStatefulWidget {
  const ReviewFormScreen({super.key, required this.bookingId, this.existingReview});

  final String bookingId;
  final Review? existingReview;

  @override
  ConsumerState<ReviewFormScreen> createState() => _ReviewFormScreenState();
}

class _ReviewFormScreenState extends ConsumerState<ReviewFormScreen> {
  late int _rating = widget.existingReview?.rating ?? 5;
  late final _commentController = TextEditingController(text: widget.existingReview?.comment ?? '');
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.existingReview != null;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final repo = ref.read(reviewRepositoryProvider);
      final comment = _commentController.text.trim().isEmpty ? null : _commentController.text.trim();
      if (_isEditing) {
        await repo.updateReview(reviewId: widget.existingReview!.id, rating: _rating, comment: comment);
      } else {
        await repo.submitReview(bookingId: widget.bookingId, rating: _rating, comment: comment);
      }
      ref.invalidate(bookingReviewProvider(widget.bookingId));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() => _errorMessage = 'Could not save review. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Review' : 'Leave a Review')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var star = 1; star <= 5; star++)
                      IconButton(
                        icon: Icon(star <= _rating ? Icons.star : Icons.star_border, color: Colors.amber),
                        onPressed: () => setState(() => _rating = star),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _commentController,
                  decoration: const InputDecoration(labelText: 'Comment (optional)'),
                  maxLines: 4,
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
                      : Text(_isEditing ? 'Save changes' : 'Submit review'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
