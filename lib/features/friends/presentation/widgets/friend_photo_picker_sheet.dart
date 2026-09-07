import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/supabase_db_service.dart';
import '../../../../core/utils/image_utils.dart';

const List<String> kPresetAvatars = [
  'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
  'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
  'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=150',
  'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
  'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
  'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150',
  'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150',
  'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150',
];

/// Displays a bottom sheet allowing the user to select an avatar from presets,
/// take a photo, or choose from device gallery.
void showFriendPhotoPickerSheet({
  required BuildContext context,
  required Future<void> Function(String newUrl) onPhotoSelected,
  String? currentPhotoUrl,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return _FriendPhotoPickerContent(
        parentContext: context,
        currentPhotoUrl: currentPhotoUrl,
        onPhotoSelected: onPhotoSelected,
      );
    },
  );
}

class _FriendPhotoPickerContent extends StatefulWidget {
  final BuildContext parentContext;
  final String? currentPhotoUrl;
  final Future<void> Function(String newUrl) onPhotoSelected;

  const _FriendPhotoPickerContent({
    required this.parentContext,
    this.currentPhotoUrl,
    required this.onPhotoSelected,
  });

  @override
  State<_FriendPhotoPickerContent> createState() => _FriendPhotoPickerContentState();
}

class _FriendPhotoPickerContentState extends State<_FriendPhotoPickerContent> {
  Future<void> _pickAndUploadImage() async {
    final parentCtx = widget.parentContext;

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return; // User cancelled
      }

      final file = result.files.first;
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }

      if (bytes == null) {
        throw Exception('Could not read image file data.');
      }

      // Close bottom sheet now that image was selected
      if (mounted) {
        Navigator.pop(context);
      }

      if (!parentCtx.mounted) return;

      // Show upload progress dialog on parent context
      showDialog(
        context: parentCtx,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Row(
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryColor),
                  SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      'Updating Profile Picture...',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      try {
        final ext = (file.extension ?? 'jpg').toLowerCase();
        String mimeType = 'image/jpeg';
        if (ext == 'png') {
          mimeType = 'image/png';
        } else if (ext == 'webp') {
          mimeType = 'image/webp';
        } else if (ext == 'gif') {
          mimeType = 'image/gif';
        }

        String finalUrl;
        if (SupabaseDbService.isConfigured) {
          final uploadedUrl = await SupabaseDbService.uploadFile(
            'friend-photos',
            file.name,
            bytes,
            mimeType: mimeType,
          );
          if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
            finalUrl = uploadedUrl;
          } else if (file.path != null && File(file.path!).existsSync()) {
            finalUrl = file.path!;
          } else {
            final base64String = base64Encode(bytes);
            finalUrl = 'data:$mimeType;base64,$base64String';
          }
        } else if (file.path != null && File(file.path!).existsSync()) {
          finalUrl = file.path!;
        } else {
          final base64String = base64Encode(bytes);
          finalUrl = 'data:$mimeType;base64,$base64String';
        }

        await widget.onPhotoSelected(finalUrl);
      } catch (e) {
        if (parentCtx.mounted) {
          ScaffoldMessenger.of(parentCtx).showSnackBar(
            SnackBar(
              content: Text('Error updating photo: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (parentCtx.mounted && Navigator.of(parentCtx, rootNavigator: true).canPop()) {
          Navigator.of(parentCtx, rootNavigator: true).pop();
        }
      }
    } catch (e) {
      if (parentCtx.mounted) {
        ScaffoldMessenger.of(parentCtx).showSnackBar(
          SnackBar(
            content: Text('Could not select image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Update Profile Picture',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSourceTile(
                  icon: Icons.camera_alt_rounded,
                  label: 'Take Photo',
                  onTap: _pickAndUploadImage,
                ),
                _buildSourceTile(
                  icon: Icons.photo_library_rounded,
                  label: 'From Gallery',
                  onTap: _pickAndUploadImage,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Select Preset Avatar',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 72,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: kPresetAvatars.length,
                itemBuilder: (context, index) {
                  final avatarUrl = kPresetAvatars[index];
                  final isSelected = widget.currentPhotoUrl == avatarUrl;
                  return GestureDetector(
                    onTap: () async {
                      Navigator.pop(context);
                      await widget.onPhotoSelected(avatarUrl);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 32,
                        backgroundImage: getAppImageProvider(avatarUrl),
                        onBackgroundImageError: (_, __) {},
                        child: getAppImageProvider(avatarUrl) == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 130,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              child: Icon(icon, color: AppTheme.primaryColor, size: 24),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
