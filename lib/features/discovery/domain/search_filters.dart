import '../../listings/domain/listing.dart';
import 'sort_option.dart';

class SearchFilters {
  const SearchFilters({this.keyword, this.category, this.location, this.minRating, this.sort = SortOption.newest});

  final String? keyword;
  final ListingCategory? category;
  final String? location;
  final double? minRating;
  final SortOption sort;
}
