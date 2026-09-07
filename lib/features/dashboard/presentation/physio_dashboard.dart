import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/shared/widgets/responsive_layout.dart';
import '../../../core/theme/theme.dart';
import '../../../core/localization/localization.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/services/supabase_db_service.dart';
import '../../../core/storage/hive_storage.dart';
import '../../friends/presentation/friends_provider.dart';
import '../../friends/models/friend.dart';
import '../../auth/presentation/auth_providers.dart';

class PhysioDashboardScreen extends ConsumerStatefulWidget {
  const PhysioDashboardScreen({super.key});

  @override
  ConsumerState<PhysioDashboardScreen> createState() => _PhysioDashboardScreenState();
}

class _PhysioDashboardScreenState extends ConsumerState<PhysioDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _workshopFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showQuickSessionModal(BuildContext context, Friend friend) {
    final durationController = TextEditingController(text: '30');
    final notesController = TextEditingController();
    int rating = 4;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.accessibility_new, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Log Physio Session: ${friend.fullName}', style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ID: ${friend.registrationNumber} • House: ${friend.assignedHouseId.replaceAll('_', ' ').toUpperCase()}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duration (Minutes)',
                    prefixIcon: Icon(Icons.timer_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Session Performance Rating:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starIndex = index + 1;
                    return IconButton(
                      icon: Icon(
                        starIndex <= rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: () => setModalState(() => rating = starIndex),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
                    final rawEx = box.get('physio_exercises_${friend.id}');
                    final exercises = rawEx is List ? List<String>.from(rawEx) : <String>[];
                    if (exercises.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Include tailored activities:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: exercises.map((ex) {
                            final label = ex.split('(').first.trim();
                            return ActionChip(
                              avatar: const Icon(Icons.add, size: 12, color: Colors.teal),
                              label: Text(label, style: const TextStyle(fontSize: 11)),
                              backgroundColor: Colors.teal.shade50,
                              onPressed: () {
                                final cur = notesController.text;
                                if (!cur.contains(label)) {
                                  notesController.text = cur.isEmpty ? 'Completed $label.' : '$cur Completed $label.';
                                }
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                      ],
                    );
                  },
                ),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Therapy Session Notes',
                    hintText: 'e.g. Gait training, ankle flexion, improved posture...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: isSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check, size: 16),
              label: const Text('Save Session'),
              onPressed: isSaving
                  ? null
                  : () async {
                      setModalState(() => isSaving = true);
                      final duration = int.tryParse(durationController.text.trim()) ?? 30;
                      final notes = notesController.text.trim();
                      final todayStr = DateTime.now().toIso8601String().substring(0, 10);

                      // Save to Hive
                      final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
                      final sessionRecord = {
                        'friend_id': friend.id,
                        'date': todayStr,
                        'duration': duration,
                        'rating': rating,
                        'notes': notes,
                        'created_at': DateTime.now().toIso8601String(),
                      };
                      final List<dynamic> localList = box.get('physio_sessions_${friend.id}') ?? [];
                      localList.insert(0, sessionRecord);
                      await box.put('physio_sessions_${friend.id}', localList);

                      // Save to Supabase
                      if (SupabaseDbService.isConfigured) {
                        try {
                          final assessment = await SupabaseDbService.fetchPhysioAssessment(friend.id);
                          String assessmentId = assessment?['id'] ?? '';
                          if (assessmentId.isEmpty) {
                            final created = await SupabaseDbService.savePhysioAssessment(
                              friend.id,
                              'Normal limits in upper extremities',
                              '4/5 strength',
                              'Stable balance',
                              'Independent mobility',
                            );
                            assessmentId = created['id'] ?? '';
                          }
                          if (assessmentId.isNotEmpty) {
                            await SupabaseDbService.addPhysioSession(assessmentId, duration, rating, notes);
                          }
                        } catch (e) {
                          debugPrint('Error syncing physio session to Supabase: $e');
                        }
                      }

                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (mounted) {
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Physiotherapy session recorded for ${friend.fullName}!'),
                            backgroundColor: AppTheme.successColor,
                          ),
                        );
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final friends = ref.watch(friendsProvider);
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isPhysio = user?.role == 'physiotherapist';
    final isPrincipalOrAdmin = user?.role == 'principal' || user?.role == 'admin';

    // Filter friends
    final filtered = friends.where((f) {
      final matchesSearch = f.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          f.registrationNumber.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesWorkshop = _workshopFilter == 'all' || f.assignedWorkshopId == _workshopFilter;
      return matchesSearch && matchesWorkshop;
    }).toList();

    return ResponsiveLayout(
      title: 'Physiotherapy Clinical Console',
      currentRoute: '/dashboard/physio',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Banner
            _buildHeaderBanner(context, user?.fullName ?? 'Therapist', isPhysio, isPrincipalOrAdmin),
            const SizedBox(height: 20),

            // 2. Metrics Overview Row
            _buildKpiSummaryRow(friends),
            const SizedBox(height: 24),

            // 3. Search & Filter Bar
            Card(
              elevation: 1.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search beneficiary by name or registration ID...',
                          prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _workshopFilter,
                        decoration: InputDecoration(
                          labelText: 'Workshop Filter',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('All Workshops')),
                          const DropdownMenuItem(value: 'bakery', child: Text('Bakery')),
                          const DropdownMenuItem(value: 'woodwork', child: Text('Woodwork')),
                          const DropdownMenuItem(value: 'farming', child: Text('Farming')),
                          const DropdownMenuItem(value: 'textile', child: Text('Textile')),
                          const DropdownMenuItem(value: 'artwork', child: Text('Artwork')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _workshopFilter = val);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 4. Beneficiaries Physiotherapy Caseload Directory
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Physical Assessment & Rehabilitation Roster',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              'Showing ${filtered.length} of ${friends.length} beneficiaries under clinical physical therapy review.',
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                        if (isPrincipalOrAdmin)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: const Text('Oversight View', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(
                          child: Text('No beneficiaries match your search criteria.', style: TextStyle(color: Colors.grey)),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final friend = filtered[index];
                          final provider = getAppImageProvider(friend.photoUrl);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundImage: provider,
                                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                                  child: provider == null
                                      ? Text(friend.fullName[0], style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor))
                                      : null,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              friend.fullName,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              friend.registrationNumber,
                                              style: TextStyle(fontSize: 10, color: Colors.blue.shade900, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Workshop: ${localizations.translate(friend.assignedWorkshopId)} • House: ${friend.assignedHouseId.replaceAll('_', ' ').toUpperCase()}',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                      ),
                                       const SizedBox(height: 6),
                                       Builder(
                                         builder: (context) {
                                           final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
                                           final sessions = (box.get('physio_sessions_${friend.id}') as List?) ?? [];
                                           final assessment = (box.get('physio_assessment_${friend.id}') as Map?) ?? {};
                                           final exercises = (box.get('physio_exercises_${friend.id}') as List?) ?? [];
                                           final hasMobility = assessment['mobility'] != null && assessment['mobility'].toString().isNotEmpty;

                                           return Wrap(
                                             spacing: 6,
                                             runSpacing: 4,
                                             children: [
                                               if (hasMobility)
                                                 _buildBadge('Mobility: ${assessment['mobility']}', Colors.teal)
                                               else
                                                 _buildBadge('Assessment Pending', Colors.orange),
                                               if (exercises.isNotEmpty)
                                                 _buildBadge('${exercises.length} Activities', Colors.indigo)
                                               else
                                                 _buildBadge('No Exercises', Colors.grey),
                                               _buildBadge('${sessions.length} Sessions', Colors.blue),
                                             ],
                                           );
                                         },
                                       ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isPhysio || isPrincipalOrAdmin)
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor),
                                        tooltip: 'Quick Log Session',
                                        onPressed: () => _showQuickSessionModal(context, friend),
                                      ),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.visibility_outlined, size: 14),
                                      label: Text(isPrincipalOrAdmin ? 'Inspect Dossier' : 'Full Profile', style: const TextStyle(fontSize: 12)),
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                      onPressed: () => context.push('/therapy/physiotherapy/${friend.id}'),
                                    ),
                                  ],
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
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBanner(BuildContext context, String userName, bool isPhysio, bool isPrincipalOrAdmin) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00695C), Color(0xFF00897B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 650;
          final titleRow = Row(
            children: const [
              Icon(Icons.accessibility_new, color: Colors.white, size: 32),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Physiotherapy Management Portal',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          );

          final badge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              isPhysio ? 'Lead Physiotherapist ($userName)' : 'Clinical Oversight View',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isNarrow) ...[
                titleRow,
                const SizedBox(height: 8),
                badge,
              ] else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleRow),
                    const SizedBox(width: 8),
                    badge,
                  ],
                ),
              const SizedBox(height: 10),
              const Text(
                'Record Range of Motion (ROM), muscle strength exercises, posture evaluations, gait analysis, and daily physical rehabilitation session milestones.',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKpiSummaryRow(List<Friend> friends) {
    final activeCount = friends.where((f) => f.status == 'active').length;
    final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);

    int totalSessions = 0;
    int totalRating = 0;
    int assessedCount = 0;

    for (final f in friends) {
      final sessions = box.get('physio_sessions_${f.id}');
      if (sessions is List && sessions.isNotEmpty) {
        totalSessions += sessions.length;
        for (final s in sessions) {
          if (s is Map && s['rating'] is num) {
            totalRating += (s['rating'] as num).toInt();
          }
        }
      }
      final assessment = box.get('physio_assessment_${f.id}');
      final exercises = box.get('physio_exercises_${f.id}');
      if ((assessment is Map && (assessment['range_of_motion'] ?? '').toString().isNotEmpty) ||
          (exercises is List && exercises.isNotEmpty)) {
        assessedCount++;
      }
    }

    final avgRatingStr = totalSessions > 0 ? '${(totalRating / totalSessions).toStringAsFixed(1)} / 5.0' : 'No ratings yet';

    final cards = [
      _buildKpiCard('Active Beneficiaries', '$activeCount Enrolled', Icons.people_outline, Colors.teal),
      _buildKpiCard('Sessions Logged', '$totalSessions Completed', Icons.fitness_center, Colors.indigo),
      _buildKpiCard('Average Performance', avgRatingStr, Icons.star, Colors.amber),
      _buildKpiCard('Clinical Coverage', '$assessedCount of ${friends.length} Assessed', Icons.verified_outlined, Colors.green),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 650) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[1]),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: cards[2]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[3]),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
            const SizedBox(width: 12),
            Expanded(child: cards[2]),
            const SizedBox(width: 12),
            Expanded(child: cards[3]),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade700, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.shade200, width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color.shade800, fontWeight: FontWeight.bold),
      ),
    );
  }
}
