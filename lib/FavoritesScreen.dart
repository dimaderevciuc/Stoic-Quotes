import 'package:flutter/material.dart';

class FavoritesScreen extends StatelessWidget {
  final List<Map<String, String>> favorites;

  FavoritesScreen({required this.favorites});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Favourites'),
          backgroundColor: Colors.black,
        ),
        body: favorites.isEmpty
            ? const Center(
                child: Text('No favorites yet!'),
              )
            : ListView.builder(itemBuilder: (context, index) {
                return ListTile(
                  title: Text(favorites[index]['quotes'] ?? ''),
                  subtitle: Text(favorites[index]['author'] ?? ''),
                );
              }));
  }
}
