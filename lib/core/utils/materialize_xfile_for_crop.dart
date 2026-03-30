import 'package:image_picker/image_picker.dart';

import 'materialize_xfile_for_crop_io.dart'
    if (dart.library.html) 'materialize_xfile_for_crop_stub.dart' as impl;

// gallery/camera XFile paths are not always readable by native croppers
Future<String> materializeXFileForImageCrop(XFile file) =>
    impl.materializeXFileForImageCrop(file);
