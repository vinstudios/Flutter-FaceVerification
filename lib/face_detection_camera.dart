import 'dart:math';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart' as PATH;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'image_data.dart';


class FaceDetectionFromLiveCamera extends StatefulWidget {
  @override
  _FaceDetectionFromLiveCameraState createState() => _FaceDetectionFromLiveCameraState();
}

class _FaceDetectionFromLiveCameraState extends State<FaceDetectionFromLiveCamera> {
  List<Face> faces;
  CameraController _controller;
  final int fac = pow(10, 2);

  bool foundFace = false;
  String text = 'Searching face...';

  double leftEyeOpenProbability = 0;
  double rightEyeOpenProbability = 0;
  double closeEyeValue = 0.05;
  double faceWidthSize = 0.0;
  Size screenSize;
  String imagePath;
  bool customSize;
  bool isCapturing = false;
  bool _isDetecting = false;
  bool closeEyes = false;
  CameraLensDirection _direction = CameraLensDirection.front;
  int elapsedMilliClosedEye = 0;
  Timer timer;

  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  void showSnackBar(String value) {
    _scaffoldKey.currentState.showSnackBar(SnackBar(duration: Duration(milliseconds : 3000), behavior: SnackBarBehavior.floating,content: Text(value)));
  }

  void startTimer() {
    //int elapsedMilli = 0;
    timer = Timer.periodic(Duration(milliseconds: 1), (timer) {
      elapsedMilliClosedEye = timer.tick;
//      int currentMilli = timer.tick;
//      if (currentMilli - elapsedMilli >= milliInterval) {
//        elapsedMilli = currentMilli;
//        print('$milliInterval milliseconds had passed');
//      }
    });
  }

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void deactivate() {
    if (_controller != null) {
      _controller.dispose();
    }
    imagePath = null;
    super.deactivate();
  }

  void _initializeCamera() async {
    CameraDescription description = await getCamera(_direction);
    ImageRotation rotation = rotationIntToImageRotation(description.sensorOrientation);

    _controller = CameraController(description,
      defaultTargetPlatform == TargetPlatform.iOS
          ? ResolutionPreset.low
          : ResolutionPreset.medium,
    );

    await _controller.initialize();

    _controller.startImageStream((CameraImage image) {
      if (_isDetecting) return;
      _isDetecting = true;

      detect(image, FirebaseVision.instance.faceDetector(FaceDetectorOptions(enableClassification: true, enableTracking: true)).processImage, rotation).then((dynamic result) {
          setState(() => faces = result);
          _isDetecting = false;
        },

      ).catchError(
        (_) {
          _isDetecting = false;
          showSnackBar(_.toString());
        },
      );
    });
  }

  void captureImage() async {
    try {
      imagePath = PATH.join((await getTemporaryDirectory()).path,'${DateTime.now()}.png');
      await _controller.initialize();
      if (_controller.value.isInitialized) {
        if (!_controller.value.isTakingPicture) {
          setState(() => isCapturing = true );
          await Future.delayed(Duration(milliseconds: 50));
          await _controller.takePicture(imagePath);
          setState(() => isCapturing = false );
          Navigator.pop(context, imagePath);
        }
        else {
          showSnackBar('Camera is busy');
        }
      }
      else {
        showSnackBar('Camera is not initialized');
      }
    } catch (e) {
      showSnackBar(e.toString());
      print('Photo capture error: ' + e.toString());
    }
  }

  void faceVerification() {
    if (faces == null || isCapturing) {
      if (timer != null) {
        timer.cancel();
      }
      elapsedMilliClosedEye = 0;
      closeEyes = false;
      foundFace = false;
      return;
    }

    if (faces.length < 1 ) {
      if (timer != null) {
        timer.cancel();
      }
      elapsedMilliClosedEye = 0;
      closeEyes = false;
      foundFace = false;
      text = 'Recognizing face...';
      return;
    }

    if (faces.length > 1) {
      if (timer != null) {
        timer.cancel();
      }
      elapsedMilliClosedEye = 0;
      text = 'Only 1 face is allowed';
      closeEyes = false;
      foundFace = false;
      return;
    }

    if (faces[0].boundingBox.width < _controller.value.previewSize.width / 2.5) {
      if (timer != null) {
        timer.cancel();
      }
      elapsedMilliClosedEye = 0;
      text = 'Come closer';
      closeEyes = false;
      foundFace = false;
      return;
    }

    if (faces[0].boundingBox.width > _controller.value.previewSize.width / 1.65 ) {
      if (timer != null) {
        timer.cancel();
      }
      elapsedMilliClosedEye = 0;
      text = 'You\'re very close';
      closeEyes = false;
      foundFace = false;
      return;
    }

    text = 'Blink your eyes to take your selfie';
    foundFace = true;

    if (faces[0].leftEyeOpenProbability != null) {
      leftEyeOpenProbability = (faces[0].leftEyeOpenProbability * fac).round() / fac;
    } else {
      leftEyeOpenProbability = 0;
    }

    if (faces[0].rightEyeOpenProbability != null) {
      rightEyeOpenProbability = (faces[0].rightEyeOpenProbability * fac).round() / fac;
    } else {
      rightEyeOpenProbability = 0;
    }

    if (closeEyes && elapsedMilliClosedEye >= 1000 && leftEyeOpenProbability > closeEyeValue && rightEyeOpenProbability > closeEyeValue) {
      captureImage();
    }

    if (leftEyeOpenProbability <= closeEyeValue && rightEyeOpenProbability <= closeEyeValue) {
      closeEyes = true;
      startTimer();
    }
    else {
      closeEyes = false;
      if (timer != null) {
        timer.cancel();
      }
      elapsedMilliClosedEye = 0;
    }

  }

  @override
  Widget build(BuildContext context) {
    screenSize = MediaQuery.of(context).size;
    faceVerification();

    return Scaffold(
      key: _scaffoldKey,
      body: Container(
        child: _controller == null || isCapturing
            ? Center(
                child: SpinKitCircle(
                  color: Color(0xff430e80),
                  size: 80.0,
                ),
              )
            : Stack(
                children: <Widget>[
                  Container(
                    width: double.infinity,
                    height: screenSize.height /2,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(100),
                          bottomRight: Radius.circular(100)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        colors: [Color(0xff280358), Color(0xff4F0C80)],
                        stops: [0.0, 1.0],
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(top: 100.0),
                      child: Column(
                        children: <Widget>[
                          Icon(Icons.face, color: Colors.white, size: 35.0),
                          SizedBox(height: 5.0),
                          Text(
                            'Face Authentication',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'GilroySemiBold',
                                fontSize: 22.0,
                                letterSpacing: 1.0),
                          ),
                          SizedBox(height: 5.0),
                          Text(
                            'Verifying...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'IBMPlexLight',
                                fontSize: 18.0,
                                letterSpacing: 3.0),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 8.0),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.25),
                            spreadRadius: 4,
                            blurRadius: 7,
                            offset: Offset(0, 3), // changes position of shadow
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: screenSize.width / 2.7,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(screenSize.width),
                          child: Container(
                            height: screenSize.width,
                            width: screenSize.width,
                            child: ClipRRect(
                              child: OverflowBox(
                                alignment: Alignment.center,
                                child: FittedBox(
                                  fit: BoxFit.fitWidth,
                                  child:  Container(
                                    width: screenSize.width,
                                    height: screenSize.width / _controller.value.aspectRatio,
                                    child: CameraPreview(_controller),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: ((screenSize.height / 2) + (screenSize.width / 2.7)) + 30),
                    child: Center(
                      child: Column(
                        children: <Widget>[
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                                text: text,
                                style: TextStyle(
                                  fontFamily: 'GilroySemiBold',
                                    color: foundFace ? Colors.green : Colors.red,
                                    fontSize: 18.0,
                                    letterSpacing: 2.0)),
                          ),
                          SizedBox(height: 15.0),
                          Container(
                            height: 140.0,
                            width: screenSize.width - 50,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10.0),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.25),
                                  spreadRadius: 2,
                                  blurRadius: 3,
                                  offset: Offset(0, 3), // changes position of shadow
                                ),
                              ],
                            ),
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.only(top: 15.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text('✔  Please remove your eyeglasses',
                                        style: TextStyle(color: Colors.grey.shade700)),
                                    SizedBox(height: 10.0),
                                    Text('✔  Position your face within the circle',
                                        style: TextStyle(color: Colors.grey.shade700)),
                                    SizedBox(height: 10.0),
                                    Text('✔  Standby for scanning',
                                        style: TextStyle(color: Colors.grey.shade700)),
                                    SizedBox(height: 10.0),
                                    Text('✔  Take a selfie by blinking your both eyes',
                                        style: TextStyle(color: Colors.grey.shade700)),

                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
      ),
//      floatingActionButton: FloatingActionButton(
//        elevation: 5.0,
//        backgroundColor: Color(0xffff8888),
//        child: Icon(Icons.camera, color: Colors.white , size: 45.0),
//        onPressed: captureImage,
//      ),
    );
  }
}