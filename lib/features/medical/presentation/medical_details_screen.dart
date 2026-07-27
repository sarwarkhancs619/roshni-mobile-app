import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../friends/presentation/friends_provider.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../../core/services/supabase_db_service.dart';

class MedicalDetailsScreen extends ConsumerStatefulWidget {
  final String friendId;
  const MedicalDetailsScreen({super.key, required this.friendId});

  @override
  ConsumerState<MedicalDetailsScreen> createState() => _MedicalDetailsScreenState();
}

class _MedicalDetailsScreenState extends ConsumerState<MedicalDetailsScreen> {
  bool _isLoading = true;
  String? _recordId;
  String _diagnosis = 'Down Syndrome, mild cognitive impairment.';
  String _history = 'History of seasonal asthma. Under regular checkups.';
  List<String> _allergies = ['Penicillin', 'Dust (triggers asthma)'];
  List<String> _vaccinations = ['COVID-19 (Fully Vaccinated)', 'Tetanus (Booster 2025)'];

  List<Map<String, dynamic>> _prescriptions = [
    {'date': '2026-07-10', 'med': 'Ventolin Inhaler', 'dose': '1 puff', 'freq': 'As needed for wheezing'},
    {'date': '2026-05-15', 'med': 'Multi-Vitamins', 'dose': '1 tablet', 'freq': 'Once daily after breakfast'}
  ];

  List<Map<String, dynamic>> _vitalsHistory = [
    {'date': '2026-07-21', 'bp': '120/80', 'hr': 72, 'temp': 98.6, 'weight': 62.4},
    {'date': '2026-07-14', 'bp': '118/78', 'hr': 70, 'temp': 98.4, 'weight': 62.1}
  ];

  // Form Controllers
  final TextEditingController _bpController = TextEditingController(text: '120/80');
  final TextEditingController _hrController = TextEditingController(text: '72');
  final TextEditingController _tempController = TextEditingController(text: '98.6');
  final TextEditingController _weightController = TextEditingController(text: '62');

  final TextEditingController _medNameController = TextEditingController();
  final TextEditingController _medDoseController = TextEditingController();
  final TextEditingController _medFreqController = TextEditingController();

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
    
    final record = await SupabaseDbService.fetchMedicalRecord(widget.friendId);
    if (record != null) {
      setState(() {
        _recordId = record['id'];
        _diagnosis = record['clinical_notes'] ?? _diagnosis;
        _history = record['medical_history'] ?? _history;
        if (record['allergies'] != null) {
          _allergies = List<String>.from(record['allergies']);
        }
        if (record['vaccinations'] != null) {
          _vaccinations = List<String>.from(record['vaccinations']);
        }
        
        final List<dynamic> pres = record['medical_prescriptions'] ?? [];
        if (pres.isNotEmpty) {
          _prescriptions = pres.map((p) => {
            'date': p['date'] ?? '',
            'med': p['medication_name'] ?? '',
            'dose': p['dosage'] ?? '',
            'freq': p['frequency'] ?? '',
          }).toList();
        }

        final List<dynamic> vit = record['medical_vitals'] ?? [];
        if (vit.isNotEmpty) {
          _vitalsHistory = vit.map((v) => {
            'date': v['date']?.toString().substring(0, 10) ?? '',
            'bp': v['blood_pressure'] ?? '',
            'hr': v['heart_rate'] ?? 72,
            'temp': double.tryParse(v['temperature']?.toString() ?? '') ?? 98.6,
            'weight': double.tryParse(v['weight']?.toString() ?? '') ?? 62.0,
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
    _bpController.dispose();
    _hrController.dispose();
    _tempController.dispose();
    _weightController.dispose();
    _medNameController.dispose();
    _medDoseController.dispose();
    _medFreqController.dispose();
    super.dispose();
  }

  void _editAssessment() {
    final diagController = TextEditingController(text: _diagnosis);
    final histController = TextEditingController(text: _history);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Medical Assessment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: diagController, decoration: const InputDecoration(labelText: 'Diagnosis')),
            const SizedBox(height: 12),
            TextField(controller: histController, decoration: const InputDecoration(labelText: 'Medical History')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              setState(() {
                _diagnosis = diagController.text;
                _history = histController.text;
              });
              Navigator.pop(context);
              
              final record = await SupabaseDbService.saveMedicalRecord(widget.friendId, diagController.text, histController.text);
              if (record.containsKey('id')) {
                _recordId = record['id'];
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

  void _addVitals() async {
    if (_recordId == null) {
      final record = await SupabaseDbService.saveMedicalRecord(widget.friendId, _diagnosis, _history);
      _recordId = record['id'] ?? 'mock_medical_record_id';
    }

    if (_recordId != null) {
      final bp = _bpController.text;
      final hr = int.tryParse(_hrController.text) ?? 72;
      final temp = double.tryParse(_tempController.text) ?? 98.6;
      final w = double.tryParse(_weightController.text) ?? 62.0;

      await SupabaseDbService.addVitals(_recordId!, bp, hr, temp, w);
      
      setState(() {
        _vitalsHistory.insert(0, {
          'date': DateTime.now().toIso8601String().substring(0, 10),
          'bp': bp,
          'hr': hr,
          'temp': temp,
          'weight': w,
        });
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vitals updated successfully.'), backgroundColor: AppTheme.successColor),
      );
    }
  }

  void _addPrescription() async {
    if (_medNameController.text.isEmpty) return;
    
    if (_recordId == null) {
      final record = await SupabaseDbService.saveMedicalRecord(widget.friendId, _diagnosis, _history);
      _recordId = record['id'] ?? 'mock_medical_record_id';
    }

    if (_recordId != null) {
      final med = _medNameController.text;
      final dose = _medDoseController.text;
      final freq = _medFreqController.text;

      await SupabaseDbService.addPrescription(_recordId!, med, dose, freq);
      
      setState(() {
        _prescriptions.insert(0, {
          'date': DateTime.now().toIso8601String().substring(0, 10),
          'med': med,
          'dose': dose,
          'freq': freq,
        });
        _medNameController.clear();
        _medDoseController.clear();
        _medFreqController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prescription added successfully.'), backgroundColor: AppTheme.successColor),
      );
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

    if (widget.friendId == 'all') {
      return Scaffold(
        appBar: AppBar(title: const Text('Medical Records Directory')),
        body: ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final f = friends[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(backgroundImage: NetworkImage(f.photoUrl)),
                title: Text(f.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('History: Logged • Vitals: normal'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => MedicalDetailsScreen(friendId: f.id)),
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
    final canEditMedical = user?.role == 'principal' || user?.role == 'medical_officer';

    return Scaffold(
      appBar: AppBar(
        title: Text('${friend.fullName} - Medical Profile'),
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
            // Diagnosis & History
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
                              Icon(Icons.assignment, color: AppTheme.primaryColor),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Clinical History & Diagnosis',
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
                    _buildField('Primary Diagnosis', _diagnosis),
                    _buildField('Medical History Brief', _history),
                    _buildField('Blood Group', friend.bloodGroup),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Allergies & Alerts (High priority style)
            Card(
              color: AppTheme.errorColor.withOpacity(0.04),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppTheme.errorColor.withOpacity(0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.warning, color: AppTheme.errorColor),
                        SizedBox(width: 8),
                        Text('Allergies & Medical Alerts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.errorColor)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _allergies.map((allergy) {
                        return Chip(
                          backgroundColor: AppTheme.errorColor.withOpacity(0.1),
                          labelStyle: const TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold),
                          label: Text(allergy),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Vitals Tracking & History
            if (canEditMedical)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Update Vitals Checkup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: TextFormField(controller: _bpController, decoration: const InputDecoration(labelText: 'BP (e.g. 120/80)'))),
                          const SizedBox(width: 12),
                          Expanded(child: TextFormField(controller: _hrController, decoration: const InputDecoration(labelText: 'HR (bpm)'))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: TextFormField(controller: _tempController, decoration: const InputDecoration(labelText: 'Temp (°F)'))),
                          const SizedBox(width: 12),
                          Expanded(child: TextFormField(controller: _weightController, decoration: const InputDecoration(labelText: 'Weight (kg)'))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _addVitals, child: const Text('Record Vitals')),
                      
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 12),
                      const Text('Vitals History Logs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 12),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _vitalsHistory.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final v = _vitalsHistory[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Vitals check on ${v['date']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text('BP: ${v['bp']} • HR: ${v['hr']} bpm • Temp: ${v['temp']}°F • Weight: ${v['weight']} kg', style: const TextStyle(fontSize: 12)),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // Prescriptions & Meds
            if (canEditMedical)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Prescriptions & Medication', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 16),
                      TextFormField(controller: _medNameController, decoration: const InputDecoration(labelText: 'Medication Name')),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: TextFormField(controller: _medDoseController, decoration: const InputDecoration(labelText: 'Dosage'))),
                          const SizedBox(width: 12),
                          Expanded(child: TextFormField(controller: _medFreqController, decoration: const InputDecoration(labelText: 'Frequency'))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _addPrescription, child: const Text('Add Prescription')),

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 12),
                      const Text('Active Prescriptions History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 12),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _prescriptions.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final p = _prescriptions[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(p['med'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text('Dose: ${p['dose']} • Freq: ${p['freq']} • Prescribed: ${p['date']}', style: const TextStyle(fontSize: 12)),
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
