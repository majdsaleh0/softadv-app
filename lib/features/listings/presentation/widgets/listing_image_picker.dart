import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../domain/listing_image.dart';

class PendingImage {
  const PendingImage({required this.bytes, required this.extension});

  final Uint8List bytes;
  final String extension;
}

class ListingImagePicker extends StatelessWidget {
  const ListingImagePicker({
    super.key,
    required this.existingImages,
    required this.pendingImages,
    required this.onAdd,
    required this.onRemoveExisting,
    required this.onRemovePending,
  });

  final List<ListingImage> existingImages;
  final List<PendingImage> pendingImages;
  final VoidCallback onAdd;
  final ValueChanged<ListingImage> onRemoveExisting;
  final ValueChanged<PendingImage> onRemovePending;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final image in existingImages) _Thumb(onRemove: () => onRemoveExisting(image), child: Image.network(image.publicUrl, fit: BoxFit.cover)),
        for (final pending in pendingImages) _Thumb(onRemove: () => onRemovePending(pending), child: Image.memory(pending.bytes, fit: BoxFit.cover)),
        InkWell(
          onTap: onAdd,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outline), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.add_a_photo_outlined),
          ),
        ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.child, required this.onRemove});

  final Widget child;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 88, height: 88, child: child)),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: const CircleAvatar(radius: 12, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}
