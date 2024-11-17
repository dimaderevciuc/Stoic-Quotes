import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:stoic_quotes/FavoritesScreen.dart';
import 'package:stoic_quotes/ContactsScreen.dart';

class QuotesScreen extends StatefulWidget {
  const QuotesScreen({super.key});

  @override
  State<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen> {
  List<Map<String, String>> quotes = [];
  int currIndex = 0;
  List<Map<String, String>> favoriteQuotes = [];
  bool isFavorite() => favoriteQuotes.contains(quotes[currIndex]);

  @override
  void initState() {
    super.initState();
    loadQuotes();
  }

  Future<void> loadQuotes() async {
    final csvRawData =
        await rootBundle.loadString('lib/assets/quotes_list.csv');
    List<List<dynamic>> csvData =
        const CsvToListConverter().convert(csvRawData);

    setState(() {
      quotes = csvData.map((row) {
        return {
          'quote': row[0].toString(),
          'author': row[1].toString(),
        };
      }).toList();
    });
  }

  void showNextQuote() {
    setState(() {
      currIndex = (currIndex + 1) % quotes.length;
    });
  }

  void showPreviousQuote() {
    setState(() {
      currIndex = (currIndex - 1 + quotes.length) % quotes.length;
    });
  }

  void toggleFavorite() {
    setState(() {
      if (isFavorite()) {
        favoriteQuotes.remove(quotes[currIndex]);
      } else {
        favoriteQuotes.add(quotes[currIndex]);
      }
    });
  }

  void openFavorites() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FavoritesScreen(favorites: favoriteQuotes),
      ),
    );
  }

  void openContactInfo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        title: Text('   Stoic Quotes'),
        titleTextStyle: TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.amber[600],
            fontSize: 17),
        backgroundColor: Colors.black87,
        actions: [
          PopupMenuButton<String>(
            color: Colors.black87,
            iconColor: Colors.amber[600],
            onSelected: (value) {
              if (value == 'Favorites') {
                openFavorites();
              } else if (value == 'Contact') {
                openContactInfo();
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                value: 'Favorites',
                child: Text(
                  'Favorites',
                  style: TextStyle(color: Colors.amber[600]),
                ),
              ),
              PopupMenuItem(
                value: 'Contact',
                child: Text(
                  'Contact',
                  style: TextStyle(color: Colors.amber[600]),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: quotes.isEmpty
            ? CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    SizedBox(height: 250),
                    SizedBox(
                      height: 250,
                      child: Column(
                        children: [
                          Text(
                            quotes[Random().nextInt(quotes.length)]['quote'] ?? '',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 24,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber[600]),
                          ),
                          SizedBox(height: 10),
                          Text(
                            '-${quotes[Random().nextInt(quotes.length)]['author'] ?? ''}-',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 18, color: Colors.amber[300]),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 100),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: showPreviousQuote,
                          child: Text('Previous'),
                        ),
                        IconButton(
                          onPressed: toggleFavorite,
                          icon: Icon(
                            isFavorite()
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: Colors.red,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: showNextQuote,
                          child: Text('Next'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
      ),
    );
  }
}
