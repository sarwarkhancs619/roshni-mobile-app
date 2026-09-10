import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme.dart';
import '../../../core/localization/localization.dart';
import '../../../core/shared/widgets/responsive_layout.dart';
import '../../friends/presentation/friends_provider.dart';
import '../../auth/presentation/auth_providers.dart';

import '../../../core/storage/hive_storage.dart';

class HouseDashboardScreen extends ConsumerStatefulWidget {
  const HouseDashboardScreen({super.key});

  @override
  ConsumerState<HouseDashboardScreen> createState() => _HouseDashboardScreenState();
}

class _HouseDashboardScreenState extends ConsumerState<HouseDashboardScreen> {
  String _selectedHouseId = 'sunbal_house';
  String? _selectedFriendId;
  
  // House skills
  double _hygiene = 3.0;
  double _roomCleanup = 3.0;
  double _tableManners = 3.0;
  double _bedMaking = 3.0;

  // Miscellaneous activities
  String _musicClass = 'active';
  String _sportsActivity = 'active';
  final TextEditingController _eventController = TextEditingController();

  @override
  void dispose() {
    _eventController.dispose();
    super.dispose();
  }

  void _loadHouseRecords(String friendId) {
    try {
      final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
      final data = box.get('house_skills_$friendId');
      if (data != null && data is Map) {
        setState(() {
          _hygiene = (data['hygiene'] as num?)?.toDouble() ?? 3.0;
          _roomCleanup = (data['room_cleanup'] as num?)?.toDouble() ?? 3.0;
          _tableManners = (data['table_manners'] as num?)?.toDouble() ?? 3.0;
          _bedMaking = (data['bed_making'] as num?)?.toDouble() ?? 3.0;
          _musicClass = data['music_class']?.toString() ?? 'active';
          _sportsActivity = data['sports_activity']?.toString() ?? 'active';
          _eventController.text = data['event_notes']?.toString() ?? '';
        });
        return;
      }
    } catch (_) {}

    setState(() {
      _hygiene = 3.0;
      _roomCleanup = 3.0;
      _tableManners = 3.0;
      _bedMaking = 3.0;
      _musicClass = 'active';
      _sportsActivity = 'active';
      _eventController.clear();
    });
  }

  Future<void> _saveHouseRecords() async {
    if (_selectedFriendId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Friend first.')),
      );
      return;
    }

    try {
      final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
      await box.put('house_skills_$_selectedFriendId', {
        'hygiene': _hygiene,
        'room_cleanup': _roomCleanup,
        'table_manners': _tableManners,
        'bed_making': _bedMaking,
        'music_class': _musicClass,
        'sports_activity': _sportsActivity,
        'event_notes': _eventController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline, color: AppTheme.successColor, size: 48),
        title: const Text('Residential Records Saved'),
        content: const Text('House skills and miscellaneous activities have been successfully logged.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final allFriends = ref.watch(friendsProvider);
    final authState = ref.watch(authProvider);
    final user = authState.user;

    // Restrict selected house if user is house staff
    final isHouseStaff = user?.role == 'house_staff';
    if (isHouseStaff && user?.workshopId != null) {
      _selectedHouseId = (user!.workshopId == 'amin_house') ? 'sunbal_house' : user.workshopId!;
    } else if (_selectedHouseId == 'amin_house') {
      _selectedHouseId = 'sunbal_house';
    }

    final houseFriends = allFriends.where((f) => f.assignedHouseId == _selectedHouseId || (_selectedHouseId == 'sunbal_house' && f.assignedHouseId == 'amin_house')).toList();

    return ResponsiveLayout(
      title: '${localizations.translate(_selectedHouseId)} - ${localizations.translate('house_dashboard')}',
      currentRoute: '/dashboard/house',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // House Selector (only for Admin/Others, hidden for restricted house staff)
            if (!isHouseStaff) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DropdownButtonFormField<String>(
                    value: _selectedHouseId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Select Residential House'),
                    items: [
                      DropdownMenuItem(value: 'sunbal_house', child: Text(localizations.translate('sunbal_house'))),
                      DropdownMenuItem(value: 'roshni_house', child: Text(localizations.translate('roshni_house'))),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedHouseId = val!;
                        _selectedFriendId = null; // reset
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Welcome & Stats
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(16),
                gradient: AppTheme.blueOrangeGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Residential Portal: ${localizations.translate(_selectedHouseId)}',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total Residents: ${houseFriends.length} • Track daily residential skills and miscellaneous activities.',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Resident Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: DropdownButtonFormField<String>(
                  value: _selectedFriendId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Select Resident / Friend'),
                  hint: const Text('Choose a friend to record'),
                  items: houseFriends.map((f) {
                    return DropdownMenuItem(value: f.id, child: Text(f.fullName));
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedFriendId = val;
                    });
                    if (val != null) {
                      _loadHouseRecords(val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            if (_selectedFriendId != null) ...[
              // Skills & Miscellaneous activities Grid
              LayoutBuilder(builder: (context, constraints) {
                return Column(
                  children: [
                    // House Skills Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Residential Skills Progress',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            _buildSkillSlider('Personal Hygiene', _hygiene, (val) => setState(() => _hygiene = val)),
                            _buildSkillSlider('Room Cleanup', _roomCleanup, (val) => setState(() => _roomCleanup = val)),
                            _buildSkillSlider('Table Manners', _tableManners, (val) => setState(() => _tableManners = val)),
                            _buildSkillSlider('Bed Making', _bedMaking, (val) => setState(() => _bedMaking = val)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Miscellaneous Activities Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              localizations.translate('miscellaneous'),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            
                            // Music class
                            DropdownButtonFormField<String>(
                              value: _musicClass,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Music Class Participation'),
                              items: const [
                                DropdownMenuItem(value: 'active', child: Text('Active & Enthusiastic')),
                                DropdownMenuItem(value: 'passive', child: Text('Passive / Listening')),
                                DropdownMenuItem(value: 'none', child: Text('Did not participate / Refused')),
                              ],
                              onChanged: (val) => setState(() => _musicClass = val!),
                            ),
                            const SizedBox(height: 16),

                            // Sports class
                            DropdownButtonFormField<String>(
                              value: _sportsActivity,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Sports & Physical Activity'),
                              items: const [
                                DropdownMenuItem(value: 'active', child: Text('Highly Active participation')),
                                DropdownMenuItem(value: 'moderate', child: Text('Moderate / Needed breaks')),
                                DropdownMenuItem(value: 'none', child: Text('Did not participate')),
                              ],
                              onChanged: (val) => setState(() => _sportsActivity = val!),
                            ),
                            const SizedBox(height: 16),

                            // Event Participation notes
                            TextField(
                              controller: _eventController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Special Event Participation & Notes',
                                hintText: 'Describe their involvement in recent drama rehearsals, celebrations, or community assemblies...',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _saveHouseRecords,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Residential & Activity Logs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ] else ...[
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.home_work_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Please select a resident to start logging records', style: TextStyle(color: Colors.grey, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildSkillSlider(String label, double val, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              Text(
                val == 1.0 
                    ? 'Needs Help' 
                    : (val == 2.0 
                        ? 'Promoted' 
                        : (val == 3.0 
                            ? 'Independent' 
                            : (val == 4.0 ? 'Aided' : 'Excellent'))),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
              ),
            ],
          ),
          Slider(
            min: 1.0,
            max: 5.0,
            divisions: 4,
            value: val,
            activeColor: AppTheme.primaryColor,
            inactiveColor: Colors.grey.shade200,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
