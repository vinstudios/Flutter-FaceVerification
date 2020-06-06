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
  String text = 'Please verify your face';

  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  void showSnackBar(String value) {
    _scaffoldKey.currentState.showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        titleSpacing: 5.0,
        elevation: 0.0,
        leading: Image.asset(
          'images/jex.png',
          scale: 35.0,
        ),
        title: Row(
          children: <Widget>[
            Text('JEX', style: TextStyle(
              fontSize: 20.0,
              letterSpacing: 2.0,
              fontFamily: 'LemonMilkBold'
            )),
            Text('MOVERS', style: TextStyle(
                fontSize: 20.0,
                letterSpacing: 2.0,
                fontFamily: 'LemonMilk'
            )),
          ],
        ),
        backgroundColor: Color(0xffff8888),
      ),
      body: SafeArea(
        child: Center(
          child: image == null
              ? Column(
                children: <Widget>[
                  Image.asset('images/face_detect.gif'),
                  SizedBox(height: 30.0),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(color: Color(0xff6576e7), fontSize: 20.0, letterSpacing: 1.5,),
                        text: text,
                      ),
                    ),
                  ),
                  //Text(text, style: TextStyle(color: Color(0xFF1a237e), fontSize: 20.0, letterSpacing: 1.5)),
                ],
              )
              : Stack(alignment: Alignment.center,
                children: <Widget>[
                  Positioned(child: Image.file(File(image))),
                  Positioned(child: Uploader(path: image)),
                ],
              ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        elevation: 5.0,
        backgroundColor: Color(0xffff8888),
        child: Icon(Icons.camera, color: Colors.white , size: 45.0),
        onPressed: () async {
          var result = await Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => FaceDetectionFromLiveCamera()));
          setState(() {
            if (result == null) {
              text = 'Face verification cancelled';
              showSnackBar(text);
            } else {
              image = result;
            }
          });
        },
      ),
      bottomNavigationBar: BottomAppBar(
        child: SizedBox(height: 50.0),
        shape: CircularNotchedRectangle(),
        color: Color(0xffff8888),
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