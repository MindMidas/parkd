import 'dart:io' show File;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloudinary/cloudinary_uploader.dart';
import '../models/listing_photo.dart';

// listing_photos rows; cloudinary
class ListingPhotosRemote {
  ListingPhotosRemote(
    this._client, {
    CloudinaryUploader? cloudinary,
  }) : _cloudinary = cloudinary;

  final SupabaseClient _client;
  final CloudinaryUploader? _cloudinary;

  static const bucket = 'listing-photos';

  Future<List<ListingPhoto>> listForListing(String listingId) async {
    final rows = await _client
        .from('listing_photos')
        .select()
        .eq('listing_id', listingId)
        .order('sort_order', ascending: true);
    return (rows as List)
        .map((e) => ListingPhoto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> setHeroMarker({
    required String listingId,
    required double markerX,
    required double markerY,
  }) async {
    await _client.from('listing_photos').update({
      'marker_x': markerX,
      'marker_y': markerY,
    }).eq('listing_id', listingId).eq('sort_order', 0);
  }

  Future<ListingPhoto> uploadFromLocalPath({
    required String listingId,
    required String localFilePath,
    int sortOrder = 0,
  }) async {
    final ext = localFilePath.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
    final Uint8List bytes;
    if (kIsWeb) {
      bytes = await XFile(localFilePath).readAsBytes();
    } else {
      bytes = await File(localFilePath).readAsBytes();
    }

    late final String publicUrl;
    final cloudinary = _cloudinary;
    if (cloudinary != null) {
      final safeListing =
          listingId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      publicUrl = await cloudinary.uploadImage(
        bytes: bytes,
        contentType: contentType,
        folder: 'parkd/listings/$safeListing',
        publicId: '${DateTime.now().microsecondsSinceEpoch}',
      );
    } else {
      final objectPath =
          '$listingId/${DateTime.now().microsecondsSinceEpoch}.$ext';
      await _client.storage.from(bucket).uploadBinary(
            objectPath,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: contentType),
          );
      publicUrl = _client.storage.from(bucket).getPublicUrl(objectPath);
    }
    final row = await _client
        .from('listing_photos')
        .insert({
          'listing_id': listingId,
          'photo_url': publicUrl,
          'sort_order': sortOrder,
        })
        .select()
        .single();
    return ListingPhoto.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deletePhoto(String photoId) async {
    await _client.from('listing_photos').delete().eq('id', photoId);
  }

  Future<void> reorderPhotos({
    required String listingId,
    required List<String> photoIdsInOrder,
  }) async {
    for (var i = 0; i < photoIdsInOrder.length; i++) {
      await _client
          .from('listing_photos')
          .update({'sort_order': i}).eq('id', photoIdsInOrder[i]).eq(
                'listing_id',
                listingId,
              );
    }
  }
}
