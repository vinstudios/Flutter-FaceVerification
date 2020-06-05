import 'dart:math';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'face_painter.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/foundation.dart';
import 'utils.dart';

class FaceDetectionFromLiveCamera extends StatefulWidget {
  @override
  _FaceDetectionFromLiveCameraState createState() =>
      _FaceDetectionFromLiveCameraState();
}

class _FaceDetectionFromLiveCameraState
    extends State<FaceDetectionFromLiveCamera> {
  List<Face> faces;
  CameraController _controller;
  BuildContext ctx;

  static int decimals = 2;
  static int fac = pow(10, decimals);

  bool foundFace = false;
  bool closeBothEyes = false;
  String text = 'Detecting face...';

  double leftEyeOpenProbability = 0;
  double rightEyeOpenProbability = 0;

  bool _isDetecting = false;
  CameraLensDirection _direction = CameraLensDirection.front;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void deactivate() {
    _controller.dispose();
    super.deactivate();
  }

  void _initializeCamera() async {
    CameraDescription description = await getCamera(_direction);
    ImageRotation rotation =
        rotationIntToImageRotation(description.sensorOrientation);

    _controller = CameraController(
      description,
      defaultTargetPlatform == TargetPlatform.iOS
          ? ResolutionPreset.low
          : ResolutionPreset.medium,
    );

    await _controller.initialize();

    _controller.startImageStream((CameraImage image) {
      if (_isDetecting) return;
      _isDetecting = true;

      detect(
              image,
              FirebaseVision.instance
                  .faceDetector(FaceDetectorOptions(enableClassification: true))
                  .processImage,
              rotation)
          .then(
        (dynamic result) {
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
      await _controller.initialize();
      final path = join(
        (await getTemporaryDirectory()).path,
        '${DateTime.now()}.png',
      );
      await _controller.takePicture(path);
      Navigator.pop(ctx, path);
    } catch (e) {
      print(e);
    }
  }

  Widget _buildResults() {
    const Text noResultsText = const Text('No results!');
    if (faces == null || _controller == null || !_controller.value.isInitialized) {
      return noResultsText;
    }

    CustomPainter painter;
    final Size imageSize = Size(_controller.value.previewSize.height,
        _controller.value.previewSize.width);

    if (faces is! List<Face>) return noResultsText;
    painter = FacePainterLiveCamera(imageSize, faces);

    if (faces.length > 0) {
      foundFace = true;
      text = faces.length > 1 ? 'Found faces' : 'Found face';
      for (Face face in faces) {
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

        if (leftEyeOpenProbability <= 0.2 && rightEyeOpenProbability <= 0.2) {
          //closeBothEyes = true;
          captureImage();
        }
      }
    } else {
      foundFace = false;
      closeBothEyes = false;
      text = 'Detecting face...';
    }

    return CustomPaint(
      painter: painter,
    );
  }

  void _toggleCameraDirection() async {
    if (_direction == CameraLensDirection.back) {
      _direction = CameraLensDirection.front;
    } else {
      _direction = CameraLensDirection.back;
    }

    await _controller.stopImageStream();
    await _controller.dispose();

    setState(() {
      _controller = null;
    });

    _initializeCamera();
  }

  @override
  Widget build(BuildContext context) {
    ctx = context;
    return Scaffold(
      backgroundColor: Colors.blue,
      body: SafeArea(
        child: Container(
          constraints: const BoxConstraints.expand(),
          child: _controller == null
              ? const Center(
                  child: Text(
                    'Initializing Camera...',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 20.0,
                    ),
                  ),
                )
              : Stack(
                  alignment: Alignment.center,
                  fit: StackFit.expand,
                  children: <Widget>[
                    CameraPreview(_controller),
                    _buildResults(),
                    Positioned(
                      bottom: 200.0,
                      child: Opacity(
                          opacity: 0.75,
                          child: Text(text,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 30.0,
                                  letterSpacing: 2.0))),
                    ),
                    !foundFace
                        ? Container()
                        : Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              Positioned(
                                bottom: 175.0,
                                child: Opacity(
                                    opacity: 0.75,
                                    child: Text(
                                        'Close both eyes to take picture',
                                        style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 20.0,
                                            letterSpacing: 1.0))),
                              ),
                              Positioned(
                                bottom: 155.0,
                                child: Opacity(
                                    opacity: 0.75,
                                    child: Text(
                                        'Left eye Prob: $leftEyeOpenProbability',
                                        style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 14.0,
                                            letterSpacing: 1.0))),
                              ),
                              Positioned(
                                bottom: 135.0,
                                child: Opacity(
                                    opacity: 0.75,
                                    child: Text(
                                        'Right eye Prob: $rightEyeOpenProbability',
                                        style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 14.0,
                                            letterSpacing: 1.0))),
                              ),
                            ],
                          ),
                  ],
                ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            await _controller.initialize();
            final path = join(
              (await getTemporaryDirectory()).path,
              '${DateTime.now()}.png',
            );

            await _controller.takePicture(path);
            Navigator.pop(context, path);
          } catch (e) {
            print(e);
          }
        }, //_toggleCameraDirection,
        child: _direction == CameraLensDirection.back
            ? const Icon(Icons.camera_front)
            : const Icon(Icons.camera_rear),
      ),
    );
  }
}
