import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/image_utils.dart';
import '../../friends/presentation/friends_provider.dart';
import '../../friends/models/friend.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../../core/services/supabase_db_service.dart';
import '../../../core/storage/hive_storage.dart';

class SpeechDetailsScreen extends ConsumerStatefulWidget {
  final String friendId;
  const SpeechDetailsScreen({super.key, required this.friendId});

  @override
  ConsumerState<SpeechDetailsScreen> createState() => _SpeechDetailsScreenState();
}

class _SpeechDetailsScreenState extends ConsumerState<SpeechDetailsScreen> {
  late String _selectedFriendId;
  bool _isLoading = true;
  String? _assessmentId;

  String _speech = '';
  String _receptive = '';
  String _goals = '';
  List<String> _activities = [];
  List<Map<String, dynamic>> _sessions = [];

  final TextEditingController _sessionNotesController = TextEditingController();
  final TextEditingController _progressController = TextEditingController();

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

    // Load from local Hive first (Real data)
    final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
    final localSessions = box.get('speech_sessions_$friendId');
    if (localSessions is List && localSessions.isNotEmpty) {
      _sessions = List<Map<String, dynamic>>.from(localSessions.map((e) => Map<String, dynamic>.from(e as Map)));
    } else {
      _sessions = [];
    }

    final localActivities = box.get('speech_activities_$friendId');
    if (localActivities is List && localActivities.isNotEmpty) {
      _activities = List<String>.from(localActivities);
    } else {
      _activities = [];
    }

    final localAssessment = box.get('speech_assessment_$friendId');
    if (localAssessment is Map) {
      _speech = localAssessment['speech_skills'] ?? '';
      _receptive = localAssessment['language_development'] ?? '';
      _goals = localAssessment['communication_goals'] ?? '';
    } else {
      _speech = '';
      _receptive = '';
      _goals = '';
    }

    final data = await SupabaseDbService.fetchSpeechAssessment(friendId);
    if (data != null && mounted) {
      setState(() {
        _assessmentId = data['id'];
        _speech = data['speech_skills'] ?? _speech;
        _receptive = data['language_development'] ?? _receptive;
        _goals = data['communication_goals'] ?? _goals;

        if (data['activities'] is List && (data['activities'] as List).isNotEmpty) {
          _activities = List<String>.from(data['activities']);
        }

        final List<dynamic> dbSessions = data['speech_sessions'] ?? [];
        if (dbSessions.isNotEmpty) {
          _sessions = dbSessions.map((s) => {
            'date': s['date']?.toString().substring(0, 10) ?? '',
            'notes': s['notes'] ?? '',
            'progress': s['progress_description'] ?? '',
          }).toList();
        }
        _isLoading = false;
      });

      // Synchronize cache
      await box.put('speech_sessions_$friendId', _sessions);
      await box.put('speech_activities_$friendId', _activities);
      await box.put('speech_assessment_$friendId', {
        'speech_skills': _speech,
        'language_development': _receptive,
        'communication_goals': _goals,
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _sessionNotesController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _editAssessment() {
    final speechController = TextEditingController(text: _speech);
    final recController = TextEditingController(text: _receptive);
    final goalsController = TextEditingController(text: _goals);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Speech & Communication Assessment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: speechController, maxLines: 2, decoration: const InputDecoration(labelText: 'Expressive Speech Ability', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: recController, maxLines: 2, decoration: const InputDecoration(labelText: 'Receptive Language Comprehension', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: goalsController, maxLines: 2, decoration: const InputDecoration(labelText: 'Active Communication Goals', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              setState(() {
                _speech = speechController.text.trim();
                _receptive = recController.text.trim();
                _goals = goalsController.text.trim();
              });
              Navigator.pop(context);

              final res = await SupabaseDbService.saveSpeechAssessment(
                _selectedFriendId,
                speechController.text.trim(),
                recController.text.trim(),
                goalsController.text.trim(),
              );
              if (res.containsKey('id')) _assessmentId = res['id'];

              final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
              await box.put('speech_assessment_$_selectedFriendId', {
                'speech_skills': _speech,
                'language_development': _receptive,
                'communication_goals': _goals,
              });

              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Speech assessment saved.'), backgroundColor: AppTheme.successColor),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddActivityDialog() {
    final titleController = TextEditingController();
    final targetController = TextEditingController(text: '15 mins per session');
    String focus = 'Articulation & Phonology';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.record_voice_over, color: Color(0xFF6A1B9A)),
              SizedBox(width: 8),
              Text('Add Speech Activity / Target', style: TextStyle(fontSize: 16)),
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
                    labelText: 'Speech Activity / Target Word *',
                    hintText: 'e.g. Bilabial sound repetition (/p/, /b/), PECS card choice...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetController,
                  decoration: const InputDecoration(
                    labelText: 'Practice Target / Frequency',
                    hintText: 'e.g. 10 repetitions, Daily lunch routine...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: focus,
                  decoration: const InputDecoration(
                    labelText: 'Communication Focus',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Articulation & Phonology', child: Text('Articulation & Phonology')),
                    DropdownMenuItem(value: 'Expressive Language', child: Text('Expressive Language')),
                    DropdownMenuItem(value: 'Receptive Comprehension', child: Text('Receptive Comprehension')),
                    DropdownMenuItem(value: 'AAC & Picture Exchange', child: Text('AAC & Picture Exchange (PECS)')),
                    DropdownMenuItem(value: 'Social Pragmatics', child: Text('Social Pragmatics & Greetings')),
                    DropdownMenuItem(value: 'Oral Motor Function', child: Text('Oral Motor Function')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => focus = val);
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A), foregroundColor: Colors.white),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Activity'),
              onPressed: () async {
                final title = titleController.text.trim();
                final target = targetController.text.trim();
                if (title.isEmpty) return;

                final entry = '$title (${target.isNotEmpty ? target : 'Standard'}) • $focus';
                setState(() {
                  _activities.add(entry);
                });
                Navigator.pop(ctx);

                final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
                await box.put('speech_activities_$_selectedFriendId', _activities);

                if (SupabaseDbService.isConfigured) {
                  if (_assessmentId == null) {
                    final res = await SupabaseDbService.saveSpeechAssessment(_selectedFriendId, _speech, _receptive, _goals);
                    if (res.containsKey('id')) _assessmentId = res['id'];
                  }
                  if (_assessmentId != null) {
                    await SupabaseDbService.updateSpeechActivities(_assessmentId!, _activities);
                  }
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added speech activity: $title'), backgroundColor: AppTheme.successColor),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _removeActivity(int index) async {
    final removed = _activities[index];
    setState(() {
      _activities.removeAt(index);
    });

    final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
    await box.put('speech_activities_$_selectedFriendId', _activities);

    if (_assessmentId != null && SupabaseDbService.isConfigured) {
      await SupabaseDbService.updateSpeechActivities(_assessmentId!, _activities);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed "$removed"'), backgroundColor: Colors.grey.shade700),
      );
    }
  }

  void _saveSession() async {
    final notes = _sessionNotesController.text.trim();
    final progress = _progressController.text.trim();
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter session notes.')));
      return;
    }

    final newEntry = {
      'date': todayStr,
      'notes': notes,
      'progress': progress,
    };

    setState(() {
      _sessions.insert(0, newEntry);
      _sessionNotesController.clear();
      _progressController.clear();
    });

    final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
    await box.put('speech_sessions_$_selectedFriendId', _sessions);

    if (SupabaseDbService.isConfigured) {
      if (_assessmentId == null) {
        final res = await SupabaseDbService.saveSpeechAssessment(_selectedFriendId, _speech, _receptive, _goals);
        if (res.containsKey('id')) _assessmentId = res['id'];
      }
      if (_assessmentId != null) {
        await SupabaseDbService.addSpeechSession(_assessmentId!, notes, progress);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech therapy session logged successfully.'), backgroundColor: AppTheme.successColor),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);
    final user = ref.read(authProvider).user;
    final isSpeechTherapist = user?.role == 'speech_therapist';
    final isPrincipalOrAdmin = user?.role == 'principal' || user?.role == 'admin';
    final canEditSpeech = isSpeechTherapist;

    Friend? currentFriend;
    if (_selectedFriendId != 'all') {
      currentFriend = friends.where((f) => f.id == _selectedFriendId).firstOrNull ?? (friends.isNotEmpty ? friends.first : null);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Speech & Language Clinical Dossier'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadFromDatabase(_selectedFriendId),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.person_search, color: Color(0xFF6A1B9A)),
                          const SizedBox(width: 12),
                          const Text('Beneficiary:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedFriendId,
                                isExpanded: true,
                                items: friends.map((f) {
                                  return DropdownMenuItem<String>(
                                    value: f.id,
                                    child: Text('${f.fullName} (${f.registrationNumber})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedFriendId = val);
                                    _loadFromDatabase(val);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  _buildRoleBanner(isSpeechTherapist, isPrincipalOrAdmin, user?.fullName ?? 'Therapist'),
                  const SizedBox(height: 20),

                  if (currentFriend != null) ...[
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
                              backgroundColor: const Color(0xFF6A1B9A).withValues(alpha: 0.1),
                              child: getAppImageProvider(currentFriend.photoUrl) == null
                                  ? Text(currentFriend.fullName.isNotEmpty ? currentFriend.fullName[0] : 'B', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A)))
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
                                    Icon(Icons.record_voice_over, color: Color(0xFF6A1B9A)),
                                    SizedBox(width: 8),
                                    Text('Speech & Communication Parameters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                                if (canEditSpeech)
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Color(0xFF6A1B9A)),
                                    tooltip: 'Edit Parameters',
                                    onPressed: _editAssessment,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_speech.isEmpty && _receptive.isEmpty && _goals.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12.0),
                                child: Column(
                                  children: [
                                    const Text('No speech & communication parameters recorded yet for this beneficiary.', style: TextStyle(color: Colors.grey)),
                                    if (canEditSpeech) ...[
                                      const SizedBox(height: 10),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A), foregroundColor: Colors.white),
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text('Record Assessment Parameters'),
                                        onPressed: _editAssessment,
                                      ),
                                    ],
                                  ],
                                ),
                              )
                            else ...[
                              _buildField('Expressive Speech Ability', _speech.isNotEmpty ? _speech : 'Not recorded'),
                              _buildField('Receptive Language Comprehension', _receptive.isNotEmpty ? _receptive : 'Not recorded'),
                              _buildField('Active Communication Goals', _goals.isNotEmpty ? _goals : 'Not recorded'),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

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
                                    Icon(Icons.auto_stories, color: Colors.purple),
                                    SizedBox(width: 8),
                                    Text('Tailored Activities & Target Goals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                                if (canEditSpeech)
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Add Activity', style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF6A1B9A),
                                      foregroundColor: Colors.white,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                    onPressed: _showAddActivityDialog,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_activities.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.record_voice_over_outlined, size: 40, color: Colors.grey.shade400),
                                      const SizedBox(height: 8),
                                      const Text('No custom speech activities or targets created yet.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                      if (canEditSpeech) ...[
                                        const SizedBox(height: 8),
                                        TextButton.icon(
                                          icon: const Icon(Icons.add, size: 16),
                                          label: const Text('Add Tailored Target / Activity'),
                                          onPressed: _showAddActivityDialog,
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
                                itemCount: _activities.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, idx) {
                                  final act = _activities[idx];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check_circle, color: Color(0xFF6A1B9A), size: 18),
                                        const SizedBox(width: 10),
                                        Expanded(child: Text(act, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                                        if (canEditSpeech)
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                            tooltip: 'Remove Activity',
                                            onPressed: () => _removeActivity(idx),
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

                    if (canEditSpeech)
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Log Speech Session', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 14),
                              if (_activities.isNotEmpty) ...[
                                const Text('Select activities completed in this session:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: _activities.map((act) {
                                    final label = act.split('(').first.trim();
                                    return ActionChip(
                                      avatar: const Icon(Icons.add, size: 14, color: Color(0xFF6A1B9A)),
                                      label: Text(label, style: const TextStyle(fontSize: 11)),
                                      backgroundColor: const Color(0xFFF3E5F5),
                                      onPressed: () {
                                        final current = _sessionNotesController.text;
                                        if (!current.contains(label)) {
                                          _sessionNotesController.text = current.isEmpty ? 'Practiced $label.' : '$current Practiced $label.';
                                        }
                                      },
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 14),
                              ],
                              TextFormField(
                                controller: _sessionNotesController,
                                maxLines: 2,
                                decoration: const InputDecoration(labelText: 'Focus Sounds / Words Exercised', border: OutlineInputBorder()),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _progressController,
                                maxLines: 2,
                                decoration: const InputDecoration(labelText: 'Articulation Outcome & Progress', border: OutlineInputBorder()),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A), foregroundColor: Colors.white),
                                icon: const Icon(Icons.save),
                                label: const Text('Save Therapy Session'),
                                onPressed: _saveSession,
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),

                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Speech Therapy Session Logs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 14),
                            if (_sessions.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('No speech therapy sessions logged yet for this beneficiary.', style: TextStyle(color: Colors.grey)),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _sessions.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final s = _sessions[index];
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                                    leading: const CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Color(0xFFE1BEE7),
                                      child: Icon(Icons.record_voice_over, color: Color(0xFF6A1B9A), size: 18),
                                    ),
                                    title: Text('Session on ${s['date']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Focus: ${s['notes']}', style: const TextStyle(fontSize: 12)),
                                        if (s['progress'] != null && s['progress'].toString().isNotEmpty)
                                          Text('Outcome: ${s['progress']}', style: const TextStyle(fontSize: 12, color: Colors.purple, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
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

  Widget _buildRoleBanner(bool isSpeechTherapist, bool isPrincipalOrAdmin, String userName) {
    if (isSpeechTherapist) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.purple.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.record_voice_over, color: Color(0xFF6A1B9A), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Signed in as Speech Pathologist ($userName). You have full authorization to log therapy sessions and update communication goals.',
                style: TextStyle(color: Colors.purple.shade900, fontSize: 13, fontWeight: FontWeight.w500),
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
                  'Reviewing articulation milestones, language comprehension progress, and speech therapy clinical logs.',
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
