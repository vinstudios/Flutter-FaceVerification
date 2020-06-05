import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart';

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
          child: image == null
              ? Text(text)
              : Stack(alignment: Alignment.center,
                children: <Widget>[
                  Positioned(child: Image.file(File(image))),
                  Positioned(child: Uploader(path: image)),
                ],
              ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.camera),
        onPressed: () async {
          var result = await Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => FaceDetectionFromLiveCamera()));
          setState(() {
            if (result == null) {
              text = 'Face verification cancelled. Please try again';
            } else {
              image = result;
            }
          });
        },
      ),
    );
  }
}

class Uploader extends StatefulWidget {
  final String path;
  Uploader({this.path});
  @override
  _UploaderState createState() => _UploaderState();
}

class _UploaderState extends State<Uploader> {
  final FirebaseStorage _storage =
      FirebaseStorage(storageBucket: 'gs://faceverification-2a54f.appspot.com');
  StorageUploadTask _uploadTask;

  void _startUpload() {
    setState(() {
      _uploadTask = _storage
          .ref()
          .child('Faces/${basename(widget.path)}')
          .putFile(File(widget.path));
    });
  }

  @override
  void initState() {
    super.initState();
    _startUpload();
  }

  @override
  Widget build(BuildContext context) {
    if (_uploadTask != null) {
      return StreamBuilder<StorageTaskEvent>(
        stream: _uploadTask.events,
        builder: (context, snapshot) {
          var event = snapshot?.data?.snapshot;
          double progressPercent = event != null ? event.bytesTransferred / event.totalByteCount : 0;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                !_uploadTask.isComplete ? Text('Uploading...',style: TextStyle(color: Colors.red)) : Text('Upload complete',style: TextStyle(color: Colors.red)),
                SizedBox(height: 10.0),
                Container(width: 250.0, child: LinearProgressIndicator(value: progressPercent)),
                SizedBox(height: 10.0),
                Text('${(progressPercent * 100).toStringAsFixed(2)}%', style: TextStyle(color: Colors.red)),
              ],
          );
        },
      );
    } else {
      return Container();
    }
  }
}
