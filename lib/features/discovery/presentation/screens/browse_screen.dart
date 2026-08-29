import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../listings/domain/listing.dart';
import '../../application/discovery_controller.dart';
import '../../domain/sort_option.dart';
import '../widgets/listing_card.dart';

class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(searchFiltersProvider);
    final resultsAsync = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse'),
        actions: [
          PopupMenuButton<SortOption>(
            initialValue: filters.sort,
            icon: const Icon(Icons.sort),
            onSelected: (sort) => ref.read(searchFiltersProvider.notifier).setSort(sort),
            itemBuilder: (context) => [for (final option in SortOption.values) PopupMenuItem(value: option, child: Text(option.label))],
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (context) => const _FilterSheet()),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(labelText: 'Search listings', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
              onSubmitted: (value) => ref.read(searchFiltersProvider.notifier).setKeyword(value),
            ),
          ),
          Expanded(
            child: resultsAsync.when(
              data: (listings) {
                if (listings.isEmpty) {
                  return const Center(child: Text('No listings match your search.'));
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(searchResultsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: listings.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final listing = listings[index];
                      return ListingCard(listing: listing, onTap: () => context.push(AppRoute.listingDetailPath(listing.id)));
                    },
                  ),
                );
              },
              error: (error, stackTrace) => Center(child: Text('Could not load listings: $error')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late ListingCategory? _category;
  late final TextEditingController _locationController;
  late double? _minRating;

  @override
  void initState() {
    super.initState();
    final filters = ref.read(searchFiltersProvider);
    _category = filters.category;
    _locationController = TextEditingController(text: filters.location ?? '');
    _minRating = filters.minRating;
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Filters', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          DropdownButtonFormField<ListingCategory?>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              const DropdownMenuItem(child: Text('Any')),
              for (final category in ListingCategory.values) DropdownMenuItem(value: category, child: Text(category.label)),
            ],
            onChanged: (value) => setState(() => _category = value),
          ),
          const SizedBox(height: 16),
          TextField(controller: _locationController, decoration: const InputDecoration(labelText: 'Location')),
          const SizedBox(height: 16),
          DropdownButtonFormField<double?>(
            initialValue: _minRating,
            decoration: const InputDecoration(labelText: 'Minimum rating'),
            items: const [
              DropdownMenuItem(child: Text('Any')),
              DropdownMenuItem(value: 3.0, child: Text('3+ stars')),
              DropdownMenuItem(value: 4.0, child: Text('4+ stars')),
              DropdownMenuItem(value: 4.5, child: Text('4.5+ stars')),
            ],
            onChanged: (value) => setState(() => _minRating = value),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              ref
                  .read(searchFiltersProvider.notifier)
                  .applyFilters(category: _category, location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(), minRating: _minRating);
              Navigator.of(context).pop();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
