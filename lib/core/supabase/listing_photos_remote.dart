import 'dart:io' show File;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/listing_photo.dart';
import '../security/image_upload_policy.dart';

/// `listing_photos` rows backed exclusively by policy-protected Supabase Storage.
class ListingPhotosRemote {
  ListingPhotosRemote(this._client);

  final SupabaseClient _client;

  static const bucket = 'listing-photos';

  Future<List<ListingPhoto>> listForListing(String listingId) async {
    final rows = await _client
        .from('listing_photos')
        .select()
        .eq('listing_id', listingId)
        .order('sort_order', ascending: true);
    return (rows as List)
        .map(
          (e) => ListingPhoto.fromJson(
            _materializePublicUrl(Map<String, dynamic>.from(e as Map)),
          ),
        )
        .toList();
  }

  Map<String, dynamic> _materializePublicUrl(Map<String, dynamic> row) {
    final stored = row['photo_url'];
    if (stored is String && stored.isNotEmpty && !stored.startsWith('http')) {
      row['photo_url'] = _client.storage.from(bucket).getPublicUrl(stored);
    }
    return row;
  }

  Future<void> setHeroMarker({
    required String listingId,
    required double markerX,
    required double markerY,
  }) async {
    await _client
        .from('listing_photos')
        .update({'marker_x': markerX, 'marker_y': markerY})
        .eq('listing_id', listingId)
        .eq('sort_order', 0);
  }

  Future<ListingPhoto> uploadFromLocalPath({
    required String listingId,
    required String localFilePath,
    int sortOrder = 0,
  }) async {
    final Uint8List bytes;
    if (kIsWeb) {
      bytes = await XFile(localFilePath).readAsBytes();
    } else {
      bytes = await File(localFilePath).readAsBytes();
    }
    final validated = ImageUploadPolicy.validate(
      bytes,
      maxBytes: ImageUploadPolicy.maxListingPhotoBytes,
    );
    final ext = validated.extension;
    final contentType = validated.contentType;

    final ownerId = _client.auth.currentUser?.id;
    if (ownerId == null) {
      throw StateError('Sign in before uploading a listing photo.');
    }
    final objectPath =
        '$ownerId/$listingId/${DateTime.now().microsecondsSinceEpoch}.$ext';
    await _client.storage
        .from(bucket)
        .uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(upsert: false, contentType: contentType),
        );
    try {
      final row = await _client
          .from('listing_photos')
          .insert({
            'listing_id': listingId,
            'photo_url': objectPath,
            'sort_order': sortOrder,
          })
          .select()
          .single();
      return ListingPhoto.fromJson(
        _materializePublicUrl(Map<String, dynamic>.from(row)),
      );
    } catch (_) {
      await _client.storage.from(bucket).remove([objectPath]);
      rethrow;
    }
  }

  Future<void> deletePhoto(String photoId) async {
    final row = await _client
        .from('listing_photos')
        .select('photo_url')
        .eq('id', photoId)
        .maybeSingle();
    final stored = row?['photo_url'];
    final storagePath = stored is String ? _storagePath(stored) : null;
    if (storagePath != null) {
      await _client.storage.from(bucket).remove([storagePath]);
    }
    await _client.from('listing_photos').delete().eq('id', photoId);
  }

  static String? _storagePath(String stored) {
    final value = stored.trim();
    if (value.isEmpty) return null;
    if (!value.startsWith('http')) return value;
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    final marker = uri.pathSegments.indexOf(bucket);
    if (marker < 0 || marker + 1 >= uri.pathSegments.length) return null;
    return uri.pathSegments.skip(marker + 1).join('/');
  }

  Future<void> reorderPhotos({
    required String listingId,
    required List<String> photoIdsInOrder,
  }) async {
    for (var i = 0; i < photoIdsInOrder.length; i++) {
      await _client
          .from('listing_photos')
          .update({'sort_order': i})
          .eq('id', photoIdsInOrder[i])
          .eq('listing_id', listingId);
    }
  }
}
