import 'package:flutter/material.dart';

import '../../../listings/domain/listing.dart';

class ListingCard extends StatelessWidget {
  const ListingCard({super.key, required this.listing, required this.onTap});

  final Listing listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(listing.title),
        subtitle: Text('${listing.category.label} · ${listing.location}'),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('\$${listing.price.toStringAsFixed(2)}'),
            const SizedBox(height: 4),
            if (listing.avgRating != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, size: 14, color: Colors.amber),
                  const SizedBox(width: 2),
                  Text(listing.avgRating!.toStringAsFixed(1)),
                ],
              )
            else
              const Text('No ratings yet', style: TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
