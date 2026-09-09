import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/shared/widgets/responsive_layout.dart';
import '../../../core/theme/theme.dart';
import '../../../core/localization/localization.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/services/supabase_db_service.dart';
import '../../../core/storage/hive_storage.dart';
import '../../friends/presentation/friends_provider.dart';
import '../../friends/models/friend.dart';
import '../../auth/presentation/auth_providers.dart';

class MedicalDashboardScreen extends ConsumerStatefulWidget {
  const MedicalDashboardScreen({super.key});

  @override
  ConsumerState<MedicalDashboardScreen> createState() => _MedicalDashboardScreenState();
}

class _MedicalDashboardScreenState extends ConsumerState<MedicalDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _workshopFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showQuickVitalsModal(BuildContext context, Friend friend) {
    final bpController = TextEditingController(text: '120/80');
    final hrController = TextEditingController(text: '72');
    final tempController = TextEditingController(text: '98.6');
    final weightController = TextEditingController(text: '62.0');
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.monitor_heart, color: Colors.redAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Record Vitals: ${friend.fullName}', style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Blood Group: ${friend.bloodGroup} • ID: ${friend.registrationNumber}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: TextField(controller: bpController, decoration: const InputDecoration(labelText: 'BP (e.g. 120/80)', border: OutlineInputBorder()))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: hrController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'HR (bpm)', border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: tempController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Temp (°F)', border: OutlineInputBorder()))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: weightController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Weight (kg)', border: OutlineInputBorder()))),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              icon: isSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check, size: 16),
              label: const Text('Save Vitals'),
              onPressed: isSaving
                  ? null
                  : () async {
                      setModalState(() => isSaving = true);
                      final bp = bpController.text.trim();
                      final hr = int.tryParse(hrController.text.trim()) ?? 72;
                      final temp = double.tryParse(tempController.text.trim()) ?? 98.6;
                      final weight = double.tryParse(weightController.text.trim()) ?? 62.0;

                      // Save to Hive
                      final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
                      final log = {
                        'friend_id': friend.id,
                        'date': DateTime.now().toIso8601String().substring(0, 10),
                        'bp': bp,
                        'hr': hr,
                        'temp': temp,
                        'weight': weight,
                      };
                      final List<dynamic> history = box.get('vitals_${friend.id}') ?? [];
                      history.insert(0, log);
                      await box.put('vitals_${friend.id}', history);

                      // Save to Supabase
                      if (SupabaseDbService.isConfigured) {
                        try {
                          final rec = await SupabaseDbService.fetchMedicalRecord(friend.id);
                          String recordId = rec?['id'] ?? '';
                          if (recordId.isEmpty) {
                            final created = await SupabaseDbService.saveMedicalRecord(friend.id, friend.medicalNotesSummary, 'Regular clinical monitoring');
                            recordId = created['id'] ?? '';
                          }
                          if (recordId.isNotEmpty) {
                            await SupabaseDbService.addVitals(recordId, bp, hr, temp, weight);
                          }
                        } catch (e) {
                          debugPrint('Error saving vitals to Supabase: $e');
                        }
                      }

                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (mounted) {
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Vitals recorded for ${friend.fullName}!'), backgroundColor: AppTheme.successColor),
                        );
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickPrescriptionModal(BuildContext context, Friend friend) {
    final medController = TextEditingController();
    final doseController = TextEditingController();
    final freqController = TextEditingController();
    String? attachedFileName;
    Uint8List? attachedFileBytes;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.medication, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Add Prescription: ${friend.fullName}', style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: medController, decoration: const InputDecoration(labelText: 'Medication Name', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: doseController, decoration: const InputDecoration(labelText: 'Dosage (e.g. 10mg / 1 tab)', border: OutlineInputBorder()))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: freqController, decoration: const InputDecoration(labelText: 'Frequency (e.g. Twice daily)', border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Prescription Document / Scan (PDF or Image):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                if (attachedFileName != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.attach_file, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(child: Text(attachedFileName!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis)),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16, color: Colors.red),
                          onPressed: () {
                            setModalState(() {
                              attachedFileName = null;
                              attachedFileBytes = null;
                            });
                          },
                        ),
                      ],
                    ),
                  )
                else
                  OutlinedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload Prescription Document / Photo'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primaryColor),
                      minimumSize: const Size(double.infinity, 40),
                    ),
                    onPressed: () async {
                      try {
                        final result = await FilePicker.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                          withData: true,
                        );
                        if (result != null && result.files.isNotEmpty) {
                          final f = result.files.first;
                          Uint8List? bytes = f.bytes;
                          if (bytes == null && f.path != null && !kIsWeb) {
                            bytes = await File(f.path!).readAsBytes();
                          }
                          setModalState(() {
                            attachedFileName = f.name;
                            attachedFileBytes = bytes;
                          });
                        }
                      } catch (e) {
                        debugPrint('File picker error: $e');
                      }
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              icon: isSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check, size: 16),
              label: const Text('Save Prescription'),
              onPressed: isSaving
                  ? null
                  : () async {
                      final med = medController.text.trim();
                      final dose = doseController.text.trim();
                      final freq = freqController.text.trim();
                      if (med.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter medication name.')));
                        return;
                      }

                      setModalState(() => isSaving = true);
                      String? uploadedUrl;

                      // Upload file to Supabase if attached
                      if (attachedFileBytes != null && SupabaseDbService.isConfigured) {
                        try {
                          uploadedUrl = await SupabaseDbService.uploadFile(
                            'medical-records',
                            attachedFileName ?? 'prescription_${DateTime.now().millisecondsSinceEpoch}.jpg',
                            attachedFileBytes!,
                          );
                        } catch (e) {
                          debugPrint('Error uploading prescription file: $e');
                        }
                      }

                      // Save to Hive
                      final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
                      final pres = {
                        'friend_id': friend.id,
                        'date': DateTime.now().toIso8601String().substring(0, 10),
                        'med': med,
                        'dose': dose,
                        'freq': freq,
                        'attachment_url': uploadedUrl,
                        'file_name': attachedFileName,
                      };
                      final List<dynamic> localPres = box.get('prescriptions_${friend.id}') ?? [];
                      localPres.insert(0, pres);
                      await box.put('prescriptions_${friend.id}', localPres);

                      // Save to Supabase
                      if (SupabaseDbService.isConfigured) {
                        try {
                          final rec = await SupabaseDbService.fetchMedicalRecord(friend.id);
                          String recordId = rec?['id'] ?? '';
                          if (recordId.isEmpty) {
                            final created = await SupabaseDbService.saveMedicalRecord(friend.id, friend.medicalNotesSummary, 'Regular monitoring');
                            recordId = created['id'] ?? '';
                          }
                          if (recordId.isNotEmpty) {
                            await Supabase.instance.client.from('medical_prescriptions').insert({
                              'record_id': recordId,
                              'date': DateTime.now().toIso8601String().substring(0, 10),
                              'medication_name': med,
                              'dosage': dose,
                              'frequency': freq,
                              'duration': '30 days',
                              'attachment_url': uploadedUrl,
                            });
                          }
                        } catch (e) {
                          debugPrint('Error saving prescription to Supabase: $e');
                        }
                      }

                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (mounted) {
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Prescription recorded for ${friend.fullName}!'), backgroundColor: AppTheme.successColor),
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
    final isMedicalOfficer = user?.role == 'medical_officer';
    final isPrincipalOrAdmin = user?.role == 'principal' || user?.role == 'admin';

    final filtered = friends.where((f) {
      final matchesSearch = f.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          f.registrationNumber.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesWorkshop = _workshopFilter == 'all' || f.assignedWorkshopId == _workshopFilter;
      return matchesSearch && matchesWorkshop;
    }).toList();

    return ResponsiveLayout(
      title: 'Medical & Clinical Health Console',
      currentRoute: '/dashboard/medical',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Banner
            _buildHeaderBanner(context, user?.fullName ?? 'Medical Officer', isMedicalOfficer, isPrincipalOrAdmin),
            const SizedBox(height: 20),

            // 2. Metrics Overview Row
            _buildKpiSummaryRow(friends),
            const SizedBox(height: 20),

            // 3. High-Priority Alerts Banner
            _buildCriticalAlertsCard(friends),
            const SizedBox(height: 24),

            // 4. Search & Filter Bar
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

            // 5. Beneficiaries Medical Directory
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Beneficiaries Medical & Health Directory',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Showing ${filtered.length} of ${friends.length} registered beneficiaries health profiles.',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (isPrincipalOrAdmin) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.red.shade300),
                            ),
                            child: const Text('Oversight View', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)),
                          ),
                        ],
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
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 600;
                                final avatar = CircleAvatar(
                                  radius: 24,
                                  backgroundImage: provider,
                                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                                  child: provider == null
                                      ? Text(friend.fullName[0], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red))
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
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.red.shade200),
                                          ),
                                          child: Text(
                                            'Blood: ${friend.bloodGroup}',
                                            style: TextStyle(fontSize: 10, color: Colors.red.shade900, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'ID: ${friend.registrationNumber} • House: ${friend.assignedHouseId.replaceAll('_', ' ').toUpperCase()} • Workshop: ${localizations.translate(friend.assignedWorkshopId)}',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    ),
                                    const SizedBox(height: 6),
                                    Builder(
                                      builder: (context) {
                                        final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
                                        final localAllergies = box.get('medical_allergies_${friend.id}') as List<dynamic>? ?? [];
                                        final localVitals = box.get('vitals_${friend.id}') as List<dynamic>? ?? [];
                                        final localPrescriptions = box.get('prescriptions_${friend.id}') as List<dynamic>? ?? [];
                                        final localRec = box.get('medical_record_${friend.id}');

                                        final diagStr = (localRec is Map && (localRec['diagnosis'] ?? '').toString().isNotEmpty)
                                            ? localRec['diagnosis'].toString()
                                            : (friend.medicalNotesSummary.isNotEmpty ? friend.medicalNotesSummary : 'General Monitoring');

                                        return Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            _buildBadge(
                                              localAllergies.isNotEmpty ? 'Alerts: ${localAllergies.length}' : 'No Allergies',
                                              localAllergies.isNotEmpty ? Colors.red : Colors.teal,
                                            ),
                                            _buildBadge('Vitals: ${localVitals.length} logs', Colors.blue),
                                            _buildBadge('Rx: ${localPrescriptions.length} active', Colors.purple),
                                            _buildBadge(diagStr.length > 22 ? '${diagStr.substring(0, 22)}...' : diagStr, Colors.amber),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                );

                                final actionButtons = Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (isMedicalOfficer || isPrincipalOrAdmin) ...[
                                      IconButton(
                                        icon: const Icon(Icons.monitor_heart_outlined, color: Colors.redAccent),
                                        tooltip: 'Record Vitals',
                                        onPressed: () => _showQuickVitalsModal(context, friend),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.upload_file_outlined, color: AppTheme.primaryColor),
                                        tooltip: 'Upload Prescription',
                                        onPressed: () => _showQuickPrescriptionModal(context, friend),
                                      ),
                                    ],
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.visibility_outlined, size: 14),
                                      label: Text(isPrincipalOrAdmin ? 'Inspect Dossier' : 'Full Chart', style: const TextStyle(fontSize: 12)),
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                      onPressed: () => context.push('/medical/${friend.id}'),
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

  Widget _buildHeaderBanner(BuildContext context, String userName, bool isMedicalOfficer, bool isPrincipalOrAdmin) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB71C1C), Color(0xFFD32F2F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.25),
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
              Icon(Icons.medical_services, color: Colors.white, size: 32),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Medical & Clinical Health Portal',
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
              isMedicalOfficer ? 'Medical Officer ($userName)' : 'Clinical Oversight View',
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
                'Maintain comprehensive clinical records, track routine vitals checkups, upload prescription documents & medical scans, and oversee urgent health alerts.',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCriticalAlertsCard(List<Friend> friends) {
    final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
    final List<Map<String, dynamic>> activeAlerts = [];

    for (final f in friends) {
      final rawAllergies = box.get('medical_allergies_${f.id}');
      if (rawAllergies is List && rawAllergies.isNotEmpty) {
        activeAlerts.add({
          'name': f.fullName,
          'blood': f.bloodGroup,
          'alerts': rawAllergies.map((e) => e.toString()).toList(),
        });
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: activeAlerts.isNotEmpty ? Colors.amber.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: activeAlerts.isNotEmpty ? Colors.amber.shade300 : Colors.blue.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            activeAlerts.isNotEmpty ? Icons.warning_amber_rounded : Icons.health_and_safety_outlined,
            color: activeAlerts.isNotEmpty ? Colors.amber.shade900 : Colors.blue.shade800,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'High-Priority Medical Alerts & Allergies',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: activeAlerts.isNotEmpty ? Colors.amber.shade900 : Colors.blue.shade900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                if (activeAlerts.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: activeAlerts.map((item) {
                      final name = item['name'];
                      final blood = item['blood'];
                      final alerts = (item['alerts'] as List<String>).join(', ');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text(
                          '• $name (Blood $blood): $alerts',
                          style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF78350F), fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                  )
                else
                  const Text(
                    'No high-priority medical alerts or drug allergies flagged across the current roster. Maintain regular vitals checks.',
                    style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF1E3A8A)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSummaryRow(List<Friend> friends) {
    final count = friends.length;
    final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);

    int totalAlerts = 0;
    int totalPrescriptions = 0;
    int totalVitals = 0;

    for (final f in friends) {
      final rawAllergies = box.get('medical_allergies_${f.id}');
      if (rawAllergies is List) totalAlerts += rawAllergies.length;

      final rawPres = box.get('prescriptions_${f.id}');
      if (rawPres is List) totalPrescriptions += rawPres.length;

      final rawVitals = box.get('vitals_${f.id}');
      if (rawVitals is List) totalVitals += rawVitals.length;
    }

    final cards = [
      _buildKpiCard('Beneficiaries', '$count Monitored', Icons.groups_outlined, Colors.red.shade700),
      _buildKpiCard('Medical Alerts', '$totalAlerts Active Flags', Icons.crisis_alert, Colors.orange.shade800),
      _buildKpiCard('Vitals Logged', '$totalVitals Checks', Icons.monitor_heart_outlined, Colors.blue.shade700),
      _buildKpiCard('Prescriptions', '$totalPrescriptions Active', Icons.receipt_long_outlined, Colors.green.shade700),
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
