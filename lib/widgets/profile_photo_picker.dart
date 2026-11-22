import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// What the user chose in the photo sheet.
sealed class PhotoChoice {
  const PhotoChoice();
}

class PhotoPicked extends PhotoChoice {
  const PhotoPicked(this.bytes);

  final Uint8List bytes;
}

class PhotoRemoved extends PhotoChoice {
  const PhotoRemoved();
}

enum _Action { library, camera, remove }

/// Bottom sheet: Choose from library / Take photo / Remove current photo.
/// Returns null if the user backs out.
///
/// Images are downscaled to 1024px so a phone photo stays small in memory.
/// TODO(storage): upload the bytes once avatar storage exists, then keep the
/// returned URL in `StudentProfile.avatarUrl` instead.
Future<PhotoChoice?> chooseProfilePhoto(
  BuildContext context, {
  required bool hasPhoto,
  ImagePicker? picker,
}) async {
  final imagePicker = picker ?? ImagePicker();
  final canUseCamera = imagePicker.supportsImageSource(ImageSource.camera);

  final action = await showModalBottomSheet<_Action>(
    context: context,
    showDragHandle: true,
    backgroundColor: McMapColors.white,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Profile photo', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from library'),
            onTap: () => Navigator.pop(context, _Action.library),
          ),
          if (canUseCamera)
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(context, _Action.camera),
            ),
          if (hasPhoto)
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: McMapColors.redStrong,
              ),
              title: const Text(
                'Remove current photo',
                style: TextStyle(color: McMapColors.redStrong),
              ),
              onTap: () => Navigator.pop(context, _Action.remove),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  switch (action) {
    case null:
      return null;
    case _Action.remove:
      return const PhotoRemoved();
    case _Action.library || _Action.camera:
      try {
        final file = await imagePicker.pickImage(
          source: action == _Action.camera
              ? ImageSource.camera
              : ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
          preferredCameraDevice: CameraDevice.front,
        );
        if (file == null) return null;
        return PhotoPicked(await file.readAsBytes());
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Couldn't open your photos. Check McMap's photo permission.",
              ),
            ),
          );
        }
        return null;
      }
  }
}
