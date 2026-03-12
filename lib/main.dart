import 'package:flutter/material.dart';
import 'package:offline_sync_flutter/ui/notes_list.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
      primarySwatch: Colors.blue,
      fontFamily: "Roboto",
      scaffoldBackgroundColor: Colors.grey.shade100,
    ),
      home: NotesScreen(),
    );
  }
}
