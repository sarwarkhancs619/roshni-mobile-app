import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../friends/presentation/friends_provider.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../../core/services/supabase_db_service.dart';
import '../../../core/storage/hive_storage.dart';

class IepDetailsScreen extends ConsumerStatefulWidget {
  final String friendId;
  const IepDetailsScreen({super.key, required this.friendId});

  @override
  ConsumerState<IepDetailsScreen> createState() => _IepDetailsScreenState();
}

class _IepDetailsScreenState extends ConsumerState<IepDetailsScreen> {
  bool _isLoading = true;
  String? _iepId;
  String _baseline = '';
  List<Map<String, dynamic>> _goals = [];

  @override
  void initState() {
    super.initState();
    _loadFromDatabase();
  }

  Future<void> _loadFromDatabase() async {
    final iep = await SupabaseDbService.fetchIep(widget.friendId);
    if (iep != null) {
      setState(() {
        _iepId = iep['id'];
        _baseline = iep['baseline'] ?? _baseline;
        final List<dynamic> dbGoals = iep['iep_goals'] ?? [];
        if (dbGoals.isNotEmpty) {
          _goals = dbGoals.map((g) => {
            'id': g['id']?.toString() ?? '',
            'title': g['title'] ?? '',
            'objectives': g['objectives'] ?? '',
            'strategies': g['strategies'] ?? '',
            'progress': g['progress_percentage'] ?? 0,
            'status': g['status'] ?? 'in_progress',
            'target': g['target_date'] ?? '',
          }).toList();
        }
        _isLoading = false;
      });
    } else {
      final box = HiveStorage.getBox(HiveStorage.iepBoxName);
      final dynamic localIep = box.get(widget.friendId);
      if (localIep != null && localIep is Map) {
        setState(() {
          _iepId = localIep['id']?.toString();
          _baseline = localIep['baseline'] ?? _baseline;
          final List<dynamic> localGoals = localIep['iep_goals'] ?? [];
          if (localGoals.isNotEmpty) {
            _goals = List<Map<String, dynamic>>.from(localGoals);
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _editBaseline() {
    final baseController = TextEditingController(text: _baseline);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Developmental Baseline'),
        content: TextField(
          controller: baseController,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Baseline Description'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              setState(() {
                _baseline = baseController.text;
              });
              Navigator.pop(context);
              
              _iepId = await SupabaseDbService.getOrCreateIep(widget.friendId, baseController.text);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Baseline saved successfully.'), backgroundColor: AppTheme.successColor),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _addNewGoal() {
    final titleController = TextEditingController();
    final objController = TextEditingController();
    final stratController = TextEditingController();
    final dateController = TextEditingController(text: '2026-12-31');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add IEP Goal'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Goal Title')),
              const SizedBox(height: 12),
              TextField(controller: objController, decoration: const InputDecoration(labelText: 'Specific Objectives')),
              const SizedBox(height: 12),
              TextField(controller: stratController, decoration: const InputDecoration(labelText: 'Strategies & Resources')),
              const SizedBox(height: 12),
              TextField(controller: dateController, decoration: const InputDecoration(labelText: 'Target Date (YYYY-MM-DD)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (titleController.text.isEmpty) return;
              
              if (_iepId == null) {
                _iepId = await SupabaseDbService.getOrCreateIep(widget.friendId, _baseline);
              }

              if (_iepId != null) {
                await SupabaseDbService.saveIepGoal(
                  _iepId!,
                  titleController.text,
                  objController.text,
                  stratController.text,
                  dateController.text,
                );
                
                setState(() {
                  _goals.add({
                    'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
                    'title': titleController.text,
                    'objectives': objController.text,
                    'strategies': stratController.text,
                    'progress': 0,
                    'status': 'in_progress',
                    'target': dateController.text,
                  });
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _updateProgress(int index, double progress) async {
    final goal = _goals[index];
    final status = progress.toInt() == 100 ? 'completed' : 'in_progress';
    
    setState(() {
      _goals[index]['progress'] = progress.toInt();
      _goals[index]['status'] = status;
    });

    final String goalId = goal['id']?.toString() ?? '';
    if (!goalId.startsWith('temp_') && goalId.isNotEmpty) {
      await SupabaseDbService.updateGoalProgress(goalId, progress.toInt(), status);
    }
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

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);
    final friend = friends.firstWhere((f) => f.id == widget.friendId);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      );
    }

    final user = ref.read(authProvider).user;
    final isPrincipal = user?.role == 'principal';

    return Scaffold(
      appBar: AppBar(
        title: Text('${friend.fullName} - IEP Module'),
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
      floatingActionButton: isPrincipal 
          ? FloatingActionButton(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              onPressed: _addNewGoal,
              child: const Icon(Icons.add_task),
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Baseline Summary
            Card(
              color: AppTheme.primaryColor.withOpacity(0.05),
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
                              Icon(Icons.description, color: AppTheme.primaryColor),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Developmental Baseline',
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
                            onPressed: _editBaseline,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _baseline.isNotEmpty
                          ? _baseline
                          : 'No baseline assessment recorded yet. Tap the edit icon to write the baseline summary.',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: _baseline.isEmpty ? FontStyle.italic : FontStyle.normal,
                        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFCBD5E1) : Colors.grey.shade800,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Goals list header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Individual Learning Goals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Chip(
                  label: Text('${_goals.where((g) => g['status'] == 'completed').length} / ${_goals.length} Completed'),
                  backgroundColor: AppTheme.successColor.withOpacity(0.1),
                  labelStyle: const TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Goals Expansion/Scroll
            if (_goals.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.assignment_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'No learning goals recorded yet.',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isPrincipal
                              ? 'Tap the "+" button below to add an individual learning goal.'
                              : 'The Principal has not yet defined learning goals for this friend.',
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _goals.length,
              itemBuilder: (context, index) {
                final goal = _goals[index];
                final progress = goal['progress'] as int;
                final isCompleted = goal['status'] == 'completed';

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              goal['title'] as String,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                decoration: isCompleted ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isCompleted 
                                    ? AppTheme.successColor.withOpacity(0.1) 
                                    : AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isCompleted ? 'Completed' : 'In Progress',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isCompleted ? AppTheme.successColor : AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Objective: ${goal['objectives']}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFCBD5E1) : Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Strategy: ${goal['strategies']}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Progress slider
                        Row(
                          children: [
                            const Text('Progress:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Slider(
                                value: progress.toDouble(),
                                min: 0,
                                max: 100,
                                divisions: 10,
                                activeColor: isCompleted ? AppTheme.successColor : AppTheme.primaryColor,
                                label: '$progress%',
                                onChanged: isPrincipal ? (val) => _updateProgress(index, val) : null,
                              ),
                            ),
                            Text('$progress%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Target Date: ${goal['target']}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                            TextButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.add_comment_outlined, size: 14),
                              label: const Text('Add Review Note', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
