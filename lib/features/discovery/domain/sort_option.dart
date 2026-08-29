enum SortOption { newest, priceLowToHigh, priceHighToLow, rating }

extension SortOptionLabel on SortOption {
  String get label => switch (this) {
    SortOption.newest => 'Newest',
    SortOption.priceLowToHigh => 'Price: Low to High',
    SortOption.priceHighToLow => 'Price: High to Low',
    SortOption.rating => 'Rating',
  };
}
