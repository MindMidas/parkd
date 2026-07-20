import 'package:image_picker/image_picker.dart';

import 'materialize_xfile_for_crop_io.dart'
    if (dart.library.html) 'materialize_xfile_for_crop_stub.dart'
    as impl;

/// Gallery/camera [XFile] paths are not always readable by native croppers
/// (iOS Photos assets, Android `content://`). This copies bytes to a temp file
/// when running on IO; on web returns [file.path] unchanged
Future<String> materializeXFileForImageCrop(XFile file) =>
    impl.materializeXFileForImageCrop(file);
