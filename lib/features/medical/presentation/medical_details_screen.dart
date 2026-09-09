import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/platform_file_viewer.dart';
import '../../../core/services/supabase_db_service.dart';
import '../../../core/storage/hive_storage.dart';
import '../../friends/presentation/friends_provider.dart';
import '../../friends/models/friend.dart';
import '../../auth/presentation/auth_providers.dart';

class MedicalDetailsScreen extends ConsumerStatefulWidget {
  final String friendId;
  const MedicalDetailsScreen({super.key, required this.friendId});

  @override
  ConsumerState<MedicalDetailsScreen> createState() => _MedicalDetailsScreenState();
}

class _MedicalDetailsScreenState extends ConsumerState<MedicalDetailsScreen> {
  late String _selectedFriendId;
  bool _isLoading = true;
  String? _recordId;
  String _diagnosis = '';
  String _history = '';
  List<String> _allergies = [];
  List<String> _vaccinations = [];
  List<Map<String, dynamic>> _prescriptions = [];
  List<Map<String, dynamic>> _vitalsHistory = [];

  // Vitals Controllers
  final TextEditingController _bpController = TextEditingController(text: '120/80');
  final TextEditingController _hrController = TextEditingController(text: '72');
  final TextEditingController _tempController = TextEditingController(text: '98.6');
  final TextEditingController _weightController = TextEditingController(text: '62.0');

  // Prescription Controllers
  final TextEditingController _medNameController = TextEditingController();
  final TextEditingController _medDoseController = TextEditingController();
  final TextEditingController _medFreqController = TextEditingController();

  String? _newPrescriptionFileName;
  Uint8List? _newPrescriptionFileBytes;
  bool _isUploadingFile = false;

  @override
  void initState() {
    super.initState();
    _selectedFriendId = widget.friendId;
    _loadFromDatabase(_selectedFriendId);
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

  Future<void> _loadFromDatabase(String friendId) async {
    if (friendId == 'all') {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    // 1. Load from Hive cache first
    final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
    final localVitals = box.get('vitals_$friendId');
    if (localVitals is List) {
      _vitalsHistory = List<Map<String, dynamic>>.from(localVitals.map((e) => Map<String, dynamic>.from(e as Map)));
    } else {
      _vitalsHistory = [];
    }

    final localPrescriptions = box.get('prescriptions_$friendId');
    if (localPrescriptions is List) {
      _prescriptions = List<Map<String, dynamic>>.from(localPrescriptions.map((e) => Map<String, dynamic>.from(e as Map)));
    } else {
      _prescriptions = [];
    }

    final localAllergies = box.get('medical_allergies_$friendId');
    if (localAllergies is List) {
      _allergies = List<String>.from(localAllergies.map((e) => e.toString()));
    } else {
      _allergies = [];
    }

    final localVaccines = box.get('medical_vaccines_$friendId');
    if (localVaccines is List) {
      _vaccinations = List<String>.from(localVaccines.map((e) => e.toString()));
    } else {
      _vaccinations = [];
    }

    final localRecord = box.get('medical_record_$friendId');
    if (localRecord is Map) {
      _diagnosis = localRecord['diagnosis']?.toString() ?? '';
      _history = localRecord['history']?.toString() ?? '';
    }

    // 2. Load from Supabase
    final record = await SupabaseDbService.fetchMedicalRecord(friendId);
    if (record != null) {
      if (mounted) {
        setState(() {
          _recordId = record['id'];
          if ((record['clinical_notes'] ?? '').toString().isNotEmpty) {
            _diagnosis = record['clinical_notes'];
          }
          if ((record['medical_history'] ?? '').toString().isNotEmpty) {
            _history = record['medical_history'];
          }
          if (record['allergies'] != null && (record['allergies'] as List).isNotEmpty) {
            _allergies = List<String>.from(record['allergies']);
            box.put('medical_allergies_$friendId', _allergies);
          }
          if (record['vaccinations'] != null && (record['vaccinations'] as List).isNotEmpty) {
            _vaccinations = List<String>.from(record['vaccinations']);
            box.put('medical_vaccines_$friendId', _vaccinations);
          }

          final List<dynamic> pres = record['medical_prescriptions'] ?? [];
          if (pres.isNotEmpty) {
            _prescriptions = pres.map((p) => {
              'date': p['date'] ?? '',
              'med': p['medication_name'] ?? '',
              'dose': p['dosage'] ?? '',
              'freq': p['frequency'] ?? '',
              'attachment_url': p['attachment_url'],
              'file_name': p['instructions'],
            }).toList();
            box.put('prescriptions_$friendId', _prescriptions);
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
            box.put('vitals_$friendId', _vitalsHistory);
          }

          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showFilePreview(String url, String fileName) {
    if (url.toLowerCase().endsWith('.pdf')) {
      openPlatformFile(fileUrl: url, fileName: fileName, fileType: 'pdf');
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, stack) => Container(
                    color: Colors.grey.shade900,
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.picture_as_pdf, color: Colors.white, size: 48),
                        const SizedBox(height: 12),
                        Text(fileName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Open Document'),
                          onPressed: () => openPlatformFile(fileUrl: url, fileName: fileName, fileType: 'pdf'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const CircleAvatar(backgroundColor: Colors.black54, child: Icon(Icons.close, color: Colors.white, size: 18)),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _editAssessment() {
    final diagController = TextEditingController(text: _diagnosis);
    final histController = TextEditingController(text: _history);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Clinical Assessment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: diagController, decoration: const InputDecoration(labelText: 'Primary Diagnosis', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: histController, maxLines: 3, decoration: const InputDecoration(labelText: 'Medical History Brief', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              setState(() {
                _diagnosis = diagController.text.trim();
                _history = histController.text.trim();
              });
              Navigator.pop(context);

              // Cache to Hive
              final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
              await box.put('medical_record_$_selectedFriendId', {
                'diagnosis': _diagnosis,
                'history': _history,
              });

              final record = await SupabaseDbService.saveMedicalRecord(_selectedFriendId, diagController.text.trim(), histController.text.trim());
              if (record.containsKey('id')) {
                _recordId = record['id'];
              }
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Clinical assessment saved successfully.'), backgroundColor: AppTheme.successColor),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddAllergyDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor),
            SizedBox(width: 8),
            Text('Add Allergy / Medical Alert', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter allergy, dietary restriction, or acute medical alert:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Allergy / Alert',
                hintText: 'e.g. Penicillin, Peanuts, Asthma Trigger',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor, foregroundColor: Colors.white),
            onPressed: () async {
              final val = controller.text.trim();
              if (val.isEmpty) return;
              Navigator.pop(ctx);
              setState(() {
                _allergies.add(val);
              });
              final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
              await box.put('medical_allergies_$_selectedFriendId', _allergies);
              await SupabaseDbService.updateMedicalAllergiesAndVaccines(_selectedFriendId, _allergies, _vaccinations);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Allergy "$val" added!'), backgroundColor: AppTheme.successColor),
                );
              }
            },
            child: const Text('Add Alert'),
          ),
        ],
      ),
    );
  }

  void _showAddVaccinationDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.vaccines_outlined, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('Add Immunization / Vaccine', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter vaccination record or booster title:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Vaccination / Booster',
                hintText: 'e.g. COVID-19 Booster, Tetanus, Hepatitis B',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final val = controller.text.trim();
              if (val.isEmpty) return;
              Navigator.pop(ctx);
              setState(() {
                _vaccinations.add(val);
              });
              final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
              await box.put('medical_vaccines_$_selectedFriendId', _vaccinations);
              await SupabaseDbService.updateMedicalAllergiesAndVaccines(_selectedFriendId, _allergies, _vaccinations);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Vaccination "$val" added!'), backgroundColor: AppTheme.successColor),
                );
              }
            },
            child: const Text('Add Vaccine'),
          ),
        ],
      ),
    );
  }

  void _deleteAllergy(int index) async {
    final removed = _allergies.removeAt(index);
    setState(() {});
    final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
    await box.put('medical_allergies_$_selectedFriendId', _allergies);
    await SupabaseDbService.updateMedicalAllergiesAndVaccines(_selectedFriendId, _allergies, _vaccinations);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed "$removed"')),
      );
    }
  }

  void _deleteVaccination(int index) async {
    final removed = _vaccinations.removeAt(index);
    setState(() {});
    final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
    await box.put('medical_vaccines_$_selectedFriendId', _vaccinations);
    await SupabaseDbService.updateMedicalAllergiesAndVaccines(_selectedFriendId, _allergies, _vaccinations);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed "$removed"')),
      );
    }
  }

  void _addVitals() async {
    final bp = _bpController.text.trim();
    final hr = int.tryParse(_hrController.text.trim()) ?? 72;
    final temp = double.tryParse(_tempController.text.trim()) ?? 98.6;
    final weight = double.tryParse(_weightController.text.trim()) ?? 62.0;

    final newEntry = {
      'date': DateTime.now().toIso8601String().substring(0, 10),
      'bp': bp,
      'hr': hr,
      'temp': temp,
      'weight': weight,
    };

    setState(() {
      _vitalsHistory.insert(0, newEntry);
    });

    // Save to Hive
    final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
    await box.put('vitals_$_selectedFriendId', _vitalsHistory);

    // Save to Supabase
    if (SupabaseDbService.isConfigured) {
      if (_recordId == null) {
        final rec = await SupabaseDbService.saveMedicalRecord(_selectedFriendId, _diagnosis, _history);
        if (rec.containsKey('id')) _recordId = rec['id'];
      }
      if (_recordId != null) {
        await SupabaseDbService.addVitals(_recordId!, bp, hr, temp, weight);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vitals check recorded successfully.'), backgroundColor: AppTheme.successColor),
      );
    }
  }

  void _pickPrescriptionFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        Uint8List? bytes = file.bytes;
        if (bytes == null && file.path != null && !kIsWeb) {
          bytes = await File(file.path!).readAsBytes();
        }
        setState(() {
          _newPrescriptionFileName = file.name;
          _newPrescriptionFileBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('Error picking prescription file: $e');
    }
  }

  void _addPrescription() async {
    final med = _medNameController.text.trim();
    final dose = _medDoseController.text.trim();
    final freq = _medFreqController.text.trim();

    if (med.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a medication name.')),
      );
      return;
    }

    setState(() => _isUploadingFile = true);
    String? uploadedUrl;

    if (_newPrescriptionFileBytes != null && SupabaseDbService.isConfigured) {
      try {
        uploadedUrl = await SupabaseDbService.uploadFile(
          'medical-records',
          _newPrescriptionFileName ?? 'prescription_${DateTime.now().millisecondsSinceEpoch}.jpg',
          _newPrescriptionFileBytes!,
        );
      } catch (e) {
        debugPrint('Error uploading prescription document: $e');
      }
    }

    final newEntry = {
      'date': DateTime.now().toIso8601String().substring(0, 10),
      'med': med,
      'dose': dose,
      'freq': freq,
      'attachment_url': uploadedUrl,
      'file_name': _newPrescriptionFileName,
    };

    setState(() {
      _prescriptions.insert(0, newEntry);
      _medNameController.clear();
      _medDoseController.clear();
      _medFreqController.clear();
      _newPrescriptionFileName = null;
      _newPrescriptionFileBytes = null;
      _isUploadingFile = false;
    });

    // Save to Hive
    final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
    await box.put('prescriptions_$_selectedFriendId', _prescriptions);

    // Save to Supabase
    if (SupabaseDbService.isConfigured) {
      if (_recordId == null) {
        final rec = await SupabaseDbService.saveMedicalRecord(_selectedFriendId, _diagnosis, _history);
        if (rec.containsKey('id')) _recordId = rec['id'];
      }
      if (_recordId != null) {
        try {
          await Supabase.instance.client.from('medical_prescriptions').insert({
            'record_id': _recordId,
            'date': DateTime.now().toIso8601String().substring(0, 10),
            'medication_name': med,
            'dosage': dose,
            'frequency': freq,
            'duration': '30 days',
            'attachment_url': uploadedUrl,
            'instructions': _newPrescriptionFileName,
          });
        } catch (e) {
          debugPrint('Error saving prescription to Supabase: $e');
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prescription and attachment saved successfully.'), backgroundColor: AppTheme.successColor),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);
    final user = ref.read(authProvider).user;
    final isMedicalOfficer = user?.role == 'medical_officer';
    final isPrincipalOrAdmin = user?.role == 'principal' || user?.role == 'admin';
    final canEditMedical = isMedicalOfficer; // Only medical officer can record/edit

    // Current friend
    Friend? currentFriend;
    if (_selectedFriendId != 'all') {
      currentFriend = friends.where((f) => f.id == _selectedFriendId).firstOrNull ?? (friends.isNotEmpty ? friends.first : null);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clinical Medical Dossier'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go(isMedicalOfficer ? '/dashboard/medical' : '/dashboard/principal');
            }
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Role Status Banner
                  _buildRoleBanner(isMedicalOfficer, isPrincipalOrAdmin, user?.fullName ?? 'User'),
                  const SizedBox(height: 16),

                  // 2. Beneficiary Selector Card
                  Card(
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Select Beneficiary Health Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                    // Friend Header Info Card
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
                              backgroundColor: Colors.red.withValues(alpha: 0.1),
                              child: getAppImageProvider(currentFriend.photoUrl) == null
                                  ? Text(currentFriend.fullName[0], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red))
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
                                    'ID: ${currentFriend.registrationNumber} • Blood: ${currentFriend.bloodGroup} • House: ${currentFriend.assignedHouseId.replaceAll('_', ' ').toUpperCase()}',
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

                    // 3. Clinical History & Diagnosis Card
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
                                    Icon(Icons.assignment_outlined, color: AppTheme.primaryColor),
                                    SizedBox(width: 8),
                                    Text('Clinical History & Diagnosis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                                if (canEditMedical)
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: AppTheme.primaryColor),
                                    tooltip: 'Edit Diagnosis',
                                    onPressed: _editAssessment,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _buildField('Primary Clinical Diagnosis', _diagnosis.isNotEmpty ? _diagnosis : 'Pending clinical diagnosis by medical officer.'),
                            _buildField('Medical History Summary', _history.isNotEmpty ? _history : 'No previous medical history recorded on file.'),
                            _buildField('Blood Group / Factor', currentFriend.bloodGroup.isNotEmpty ? currentFriend.bloodGroup : 'Not specified'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 4. Allergies & Medical Alerts Card
                    Card(
                      elevation: 2,
                      color: AppTheme.errorColor.withValues(alpha: 0.04),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: AppTheme.errorColor.withValues(alpha: 0.3)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 500;
                                final titleWidget = const Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Allergies & High-Priority Alerts',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.errorColor),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                );

                                if (isNarrow) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      titleWidget,
                                      if (canEditMedical) ...[
                                        const SizedBox(height: 8),
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.add_alert, size: 14),
                                          label: const Text('Add Alert', style: TextStyle(fontSize: 12)),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.errorColor,
                                            side: const BorderSide(color: AppTheme.errorColor),
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          ),
                                          onPressed: _showAddAllergyDialog,
                                        ),
                                      ],
                                    ],
                                  );
                                }

                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: titleWidget),
                                    if (canEditMedical) ...[
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.add_alert, size: 14),
                                        label: const Text('Add Alert', style: TextStyle(fontSize: 12)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.errorColor,
                                          side: const BorderSide(color: AppTheme.errorColor),
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        ),
                                        onPressed: _showAddAllergyDialog,
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            if (_allergies.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text('No known allergies or high-priority medical alerts recorded.', style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _allergies.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final allergy = entry.value;
                                  return Chip(
                                    backgroundColor: AppTheme.errorColor.withValues(alpha: 0.1),
                                    labelStyle: const TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold),
                                    label: Text(allergy),
                                    deleteIcon: canEditMedical ? const Icon(Icons.close, size: 14, color: AppTheme.errorColor) : null,
                                    onDeleted: canEditMedical ? () => _deleteAllergy(index) : null,
                                  );
                                }).toList(),
                              ),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 500;
                                final titleWidget = const Row(
                                  children: [
                                    Icon(Icons.vaccines_outlined, color: AppTheme.primaryColor, size: 20),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Immunizations & Vaccinations',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                );

                                if (isNarrow) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      titleWidget,
                                      if (canEditMedical) ...[
                                        const SizedBox(height: 8),
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.add, size: 14),
                                          label: const Text('Add Vaccine', style: TextStyle(fontSize: 12)),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.primaryColor,
                                            side: const BorderSide(color: AppTheme.primaryColor),
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          ),
                                          onPressed: _showAddVaccinationDialog,
                                        ),
                                      ],
                                    ],
                                  );
                                }

                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: titleWidget),
                                    if (canEditMedical) ...[
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.add, size: 14),
                                        label: const Text('Add Vaccine', style: TextStyle(fontSize: 12)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.primaryColor,
                                          side: const BorderSide(color: AppTheme.primaryColor),
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        ),
                                        onPressed: _showAddVaccinationDialog,
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            if (_vaccinations.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text('No immunizations or vaccination records on file.', style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _vaccinations.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final vax = entry.value;
                                  return Chip(
                                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.08),
                                    labelStyle: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                                    label: Text(vax),
                                    deleteIcon: canEditMedical ? const Icon(Icons.close, size: 14, color: AppTheme.primaryColor) : null,
                                    onDeleted: canEditMedical ? () => _deleteVaccination(index) : null,
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 5. Prescriptions & Medication Management Card (with Uploads!)
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
                                const Expanded(
                                  child: Row(
                                    children: [
                                      Icon(Icons.medication_outlined, color: AppTheme.primaryColor),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Prescriptions & Medication Management',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!canEditMedical)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    margin: const EdgeInsets.only(left: 8),
                                    decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                    child: const Text('Read-Only', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Edit form for Medical Officer
                            if (canEditMedical) ...[
                              TextFormField(controller: _medNameController, decoration: const InputDecoration(labelText: 'Medication Name', border: OutlineInputBorder())),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: TextFormField(controller: _medDoseController, decoration: const InputDecoration(labelText: 'Dosage (e.g. 10mg / 1 puff)', border: OutlineInputBorder()))),
                                  const SizedBox(width: 12),
                                  Expanded(child: TextFormField(controller: _medFreqController, decoration: const InputDecoration(labelText: 'Frequency (e.g. Twice Daily)', border: OutlineInputBorder()))),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Upload Prescription File Button / Badge
                              if (_newPrescriptionFileName != null)
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.attach_file, color: Colors.green),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Attached: $_newPrescriptionFileName',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 16, color: Colors.red),
                                        onPressed: () => setState(() {
                                          _newPrescriptionFileName = null;
                                          _newPrescriptionFileBytes = null;
                                        }),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text('Attach Prescription Document / Scan (PDF or Image)'),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppTheme.primaryColor),
                                    minimumSize: const Size(double.infinity, 42),
                                  ),
                                  onPressed: _pickPrescriptionFile,
                                ),
                              const SizedBox(height: 14),

                              ElevatedButton.icon(
                                icon: _isUploadingFile
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.add),
                                label: const Text('Record Prescription'),
                                onPressed: _isUploadingFile ? null : _addPrescription,
                              ),
                              const SizedBox(height: 20),
                              const Divider(),
                              const SizedBox(height: 12),
                            ],

                            // Active Prescriptions List
                            const Text('Active Prescriptions History & Documents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 12),
                            if (_prescriptions.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('No active prescriptions recorded for this beneficiary.', style: TextStyle(color: Colors.grey)),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _prescriptions.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final p = _prescriptions[index];
                                  final attachUrl = p['attachment_url']?.toString();
                                  final fileName = p['file_name']?.toString() ?? 'prescription_${p['date']}.pdf';

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                    leading: const CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Colors.purple,
                                      child: Icon(Icons.medication, color: Colors.white, size: 18),
                                    ),
                                    title: Text(p['med'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    subtitle: Text('Dose: ${p['dose']} • Frequency: ${p['freq']} • Prescribed: ${p['date']}', style: const TextStyle(fontSize: 12)),
                                    trailing: attachUrl != null && attachUrl.isNotEmpty
                                        ? ElevatedButton.icon(
                                            icon: const Icon(Icons.visibility, size: 14),
                                            label: const Text('View Scan', style: TextStyle(fontSize: 11)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.primaryColor,
                                              foregroundColor: Colors.white,
                                              visualDensity: VisualDensity.compact,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            ),
                                            onPressed: () => _showFilePreview(attachUrl, fileName),
                                          )
                                        : null,
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 6. Routine Vitals Tracking & History
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
                                const Expanded(
                                  child: Row(
                                    children: [
                                      Icon(Icons.monitor_heart_outlined, color: Colors.redAccent),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Vitals Checks & Logs',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!canEditMedical)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    margin: const EdgeInsets.only(left: 8),
                                    decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                    child: const Text('Read-Only', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            if (canEditMedical) ...[
                              Row(
                                children: [
                                  Expanded(child: TextFormField(controller: _bpController, decoration: const InputDecoration(labelText: 'BP (e.g. 120/80)', border: OutlineInputBorder()))),
                                  const SizedBox(width: 12),
                                  Expanded(child: TextFormField(controller: _hrController, decoration: const InputDecoration(labelText: 'HR (bpm)', border: OutlineInputBorder()))),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: TextFormField(controller: _tempController, decoration: const InputDecoration(labelText: 'Temp (°F)', border: OutlineInputBorder()))),
                                  const SizedBox(width: 12),
                                  Expanded(child: TextFormField(controller: _weightController, decoration: const InputDecoration(labelText: 'Weight (kg)', border: OutlineInputBorder()))),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton(onPressed: _addVitals, child: const Text('Record Vitals')),
                              const SizedBox(height: 20),
                              const Divider(),
                              const SizedBox(height: 12),
                            ],

                            const Text('Vitals History Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 12),
                            if (_vitalsHistory.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('No vitals records logged yet.', style: TextStyle(color: Colors.grey)),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _vitalsHistory.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final v = _vitalsHistory[index];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.redAccent,
                                      child: Icon(Icons.favorite, color: Colors.white, size: 16),
                                    ),
                                    title: Text('Vitals check: ${v['date']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    subtitle: Text(
                                      'BP: ${v['bp']} • HR: ${v['hr']} bpm • Temp: ${v['temp']}°F • Weight: ${v['weight']} kg',
                                      style: const TextStyle(fontSize: 12),
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

  Widget _buildRoleBanner(bool isMedicalOfficer, bool isPrincipalOrAdmin, String userName) {
    if (isMedicalOfficer) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.medical_services_outlined, color: Colors.red.shade700, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Signed in as Medical Officer ($userName). You have full authorization to record vitals, diagnosis, and upload prescriptions.',
                style: TextStyle(color: Colors.red.shade900, fontSize: 13, fontWeight: FontWeight.w500),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          final titleCol = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Principal / Administrative Oversight Console (Read-Only Mode)',
                style: TextStyle(color: Color(0xFF1E3A8A), fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                'Reviewing complete medical dossier, clinical diagnoses, vitals trends, and uploaded prescription documents.',
                style: TextStyle(color: Colors.blueGrey.shade800, fontSize: 12),
              ),
            ],
          );

          final readOnlyBadge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E40AF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'READ ONLY',
              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.visibility_outlined, color: Color(0xFF1D4ED8), size: 22),
                    readOnlyBadge,
                  ],
                ),
                const SizedBox(height: 8),
                titleCol,
              ],
            );
          }

          return Row(
            children: [
              const Icon(Icons.visibility_outlined, color: Color(0xFF1D4ED8), size: 22),
              const SizedBox(width: 10),
              Expanded(child: titleCol),
              const SizedBox(width: 12),
              readOnlyBadge,
            ],
          );
        },
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
