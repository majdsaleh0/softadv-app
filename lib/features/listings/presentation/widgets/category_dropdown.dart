import 'package:flutter/material.dart';

import '../../domain/listing.dart';

class CategoryDropdown extends StatelessWidget {
  const CategoryDropdown({super.key, required this.value, required this.onChanged});

  final ListingCategory value;
  final ValueChanged<ListingCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<ListingCategory>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Category'),
      items: [for (final category in ListingCategory.values) DropdownMenuItem(value: category, child: Text(category.label))],
      onChanged: (category) {
        if (category != null) onChanged(category);
      },
    );
  }
}
