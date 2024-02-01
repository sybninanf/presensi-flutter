import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart' as imglib;

typedef HandleDetection = Future<dynamic> Function(InputImage image);
enum Choice { view, delete }

Future<CameraDescription> getCamera(CameraLensDirection dir) async {
  return await availableCameras().then(
    (List<CameraDescription> cameras) => cameras.firstWhere(
      (CameraDescription camera) => camera.lensDirection == dir,
    ),
  );
}

InputImage buildMetaData(
  CameraImage image,
  InputImageRotation rotation,
) {
  final metadata = InputImageMetadata(
    size: Size(image.width.toDouble(), image.height.toDouble()),
    rotation: rotation,
    format: InputImageFormatValue.fromRawValue(image.format.raw) ??
        InputImageFormat.nv21,// Use rawFormat instead of inputImageFormat
    bytesPerRow: image.planes[0].bytesPerRow,
  );

Uint8List concatenatePlanes(List<Plane> planes) {
  final Plane plane = planes[0];
  final int totalBytes = plane.bytes.length;
  final Uint8List concatenatedBytes = Uint8List(totalBytes);

  int offset = 0;
  for (int i = 0; i < planes.length; i++) {
    concatenatedBytes.setRange(offset, offset + planes[i].bytes.length, planes[i].bytes);
    offset += planes[i].bytes.length;
  }

  return concatenatedBytes;
}

  return InputImage.fromBytes(
    bytes: concatenatePlanes(image.planes),
    metadata: metadata,
  );
}



Future<dynamic> detect(
    CameraImage image, HandleDetection handleDetection) async {
  try {
    CameraDescription description = await getCamera(CameraLensDirection.front);
    InputImageRotation rotation = rotationIntToImageRotation(
      description.sensorOrientation,
    );

    Uint8List concatenatePlanes(List<Plane> planes) {
      int totalSize = 0;
      planes.forEach((plane) {
        totalSize += plane.bytes.length;
      });

      Uint8List concatenatedBytes = Uint8List(totalSize);
      int offset = 0;
      planes.forEach((plane) {
        concatenatedBytes.setRange(offset, offset + plane.bytes.length, plane.bytes);
        offset += plane.bytes.length;
      });

      return concatenatedBytes;
    }

final metadata = InputImageMetadata(
  size: Size(image.width.toDouble(), image.height.toDouble()),
  rotation: rotation,
  format: InputImageFormatValue.fromRawValue(image.format.raw) ??
        InputImageFormat.nv21,
  bytesPerRow: image.planes[0].bytesPerRow,
);

    return handleDetection(
      InputImage.fromBytes(
        bytes: concatenatePlanes(image.planes),
        metadata: metadata,
      ),
    );
  } catch (e) {
    print({'detect': e});
  }
}

InputImageRotation rotationIntToImageRotation(int rotation) {
  switch (rotation) {
    case 0:
      return InputImageRotation.rotation0deg;
    case 90:
      return InputImageRotation.rotation90deg;
    case 180:
      return InputImageRotation.rotation180deg;
    default:
      assert(rotation == 270);
      return InputImageRotation.rotation270deg;
  }
}


Float32List imageToByteListFloat32(
    imglib.Image image, int inputSize, double mean, double std) {
  var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
  var buffer = Float32List.view(convertedBytes.buffer);
  int pixelIndex = 0;
  for (var i = 0; i < inputSize; i++) {
    for (var j = 0; j < inputSize; j++) {
      var pixel = image.getPixel(j, i);
      buffer[pixelIndex++] = (imglib.getRed(pixel) - mean) / std;
      buffer[pixelIndex++] = (imglib.getGreen(pixel) - mean) / std;
      buffer[pixelIndex++] = (imglib.getBlue(pixel) - mean) / std;
    }
  }
  return convertedBytes.buffer.asFloat32List();
}

double euclideanDistance(List e1, List e2) {
  double sum = 0.0;
  for (int i = 0; i < e1.length; i++) {
    sum += pow((e1[i] - e2[i]), 2);
  }
  return sqrt(sum);
}