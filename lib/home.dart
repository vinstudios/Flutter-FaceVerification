import 'dart:io';
import 'face_detection_camera.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  String image;
  String text = 'Please verify if you are handsome';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: image == null ? Text(text) :
          Image.file(File(image)),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.camera),
        onPressed: () async {
         var result =  await Navigator.of(context).push(MaterialPageRoute(builder: (context) => FaceDetectionFromLiveCamera()));
         setState((){
           if (result == null) {
             text = 'Face verification cancelled. Please try again';
           }
         });
        },
      ),
    );
  }
}

