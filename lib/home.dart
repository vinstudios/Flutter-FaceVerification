import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart';
import 'face_detection_camera.dart';
import 'package:flutter/material.dart';
import 'dart:async';

final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
void showSnackBar(String value) {
  _scaffoldKey.currentState.showSnackBar(SnackBar(
      duration: Duration(milliseconds: 3000),
      //behavior: SnackBarBehavior.floating,
      content: Text(value)));
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String image;
  String text = 'Please verify your face';


  Timer timer;

  void startTimer() {
    const millis = Duration(seconds: 1);

    timer = Timer.periodic(millis, (Timer timer) {
      print('Timer is starting...');
    });
  }

//  @override
//  void initState() {
//    // TODO: implement initState
//    super.initState();
//    //print('start time');
//    //startTimer();
//
//  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: SingleChildScrollView(
        child: Column(
          //mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Container(
              width: double.infinity,
              height: 90.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30.0),
                    bottomRight: Radius.circular(30.0)),
                gradient: LinearGradient(
                  colors: [Color(0xff28045b), Color(0xff430e80)],
                  stops: [0.0, 0.0],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(top: 45.0),
                child: Text(
                  'FACE AUTHENTICATION',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'GilroySemiBold',
                      fontSize: 20.0,
                      letterSpacing: 1.5),
                ),
              ),
            ),
            SizedBox(height: 20.0),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 30.0),
              child: image == null ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Getting ready!',
                    style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 5.0),
                  Text(
                    'To complete your account, we will be collecting and verifying your personal information.',
                    style: TextStyle(fontSize: 14.0, color: Colors.grey.shade500),
                  ),
                  SizedBox(height: 20.0),
                  Image.asset('images/face_verification.jpg'),
                  SizedBox(height: 20.0),
                  Text('To take a photo of yourself follow these steps:', style: TextStyle(fontSize: 14.0)),
                  Padding(
                    padding: EdgeInsets.only(left: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(height: 10.0),
                        Text('◼  Position your face within the circle',
                            style: TextStyle(color: Colors.grey.shade700)),
                        SizedBox(height: 10.0),
                        Text('◼  Standby for scanning',
                            style: TextStyle(color: Colors.grey.shade700)),
                        SizedBox(height: 10.0),
                        Text('◼  Take a selfie by blinking your both eyes',
                            style: TextStyle(color: Colors.grey.shade700)),
                        SizedBox(height: 10.0),
                        Text('◼  Please remove your eyeglasses',
                            style: TextStyle(color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                ],
              )
                : Column(
            children: <Widget>[
            Image.file(File(image)),
      Uploader(path: image),
      ],
    ),
            ),
            SizedBox(height: 30.0),
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                image == null ? Text('Are you ready? Click "Next" to start verifying.',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12.0)) : Container(),
                RaisedButton(
                  elevation: 1.0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  color: Color(0xff430e80),
                  padding: EdgeInsets.symmetric(horizontal: 100.0),
                  child: Text( image == null ?
                    'NEXT' : 'TRY AGAIN',
                    style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'LemonMilk',
                        letterSpacing: 3.0),
                  ),
                  onPressed: () async {
                    image = null;
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
              ],
            ),
            SizedBox(height: 20.0),
          ],
        ),
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
      try {
        _uploadTask = _storage
            .ref()
            .child('Faces/${basename(widget.path)}')
            .putFile(File(widget.path));
      } catch (e) {
        showSnackBar(e.toString());
        print('Upload error: ' + e.toString());
      }
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
          double progressPercent =
              event != null ? event.bytesTransferred / event.totalByteCount : 0;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              !_uploadTask.isComplete
                  ? Text('Uploading...', style: TextStyle(color: Colors.red))
                  : Text('Upload complete',
                      style: TextStyle(color: Colors.red)),
              SizedBox(height: 10.0),
              Container(
                  width: 250.0,
                  child: LinearProgressIndicator(value: progressPercent)),
              SizedBox(height: 10.0),
              Text('${(progressPercent * 100).toStringAsFixed(2)}%',
                  style: TextStyle(color: Colors.red)),
            ],
          );
        },
      );
    } else {
      return Container();
    }
  }
}
