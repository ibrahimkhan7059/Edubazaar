import 'package:flutter/material.dart';

class TestDetailScreen extends StatefulWidget {
  const TestDetailScreen({super.key});

  @override
  State<TestDetailScreen> createState() => _TestDetailScreenState();
}

class _TestDetailScreenState extends State<TestDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Screen'),
      ),
      body: Column(
        children: [
          // Test static text
          const Text('Details'),
          const Text('Description'),
          const Text('database'),

          // Test dynamic text (similar to detail screen)
          Text('${1} views'),
          Text('${0} favorites'),
          Text('Aug 12, 2025'),

          // Test with variables
          Builder(
            builder: (context) {
              final title = 'test title';
              final views = 5;
              final favorites = 2;

              return Column(
                children: [
                  Text(title),
                  Text('$views views'),
                  Text('$favorites favorites'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
