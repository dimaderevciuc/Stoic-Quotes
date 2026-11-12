import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:stoic_quotes/favorites_screen.dart';
import 'package:stoic_quotes/contacts_screen.dart';
import 'package:stoic_quotes/favoritesdb.dart';

/// Parses the bundled CSV (columns: quote, author, no header) into quote maps.
/// Kept as a pure function so it can be unit tested without Flutter bindings.
List<Map<String, String>> parseQuotesCsv(String csvText) {
  // Fixed delimiter: auto detection could guess wrong for quotes containing ';'.
  final List<List<dynamic>> rows = Csv(autoDetect: false).decode(csvText);
  return rows
      .where((row) => row.length >= 2)
      .map((row) => {
            'quote': row[0].toString(),
            'author': row[1].toString(),
          })
      .toList();
}

class QuotesScreen extends StatefulWidget {
  const QuotesScreen({super.key});

  @override
  State<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen> {
  List<Map<String, String>> quotes = [];
  int currIndex = 0;
  // Favorites are tracked by quote text, so lookups compare content, not object identity.
  Set<String> favoriteTexts = {};
  bool isFavorite() =>
      quotes.isNotEmpty && favoriteTexts.contains(quotes[currIndex]['quote']);

  @override
  void initState() {
    super.initState();
    loadQuotes();
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    final rows = await DBHelper().getFavorites();
    if (!mounted) return;
    setState(() {
      favoriteTexts = rows.map((row) => row['quote'].toString()).toSet();
    });
  }

  Future<void> loadQuotes() async {
    final csvRawData =
        await rootBundle.loadString('lib/assets/quotes_list.csv');
    if (!mounted) return;
    setState(() {
      quotes = parseQuotesCsv(csvRawData)
        ..shuffle(); // random order, no repeats until the list wraps
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

  Future<void> toggleFavorite() async {
    final currentQuote = quotes[currIndex];
    final dbHelper = DBHelper();

    if(isFavorite()){
      await dbHelper.deleteFavorite(currentQuote['quote']!);
      favoriteTexts.remove(currentQuote['quote']);
    } else {
      await dbHelper.insertFavorite(currentQuote['quote']!, currentQuote['author']!,);
      favoriteTexts.add(currentQuote['quote']!);
    }
    if (!mounted) return;
    setState(() {});
  }

  void openFavorites() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const FavoritesScreen(),
      ),
    ).then((_) => loadFavorites()); // refresh in case favorites were removed there
  }

  void openContactInfo() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const ContactsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        title: const Text('   Stoic Quotes'),
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
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(height: 250),
                    SizedBox(
                      height: 250,
                      child: Column(
                        children: [
                          Text(
                            quotes[currIndex]['quote'] ?? '',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 24,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber[600]),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '-${quotes[currIndex]['author'] ?? ''}-',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 18, color: Colors.amber[300]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 100),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: showPreviousQuote,
                          child: const Text('Previous'),
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
                          child: const Text('Next'),
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
