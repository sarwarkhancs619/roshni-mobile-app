import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../friends/presentation/friends_provider.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../../core/services/supabase_db_service.dart';

class SpeechDetailsScreen extends ConsumerStatefulWidget {
  final String friendId;
  const SpeechDetailsScreen({super.key, required this.friendId});

  @override
  ConsumerState<SpeechDetailsScreen> createState() => _SpeechDetailsScreenState();
}

class _SpeechDetailsScreenState extends ConsumerState<SpeechDetailsScreen> {
  bool _isLoading = true;
  String? _assessmentId;

  String _speech = 'Expressive language limited to simple phrases. Receptive skills are solid.';
  String _receptive = 'Able to understand 2-step command workflows in the bakery and woodwork workshops.';
  String _goals = '1. Pronounce packaging labels clearly.\n2. Express basic physical needs independently using picture cards.';

  List<Map<String, dynamic>> _sessions = [
    {'date': '2026-07-19', 'notes': 'Practiced naming daily baking tools. Responded correctly to 4/5 picture card requests.'},
    {'date': '2026-07-12', 'notes': 'Focused on vocal exercises. Good focus, participated enthusiastically.'}
  ];

  final TextEditingController _sessionNotesController = TextEditingController();

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

    final data = await SupabaseDbService.fetchSpeechAssessment(widget.friendId);
    if (data != null) {
      setState(() {
        _assessmentId = data['id'];
        _speech = data['speech_skills'] ?? _speech;
        _receptive = data['language_development'] ?? _receptive;
        _goals = data['communication_goals'] ?? _goals;

        final List<dynamic> dbSessions = data['speech_sessions'] ?? [];
        if (dbSessions.isNotEmpty) {
          _sessions = dbSessions.map((s) => {
            'date': s['date']?.toString().substring(0, 10) ?? '',
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
    final speechController = TextEditingController(text: _speech);
    final recepController = TextEditingController(text: _receptive);
    final goalsController = TextEditingController(text: _goals);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Speech Assessment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: speechController, decoration: const InputDecoration(labelText: 'Expressive Speech Ability')),
              const SizedBox(height: 12),
              TextField(controller: recepController, decoration: const InputDecoration(labelText: 'Receptive Language Comprehension')),
              const SizedBox(height: 12),
              TextField(controller: goalsController, decoration: const InputDecoration(labelText: 'Communication Goals')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              setState(() {
                _speech = speechController.text;
                _receptive = recepController.text;
                _goals = goalsController.text;
              });
              Navigator.pop(context);

              final res = await SupabaseDbService.saveSpeechAssessment(
                widget.friendId,
                speechController.text,
                recepController.text,
                goalsController.text,
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add speech therapy progress notes.')));
      return;
    }

    if (_assessmentId == null) {
      final res = await SupabaseDbService.saveSpeechAssessment(widget.friendId, _speech, _receptive, _goals);
      _assessmentId = res['id'] ?? 'mock_speech_assessment_id';
    }

    if (_assessmentId != null) {
      final notes = _sessionNotesController.text;
      await SupabaseDbService.addSpeechSession(_assessmentId!, notes, 'Session completed');

      setState(() {
        _sessions.insert(0, {
          'date': DateTime.now().toIso8601String().substring(0, 10),
          'notes': notes,
        });
        _sessionNotesController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech Therapy Session logged successfully!'), backgroundColor: AppTheme.successColor),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);

    if (widget.friendId == 'all') {
      return Scaffold(
        appBar: AppBar(title: const Text('Speech Therapy Directory')),
        body: ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final f = friends[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(backgroundImage: NetworkImage(f.photoUrl)),
                title: Text(f.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Vocal level: Moderate • Goals: 2 active'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => SpeechDetailsScreen(friendId: f.id)),
                  );
                },
              ),
            );
          },
        ),
      );
    }

    final friend = friends.firstWhere((f) => f.id == widget.friendId);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      );
    }

    final user = ref.read(authProvider).user;
    final isPrincipal = user?.role == 'principal';
    final canEditSpeech = user?.role == 'principal' || user?.role == 'speech_therapist';

    return Scaffold(
      appBar: AppBar(
        title: Text('${friend.fullName} - Speech Therapy'),
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
            // Speech Assessment Card
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
                              Icon(Icons.spatial_audio_off_sharp, color: AppTheme.primaryColor),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Speech & Communication assessment',
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
                    _buildAssessmentField('Expressive Speech Ability', _speech),
                    _buildAssessmentField('Receptive Language Comprehension', _receptive),
                    _buildAssessmentField('Active Communication Goals', _goals),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Log New Session Card
            if (canEditSpeech)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Log Speech Session', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _sessionNotesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Enter session goals achieved, exercises performed, vocabulary gains...',
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
                              Text(session['date'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
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
