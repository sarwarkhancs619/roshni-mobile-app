import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:math';
import '../../../core/theme/theme.dart';
import '../../../core/localization/localization.dart';
import '../../../core/utils/image_utils.dart';
import '../models/friend.dart';
import 'friends_provider.dart';
import 'widgets/friend_photo_picker_sheet.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../../core/services/supabase_db_service.dart';
import '../../../core/storage/hive_storage.dart';

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

  // Individual Plan (IP / IEP) Controllers
  late TextEditingController _baselineController;
  late TextEditingController _iepGoalTitleController;
  late TextEditingController _iepGoalObjectivesController;
  late TextEditingController _iepGoalStrategiesController;
  DateTime _iepTargetDate = DateTime.now().add(const Duration(days: 90));

  // Non-controller state fields
  DateTime _dob = DateTime(2000, 1, 1);
  DateTime _admissionDate = DateTime.now();
  String _gender = 'male';
  String _bloodGroup = 'A+';
  String _assignedWorkshop = 'bakery';
  String _assignedHouse = 'sunbal_house';
  String _status = 'active';
  String _registrationNumber = '';

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

    // Initialize IP / IEP controllers
    _baselineController = TextEditingController(text: 'Initial assessment indicates strong physical mobility and eagerness to learn vocational tasks.');
    _iepGoalTitleController = TextEditingController(text: 'Vocational Skill Onboarding & Task Discipline');
    _iepGoalObjectivesController = TextEditingController(text: 'Demonstrate basic tool handling and workshop discipline with minimal prompts.');
    _iepGoalStrategiesController = TextEditingController(text: 'Pairing with peer mentor and step-by-step visual demonstration.');

    // Check auth details
    final user = ref.read(authProvider).user;
    if (user == null || (user.role != 'principal' && user.role != 'admin')) {
      _accessDenied = true;
    } else {
      if (user.role == 'workshop_staff') {
        _assignedWorkshop = user.workshopId ?? 'bakery';
      } else if (user.role == 'house_staff') {
        final house = user.workshopId;
        _assignedHouse = (house == 'amin_house' || house == null) ? 'sunbal_house' : house;
      }
    }

    if (_isEdit) {
      // Find the existing friend and populate controllers safely
      WidgetsBinding.instance.addPostFrameCallback((_) async {
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
          _registrationNumber = friend.registrationNumber;
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
          _assignedHouse = (friend.assignedHouseId == 'amin_house') ? 'sunbal_house' : friend.assignedHouseId;
          _status = friend.status;
        });

        // Populate existing IEP if available
        final iep = await SupabaseDbService.fetchIep(friend.id);
        if (iep != null && mounted) {
          setState(() {
            _baselineController.text = iep['baseline'] ?? _baselineController.text;
            final List<dynamic> goals = iep['iep_goals'] ?? [];
            if (goals.isNotEmpty) {
              _iepGoalTitleController.text = goals.first['title'] ?? '';
              _iepGoalObjectivesController.text = goals.first['objectives'] ?? '';
              _iepGoalStrategiesController.text = goals.first['strategies'] ?? '';
            }
          });
        }
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
    _baselineController.dispose();
    _iepGoalTitleController.dispose();
    _iepGoalObjectivesController.dispose();
    _iepGoalStrategiesController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (_formKey.currentState!.validate()) {
      final regId = _isEdit 
          ? widget.friendId! 
          : 'RAMS-2026-${(1000 + Random().nextInt(9000))}';
      final regNumber = _isEdit && _registrationNumber.isNotEmpty
          ? _registrationNumber
          : regId;

      final friend = Friend(
        id: regId,
        registrationNumber: regNumber,
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
        await ref.read(friendsProvider.notifier).updateFriend(friend);
      } else {
        await ref.read(friendsProvider.notifier).addFriend(friend);
      }

      // Save Individual Plan (IP / IEP)
      final baselineText = _baselineController.text.trim();
      final goalTitle = _iepGoalTitleController.text.trim();
      if (baselineText.isNotEmpty || goalTitle.isNotEmpty) {
        final baseline = baselineText.isNotEmpty ? baselineText : 'Initial developmental evaluation.';
        final iepId = await SupabaseDbService.getOrCreateIep(friend.id, baseline);

        final newGoal = {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'title': goalTitle.isNotEmpty ? goalTitle : 'Vocational & Social Integration',
          'objectives': _iepGoalObjectivesController.text.trim().isNotEmpty 
              ? _iepGoalObjectivesController.text.trim() 
              : 'Active engagement in assigned workshop tasks.',
          'strategies': _iepGoalStrategiesController.text.trim().isNotEmpty 
              ? _iepGoalStrategiesController.text.trim() 
              : 'Task sequencing with visual cues.',
          'target_date': _iepTargetDate.toIso8601String().split('T')[0],
          'progress_percentage': 0,
          'status': 'in_progress',
        };

        if (iepId.isNotEmpty && goalTitle.isNotEmpty) {
          await SupabaseDbService.saveIepGoal(
            iepId,
            newGoal['title'] as String,
            newGoal['objectives'] as String,
            newGoal['strategies'] as String,
            newGoal['target_date'] as String,
          );
        }

        // Cache locally in Hive
        final iepBox = HiveStorage.getBox(HiveStorage.iepBoxName);
        await iepBox.put(friend.id, {
          'id': iepId.isNotEmpty ? iepId : 'local_iep_${friend.id}',
          'friend_id': friend.id,
          'baseline': baseline,
          'iep_goals': [newGoal],
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit 
                ? 'Friend profile updated successfully.' 
                : 'Friend and Individual Plan (IP) created successfully.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.pop();
      }
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
                  GestureDetector(
                    onTap: _openPhotoPicker,
                    child: CircleAvatar(
                      key: ValueKey('form_avatar_${_photoController.text}'),
                      radius: 64,
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                      backgroundImage: getAppImageProvider(_photoController.text),
                      onBackgroundImageError: (_, __) {},
                      child: getAppImageProvider(_photoController.text) == null
                          ? const Icon(Icons.person, size: 64, color: Colors.grey)
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      backgroundColor: AppTheme.primaryColor,
                      radius: 20,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                        onPressed: _openPhotoPicker,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: _openPhotoPicker,
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
                  DropdownMenuItem(value: 'sunbal_house', child: Text(localizations.translate('sunbal_house'))),
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
            const SizedBox(height: 24),

            // Individual Plan (IP / IEP) Setup Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F7FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBDEFB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.school, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Individual Plan (IP / IEP) Setup',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Setup the initial developmental baseline and first vocational goal for this beneficiary:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFCBD5E1) : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Baseline
                  TextFormField(
                    controller: _baselineController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Developmental Baseline Notes',
                      hintText: 'Describe physical, behavioral, and sensory baseline...',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Initial Goal Title
                  TextFormField(
                    controller: _iepGoalTitleController,
                    decoration: const InputDecoration(
                      labelText: 'Initial IP Goal Title',
                      hintText: 'e.g., Tool handling and workshop safety',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Objectives
                  TextFormField(
                    controller: _iepGoalObjectivesController,
                    decoration: const InputDecoration(
                      labelText: 'Goal Objectives',
                      hintText: 'e.g., Complete daily routine tasks with minimal assistance',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Strategies
                  TextFormField(
                    controller: _iepGoalStrategiesController,
                    decoration: const InputDecoration(
                      labelText: 'Strategies & Support',
                      hintText: 'e.g., Pair with peer mentor, use step-by-step visual cards',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Target Date
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF475569) : Colors.grey.shade300,
                      ),
                    ),
                    leading: Icon(
                      Icons.calendar_month,
                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF60A5FA) : AppTheme.primaryColor,
                    ),
                    title: const Text('Target Completion Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text('${_iepTargetDate.day}/${_iepTargetDate.month}/${_iepTargetDate.year}'),
                    trailing: const Icon(Icons.arrow_drop_down),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _iepTargetDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                      );
                      if (picked != null) {
                        setState(() {
                          _iepTargetDate = picked;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _saveForm,
              child: Text(_isEdit ? 'Save Changes' : 'Register Friend Profile & IP'),
            ),
          ],
        ),
      ),
    );
  }

  void _openPhotoPicker() {
    showFriendPhotoPickerSheet(
      context: context,
      currentPhotoUrl: _photoController.text,
      onPhotoSelected: (newUrl) async {
        setState(() {
          _photoController.text = newUrl;
        });

        // If editing an existing friend, save immediately to database and cache
        if (_isEdit && widget.friendId != null) {
          final allFriends = ref.read(friendsProvider);
          final existingIdx = allFriends.indexWhere((f) => f.id == widget.friendId);
          if (existingIdx != -1) {
            final updated = allFriends[existingIdx].copyWith(photoUrl: newUrl);
            await ref.read(friendsProvider.notifier).updateFriend(updated);
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully!'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      },
    );
  }
}
