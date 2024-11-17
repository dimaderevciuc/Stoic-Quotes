import 'package:flutter/material.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Contact Us'),
        backgroundColor: Colors.black87,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                
              },
              icon: Icon(Icons.email),
              label: Text('Email Us'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                
              },
              icon: Icon(Icons.facebook),
              label: Text('Visit Facebook'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                
              },
              icon: Icon(Icons.camera_alt),
              label: Text('Follow on Instagram'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
