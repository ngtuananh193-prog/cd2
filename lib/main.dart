import 'package:flutter/material.dart';
import 'package:flute_example/my_app.dart';
import 'package:flute_example/utils/themes.dart';

void main() => runApp(const MyMaterialApp());

class MyMaterialApp extends StatefulWidget {
  const MyMaterialApp({super.key});

  @override
  MyMaterialAppState createState() {
    return MyMaterialAppState();
  }
}

class MyMaterialAppState extends State<MyMaterialApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: darkTheme,
      home: const MyApp(),
    );
  }
}
