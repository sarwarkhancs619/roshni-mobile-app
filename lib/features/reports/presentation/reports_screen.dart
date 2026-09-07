import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import '../../../core/shared/widgets/responsive_layout.dart';
import '../../../core/theme/theme.dart';
import '../../../core/localization/localization.dart';
import '../../friends/presentation/friends_provider.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../auth/models/app_user.dart';
import '../../friends/models/friend.dart';
import 'widgets/executive_report_view.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _selectedReportType = 'friend_summary';
  String? _selectedFriendId;
  String _selectedFormat = 'pdf';

  Future<Uint8List> _generatePdfReport(List<Friend> friends, String scopeText) async {
    final pdf = pw.Document();
    
    Friend? targetFriend;
    if (_selectedFriendId != null) {
      try {
        targetFriend = friends.firstWhere((f) => f.id == _selectedFriendId);
      } catch (_) {}
    }
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Roshni Association (RAMS) Report System', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                  pw.Text('Date: ${DateTime.now().toIso8601String().substring(0, 10)}'),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Report Category: ${_selectedReportType.replaceAll('_', ' ').toUpperCase()}$scopeText',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            pw.SizedBox(height: 10),
            
            if (targetFriend != null) ...[
              pw.Text('Target Profile Details:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.SizedBox(height: 8),
              pw.Bullet(text: 'Full Name: ${targetFriend.fullName}'),
              pw.Bullet(text: 'Registration Number: ${targetFriend.registrationNumber}'),
              pw.Bullet(text: 'Assigned Workshop: ${targetFriend.assignedWorkshopId.toUpperCase()}'),
              pw.Bullet(text: 'Assigned House: ${targetFriend.assignedHouseId.toUpperCase()}'),
              pw.Bullet(text: 'Gender: ${targetFriend.gender.toUpperCase()}'),
              pw.Bullet(text: 'Blood Group: ${targetFriend.bloodGroup}'),
              pw.Bullet(text: 'Admission Date: ${targetFriend.admissionDate.toIso8601String().substring(0, 10)}'),
              pw.Bullet(text: 'Guardian: ${targetFriend.guardianName} (${targetFriend.guardianPhone})'),
              pw.Bullet(text: 'Status: ${targetFriend.status.toUpperCase()}'),
              if (targetFriend.medicalNotesSummary.isNotEmpty)
                pw.Bullet(text: 'Medical Notes: ${targetFriend.medicalNotesSummary}'),
            ] else ...[
              pw.Text('Registered Friends Profiles:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.SizedBox(height: 8),
              for (var f in friends) 
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Text('${f.registrationNumber} - ${f.fullName} (Workshop: ${f.assignedWorkshopId.toUpperCase()} | House: ${f.assignedHouseId.toUpperCase()})'),
                ),
            ],
            pw.SizedBox(height: 30),
            pw.Divider(),
            pw.Align(
              alignment: pw.Alignment.center,
              child: pw.Text('End of Official Report - Generated Digitally by RAMS System', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
            ),
          ];
        },
      ),
    );
    return pdf.save();
  }

  Uint8List _generateCsvReport(List<Friend> friends) {
    final List<List<dynamic>> rows = [
      ['Registration Number', 'Full Name', 'Workshop ID', 'House ID', 'Gender', 'Blood Group', 'Admission Date', 'Status']
    ];
    
    if (_selectedFriendId != null) {
      try {
        final f = friends.firstWhere((f) => f.id == _selectedFriendId);
        rows.add([
          f.registrationNumber,
          f.fullName,
          f.assignedWorkshopId,
          f.assignedHouseId,
          f.gender,
          f.bloodGroup,
          f.admissionDate.toIso8601String().substring(0, 10),
          f.status,
        ]);
      } catch (_) {}
    } else {
      for (var f in friends) {
        rows.add([
          f.registrationNumber,
          f.fullName,
          f.assignedWorkshopId,
          f.assignedHouseId,
          f.gender,
          f.bloodGroup,
          f.admissionDate.toIso8601String().substring(0, 10),
          f.status,
        ]);
      }
    }
    
    final csvString = const ListToCsvConverter().convert(rows);
    return Uint8List.fromList(utf8.encode(csvString));
  }

  void _exportReport(AppUser? user, String workshopName) async {
    String scopeText = '';
    final role = user?.role;
    if (role == 'workshop_staff') {
      scopeText = ' for the $workshopName Workshop';
    } else if (role == 'physiotherapist') {
      scopeText = ' for Physiotherapy';
    } else if (role == 'speech_therapist') {
      scopeText = ' for Speech Therapy';
    } else if (role == 'medical_officer') {
      scopeText = ' for Medical Records';
    }

    final friends = ref.read(visibleFriendsProvider);
    Uint8List fileBytes;
    String extension = _selectedFormat;
    
    if (_selectedFormat == 'pdf') {
      fileBytes = await _generatePdfReport(friends, scopeText);
    } else {
      fileBytes = _generateCsvReport(friends);
      extension = _selectedFormat == 'excel' ? 'xlsx' : 'csv';
    }

    final String defaultFileName = 'RAMS_Report_${_selectedReportType}_${DateTime.now().millisecondsSinceEpoch}.$extension';

    try {
      final String? selectedPath = await FilePicker.saveFile(
        dialogTitle: 'Select where to save the exported report:',
        fileName: defaultFileName,
        bytes: fileBytes,
      );

      if (selectedPath != null && mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.download_done_rounded, color: AppTheme.successColor, size: 48),
            title: const Text('Report Exported'),
            content: Text(
              'The report has been successfully generated$scopeText and saved.\n\nFile Name: $defaultFileName',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report export cancelled.')),
        );
      }
    } catch (e) {
      debugPrint('Error saving file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving report: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final friends = ref.watch(visibleFriendsProvider);
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final role = user?.role;
    final isWorkshopStaff = role == 'workshop_staff';
    final isPhysio = role == 'physiotherapist';
    final isSpeech = role == 'speech_therapist';
    final isMedical = role == 'medical_officer';
    final isPrincipal = role == 'principal';
    final workshopId = user?.workshopId;
    final workshopName = (isWorkshopStaff && workshopId != null) 
        ? localizations.translate(workshopId) 
        : '';

    // Filter report types based on user role
    final List<DropdownMenuItem<String>> reportTypes = [
      const DropdownMenuItem(value: 'friend_summary', child: Text('Friend Profile Summary')),
      if (role == 'admin' || isPrincipal || isWorkshopStaff)
        const DropdownMenuItem(value: 'attendance_monthly', child: Text('Attendance Log (Monthly)')),
      if (role == 'admin' || isPrincipal || isWorkshopStaff || isPhysio || isSpeech)
        const DropdownMenuItem(value: 'iep_assessment', child: Text('Individual Education Plan (IEP) Assessment')),
      if (role == 'admin' || isPrincipal || isMedical)
        const DropdownMenuItem(value: 'medical_clinical', child: Text('Doctor clinical & Prescription record')),
      if (role == 'admin' || isPrincipal || isWorkshopStaff)
        const DropdownMenuItem(value: 'workshop_productivity', child: Text('Workshop Productivity & Skills report')),
      if (role == 'admin' || isPrincipal || isPhysio)
        const DropdownMenuItem(value: 'physio_report', child: Text('Physiotherapy Session & Progress Report')),
      if (role == 'admin' || isPrincipal || isSpeech)
        const DropdownMenuItem(value: 'speech_report', child: Text('Speech Therapy Progress Report')),
    ];

    String cardTitleText = 'Report Generation Engine';
    String cardSubtitleText = 'Select report category, target filters, and output format. System exports standard compliant medical/educational documentation.';
    
    if (isWorkshopStaff) {
      cardTitleText = '$workshopName Workshop Report Generator';
      cardSubtitleText = 'Select report category, target filters, and output format for your assigned workshop.';
    } else if (isPhysio) {
      cardTitleText = 'Physiotherapy Report Generator';
      cardSubtitleText = 'Select physiotherapy report category, target filters, and output format.';
    } else if (isSpeech) {
      cardTitleText = 'Speech Therapy Report Generator';
      cardSubtitleText = 'Select speech therapy report category, target filters, and output format.';
    } else if (isMedical) {
      cardTitleText = 'Medical Records Report Generator';
      cardSubtitleText = 'Select medical report category, target filters, and output format.';
    }

    if (isPrincipal || role == 'admin') {
      return ResponsiveLayout(
        title: 'Executive Institutional Reports - RAMS',
        currentRoute: '/reports',
        body: ExecutiveReportView(
          principalName: user?.fullName ?? 'Tariq Alvi (Principal)',
          isEmbeddedInDashboard: false,
        ),
      );
    }

    return ResponsiveLayout(
      title: localizations.translate('reports'),
      currentRoute: '/reports',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cardTitleText,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      cardSubtitleText,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    const SizedBox(height: 24),

                    // Report Type
                    DropdownButtonFormField<String>(
                      value: _selectedReportType,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Report Type'),
                      items: reportTypes,
                      onChanged: (val) {
                        setState(() {
                          _selectedReportType = val!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Target Friend (Optional depending on report type)
                    DropdownButtonFormField<String>(
                      value: _selectedFriendId,
                      isExpanded: true,
                      hint: const Text('Apply Filter: All Friends'),
                      decoration: const InputDecoration(labelText: 'Target Profile'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Registered Friends'),
                        ),
                        ...friends.map((f) {
                          return DropdownMenuItem(
                            value: f.id,
                            child: Text(f.fullName),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedFriendId = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Output Format selector
                    DropdownButtonFormField<String>(
                      value: _selectedFormat,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Format'),
                      items: const [
                        DropdownMenuItem(value: 'pdf', child: Text('PDF Documents (.pdf)')),
                        DropdownMenuItem(value: 'csv', child: Text('CSV Spreadsheet (.csv)')),
                        DropdownMenuItem(value: 'excel', child: Text('Excel Sheet (.xlsx)')),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedFormat = val!;
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton.icon(
                      onPressed: () => _exportReport(user, workshopName),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: Text(localizations.translate('generate_pdf')),
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
}
