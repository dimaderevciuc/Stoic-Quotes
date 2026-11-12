import 'package:flutter/material.dart';
import 'package:stoic_quotes/quotes_page.dart';
void main() => runApp(const QuotesGeneratorApp());

class QuotesGeneratorApp extends StatelessWidget {
  const QuotesGeneratorApp({super.key});

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
