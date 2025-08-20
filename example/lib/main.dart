import 'package:flutter/material.dart';
import 'package:flutter_rust_http/flutter_rust_http.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterRustHttp.initialize();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Flutter Rust HTTP Example')),
        body: Center(
          child: ElevatedButton(
            child: Text('Make Request'),
            onPressed: () async {
              try {
                final response = await FlutterRustHttp().get(
                  'https://jsonplaceholder.typicode.com/posts/1',
                );
                print('Response: ${response.body}');
              } catch (e) {
                print('Error: $e');
              }
            },
          ),
        ),
      ),
    );
  }
}