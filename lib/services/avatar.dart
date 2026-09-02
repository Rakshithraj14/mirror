import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Picks a photo and keeps a copy this app owns.
///
/// Returns the new file's path, or null if you cancelled — or on web, where
/// there is no documents directory and the design preview would otherwise
/// throw. Deletes [previous] once the replacement is safely written.
Future<String?> pickAvatar({String? previous}) async {
  if (kIsWeb) return null;

  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    // Drawn at 46px. A 4000px photo would cost megabytes to store and decode
    // for something the size of a fingernail.
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 85,
  );
  if (picked == null) return null;

  // image_picker hands back a file in the app's *cache*, which Android
  // reclaims under storage pressure — the avatar would vanish weeks later.
  // The timestamped name also sidesteps Flutter's FileImage cache, which
  // would keep painting the old photo if the path never changed.
  final dir = await getApplicationDocumentsDirectory();
  final path =
      '${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
  await File(picked.path).copy(path);

  await deleteAvatar(previous);
  return path;
}

/// Best-effort: a missing or already-deleted file is not a failure worth
/// surfacing, and the profile row is the source of truth either way.
Future<void> deleteAvatar(String? path) async {
  if (kIsWeb || path == null || path.isEmpty) return;
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } catch (_) {}
}
