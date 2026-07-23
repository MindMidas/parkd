import 'dart:io';

import 'package:image_picker/image_picker.dart';

/// Writes pick bytes to a temp path native [image_cropper] can open
Future<String> materializeXFileForImageCrop(XFile file) async {
  final bytes = await file.readAsBytes();
  final lower = file.name.toLowerCase();
  final ext = lower.endsWith('.png') ? 'png' : 'jpg';
  final path =
      '${Directory.systemTemp.path}/parkd_pick_${DateTime.now().microsecondsSinceEpoch}.$ext';
  await File(path).writeAsBytes(bytes);
  return path;
}
