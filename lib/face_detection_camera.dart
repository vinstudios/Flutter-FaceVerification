import 'dart:math';
import 'package:path/path.dart' as PATH;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/foundation.dart';
import 'image_data.dart';
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
  String text = 'Searching face...';

  double leftEyeOpenProbability = 0;
  double rightEyeOpenProbability = 0;
  double closeEyeValue = 0.05;
  int faceId;
  double faceWidthSize = 0.0;
  Size screenSize;
  String imagePath;
  bool customSize;
  bool isCapturing = false;
  bool _isDetecting = false;
  CameraLensDirection _direction = CameraLensDirection.front;


  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  void showSnackBar(String value) {
    _scaffoldKey.currentState.showSnackBar(SnackBar(duration: Duration(milliseconds : 3000), behavior: SnackBarBehavior.floating,content: Text(value)));
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
    if (faces != null && !isCapturing) {
      if (faces.length > 0) {
        for (Face face in faces) {
          if (face.boundingBox.width < screenSize.width - (screenSize.width / 2.4)) {
            text = 'Please come closer';
            foundFace = false;
            faceId = null;
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
//              print('Face Id: ' + face.trackingId.toString());
//              print('Face Left: ' + face.boundingBox.left.toString());
//              print('Face Right: ' + face.boundingBox.right.toString());
//              print('Face Top: ' + face.boundingBox.top.toString());
//              print('Face Bottom: ' + face.boundingBox.bottom.toString());
//              print('Face Width: ' + face.boundingBox.width.toString());
//              print('Face height: ' + face.boundingBox.height.toString());

              captureImage();
            }
          }
        }
      }
      else {
        foundFace = false;
        faceId = null;
        text = 'Searching face...';
      }
    }
  }

  void _modalBottomSheetMenu(){
    showModalBottomSheet(
        context: context,
        builder: (builder){
          return Container(
            height: 350.0,
            color: Colors.transparent, //could change this to Color(0xFF737373),
            //so you don't have to change MaterialApp canvasColor
            child: Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10.0),
                        topRight: Radius.circular(10.0))),
                child: Center(
                  child: Column(
                    children: <Widget>[
                      Text("This is a modal sheet"),
                    ],
                  ),
                )),
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    screenSize = MediaQuery.of(context).size;
    faceVerification();
    return Scaffold(
      key: _scaffoldKey,
      body: Container(
        //constraints: BoxConstraints.expand(),
        child: _controller == null || isCapturing
            ? Center(
                child: SpinKitCircle(
                  color: Color(0xff430e80),
                  size: 80.0,
                ),
              )
            : Stack(
                //alignment: Alignment.center,
                //fit: StackFit.expand,
                children: <Widget>[
                  Center(
                    child: AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: CameraPreview(_controller)),
                  ),
                  ColorFiltered(
                    colorFilter: ColorFilter.mode(Colors.white,/**Colors.white.withOpacity(0.35)*/ BlendMode.srcOut), // This one will create the magic
                    child: Stack(
                      //fit: StackFit.expand,
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
                            height: screenSize.width - (screenSize.width / 2.4),//screenSize.height - (screenSize.height / 1.5),
                            width: screenSize.width - (screenSize.width / 2.4),
                            decoration: BoxDecoration(color: Colors.red,
                              borderRadius: BorderRadius.circular(150),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                        'FACE VERIFICATION',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'LemonMilk',
                            fontSize: 18.0,
                            letterSpacing: 1.5),
                      ),
                    ),
                  ),
                  !foundFace
                      ? Positioned(
                    top: screenSize.height - (screenSize.width / 2),
                    child: Center(
                      child: Text(text,
                          style: TextStyle(
                              color:Color(0xff430e80),
                              fontSize: 22.0,
                              letterSpacing: 2.0))),
                  )
                      : Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            Positioned(
                              top: screenSize.height - (screenSize.width / 2),
                              child: Column(
                                children: <Widget>[
                                  Text(
                                      'Blink both eyes to take picture',
                                      style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 20.0,
                                          letterSpacing: 1.0)),
                                  Row(
                                    children: <Widget>[
                                      Text(
                                          'Left eye lid: ${(leftEyeOpenProbability * 100).toStringAsFixed(2)}%',
                                          style: TextStyle(
                                              color: Colors.red,
                                              fontSize: 14.0,
                                              letterSpacing: 1.0)),
                                      SizedBox(width: 10.0),
                                      Text(' | ', style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 14.0,
                                          letterSpacing: 1.0)),
                                      SizedBox(width: 10.0),
                                      Text(
                                        'Right eye lid: ${(rightEyeOpenProbability * 100).toStringAsFixed(2)}%',
                                        style: TextStyle(
                                            color: Colors.red,
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
//      floatingActionButton: FloatingActionButton(
//        elevation: 5.0,
//        backgroundColor: Color(0xffff8888),
//        child: Icon(Icons.camera, color: Colors.white , size: 45.0),
//        onPressed: captureImage,
//      ),
    );
  }
}