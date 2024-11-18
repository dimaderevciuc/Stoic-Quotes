import 'package:flutter/material.dart';
import 'favoritesdb.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Map<String, dynamic>> favorites = [];

  @override
  void initState() {
    super.initState();
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    final dbHelper = DBHelper();
    final favoriteData = await dbHelper.getFavorites();

    setState(() {
      favorites = favoriteData;
    });
  }

  Future<void> removeFavorite(String quote) async {
    final dbHelper = DBHelper();
    await dbHelper.deleteFavorite(quote);
    loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        title: Text('Favorites', style: TextStyle(color: Colors.amber[600])),
        backgroundColor: Colors.black87,
        iconTheme: IconThemeData(
          color: Colors.amber[600],
        ),
      ),
      body: favorites.isEmpty
          ? Center(
              child: Text(
                'No favorites yet!',
                style: TextStyle(color: Colors.amber[600]),
              ),
            )
          : ListView.builder(
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final favorite = favorites[index];
                return ListTile(
                  title: Text(
                    favorite['quote'] ?? '',
                    style: TextStyle(color: Colors.amber[600]),
                  ),
                  subtitle: Text(
                    favorite['author'] ?? '',
                    style: TextStyle(color: Colors.amber[300]),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      removeFavorite(favorite['quote'] ?? '');
                    },
                  ),
                );
              },
            ),
    );
  }
}
