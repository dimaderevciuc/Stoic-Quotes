import 'package:flutter/material.dart';

class FavoritesScreen extends StatelessWidget {
  final List<Map<String, String>> favorites;

  FavoritesScreen({required this.favorites});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black87,
        appBar: AppBar(
          title: Text('Favourites', style: TextStyle(color: Colors.amber[600])),
          backgroundColor: Colors.black87,
          iconTheme: IconThemeData(
            color: Colors.amber[600]
          ),
        ),
        body: favorites.isEmpty
            ? Center(
                child: Text('No favorites yet!',
                    style: TextStyle(color: Colors.amber[600])),
              )
            : ListView.builder(itemBuilder: (context, index) {
                return ListTile(
                  title: Text(favorites[index]['quotes'] ?? ''),
                  subtitle: Text(favorites[index]['author'] ?? ''),
                );
              }));
  }
}
