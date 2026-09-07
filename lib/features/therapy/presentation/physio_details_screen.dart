import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/image_utils.dart';
import '../../friends/presentation/friends_provider.dart';
import '../../friends/models/friend.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../../core/services/supabase_db_service.dart';
import '../../../core/storage/hive_storage.dart';

class PhysioDetailsScreen extends ConsumerStatefulWidget {
  final String friendId;
  const PhysioDetailsScreen({super.key, required this.friendId});

  @override
  ConsumerState<PhysioDetailsScreen> createState() => _PhysioDetailsScreenState();
}

class _PhysioDetailsScreenState extends ConsumerState<PhysioDetailsScreen> {
  late String _selectedFriendId;
  bool _isLoading = true;
  String? _assessmentId;
  
  String _rom = '';
  String _strength = '';
  String _balance = '';
  String _mobility = '';

  List<String> _exercises = [];
  List<Map<String, dynamic>> _sessions = [];

  final TextEditingController _sessionNotesController = TextEditingController();
  final TextEditingController _durationController = TextEditingController(text: '30');
  int _performanceRating = 4;

  @override
  void initState() {
    super.initState();
    _selectedFriendId = widget.friendId;
    _loadFromDatabase(_selectedFriendId);
  }

  Future<void> _loadFromDatabase(String friendId) async {
    if (friendId == 'all') {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    // Load from local Hive cache first (Real data)
    final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
    final localSessions = box.get('physio_sessions_$friendId');
    if (localSessions is List && localSessions.isNotEmpty) {
      _sessions = List<Map<String, dynamic>>.from(localSessions.map((e) => Map<String, dynamic>.from(e as Map)));
    } else {
      _sessions = [];
    }

    final localExercises = box.get('physio_exercises_$friendId');
    if (localExercises is List && localExercises.isNotEmpty) {
      _exercises = List<String>.from(localExercises);
    } else {
      _exercises = [];
    }

    final localAssessment = box.get('physio_assessment_$friendId');
    if (localAssessment is Map) {
      _rom = localAssessment['range_of_motion'] ?? '';
      _strength = localAssessment['strength'] ?? '';
      _balance = localAssessment['balance'] ?? '';
      _mobility = localAssessment['mobility'] ?? '';
    } else {
      _rom = '';
      _strength = '';
      _balance = '';
      _mobility = '';
    }

    final data = await SupabaseDbService.fetchPhysioAssessment(friendId);
    if (data != null && mounted) {
      setState(() {
        _assessmentId = data['id'];
        _rom = data['range_of_motion'] ?? _rom;
        _strength = data['strength'] ?? _strength;
        _balance = data['balance'] ?? _balance;
        _mobility = data['mobility'] ?? _mobility;

        if (data['exercises'] is List && (data['exercises'] as List).isNotEmpty) {
          _exercises = List<String>.from(data['exercises']);
        }
        
        final List<dynamic> dbSessions = data['physiotherapy_sessions'] ?? [];
        if (dbSessions.isNotEmpty) {
          _sessions = dbSessions.map((s) => {
            'date': s['date']?.toString().substring(0, 10) ?? '',
            'duration': s['duration_minutes'] ?? 30,
            'rating': s['performance_rating'] ?? 4,
            'notes': s['notes'] ?? '',
          }).toList();
        }
        _isLoading = false;
      });

      // Synchronize cache
      await box.put('physio_sessions_$friendId', _sessions);
      await box.put('physio_exercises_$friendId', _exercises);
      await box.put('physio_assessment_$friendId', {
        'range_of_motion': _rom,
        'strength': _strength,
        'balance': _balance,
        'mobility': _mobility,
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _sessionNotesController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _editAssessment() {
    final romController = TextEditingController(text: _rom);
    final strController = TextEditingController(text: _strength);
    final balController = TextEditingController(text: _balance);
    final mobController = TextEditingController(text: _mobility);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Physio Assessment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: romController, decoration: const InputDecoration(labelText: 'Range of Motion (ROM)', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: strController, decoration: const InputDecoration(labelText: 'Muscle Strength', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: balController, decoration: const InputDecoration(labelText: 'Balance & Posture', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: mobController, decoration: const InputDecoration(labelText: 'Functional Mobility', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              setState(() {
                _rom = romController.text.trim();
                _strength = strController.text.trim();
                _balance = balController.text.trim();
                _mobility = mobController.text.trim();
              });
              Navigator.pop(context);

              final res = await SupabaseDbService.savePhysioAssessment(
                _selectedFriendId,
                romController.text.trim(),
                strController.text.trim(),
                balController.text.trim(),
                mobController.text.trim(),
              );
              if (res.containsKey('id')) _assessmentId = res['id'];

              // Sync assessment to Hive
              final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
              await box.put('physio_assessment_$_selectedFriendId', {
                'range_of_motion': _rom,
                'strength': _strength,
                'balance': _balance,
                'mobility': _mobility,
              });

              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Physiotherapy assessment saved.'), backgroundColor: AppTheme.successColor),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddExerciseDialog() {
    final titleController = TextEditingController();
    final targetController = TextEditingController(text: '3 sets of 10 reps');
    String category = 'Mobility & Range';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.fitness_center, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Text('Add Custom Therapy Activity', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Activity / Exercise Name *',
                    hintText: 'e.g. Ankle dorsiflexion, Bilateral squats, Gait training...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetController,
                  decoration: const InputDecoration(
                    labelText: 'Target / Reps / Duration',
                    hintText: 'e.g. 15 mins, 2 sets of 8 reps, 20 steps...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(
                    labelText: 'Therapy Focus Area',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Mobility & Range', child: Text('Mobility & Range (ROM)')),
                    DropdownMenuItem(value: 'Muscle Strengthening', child: Text('Muscle Strengthening')),
                    DropdownMenuItem(value: 'Balance & Posture', child: Text('Balance & Posture')),
                    DropdownMenuItem(value: 'Gait & Ambulation', child: Text('Gait & Ambulation')),
                    DropdownMenuItem(value: 'Coordination & Motor', child: Text('Coordination & Motor')),
                    DropdownMenuItem(value: 'Stretching & Flexibility', child: Text('Stretching & Flexibility')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => category = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Activity'),
              onPressed: () async {
                final title = titleController.text.trim();
                final target = targetController.text.trim();
                if (title.isEmpty) return;

                final entry = '$title (${target.isNotEmpty ? target : 'Standard'}) • $category';
                setState(() {
                  _exercises.add(entry);
                });
                Navigator.pop(ctx);

                // Save to Hive
                final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
                await box.put('physio_exercises_$_selectedFriendId', _exercises);

                // Save to Supabase
                if (SupabaseDbService.isConfigured) {
                  if (_assessmentId == null) {
                    final res = await SupabaseDbService.savePhysioAssessment(_selectedFriendId, _rom, _strength, _balance, _mobility);
                    if (res.containsKey('id')) _assessmentId = res['id'];
                  }
                  if (_assessmentId != null) {
                    await SupabaseDbService.updatePhysioExercises(_assessmentId!, _exercises);
                  }
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added exercise: $title'), backgroundColor: AppTheme.successColor),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _removeExercise(int index) async {
    final removed = _exercises[index];
    setState(() {
      _exercises.removeAt(index);
    });

    final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
    await box.put('physio_exercises_$_selectedFriendId', _exercises);

    if (_assessmentId != null && SupabaseDbService.isConfigured) {
      await SupabaseDbService.updatePhysioExercises(_assessmentId!, _exercises);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed "$removed"'), backgroundColor: Colors.grey.shade700),
      );
    }
  }

  void _saveSession() async {
    final duration = int.tryParse(_durationController.text.trim()) ?? 30;
    final notes = _sessionNotesController.text.trim();
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    final newEntry = {
      'date': todayStr,
      'duration': duration,
      'rating': _performanceRating,
      'notes': notes,
    };

    setState(() {
      _sessions.insert(0, newEntry);
      _sessionNotesController.clear();
    });

    // Save to Hive
    final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
    await box.put('physio_sessions_$_selectedFriendId', _sessions);

    // Save to Supabase
    if (SupabaseDbService.isConfigured) {
      if (_assessmentId == null) {
        final res = await SupabaseDbService.savePhysioAssessment(_selectedFriendId, _rom, _strength, _balance, _mobility);
        if (res.containsKey('id')) _assessmentId = res['id'];
      }
      if (_assessmentId != null) {
        await SupabaseDbService.addPhysioSession(_assessmentId!, duration, _performanceRating, notes);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Physiotherapy session recorded successfully.'), backgroundColor: AppTheme.successColor),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);
    final user = ref.read(authProvider).user;
    final isPhysio = user?.role == 'physiotherapist';
    final isPrincipalOrAdmin = user?.role == 'principal' || user?.role == 'admin';
    final canEditPhysio = isPhysio;

    Friend? currentFriend;
    if (_selectedFriendId != 'all') {
      currentFriend = friends.where((f) => f.id == _selectedFriendId).firstOrNull ?? (friends.isNotEmpty ? friends.first : null);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Physiotherapy Dossier'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go(isPhysio ? '/dashboard/physio' : '/dashboard/principal');
            }
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Role Status Banner
                  _buildRoleBanner(isPhysio, isPrincipalOrAdmin, user?.fullName ?? 'User'),
                  const SizedBox(height: 16),

                  // Beneficiary Selector
                  Card(
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Select Beneficiary Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _selectedFriendId == 'all' && friends.isNotEmpty ? friends.first.id : _selectedFriendId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: friends.map((f) {
                              final provider = getAppImageProvider(f.photoUrl);
                              return DropdownMenuItem(
                                value: f.id,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundImage: provider,
                                      child: provider == null ? Text(f.fullName[0], style: const TextStyle(fontSize: 10)) : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(f.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 6),
                                    Text('(${f.registrationNumber})', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedFriendId = val);
                                _loadFromDatabase(val);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (currentFriend != null) ...[
                    // Friend Info Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundImage: getAppImageProvider(currentFriend.photoUrl),
                              backgroundColor: Colors.teal.withValues(alpha: 0.1),
                              child: getAppImageProvider(currentFriend.photoUrl) == null
                                  ? Text(currentFriend.fullName[0], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal))
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(currentFriend.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ID: ${currentFriend.registrationNumber} • House: ${currentFriend.assignedHouseId.replaceAll('_', ' ').toUpperCase()}',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Physical Assessment Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.accessibility_new, color: AppTheme.primaryColor),
                                    SizedBox(width: 8),
                                    Text('Physical Assessment Parameters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                                if (canEditPhysio)
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: AppTheme.primaryColor),
                                    tooltip: 'Edit Parameters',
                                    onPressed: _editAssessment,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_rom.isEmpty && _strength.isEmpty && _balance.isEmpty && _mobility.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12.0),
                                child: Column(
                                  children: [
                                    const Text('No physical assessment recorded yet for this beneficiary.', style: TextStyle(color: Colors.grey)),
                                    if (canEditPhysio) ...[
                                      const SizedBox(height: 10),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text('Record Assessment Parameters'),
                                        onPressed: _editAssessment,
                                      ),
                                    ],
                                  ],
                                ),
                              )
                            else ...[
                              _buildField('Range of Motion (ROM)', _rom.isNotEmpty ? _rom : 'Not recorded'),
                              _buildField('Muscle Strength', _strength.isNotEmpty ? _strength : 'Not recorded'),
                              _buildField('Balance & Posture', _balance.isNotEmpty ? _balance : 'Not recorded'),
                              _buildField('Functional Mobility', _mobility.isNotEmpty ? _mobility : 'Not recorded'),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Active Exercise Program (Tailored / Dynamic)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.fitness_center, color: Colors.teal),
                                    SizedBox(width: 8),
                                    Text('Tailored Activities & Exercises', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                                if (canEditPhysio)
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Add Activity', style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal,
                                      foregroundColor: Colors.white,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                    onPressed: _showAddExerciseDialog,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_exercises.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.directions_run_outlined, size: 40, color: Colors.grey.shade400),
                                      const SizedBox(height: 8),
                                      const Text('No custom therapy activities created yet.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                      if (canEditPhysio) ...[
                                        const SizedBox(height: 8),
                                        TextButton.icon(
                                          icon: const Icon(Icons.add, size: 16),
                                          label: const Text('Add Tailored Activity / Exercise'),
                                          onPressed: _showAddExerciseDialog,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _exercises.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, idx) {
                                  final ex = _exercises[idx];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check_circle, color: Colors.teal, size: 18),
                                        const SizedBox(width: 10),
                                        Expanded(child: Text(ex, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                                        if (canEditPhysio)
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                            tooltip: 'Remove Activity',
                                            onPressed: () => _removeExercise(idx),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Record Session (for Physiotherapist only)
                    if (canEditPhysio)
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Record Therapy Session', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 14),
                              if (_exercises.isNotEmpty) ...[
                                const Text('Select activities completed in this session:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: _exercises.map((ex) {
                                    final shortName = ex.split('(').first.trim();
                                    return ActionChip(
                                      avatar: const Icon(Icons.add, size: 14, color: Colors.teal),
                                      label: Text(shortName, style: const TextStyle(fontSize: 11)),
                                      backgroundColor: Colors.teal.shade50,
                                      onPressed: () {
                                        final current = _sessionNotesController.text;
                                        if (!current.contains(shortName)) {
                                          _sessionNotesController.text = current.isEmpty ? 'Completed $shortName.' : '$current Completed $shortName.';
                                        }
                                      },
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 14),
                              ],
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _durationController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: 'Duration (Minutes)', border: OutlineInputBorder()),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: DropdownButtonFormField<int>(
                                      value: _performanceRating,
                                      decoration: const InputDecoration(labelText: 'Performance Rating', border: OutlineInputBorder()),
                                      items: const [
                                        DropdownMenuItem(value: 5, child: Text('5 - Excellent')),
                                        DropdownMenuItem(value: 4, child: Text('4 - Good')),
                                        DropdownMenuItem(value: 3, child: Text('3 - Moderate')),
                                        DropdownMenuItem(value: 2, child: Text('2 - Struggled')),
                                        DropdownMenuItem(value: 1, child: Text('1 - Refused')),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) setState(() => _performanceRating = val);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _sessionNotesController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: 'Clinical Session Notes',
                                  hintText: 'Describe response to exercises, gait balance, improvements...',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.save),
                                label: const Text('Save Therapy Session'),
                                onPressed: _saveSession,
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Session History Log (Visible to both Principal and Physio!)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Physiotherapy Session Logs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 14),
                            if (_sessions.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('No therapy sessions recorded yet for this beneficiary.', style: TextStyle(color: Colors.grey)),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _sessions.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final s = _sessions[index];
                                  final rating = s['rating'] ?? 4;
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                                    leading: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Colors.teal.shade100,
                                      child: Text('${s['duration']}m', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
                                    ),
                                    title: Text('Session on ${s['date']} (Rating: $rating/5)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    subtitle: Text(s['notes']?.toString() ?? '', style: const TextStyle(fontSize: 12)),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildRoleBanner(bool isPhysio, bool isPrincipalOrAdmin, String userName) {
    if (isPhysio) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.teal.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.accessibility_new, color: Colors.teal.shade700, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Signed in as Physiotherapist ($userName). You have full authorization to record therapy sessions and modify assessments.',
                style: TextStyle(color: Colors.teal.shade900, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined, color: Color(0xFF1D4ED8), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Principal / Administrative Oversight Console (Read-Only Mode)',
                  style: TextStyle(color: Color(0xFF1E3A8A), fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Reviewing physical assessment progress, range of motion, muscle strength, and clinical therapy session histories.',
                  style: TextStyle(color: Colors.blueGrey.shade800, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFF1E40AF), borderRadius: BorderRadius.circular(20)),
            child: const Text('READ ONLY', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(val, style: const TextStyle(fontSize: 14)),
          const Divider(),
        ],
      ),
    );
  }
}
