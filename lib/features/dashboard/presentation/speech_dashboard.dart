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

class SpeechDashboardScreen extends ConsumerStatefulWidget {
  const SpeechDashboardScreen({super.key});

  @override
  ConsumerState<SpeechDashboardScreen> createState() => _SpeechDashboardScreenState();
}

class _SpeechDashboardScreenState extends ConsumerState<SpeechDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _workshopFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showQuickSpeechSessionModal(BuildContext context, Friend friend) {
    final notesController = TextEditingController();
    final progressController = TextEditingController();
    bool isSaving = false;

    // Load friend's dynamic speech activities
    final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
    final rawActivities = box.get('speech_activities_${friend.id}');
    final List<Map<String, dynamic>> friendActivities = [];
    if (rawActivities is List) {
      for (final a in rawActivities) {
        if (a is Map) {
          friendActivities.add(Map<String, dynamic>.from(a));
        } else if (a is String) {
          friendActivities.add({'title': a, 'category': 'General'});
        }
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.record_voice_over, color: Color(0xFF6A1B9A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Log Speech Session: ${friend.fullName}', style: const TextStyle(fontSize: 16)),
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
                if (friendActivities.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Select Target Activity / Communication Goal:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: friendActivities.map((act) {
                      final title = act['title'] ?? '';
                      final isSelected = notesController.text.contains(title);
                      return ChoiceChip(
                        label: Text(title, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.purple.shade900)),
                        selected: isSelected,
                        selectedColor: const Color(0xFF6A1B9A),
                        backgroundColor: Colors.purple.shade50,
                        onSelected: (selected) {
                          setModalState(() {
                            if (selected) {
                              if (notesController.text.isEmpty) {
                                notesController.text = title;
                              } else {
                                notesController.text = '${notesController.text}, $title';
                              }
                            } else {
                              notesController.text = notesController.text
                                  .replaceAll(', $title', '')
                                  .replaceAll('$title, ', '')
                                  .replaceAll(title, '')
                                  .trim();
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Session Focus / Phonetics Exercised',
                    hintText: 'e.g. Bilabial sounds /b/, /p/, two-word sentence structures...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: progressController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Progress Description & Articulation Outcome',
                    hintText: 'e.g. Demonstrated clear imitation with visual prompts. High motivation.',
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A), foregroundColor: Colors.white),
              icon: isSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check, size: 16),
              label: const Text('Save Speech Log'),
              onPressed: isSaving
                  ? null
                  : () async {
                      setModalState(() => isSaving = true);
                      final notes = notesController.text.trim();
                      final progress = progressController.text.trim();
                      final todayStr = DateTime.now().toIso8601String().substring(0, 10);

                      // Save to Hive
                      final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
                      final sessionRecord = {
                        'friend_id': friend.id,
                        'date': todayStr,
                        'notes': notes,
                        'progress': progress,
                        'created_at': DateTime.now().toIso8601String(),
                      };
                      final List<dynamic> localList = box.get('speech_sessions_${friend.id}') ?? [];
                      localList.insert(0, sessionRecord);
                      await box.put('speech_sessions_${friend.id}', localList);

                      // Save to Supabase
                      if (SupabaseDbService.isConfigured) {
                        try {
                          final assessment = await SupabaseDbService.fetchSpeechAssessment(friend.id);
                          String assessmentId = assessment?['id'] ?? '';
                          if (assessmentId.isEmpty) {
                            final created = await SupabaseDbService.saveSpeechAssessment(
                              friend.id,
                              'Emerging vocalization',
                              'Moderate comprehension',
                              'Express basic needs using functional words',
                            );
                            assessmentId = created['id'] ?? '';
                          }
                          if (assessmentId.isNotEmpty) {
                            await SupabaseDbService.addSpeechSession(assessmentId, notes, progress);
                          }
                        } catch (e) {
                          debugPrint('Error syncing speech session to Supabase: $e');
                        }
                      }

                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (mounted) {
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Speech therapy log recorded for ${friend.fullName}!'),
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
    final isSpeechTherapist = user?.role == 'speech_therapist';
    final isPrincipalOrAdmin = user?.role == 'principal' || user?.role == 'admin';

    // Filter friends
    final filtered = friends.where((f) {
      final matchesSearch = f.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          f.registrationNumber.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesWorkshop = _workshopFilter == 'all' || f.assignedWorkshopId == _workshopFilter;
      return matchesSearch && matchesWorkshop;
    }).toList();

    return ResponsiveLayout(
      title: 'Speech & Language Therapy Console',
      currentRoute: '/dashboard/speech',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Banner
            _buildHeaderBanner(context, user?.fullName ?? 'Therapist', isSpeechTherapist, isPrincipalOrAdmin),
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 600;
                    final searchField = TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search beneficiary by name or registration ID...',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF6A1B9A)),
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
                    );

                    final dropdown = DropdownButtonFormField<String>(
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
                    );

                    if (isNarrow) {
                      return Column(
                        children: [
                          searchField,
                          const SizedBox(height: 12),
                          dropdown,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(flex: 3, child: searchField),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: dropdown),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 4. Beneficiaries Speech Therapy Caseload Directory
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 600;
                        final titleColumn = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Speech & Communication Development Directory',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Showing ${filtered.length} of ${friends.length} beneficiaries undergoing speech & communication intervention.',
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        );

                        final badge = isPrincipalOrAdmin
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.purple.shade300),
                                ),
                                child: const Text('Oversight View', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple)),
                              )
                            : null;

                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              titleColumn,
                              if (badge != null) ...[
                                const SizedBox(height: 8),
                                badge,
                              ],
                            ],
                          );
                        }

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: titleColumn),
                            if (badge != null) ...[
                              const SizedBox(width: 8),
                              badge,
                            ],
                          ],
                        );
                      },
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
                          final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
                          final assessment = box.get('speech_assessment_${friend.id}');
                          final rawActs = box.get('speech_activities_${friend.id}');
                          final rawSessions = box.get('speech_sessions_${friend.id}');

                          final int sessionCount = rawSessions is List ? rawSessions.length : 0;
                          final int targetCount = rawActs is List ? rawActs.length : 0;
                          final String articScore = (assessment is Map && (assessment['articulation_score'] ?? '').toString().isNotEmpty)
                              ? assessment['articulation_score'].toString()
                              : 'Pending Eval';
                          final String? targetGoal = (assessment is Map && (assessment['target_goal'] ?? '').toString().isNotEmpty)
                              ? assessment['target_goal'].toString()
                              : (rawActs is List && rawActs.isNotEmpty
                                  ? (rawActs.first is Map ? (rawActs.first['title'] ?? '').toString() : rawActs.first.toString())
                                  : null);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 600;
                                final avatar = CircleAvatar(
                                  radius: 24,
                                  backgroundImage: provider,
                                  backgroundColor: const Color(0xFF6A1B9A).withValues(alpha: 0.1),
                                  child: provider == null
                                      ? Text(friend.fullName[0], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A)))
                                      : null,
                                );

                                final infoColumn = Column(
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
                                            color: Colors.purple.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            friend.registrationNumber,
                                            style: TextStyle(fontSize: 10, color: Colors.purple.shade900, fontWeight: FontWeight.bold),
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
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        _buildBadge('Artic: $articScore', Colors.purple),
                                        _buildBadge('Sessions: $sessionCount', Colors.indigo),
                                        if (targetGoal != null)
                                          _buildBadge('Goal: $targetGoal', Colors.deepPurple)
                                        else
                                          _buildBadge('Targets: $targetCount active', Colors.deepPurple),
                                      ],
                                    ),
                                  ],
                                );

                                final actionButtons = Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (isSpeechTherapist || isPrincipalOrAdmin)
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline, color: Color(0xFF6A1B9A)),
                                        tooltip: 'Quick Log Session',
                                        onPressed: () => _showQuickSpeechSessionModal(context, friend),
                                      ),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.visibility_outlined, size: 14),
                                      label: Text(isPrincipalOrAdmin ? 'Inspect Dossier' : 'Full Profile', style: const TextStyle(fontSize: 12)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF6A1B9A),
                                        side: const BorderSide(color: Color(0xFF6A1B9A)),
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                      onPressed: () => context.push('/therapy/speech/${friend.id}'),
                                    ),
                                  ],
                                );

                                if (isNarrow) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          avatar,
                                          const SizedBox(width: 14),
                                          Expanded(child: infoColumn),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      actionButtons,
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    avatar,
                                    const SizedBox(width: 14),
                                    Expanded(child: infoColumn),
                                    const SizedBox(width: 8),
                                    actionButtons,
                                  ],
                                );
                              },
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

  Widget _buildHeaderBanner(BuildContext context, String userName, bool isSpeechTherapist, bool isPrincipalOrAdmin) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.25),
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
              Icon(Icons.record_voice_over, color: Colors.white, size: 32),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Speech & Language Therapy Portal',
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
              isSpeechTherapist ? 'Speech Pathologist ($userName)' : 'Clinical Oversight View',
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
                'Track speech articulation milestones, receptive & expressive language development, non-verbal AAC communication, and structured oral therapy sessions.',
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
    int assessedCount = 0;
    int totalCustomActivities = 0;

    for (final f in friends) {
      final sessions = box.get('speech_sessions_${f.id}');
      if (sessions is List && sessions.isNotEmpty) {
        totalSessions += sessions.length;
      }
      final assessment = box.get('speech_assessment_${f.id}');
      final activities = box.get('speech_activities_${f.id}');
      if (activities is List && activities.isNotEmpty) {
        totalCustomActivities += activities.length;
      }
      if ((assessment is Map && (assessment['articulation_score'] ?? '').toString().isNotEmpty) ||
          (activities is List && activities.isNotEmpty)) {
        assessedCount++;
      }
    }

    final cards = [
      _buildKpiCard('Speech Caseload', '$activeCount Enrolled', Icons.people_outline, Colors.purple),
      _buildKpiCard('Sessions Logged', '$totalSessions Recorded', Icons.record_voice_over_outlined, Colors.indigo),
      _buildKpiCard('Clinical Coverage', '$assessedCount of ${friends.length} Assessed', Icons.verified_outlined, Colors.deepPurple),
      _buildKpiCard('Active Goals/Targets', '$totalCustomActivities Configured', Icons.track_changes, Colors.teal),
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
