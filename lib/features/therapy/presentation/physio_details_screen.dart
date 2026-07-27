import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../friends/presentation/friends_provider.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../../core/services/supabase_db_service.dart';

class PhysioDetailsScreen extends ConsumerStatefulWidget {
  final String friendId;
  const PhysioDetailsScreen({super.key, required this.friendId});

  @override
  ConsumerState<PhysioDetailsScreen> createState() => _PhysioDetailsScreenState();
}

class _PhysioDetailsScreenState extends ConsumerState<PhysioDetailsScreen> {
  bool _isLoading = true;
  String? _assessmentId;
  
  String _rom = 'Normal limits in upper extremities, mild stiffness in ankle joints.';
  String _strength = '4/5 in upper limbs, 3/5 in lower limbs.';
  String _balance = 'Unstable on single leg stance. Stable during standard bilateral posture.';
  String _mobility = 'Walks independently. Safe on level surfaces, requires handrail assistance on stairs.';

  List<String> _exercises = ['Ankle rotation stretch (10 reps)', 'Bilateral standing balance (2 mins)', 'Hand grip squeezes (15 reps)'];
  List<Map<String, dynamic>> _sessions = [
    {'date': '2026-07-20', 'duration': 30, 'rating': 4, 'notes': 'Participated well in ankle stretching. Improved posture during balance practice.'},
    {'date': '2026-07-13', 'duration': 25, 'rating': 3, 'notes': 'Some resistance during lower limb stretching, completed hand grip exercises successfully.'}
  ];

  final TextEditingController _sessionNotesController = TextEditingController();
  final TextEditingController _durationController = TextEditingController(text: '30');
  int _performanceRating = 4;

  @override
  void initState() {
    super.initState();
    _loadFromDatabase();
  }

  Future<void> _loadFromDatabase() async {
    if (widget.friendId == 'all') {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final data = await SupabaseDbService.fetchPhysioAssessment(widget.friendId);
    if (data != null) {
      setState(() {
        _assessmentId = data['id'];
        _rom = data['range_of_motion'] ?? _rom;
        _strength = data['strength'] ?? _strength;
        _balance = data['balance'] ?? _balance;
        _mobility = data['mobility'] ?? _mobility;
        
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
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _sessionNotesController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  String _getDashboardRoute(String? role) {
    switch (role) {
      case 'admin':
        return '/dashboard/admin';
      case 'workshop_staff':
        return '/dashboard/staff';
      case 'physiotherapist':
        return '/dashboard/physio';
      case 'speech_therapist':
        return '/dashboard/speech';
      case 'medical_officer':
        return '/dashboard/medical';
      case 'house_staff':
        return '/dashboard/house';
      default:
        return '/login';
    }
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
              TextField(controller: romController, decoration: const InputDecoration(labelText: 'Range of Motion (ROM)')),
              const SizedBox(height: 12),
              TextField(controller: strController, decoration: const InputDecoration(labelText: 'Muscle Strength')),
              const SizedBox(height: 12),
              TextField(controller: balController, decoration: const InputDecoration(labelText: 'Balance & Posture')),
              const SizedBox(height: 12),
              TextField(controller: mobController, decoration: const InputDecoration(labelText: 'Functional Mobility')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              setState(() {
                _rom = romController.text;
                _strength = strController.text;
                _balance = balController.text;
                _mobility = mobController.text;
              });
              Navigator.pop(context);

              final res = await SupabaseDbService.savePhysioAssessment(
                widget.friendId,
                romController.text,
                strController.text,
                balController.text,
                mobController.text,
              );
              if (res.containsKey('id')) {
                _assessmentId = res['id'];
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Assessment saved successfully.'), backgroundColor: AppTheme.successColor),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _saveSession() async {
    if (_sessionNotesController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add session progress notes.')));
      return;
    }

    if (_assessmentId == null) {
      final res = await SupabaseDbService.savePhysioAssessment(widget.friendId, _rom, _strength, _balance, _mobility);
      _assessmentId = res['id'] ?? 'mock_physio_assessment_id';
    }

    if (_assessmentId != null) {
      final dur = int.tryParse(_durationController.text) ?? 30;
      final notes = _sessionNotesController.text;
      
      await SupabaseDbService.addPhysioSession(_assessmentId!, dur, _performanceRating, notes);

      setState(() {
        _sessions.insert(0, {
          'date': DateTime.now().toIso8601String().substring(0, 10),
          'duration': dur,
          'rating': _performanceRating,
          'notes': notes,
        });
        _sessionNotesController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Physiotherapy Session recorded successfully!'), backgroundColor: AppTheme.successColor),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);
    
    // Check if showing "all" list or a specific friend
    if (widget.friendId == 'all') {
      return Scaffold(
        appBar: AppBar(title: const Text('Physiotherapy Directory')),
        body: ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final f = friends[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(backgroundImage: NetworkImage(f.photoUrl)),
                title: Text(f.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('ROM: Stable • Mobility: Independent'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => PhysioDetailsScreen(friendId: f.id)),
                  );
                },
              ),
            );
          },
        ),
      );
    }

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      );
    }

    final friend = friends.firstWhere((f) => f.id == widget.friendId);

    final user = ref.read(authProvider).user;
    final isPrincipal = user?.role == 'principal';
    final canEditPhysio = user?.role == 'principal' || user?.role == 'physiotherapist';

    return Scaffold(
      appBar: AppBar(
        title: Text('${friend.fullName} - Physiotherapy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Back to Dashboard',
            onPressed: () {
              final role = ref.read(authProvider).user?.role;
              context.go(_getDashboardRoute(role));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Physical Assessment Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: const [
                              Icon(Icons.accessibility, color: AppTheme.primaryColor),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Physical Assessment Parameters',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isPrincipal)
                          IconButton(
                            icon: const Icon(Icons.edit, color: AppTheme.primaryColor),
                            onPressed: _editAssessment,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildAssessmentField('Range of Motion (ROM)', _rom),
                    _buildAssessmentField('Muscle Strength', _strength),
                    _buildAssessmentField('Balance & Posture', _balance),
                    _buildAssessmentField('Functional Mobility', _mobility),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Exercises/Plan Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Active Exercise Program', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    ..._exercises.map((exercise) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          children: [
                            const Icon(Icons.check_box_outlined, color: AppTheme.primaryColor, size: 20),
                            const SizedBox(width: 10),
                            Text(exercise, style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Record New Session Card
            if (canEditPhysio)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Record Therapy Session', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _durationController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Duration (Minutes)',
                                prefixIcon: Icon(Icons.timer_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _performanceRating,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Performance'),
                              items: const [
                                DropdownMenuItem(value: 5, child: Text('5 - Excellent')),
                                DropdownMenuItem(value: 4, child: Text('4 - Very Good')),
                                DropdownMenuItem(value: 3, child: Text('3 - Moderate')),
                                DropdownMenuItem(value: 2, child: Text('2 - Needs Assist')),
                                DropdownMenuItem(value: 1, child: Text('1 - Poor')),
                              ],
                              onChanged: (val) => setState(() => _performanceRating = val!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _sessionNotesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Enter specific observations, stretch tolerances or fatigue alerts...',
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _saveSession,
                        child: const Text('Log Therapy Session'),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // History Log
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Session Logs History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _sessions.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final session = _sessions[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(session['date'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text('${session['duration']} mins • Rating: ${session['rating']}/5', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(session['notes'] as String, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
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
        ),
      ),
    );
  }

  Widget _buildAssessmentField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14)),
          const Divider(),
        ],
      ),
    );
  }
}
