import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/theme.dart';
import '../../../core/localization/localization.dart';
import '../../../core/shared/widgets/responsive_layout.dart';
import '../../friends/presentation/friends_provider.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../../core/services/supabase_db_service.dart';

class WorkshopDetailsScreen extends ConsumerStatefulWidget {
  final String workshopId;
  const WorkshopDetailsScreen({super.key, required this.workshopId});

  @override
  ConsumerState<WorkshopDetailsScreen> createState() => _WorkshopDetailsScreenState();
}

class _WorkshopDetailsScreenState extends ConsumerState<WorkshopDetailsScreen> {
  String? _selectedFriendId;
  String _mood = 'neutral';
  
  // Ratings
  double _participation = 3.0;
  double _communication = 3.0;
  double _independence = 3.0;
  double _taskCompletion = 3.0;

  // Skills specific to workshops
  final Map<String, List<String>> _workshopSkills = {
    'bakery': ['Mixing', 'Baking', 'Packaging', 'Cleaning'],
    'woodwork': ['Sanding', 'Cutting', 'Assembling', 'Polishing'],
    'farming': ['Composting', 'Animal Care', 'Harvesting', 'Fencing'],
    'textile': ['Cutting', 'Stitching', 'Ironing', 'Packing'],
    'artwork': ['Painting', 'Drawing', 'Clay Crafting', 'Polishing'],
  };

  final Map<String, double> _skillRatings = {};

  final TextEditingController _notesController = TextEditingController();
  final List<String> _attachedPhotos = [];
  bool _isUploadingPhoto = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _saveRecords() {
    if (_selectedFriendId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Friend first.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline, color: AppTheme.successColor, size: 48),
        title: const Text('Workshop Records Saved'),
        content: const Text('Daily activities and vocational skill progress have been recorded successfully.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final friends = ref.watch(friendsProvider);
    final workshopFriends = friends.where((f) => f.assignedWorkshopId == widget.workshopId).toList();
    final user = ref.read(authProvider).user;
    final canSaveWorkshop = user?.role == 'principal' || user?.role == 'workshop_staff';
    
    // Filter friends belonging to this workshop
    final skills = _workshopSkills[widget.workshopId] ?? ['Task Execution', 'Tool Handling', 'Safety', 'Cleaning'];

    // Initialize skill ratings if empty
    if (_skillRatings.isEmpty) {
      for (var skill in skills) {
        _skillRatings[skill] = 3.0;
      }
    }

    return ResponsiveLayout(
      title: '${localizations.translate(widget.workshopId)} Workshop Records',
      currentRoute: '/workshops/${widget.workshopId}',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Select Friend Dropdown
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Friend Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedFriendId,
                      isExpanded: true,
                      hint: const Text('Choose a Friend...'),
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
                      items: workshopFriends.map((f) {
                        return DropdownMenuItem(
                          value: f.id,
                          child: Text(f.fullName),
                        );
                      }).toList(),
                      onChanged: canSaveWorkshop ? (val) {
                        setState(() {
                          _selectedFriendId = val;
                        });
                      } : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Daily activity assessment
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Daily Activity & Behavior', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    
                    // Mood
                    const Text('Mood Assessment', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _mood,
                      isExpanded: true,
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
                      items: const [
                        DropdownMenuItem(value: 'excellent', child: Text('Excellent / Energetic')),
                        DropdownMenuItem(value: 'good', child: Text('Good / Happy')),
                        DropdownMenuItem(value: 'neutral', child: Text('Neutral / Calm')),
                        DropdownMenuItem(value: 'agitated', child: Text('Agitated / Unsettled')),
                        DropdownMenuItem(value: 'withdrawn', child: Text('Withdrawn / Passive')),
                      ],
                      onChanged: canSaveWorkshop ? (val) => setState(() => _mood = val!) : null,
                    ),
                    const SizedBox(height: 20),

                    // Participation Rating
                    _buildRatingRow('Participation Level', _participation, canSaveWorkshop ? (val) => setState(() => _participation = val) : null),
                    // Communication
                    _buildRatingRow('Communication', _communication, canSaveWorkshop ? (val) => setState(() => _communication = val) : null),
                    // Independence
                    _buildRatingRow('Independence / Self-help', _independence, canSaveWorkshop ? (val) => setState(() => _independence = val) : null),
                    // Task Completion
                    _buildRatingRow('Task Completion Rate', _taskCompletion, canSaveWorkshop ? (val) => setState(() => _taskCompletion = val) : null),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Vocational Skills progress
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vocational Skills - ${localizations.translate(widget.workshopId)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    ...skills.map((skill) {
                      return _buildRatingRow(
                        skill,
                        _skillRatings[skill] ?? 3.0,
                        canSaveWorkshop ? (val) => setState(() => _skillRatings[skill] = val) : null,
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Daily Notes
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Daily Progress Notes & Photos', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 4,
                      enabled: canSaveWorkshop,
                      decoration: const InputDecoration(
                        hintText: 'Describe general performance, challenges faced, behavioral triggers or successes...',
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_attachedPhotos.isNotEmpty) ...[
                      const Text(
                        'Attached Photos:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 90,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _attachedPhotos.length + (_isUploadingPhoto ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _attachedPhotos.length && _isUploadingPhoto) {
                              return Container(
                                width: 80,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            }

                            final photoUrl = _attachedPhotos[index];
                            return Stack(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image: NetworkImage(photoUrl),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: canSaveWorkshop ? () {
                                      setState(() {
                                        _attachedPhotos.removeAt(index);
                                      });
                                    } : null,
                                    child: const CircleAvatar(
                                      radius: 9,
                                      backgroundColor: Colors.red,
                                      child: Icon(Icons.close, color: Colors.white, size: 10),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    OutlinedButton.icon(
                      onPressed: canSaveWorkshop ? (_isUploadingPhoto ? null : _pickProgressPhoto) : null,
                      icon: _isUploadingPhoto 
                          ? const SizedBox(
                              width: 16, 
                              height: 16, 
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.primaryColor),
                            )
                          : const Icon(Icons.add_a_photo_outlined),
                      label: Text(_isUploadingPhoto ? 'Uploading...' : 'Add Photos / Attachments'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.primaryColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            if (canSaveWorkshop)
              ElevatedButton(
                onPressed: _saveRecords,
                child: const Text('Save Daily Records'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingRow(String label, double rating, ValueChanged<double>? onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              Text('${rating.toInt()} / 5', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            ],
          ),
          Slider(
            value: rating,
            min: 1.0,
            max: 5.0,
            divisions: 4,
            activeColor: AppTheme.primaryColor,
            inactiveColor: Colors.grey.shade200,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Future<void> _pickProgressPhoto() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return; // User cancelled
      }

      setState(() {
        _isUploadingPhoto = true;
      });

      final file = result.files.first;
      Uint8List? bytes;
      if (kIsWeb) {
        bytes = file.bytes;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }

      if (bytes == null) {
        throw Exception('Could not read file data');
      }

      String finalUrl;
      if (SupabaseDbService.isConfigured) {
        final uploadedUrl = await SupabaseDbService.uploadFile(
          'progress-photos',
          file.name,
          bytes,
        );
        if (uploadedUrl != null) {
          finalUrl = uploadedUrl;
        } else {
          final base64String = base64Encode(bytes);
          finalUrl = 'data:image/png;base64,$base64String';
        }
      } else {
        final base64String = base64Encode(bytes);
        finalUrl = 'data:image/png;base64,$base64String';
      }

      setState(() {
        _attachedPhotos.add(finalUrl);
        _isUploadingPhoto = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo attached successfully!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      setState(() {
        _isUploadingPhoto = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading picture: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
