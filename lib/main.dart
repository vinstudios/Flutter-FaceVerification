import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'home.dart';
import 'package:path/path.dart' as p;

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  void asd() async {
  String path = p.join((await getTemporaryDirectory()).path,'images.png',);

  print(path);
  }

  @override
  Widget build(BuildContext context) {
    asd();

    return MaterialApp(
      home: HomeScreen(),
    );
  }
}