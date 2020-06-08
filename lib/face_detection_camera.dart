import 'dart:math';
import 'package:flutter/cupertino.dart';
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
          //await Future.delayed(Duration(milliseconds: 50));
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
    if (faces == null || isCapturing) {return;}

    if (faces.length < 1 ) {
      foundFace = false;
      text = 'Searching face...';
      return;
    }

    if (faces.length > 1) {
      text = 'Only 1 face is allowed';
      foundFace = false;
      return;
    }

    if (faces[0].boundingBox.width < _controller.value.previewSize.width / 2.5) {
      text = 'Please come closer';
      foundFace = false;
      return;
    }

    if (faces[0].boundingBox.width > _controller.value.previewSize.width / 1.65 ) {
      text = 'Your too close';
      foundFace = false;
      return;
    }

    text = 'Now blink your eyes';
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


    if (leftEyeOpenProbability <= closeEyeValue && rightEyeOpenProbability <= closeEyeValue) {

      print('########################## CAMERA SETTINGS ##########################');
      print('Camera Height: ' + _controller.value.previewSize.height.toString());
      print('Camera Width: ' + _controller.value.previewSize.width.toString());
      print('Camera Aspect Ratio: ' + _controller.value.previewSize.aspectRatio.toString());

      print('########################## FACE SETTINGS   ##########################');
      print('Face Left: ' + faces[0].boundingBox.left.toString());
      print('Face Right: ' + faces[0].boundingBox.right.toString());
      print('Face Top: ' + faces[0].boundingBox.top.toString());
      print('Face Bottom: ' + faces[0].boundingBox.bottom.toString());
      print('Face Width: ' + faces[0].boundingBox.width.toString());
      print('Face height: ' + faces[0].boundingBox.height.toString());

      captureImage();
    }




  }

//  void _modalBottomSheetMenu(){
//    showModalBottomSheet(
//        context: context,
//        builder: (builder){
//          return Container(
//            height: 350.0,
//            color: Colors.transparent, //could change this to Color(0xFF737373),
//            //so you don't have to change MaterialApp canvasColor
//            child: Container(
//                decoration: BoxDecoration(
//                    color: Colors.white,
//                    borderRadius: BorderRadius.only(
//                        topLeft: Radius.circular(10.0),
//                        topRight: Radius.circular(10.0))),
//                child: Center(
//                  child: Column(
//                    children: <Widget>[
//                      Text("This is a modal sheet"),
//                    ],
//                  ),
//                )),
//          );
//        }
//    );
//  }

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
                      padding: EdgeInsets.only(top: 140.0),
                      child: Column(
                        children: <Widget>[
                          Text(
                            'Face Verification',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'GilroySemiBold',
                                fontSize: 22.0,
                                letterSpacing: 1.5),
                          ),
                          SizedBox(height: 5.0),
                          Text(
                            'Identifying...',
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
//                  Center(
//                    child: CircleAvatar(
//                      radius: screenSize.width / 2.8,
//                      child: ClipRRect(
//                        borderRadius: BorderRadius.circular(screenSize.width),
//                        child: Container(
//                          height: screenSize.width,
//                          width: screenSize.width,
//                          child: ClipRRect(
//                            child: OverflowBox(
//                              alignment: Alignment.center,
//                              child: FittedBox(
//                                fit: BoxFit.fitWidth,
//                                child:  Container(
//                                  width: screenSize.width,
//                                  height: screenSize.width / _controller.value.aspectRatio,
//                                  child: CameraPreview(_controller),
//                                ),
//                              ),
//                            ),
//                          ),
//                          decoration: BoxDecoration(
//                            //border: Border.all(color: Colors.white),
//                            boxShadow: [
//                              BoxShadow(
//                                color: Colors.grey.withOpacity(0.5),
//                                spreadRadius: 10,
//                                blurRadius: 10,
//                                offset: Offset(1, 0), // changes position of shadow
//                              ),
//                            ],),
//                        ),
//                      ),
//                    ),
//                  ),

//                  Center(
//                    child: Stack(
//                      children: <Widget>[
//                        Center(
//                          child: AspectRatio(
//                              aspectRatio: _controller.value.aspectRatio,
//                              child: CameraPreview(_controller)),
//                        ),
//                        ColorFiltered(
//                          colorFilter: ColorFilter.mode(Colors.white,/**Colors.white.withOpacity(0.35)*/ BlendMode.srcOut), // This one will create the magic
//                          child: Stack(
//                            //fit: StackFit.expand,
//                            alignment: Alignment.center,
//                            children: <Widget>[
//                              Container(
//                                decoration: BoxDecoration(
//                                    color: Color(0xff430e80),
//                                    backgroundBlendMode: BlendMode.dstOut), // This one will handle background + difference out
//                              ),
//                              Container(
//                                height: screenSize.width - (screenSize.width / 4),//screenSize.height - (screenSize.height / 1.5),
//                                width: screenSize.width - (screenSize.width / 4),
//                                decoration: BoxDecoration(color: Colors.red,
//                                  borderRadius: BorderRadius.circular(screenSize.width),
//                                ),
//                              ),
//                            ],
//                          ),
//                        ),
//
//                      ],
//                    ),
//                  ),
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
                          SizedBox(height: 20.0),
                          Container(
                            height: 120.0,
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
                                padding: EdgeInsets.only(top: 18.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text('◼  Position your face within the frame',
                                        style: TextStyle(color: Colors.grey.shade700)),
                                    SizedBox(height: 10.0),
                                    Text('◼  Your face will be automatically scan',
                                        style: TextStyle(color: Colors.grey.shade700)),
                                    SizedBox(height: 10.0),
                                    Text('◼  Blink your both eyes to take a selfie',
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