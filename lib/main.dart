import 'package:flutter/material.dart';
import 'package:stoic_quotes/quotes_page.dart';
void main() => runApp(QuotesGeneratorApp());

class QuotesGeneratorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quotes Generator',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const QuotesScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
