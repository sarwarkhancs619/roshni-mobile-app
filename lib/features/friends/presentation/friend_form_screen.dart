import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/theme.dart';
import '../../../core/localization/localization.dart';
import '../models/friend.dart';
import 'friends_provider.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../../core/services/supabase_db_service.dart';

class FriendFormScreen extends ConsumerStatefulWidget {
  final String? friendId;
  const FriendFormScreen({super.key, this.friendId});

  @override
  ConsumerState<FriendFormScreen> createState() => _FriendFormScreenState();
}

class _FriendFormScreenState extends ConsumerState<FriendFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _photoController;
  late TextEditingController _cnicController;
  late TextEditingController _guardianNameController;
  late TextEditingController _guardianRelationController;
  late TextEditingController _guardianPhoneController;
  late TextEditingController _guardianEmailController;
  late TextEditingController _guardianAddressController;
  late TextEditingController _emergencyNameController;
  late TextEditingController _emergencyRelationController;
  late TextEditingController _emergencyPhoneController;
  late TextEditingController _medicalSummaryController;

  // Non-controller state fields
  DateTime _dob = DateTime(2000, 1, 1);
  DateTime _admissionDate = DateTime.now();
  String _gender = 'male';
  String _bloodGroup = 'A+';
  String _assignedWorkshop = 'bakery';
  String _assignedHouse = 'amin_house';
  String _status = 'active';

  bool _isEdit = false;
  bool _accessDenied = false;

  @override
  void initState() {
    super.initState();
    _isEdit = widget.friendId != null;

    // Default initializing values
    _nameController = TextEditingController();
    _photoController = TextEditingController(text: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150');
    _cnicController = TextEditingController();
    _guardianNameController = TextEditingController();
    _guardianRelationController = TextEditingController();
    _guardianPhoneController = TextEditingController();
    _guardianEmailController = TextEditingController();
    _guardianAddressController = TextEditingController();
    _emergencyNameController = TextEditingController();
    _emergencyRelationController = TextEditingController();
    _emergencyPhoneController = TextEditingController();
    _medicalSummaryController = TextEditingController();

    // Check auth details
    final user = ref.read(authProvider).user;
    if (user == null || user.role != 'principal') {
      _accessDenied = true;
    } else {
      if (user.role == 'workshop_staff') {
        _assignedWorkshop = user.workshopId ?? 'bakery';
      } else if (user.role == 'house_staff') {
        _assignedHouse = user.workshopId ?? 'amin_house';
      }
    }

    if (_isEdit) {
      // Find the existing friend and populate controllers safely
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final friends = ref.read(visibleFriendsProvider);
        final friendIndex = friends.indexWhere((f) => f.id == widget.friendId);
        if (friendIndex == -1) {
          setState(() {
            _accessDenied = true;
          });
          return;
        }
        final friend = friends[friendIndex];
        setState(() {
          _nameController.text = friend.fullName;
          _photoController.text = friend.photoUrl;
          _cnicController.text = friend.cnicOrBForm ?? '';
          _guardianNameController.text = friend.guardianName;
          _guardianRelationController.text = friend.guardianRelation;
          _guardianPhoneController.text = friend.guardianPhone;
          _guardianEmailController.text = friend.guardianEmail;
          _guardianAddressController.text = friend.guardianAddress;
          _emergencyNameController.text = friend.emergencyName;
          _emergencyRelationController.text = friend.emergencyRelation;
          _emergencyPhoneController.text = friend.emergencyPhone;
          _medicalSummaryController.text = friend.medicalNotesSummary;

          _dob = friend.dateOfBirth;
          _admissionDate = friend.admissionDate;
          _gender = friend.gender;
          _bloodGroup = friend.bloodGroup;
          _assignedWorkshop = friend.assignedWorkshopId;
          _assignedHouse = friend.assignedHouseId;
          _status = friend.status;
        });
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _photoController.dispose();
    _cnicController.dispose();
    _guardianNameController.dispose();
    _guardianRelationController.dispose();
    _guardianPhoneController.dispose();
    _guardianEmailController.dispose();
    _guardianAddressController.dispose();
    _emergencyNameController.dispose();
    _emergencyRelationController.dispose();
    _emergencyPhoneController.dispose();
    _medicalSummaryController.dispose();
    super.dispose();
  }

  void _saveForm() {
    if (_formKey.currentState!.validate()) {
      final regId = _isEdit 
          ? widget.friendId! 
          : 'RAMS-2026-${(1000 + Random().nextInt(9000))}';

      final friend = Friend(
        id: regId,
        registrationNumber: regId,
        fullName: _nameController.text,
        photoUrl: _photoController.text,
        dateOfBirth: _dob,
        gender: _gender,
        bloodGroup: _bloodGroup,
        cnicOrBForm: _cnicController.text.isNotEmpty ? _cnicController.text : null,
        admissionDate: _admissionDate,
        assignedWorkshopId: _assignedWorkshop,
        assignedHouseId: _assignedHouse,
        status: _status,
        guardianName: _guardianNameController.text,
        guardianRelation: _guardianRelationController.text,
        guardianPhone: _guardianPhoneController.text,
        guardianEmail: _guardianEmailController.text,
        guardianAddress: _guardianAddressController.text,
        emergencyName: _emergencyNameController.text,
        emergencyRelation: _emergencyRelationController.text,
        emergencyPhone: _emergencyPhoneController.text,
        medicalNotesSummary: _medicalSummaryController.text,
      );

      if (_isEdit) {
        ref.read(friendsProvider.notifier).updateFriend(friend);
      } else {
        ref.read(friendsProvider.notifier).addFriend(friend);
      }

      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isWorkshopStaff = user?.role == 'workshop_staff';

    if (_accessDenied) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Access Denied: You do not have permission to edit this friend.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Friend Profile' : 'Add Friend Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveForm,
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Personal Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
            ),
            const SizedBox(height: 16),
            
            // Name Field
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Profile Picture Picker & Preview
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 64,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    backgroundImage: NetworkImage(_photoController.text),
                    onBackgroundImageError: (_, __) {
                      // Fallback icon if image fails to load
                    },
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      backgroundColor: AppTheme.primaryColor,
                      radius: 20,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                        onPressed: () {
                          _showImageSourceBottomSheet(context);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () => _showImageSourceBottomSheet(context),
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Update Profile Picture'),
              ),
            ),
            const SizedBox(height: 24),


            // Date of birth
            ListTile(
              title: const Text('Date of Birth'),
              subtitle: Text('${_dob.day}/${_dob.month}/${_dob.year}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _dob,
                  firstDate: DateTime(1960),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() {
                    _dob = date;
                  });
                }
              },
            ),
            const Divider(),

            // Admission Date
            ListTile(
              title: const Text('Admission Date'),
              subtitle: Text('${_admissionDate.day}/${_admissionDate.month}/${_admissionDate.year}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _admissionDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() {
                    _admissionDate = date;
                  });
                }
              },
            ),
            const Divider(),

            // Gender & Blood Group
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _gender,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Gender'),
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                    ],
                    onChanged: (val) => setState(() => _gender = val!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _bloodGroup,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Blood Group'),
                    items: const [
                      DropdownMenuItem(value: 'A+', child: Text('A+')),
                      DropdownMenuItem(value: 'A-', child: Text('A-')),
                      DropdownMenuItem(value: 'B+', child: Text('B+')),
                      DropdownMenuItem(value: 'B-', child: Text('B-')),
                      DropdownMenuItem(value: 'O+', child: Text('O+')),
                      DropdownMenuItem(value: 'O-', child: Text('O-')),
                      DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                      DropdownMenuItem(value: 'AB-', child: Text('AB-')),
                    ],
                    onChanged: (val) => setState(() => _bloodGroup = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // CNIC
            TextFormField(
              controller: _cnicController,
              decoration: const InputDecoration(
                labelText: 'CNIC / B-Form (Optional)',
                prefixIcon: Icon(Icons.credit_card),
              ),
            ),
            const SizedBox(height: 16),

            // Workshop selection / display
            if (isWorkshopStaff)
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Assigned Workshop'),
                child: Text(localizations.translate(user?.workshopId ?? '')),
              )
            else
              DropdownButtonFormField<String>(
                value: _assignedWorkshop,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Assigned Workshop'),
                items: [
                  DropdownMenuItem(value: 'bakery', child: Text(localizations.translate('bakery'))),
                  DropdownMenuItem(value: 'woodwork', child: Text(localizations.translate('woodwork'))),
                  DropdownMenuItem(value: 'farming', child: Text(localizations.translate('farming'))),
                  DropdownMenuItem(value: 'textile', child: Text(localizations.translate('textile'))),
                  DropdownMenuItem(value: 'artwork', child: Text(localizations.translate('artwork'))),
                ],
                onChanged: (val) => setState(() => _assignedWorkshop = val!),
              ),
            const SizedBox(height: 16),

            // House selection / display
            if (user?.role == 'house_staff')
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Assigned House'),
                child: Text(localizations.translate(user?.workshopId ?? '')),
              )
            else
              DropdownButtonFormField<String>(
                value: _assignedHouse,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Assigned House'),
                items: [
                  DropdownMenuItem(value: 'amin_house', child: Text(localizations.translate('amin_house'))),
                  DropdownMenuItem(value: 'roshni_house', child: Text(localizations.translate('roshni_house'))),
                ],
                onChanged: (val) => setState(() => _assignedHouse = val!),
              ),
            const SizedBox(height: 24),

            // Guardian Information
            Text(
              'Guardian Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _guardianNameController,
              decoration: const InputDecoration(labelText: 'Guardian Name', prefixIcon: Icon(Icons.family_restroom)),
              validator: (value) => value!.isEmpty ? 'Enter guardian name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _guardianRelationController,
              decoration: const InputDecoration(labelText: 'Relation', prefixIcon: Icon(Icons.people)),
              validator: (value) => value!.isEmpty ? 'Enter relation' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _guardianPhoneController,
              decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone)),
              validator: (value) => value!.isEmpty ? 'Enter phone number' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _guardianEmailController,
              decoration: const InputDecoration(labelText: 'Email Address (Optional)', prefixIcon: Icon(Icons.email)),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _guardianAddressController,
              decoration: const InputDecoration(labelText: 'Residential Address', prefixIcon: Icon(Icons.home)),
              validator: (value) => value!.isEmpty ? 'Enter address' : null,
            ),
            const SizedBox(height: 24),

            // Emergency Contacts
            Text(
              'Emergency Contact Details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emergencyNameController,
              decoration: const InputDecoration(labelText: 'Emergency Contact Person', prefixIcon: Icon(Icons.contact_phone)),
              validator: (value) => value!.isEmpty ? 'Enter contact person' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emergencyRelationController,
              decoration: const InputDecoration(labelText: 'Relation', prefixIcon: Icon(Icons.people)),
              validator: (value) => value!.isEmpty ? 'Enter relation' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emergencyPhoneController,
              decoration: const InputDecoration(labelText: 'Emergency Phone Number', prefixIcon: Icon(Icons.phone)),
              validator: (value) => value!.isEmpty ? 'Enter emergency phone' : null,
            ),
            const SizedBox(height: 24),

            // Medical Notes Summary
            Text(
              'Medical Notes Summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _medicalSummaryController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Critical medical alerts, allergies, or cognitive notes...',
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _saveForm,
              child: Text(_isEdit ? 'Save Changes' : 'Register Friend Profile'),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageSourceBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final presets = [
          'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150',
          'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150',
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
          'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=150',
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
          'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=150',
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
        ];

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Update Profile Picture',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSourceTile(
                      icon: Icons.camera_alt_rounded,
                      label: 'Take Photo',
                      onTap: () {
                        Navigator.pop(context);
                        _startImageUpload('Camera');
                      },
                    ),
                    _buildSourceTile(
                      icon: Icons.photo_library_rounded,
                      label: 'From Gallery',
                      onTap: () {
                        Navigator.pop(context);
                        _startImageUpload('Gallery');
                      },
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
                  height: 70,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: presets.length,
                    itemBuilder: (context, index) {
                      final isSelected = _photoController.text == presets[index];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _photoController.text = presets[index];
                          });
                          Navigator.pop(context);
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
                            radius: 30,
                            backgroundImage: NetworkImage(presets[index]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSourceTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 28),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Future<void> _startImageUpload(String source) async {
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
      Uint8List? bytes;
      if (kIsWeb) {
        bytes = file.bytes;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }

      if (bytes == null) {
        throw Exception('Could not read file data');
      }

      // Show upload progress dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              double progress = 0.0;
              String status = 'Preparing upload...';

              void runUpload() async {
                try {
                  setDialogState(() {
                    progress = 0.2;
                    status = 'Reading image...';
                  });
                  await Future.delayed(const Duration(milliseconds: 300));

                  setDialogState(() {
                    progress = 0.5;
                    status = 'Uploading to storage...';
                  });

                  String finalUrl;
                  if (SupabaseDbService.isConfigured) {
                    final uploadedUrl = await SupabaseDbService.uploadFile(
                      'friend-photos',
                      file.name,
                      bytes!,
                    );
                    if (uploadedUrl != null) {
                      finalUrl = uploadedUrl;
                    } else {
                      final base64String = base64Encode(bytes!);
                      finalUrl = 'data:image/png;base64,$base64String';
                    }
                  } else {
                    final base64String = base64Encode(bytes!);
                    finalUrl = 'data:image/png;base64,$base64String';
                  }

                  setDialogState(() {
                    progress = 0.8;
                    status = 'Caching image...';
                  });
                  await Future.delayed(const Duration(milliseconds: 300));

                  setDialogState(() {
                    progress = 1.0;
                    status = 'Finished!';
                  });
                  await Future.delayed(const Duration(milliseconds: 200));

                  setState(() {
                    _photoController.text = finalUrl;
                  });

                  if (!context.mounted) return;
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile picture updated successfully!'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error uploading picture: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }

              // Start the upload sequence once dialog is built
              Future.microtask(runUpload);

              return AlertDialog(
                title: const Text('Uploading Profile Picture'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(status),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: progress,
                      color: AppTheme.primaryColor,
                      backgroundColor: Colors.grey.shade100,
                    ),
                    const SizedBox(height: 8),
                    Text('${(progress * 100).toInt()}%'),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting picture: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
