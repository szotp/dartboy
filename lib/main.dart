import 'package:dartboy/gui/main_screen.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const DartBoy());
}

class DartBoy extends StatelessWidget {
  const DartBoy({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GBC',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MainScreen(title: 'GBC'),
      debugShowCheckedModeBanner: false,
    );
  }
}
