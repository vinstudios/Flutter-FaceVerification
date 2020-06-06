import 'dart:math';
import 'package:path/path.dart' as PATH;
import 'package:path_provider/path_provider.dart';
//import 'face_painter.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/foundation.dart';
import 'utils.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class FaceDetectionFromLiveCamera extends StatefulWidget {
  @override
  _FaceDetectionFromLiveCameraState createState() => _FaceDetectionFromLiveCameraState();
}

class _FaceDetectionFromLiveCameraState extends State<FaceDetectionFromLiveCamera> {
  List<Face> faces;
  CameraController _controller;
  final int fac = pow(10, 2);

  bool foundFace = false;
  bool validFace = false;
  String text = 'Searching face...';

  double leftEyeOpenProbability = 0;
  double rightEyeOpenProbability = 0;
  double closeEyeValue = 0.05;
  int faceId;

  bool isCapturing = false;
  bool _isDetecting = false;
  CameraLensDirection _direction = CameraLensDirection.back;

  Size screenSize;

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

      detect(image, FirebaseVision.instance.faceDetector(FaceDetectorOptions(enableClassification: true)).processImage, rotation).then((dynamic result) {
          setState(() => faces = result);
          _isDetecting = false;
        },

      ).catchError(
        (_) {
          _isDetecting = false;
        },
      );
    });
  }

  void captureImage() async {
    try {
      final path = PATH.join((await getTemporaryDirectory()).path,'${DateTime.now()}.png');
      await _controller.initialize();
      setState(() => isCapturing = true );
      await Future.delayed(Duration(milliseconds: 50));
      await _controller.takePicture(path);
      Navigator.pop(context, path);
    } catch (e) {
      print(e);
    }
  }

  void faceVerification() {
    if (faces != null) {
      if (faces.length > 0) {
        for (Face face in faces) {

          if (face.boundingBox.width < (screenSize.width - (screenSize.width / 4.25))) {
            text = 'Please align your face';
          }
          else {
            foundFace = true;
            faceId = face.trackingId;
            if (face.leftEyeOpenProbability != null) {
              leftEyeOpenProbability =
                  (face.leftEyeOpenProbability * fac).round() / fac;
            } else {
              leftEyeOpenProbability = 0;
            }

            if (face.rightEyeOpenProbability != null) {
              rightEyeOpenProbability =
                  (face.rightEyeOpenProbability * fac).round() / fac;
            } else {
              rightEyeOpenProbability = 0;
            }

            if (leftEyeOpenProbability <= closeEyeValue && rightEyeOpenProbability <= closeEyeValue) {
              print('Face Id: ' + faceId.toString());
              captureImage();
            }
          }
        }
      }
      else {
        foundFace = false;
        text = 'Searching face...';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    screenSize = MediaQuery.of(context).size;
    faceVerification();
    return Scaffold(
      appBar: AppBar(
        elevation: 0.0,
        title:Row(
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
      body: Container(
        //constraints: const BoxConstraints.expand(),
        child: _controller == null || isCapturing
            ? Center(
                child: SpinKitCircle(
                  color: Color(0xffff8888),
                  size: 80.0,
                ),
              )
            : Stack(
                alignment: Alignment.center,
                fit: StackFit.expand,
                children: <Widget>[
                  CameraPreview(_controller),
                  ColorFiltered(
                    colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.35), BlendMode.srcOut), // This one will create the magic
                    child: Stack(
                      fit: StackFit.expand,
                      alignment: Alignment.center,
                      children: <Widget>[
                        Container(
                          decoration: BoxDecoration(
                              color: Colors.black,
                              backgroundBlendMode: BlendMode.dstOut), // This one will handle background + difference out
                        ),
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            // margin: EdgeInsets.only(bottom: 30.0),
                            height: screenSize.height - (screenSize.height / 2),
                            width: screenSize.width - (screenSize.width / 5),
                            decoration: BoxDecoration(color: Colors.red,
                              borderRadius: BorderRadius.circular(250),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  foundFace
                      ? Positioned(
                    top: screenSize.height - (screenSize.width / 2),
                    child: Text(text,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22.0,
                            letterSpacing: 2.0)),
                  )
                      : Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            Positioned(
                              top: screenSize.height - (screenSize.width / 2),
                              child: Column(
                                children: <Widget>[
                                  Text(
                                      'Close both eyes to take picture',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20.0,
                                          letterSpacing: 1.0)),
                                  Row(
                                    children: <Widget>[
                                      Text(
                                          'Left eye lid: ${(leftEyeOpenProbability * 100).toStringAsFixed(2)}%',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14.0,
                                              letterSpacing: 1.0)),
                                      SizedBox(width: 10.0),
                                      Text(' | ', style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14.0,
                                          letterSpacing: 1.0)),
                                      SizedBox(width: 10.0),
                                      Text(
                                        'Right eye lid: ${(rightEyeOpenProbability * 100).toStringAsFixed(2)}%',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14.0,
                                            letterSpacing: 1.0),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ],
              ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Container(
          height: 50.0,
          child: Center(
            child: Text('Face Verification', textAlign: TextAlign.center, style: TextStyle(
                fontSize: 20.0,
                letterSpacing: 2.0,
                fontFamily: 'LemonMilk',
                color: Colors.white,
            )),
          ),
        ),
        shape: CircularNotchedRectangle(),
        color: Color(0xffff8888),
      ),
    );
  }
}