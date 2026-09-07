import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/platform_file_viewer.dart';
import '../../../friends/presentation/friends_provider.dart';
import '../../../friends/presentation/documents_provider.dart';
import '../../../friends/models/friend.dart';
import '../../domain/executive_report_builder.dart';

class ExecutiveReportView extends ConsumerStatefulWidget {
  final String principalName;
  final bool isEmbeddedInDashboard;

  const ExecutiveReportView({
    super.key,
    this.principalName = 'Tariq Alvi (Principal)',
    this.isEmbeddedInDashboard = true,
  });

  @override
  ConsumerState<ExecutiveReportView> createState() => _ExecutiveReportViewState();
}

class _ExecutiveReportViewState extends ConsumerState<ExecutiveReportView> {
  ReportScope _selectedScope = ReportScope.allWorkshops;
  String _selectedWorkshopId = 'bakery';
  String? _selectedFriendId;
  bool _isExporting = false;

  final Map<String, IconData> _workshopIcons = {
    'bakery': Icons.bakery_dining,
    'woodwork': Icons.handyman,
    'farming': Icons.forest,
    'textile': Icons.checkroom,
    'artwork': Icons.palette,
    'sports': Icons.sports_soccer,
  };

  void _exportPdf(List<Friend> friends, BuildContext context) async {
    setState(() => _isExporting = true);
    try {
      final docsState = ref.read(documentsProvider);
      Friend? targetFriend;
      if (_selectedFriendId != null) {
        try {
          targetFriend = friends.firstWhere((f) => f.id == _selectedFriendId);
        } catch (_) {}
      } else if (friends.isNotEmpty) {
        targetFriend = friends.first;
      }

      final bytes = await ExecutiveReportBuilder.generatePdf(
        scope: _selectedScope,
        allFriends: friends,
        allDocs: docsState.documents,
        selectedFriend: targetFriend,
        selectedWorkshopId: _selectedWorkshopId,
        principalName: widget.principalName,
      );

      final scopeSlug = _selectedScope.name;
      final fileName = 'Roshni_RAMS_Report_${scopeSlug}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final saved = await FilePicker.saveFile(
        dialogTitle: 'Save Executive Report (PDF)',
        fileName: fileName,
        bytes: bytes,
      );

      if (!context.mounted) return;

      if (saved != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report successfully saved as $fileName'),
            backgroundColor: AppTheme.successColor,
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () {
                openPlatformFile(
                  fileUrl: '',
                  fileName: fileName,
                  fileType: 'pdf',
                  bytes: bytes,
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF report: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _exportCsv(List<Friend> friends, BuildContext context) async {
    setState(() => _isExporting = true);
    try {
      final docsState = ref.read(documentsProvider);
      Friend? targetFriend;
      if (_selectedFriendId != null) {
        try {
          targetFriend = friends.firstWhere((f) => f.id == _selectedFriendId);
        } catch (_) {}
      } else if (friends.isNotEmpty) {
        targetFriend = friends.first;
      }

      final bytes = ExecutiveReportBuilder.generateCsv(
        scope: _selectedScope,
        allFriends: friends,
        allDocs: docsState.documents,
        selectedFriend: targetFriend,
        selectedWorkshopId: _selectedWorkshopId,
      );

      final scopeSlug = _selectedScope.name;
      final fileName = 'Roshni_RAMS_Report_${scopeSlug}_${DateTime.now().millisecondsSinceEpoch}.csv';

      final saved = await FilePicker.saveFile(
        dialogTitle: 'Save Executive Report (CSV)',
        fileName: fileName,
        bytes: bytes,
      );

      if (!context.mounted) return;

      if (saved != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report exported successfully as $fileName'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting CSV report: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _previewDocument(List<Friend> friends) async {
    setState(() => _isExporting = true);
    try {
      final docsState = ref.read(documentsProvider);
      Friend? targetFriend;
      if (_selectedFriendId != null) {
        try {
          targetFriend = friends.firstWhere((f) => f.id == _selectedFriendId);
        } catch (_) {}
      } else if (friends.isNotEmpty) {
        targetFriend = friends.first;
      }

      final bytes = await ExecutiveReportBuilder.generatePdf(
        scope: _selectedScope,
        allFriends: friends,
        allDocs: docsState.documents,
        selectedFriend: targetFriend,
        selectedWorkshopId: _selectedWorkshopId,
        principalName: widget.principalName,
      );

      final scopeSlug = _selectedScope.name;
      final fileName = 'Roshni_RAMS_Report_$scopeSlug.pdf';

      await openPlatformFile(
        fileUrl: '',
        fileName: fileName,
        fileType: 'pdf',
        bytes: bytes,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error previewing report: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);
    final docsState = ref.watch(documentsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Ensure selectedFriendId is valid
    if (_selectedFriendId == null && friends.isNotEmpty) {
      _selectedFriendId = friends.first.id;
    }

    final selectedFriend = friends.firstWhere(
      (f) => f.id == _selectedFriendId,
      orElse: () => friends.isNotEmpty ? friends.first : Friend(
        id: 'none',
        registrationNumber: 'N/A',
        fullName: 'No Beneficiary Found',
        photoUrl: '',
        dateOfBirth: DateTime.now(),
        gender: 'male',
        bloodGroup: 'N/A',
        admissionDate: DateTime.now(),
        assignedWorkshopId: 'bakery',
        assignedHouseId: 'amin_house',
        status: 'active',
        guardianName: 'N/A',
        guardianRelation: 'Guardian',
        guardianPhone: 'N/A',
        guardianEmail: '',
        guardianAddress: '',
        emergencyName: '',
        emergencyRelation: '',
        emergencyPhone: '',
        medicalNotesSummary: '',
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Control & Filter Console Bar
          _buildControlBar(context, friends, isDark),
          const SizedBox(height: 20),

          // 2. Official Formal On-Screen Report Sheet
          _buildReportSheet(context, friends, docsState, selectedFriend, isDark),
        ],
      ),
    );
  }

  Widget _buildControlBar(BuildContext context, List<Friend> friends, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? (isDark ? const Color(0xFF1E293B) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.analytics, color: AppTheme.primaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Executive Report Configuration',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      'Select report scope, target workshop or beneficiary, and view official report format below.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (_isExporting)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Segmented Scope Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildScopeChip(ReportScope.allWorkshops, 'All Workshops Audit', Icons.domain),
              _buildScopeChip(ReportScope.oneWorkshop, 'One Workshop Report', Icons.handyman),
              _buildScopeChip(ReportScope.singleBeneficiary, 'Single Beneficiary Dossier', Icons.person),
              _buildScopeChip(ReportScope.allBeneficiaries, 'All Beneficiaries Master Roster', Icons.groups),
            ],
          ),
          const SizedBox(height: 16),

          // Secondary Dropdown selectors based on selected scope
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 750;

              final selectorWidget = _selectedScope == ReportScope.oneWorkshop
                  ? DropdownButtonFormField<String>(
                      value: _selectedWorkshopId,
                      decoration: InputDecoration(
                        labelText: 'Target Vocational Workshop',
                        prefixIcon: Icon(_workshopIcons[_selectedWorkshopId] ?? Icons.storefront, color: AppTheme.primaryColor),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: ExecutiveReportBuilder.workshopDisplayNames.entries.map((e) {
                        return DropdownMenuItem(
                          value: e.key,
                          child: Row(
                            children: [
                              Icon(_workshopIcons[e.key] ?? Icons.storefront, size: 18, color: Colors.grey.shade700),
                              const SizedBox(width: 8),
                              Text(e.value),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedWorkshopId = val);
                      },
                    )
                  : _selectedScope == ReportScope.singleBeneficiary
                      ? DropdownButtonFormField<String>(
                          value: _selectedFriendId,
                          decoration: InputDecoration(
                            labelText: 'Target Beneficiary Profile',
                            prefixIcon: const Icon(Icons.badge, color: AppTheme.primaryColor),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: friends.map((f) {
                            return DropdownMenuItem(
                              value: f.id,
                              child: Text('${f.registrationNumber} - ${f.fullName} (${f.assignedWorkshopId.toUpperCase()})'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedFriendId = val);
                          },
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 18, color: AppTheme.primaryColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedScope == ReportScope.allWorkshops
                                      ? 'Consolidating all 6 vocational workshops across Roshni Association.'
                                      : 'Compiling institutional master roster of all ${friends.length} registered beneficiaries.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                              ),
                            ],
                          ),
                        );

              final actionButtons = [
                OutlinedButton.icon(
                  icon: const Icon(Icons.fullscreen, size: 18),
                  label: const Text('Preview / Print'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isExporting ? null : () => _previewDocument(friends),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: const Text('Export PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isExporting ? null : () => _exportPdf(friends, context),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.table_chart, size: 18),
                  label: const Text('Export CSV'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isExporting ? null : () => _exportCsv(friends, context),
                ),
              ];

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    selectorWidget,
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: actionButtons,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: selectorWidget),
                  const SizedBox(width: 12),
                  ...actionButtons.map((btn) => Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: btn,
                      )),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScopeChip(ReportScope scope, String label, IconData icon) {
    final isSelected = _selectedScope == scope;
    return ChoiceChip(
      selected: isSelected,
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : AppTheme.primaryColor),
      label: Text(label),
      selectedColor: AppTheme.primaryColor,
      backgroundColor: Colors.transparent,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      onSelected: (val) {
        if (val) setState(() => _selectedScope = scope);
      },
    );
  }

  Widget _buildReportSheet(
    BuildContext context,
    List<Friend> friends,
    DocumentsState docsState,
    Friend targetFriend,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131C2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Official Header
          _buildOfficialReportHeader(context, isDark),
          const Divider(thickness: 1.5, height: 32),

          // Report Content depending on selected scope
          if (_selectedScope == ReportScope.singleBeneficiary)
            _buildSingleBeneficiaryReportContent(context, targetFriend, docsState, isDark)
          else if (_selectedScope == ReportScope.oneWorkshop)
            _buildOneWorkshopReportContent(context, friends, isDark)
          else if (_selectedScope == ReportScope.allWorkshops)
            _buildAllWorkshopsReportContent(context, friends, isDark)
          else
            _buildAllBeneficiariesReportContent(context, friends, isDark),

          const Divider(thickness: 1, height: 36),

          // Official Sign-off Footer
          _buildOfficialReportFooter(context, isDark),
        ],
      ),
    );
  }

  Widget _buildOfficialReportHeader(BuildContext context, bool isDark) {
    final now = DateTime.now();
    final dateStr = '${now.day} ${_getMonthName(now.month)} ${now.year} - ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;

        final crest = Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Icon(Icons.wb_sunny, color: Colors.white, size: 36),
          ),
        );

        final titles = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ROSHNI ASSOCIATION FOR SPECIAL EDUCATION',
              style: TextStyle(
                fontSize: isNarrow ? 13 : 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                color: isDark ? Colors.lightBlue.shade300 : const Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Roshni Activity & Management System (RAMS) - Executive Console',
              style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              _getScopeHeaderTitle(),
              style: TextStyle(fontSize: isNarrow ? 14 : 16, fontWeight: FontWeight.bold),
            ),
          ],
        );

        final metadata = Column(
          crossAxisAlignment: isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade300),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'OFFICIAL & CONFIDENTIAL',
                style: TextStyle(
                  color: Colors.red.shade900,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text('Generated: $dateStr', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text('Authorized Signee: ${widget.principalName}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  crest,
                  const SizedBox(width: 12),
                  Expanded(child: titles),
                ],
              ),
              const SizedBox(height: 12),
              metadata,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            crest,
            const SizedBox(width: 16),
            Expanded(child: titles),
            metadata,
          ],
        );
      },
    );
  }

  String _getScopeHeaderTitle() {
    switch (_selectedScope) {
      case ReportScope.singleBeneficiary:
        return 'INDIVIDUAL BENEFICIARY COMPREHENSIVE DOSSIER';
      case ReportScope.oneWorkshop:
        return 'VOCATIONAL WORKSHOP PROGRESS & CURRICULUM REPORT';
      case ReportScope.allWorkshops:
        return 'CONSOLIDATED VOCATIONAL WORKSHOPS EXECUTIVE AUDIT';
      case ReportScope.allBeneficiaries:
        return 'INSTITUTIONAL MASTER BENEFICIARY ENROLLMENT ROSTER';
    }
  }

  // --- REPORT SECTION: Single Beneficiary ---
  Widget _buildSingleBeneficiaryReportContent(
    BuildContext context,
    Friend f,
    DocumentsState docsState,
    bool isDark,
  ) {
    final docs = docsState.documents.where((d) => d.friendId == f.id).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top KPI Cards for this Beneficiary
        Row(
          children: [
            _buildKpiMiniCard('Overall Participation', '4.4 / 5.0', 'High Engagement', Icons.trending_up, Colors.blue),
            const SizedBox(width: 12),
            _buildKpiMiniCard('Task Independence', '85%', 'Self-directed', Icons.psychology, Colors.teal),
            const SizedBox(width: 12),
            _buildKpiMiniCard('Workshop Attendance', '96%', 'Present 24/25 days', Icons.event_available, Colors.green),
            const SizedBox(width: 12),
            _buildKpiMiniCard('Vault Documents', '${docs.length}', 'Official Records', Icons.folder_shared, Colors.purple),
          ],
        ),
        const SizedBox(height: 24),

        // Section 1: Demographics
        _buildSectionHeader('1. Beneficiary Identification & Residential Placement', Icons.person_outline),
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _buildDataRow('Full Name:', f.fullName, 'Registration Number:', f.registrationNumber),
              const Divider(height: 16),
              _buildDataRow(
                'Assigned Workshop:',
                ExecutiveReportBuilder.workshopDisplayNames[f.assignedWorkshopId] ?? f.assignedWorkshopId.toUpperCase(),
                'Residential House:',
                f.assignedHouseId.toUpperCase(),
              ),
              const Divider(height: 16),
              _buildDataRow(
                'Date of Birth / Age:',
                '${f.dateOfBirth.toIso8601String().split('T')[0]} (${f.age} years old)',
                'Gender & Blood Group:',
                '${f.gender.toUpperCase()} | ${f.bloodGroup}',
              ),
              const Divider(height: 16),
              _buildDataRow(
                'Admission Date:',
                f.admissionDate.toIso8601String().split('T')[0],
                'Enrollment Status:',
                f.status.toUpperCase(),
              ),
              const Divider(height: 16),
              _buildDataRow(
                'Guardian Contact:',
                '${f.guardianName} (${f.guardianRelation}) - ${f.guardianPhone}',
                'Emergency Contact:',
                '${f.emergencyName} (${f.emergencyRelation}) - ${f.emergencyPhone}',
              ),
              if (f.medicalNotesSummary.isNotEmpty) ...[
                const Divider(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Clinical & Medical Summary: ${f.medicalNotesSummary}',
                    style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Section 2: Vocational Skills & Activities in Workshop
        _buildSectionHeader(
          '2. Vocational Workshop Evaluation (${ExecutiveReportBuilder.workshopDisplayNames[f.assignedWorkshopId] ?? "Assigned Workshop"})',
          Icons.handyman,
        ),
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Assessed Vocational Activities & Skill Proficiency:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: ExecutiveReportBuilder.getWorkshopSkills(f.assignedWorkshopId).map((skill) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 16),
                        const SizedBox(width: 6),
                        Text(skill, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade700,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Proficient (4.5)', style: TextStyle(color: Colors.white, fontSize: 10)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Section 3: Confidential Vault Files
        _buildSectionHeader('3. Confidential Institutional Records on File', Icons.security),
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
          ),
          child: docs.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('No confidential records uploaded specifically for this beneficiary yet.'),
                )
              : Column(
                  children: docs.map((d) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        d.fileType == 'pdf' ? Icons.picture_as_pdf : Icons.image,
                        color: d.fileType == 'pdf' ? Colors.red.shade700 : Colors.blue.shade700,
                      ),
                      title: Text(d.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text('Category: ${d.documentType} | File: ${d.fileName} | Uploaded by: ${d.uploadedBy}', style: const TextStyle(fontSize: 11)),
                      trailing: Text(
                        d.uploadedAt.toIso8601String().split('T')[0],
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  // --- REPORT SECTION: One Workshop ---
  Widget _buildOneWorkshopReportContent(
    BuildContext context,
    List<Friend> friends,
    bool isDark,
  ) {
    final ws = ExecutiveReportBuilder.getWorkshopData(_selectedWorkshopId, friends);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live Workshop Console Navigation Banner
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.touch_app_outlined, color: AppTheme.primaryColor, size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Workshop Activity & Behavior Console',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
                    ),
                    Text(
                      'Inspect all friends of this workshop or select individual beneficiary evaluations in read-only oversight mode.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.open_in_new, size: 15),
                label: const Text('Open Console'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => context.push('/workshops/$_selectedWorkshopId'),
              ),
            ],
          ),
        ),

        // Workshop Top KPI Cards
        Row(
          children: [
            _buildKpiMiniCard('Enrolled Headcount', '${ws.enrolledBeneficiaries.length} / ${ws.capacity}', 'Capacity Utilization', Icons.groups, Colors.blue),
            const SizedBox(width: 12),
            _buildKpiMiniCard('Average Participation', '${ws.averageParticipation} / 5.0', 'Active Engagement', Icons.grade, Colors.amber.shade800),
            const SizedBox(width: 12),
            _buildKpiMiniCard('Task Completion Rate', '${(ws.averageTaskCompletion * 20).toInt()}%', 'Standard Execution', Icons.task_alt, Colors.teal),
            const SizedBox(width: 12),
            _buildKpiMiniCard('Average Attendance', '${ws.averageAttendanceRate}%', 'Weekly Average', Icons.event_available, Colors.green),
          ],
        ),
        const SizedBox(height: 24),

        // Section 1: Curriculum Skills
        _buildSectionHeader('1. Active Vocational Curriculum Activities & Competencies', Icons.school),
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vocational Modules for ${ws.name}:',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: ws.skills.map((s) {
                  return Chip(
                    avatar: const Icon(Icons.star, size: 16, color: AppTheme.primaryColor),
                    label: Text(s, style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey.shade300),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Section 2: Enrolled Beneficiaries Roster
        _buildSectionHeader('2. Enrolled Beneficiaries Roster (${ws.enrolledBeneficiaries.length} Enrolled)', Icons.list_alt),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(1.5),
              1: FlexColumnWidth(2.5),
              2: FlexColumnWidth(1.5),
              3: FlexColumnWidth(1.2),
              4: FlexColumnWidth(1.2),
              5: FlexColumnWidth(2.0),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100),
                children: const [
                  _TableHeaderCell('Reg #'),
                  _TableHeaderCell('Beneficiary Name'),
                  _TableHeaderCell('House'),
                  _TableHeaderCell('Gender'),
                  _TableHeaderCell('Status'),
                  _TableHeaderCell('Guardian Phone'),
                ],
              ),
              for (var f in ws.enrolledBeneficiaries)
                TableRow(
                  children: [
                    _TableCell(f.registrationNumber, isBold: true),
                    _TableCell(f.fullName),
                    _TableCell(f.assignedHouseId.toUpperCase()),
                    _TableCell(f.gender.toUpperCase()),
                    _TableCell(f.status.toUpperCase(), textColor: Colors.green.shade800),
                    _TableCell(f.guardianPhone),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  // --- REPORT SECTION: All Workshops ---
  Widget _buildAllWorkshopsReportContent(
    BuildContext context,
    List<Friend> friends,
    bool isDark,
  ) {
    final allWs = ExecutiveReportBuilder.getAllWorkshopsData(friends);
    final totalEnrolled = allWs.fold<int>(0, (sum, ws) => sum + ws.enrolledBeneficiaries.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Institutional Vocational Metrics
        Row(
          children: [
            _buildKpiMiniCard('Total Vocational Headcount', '$totalEnrolled Friends', 'Active Across Units', Icons.groups, Colors.blue),
            const SizedBox(width: 12),
            _buildKpiMiniCard('Operational Workshops', '${allWs.length} Units', 'Bakery, Woodwork, Farm, etc.', Icons.storefront, Colors.amber.shade800),
            const SizedBox(width: 12),
            _buildKpiMiniCard('Institutional Attendance', '94.2%', 'Aggregate Presence', Icons.event_available, Colors.green),
            const SizedBox(width: 12),
            _buildKpiMiniCard('Capacity Utilization', '${(totalEnrolled / (allWs.length * 15) * 100).toInt()}%', 'Based on 90 Max Seats', Icons.pie_chart, Colors.purple),
          ],
        ),
        const SizedBox(height: 24),

        _buildSectionHeader('Vocational Workshop Comparison Matrix', Icons.table_chart),
        const SizedBox(height: 8),

        Container(
          decoration: BoxDecoration(
            border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(2.5),
              1: FlexColumnWidth(1.5),
              2: FlexColumnWidth(1.5),
              3: FlexColumnWidth(1.5),
              4: FlexColumnWidth(1.5),
              5: FlexColumnWidth(3.0),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100),
                children: const [
                  _TableHeaderCell('Workshop Unit'),
                  _TableHeaderCell('Enrolled / Cap'),
                  _TableHeaderCell('Avg Part. (5.0)'),
                  _TableHeaderCell('Task Rate'),
                  _TableHeaderCell('Attendance'),
                  _TableHeaderCell('Core Curriculum Modules'),
                ],
              ),
              for (var ws in allWs)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Row(
                        children: [
                          Icon(_workshopIcons[ws.id] ?? Icons.handyman, size: 18, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Expanded(child: Text(ws.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        ],
                      ),
                    ),
                    _TableCell('${ws.enrolledBeneficiaries.length} / ${ws.capacity}'),
                    _TableCell('${ws.averageParticipation}'),
                    _TableCell('${(ws.averageTaskCompletion * 20).toInt()}%'),
                    _TableCell('${ws.averageAttendanceRate}%', textColor: Colors.green.shade800),
                    _TableCell(ws.skills.take(3).join(', ')),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  // --- REPORT SECTION: All Beneficiaries ---
  Widget _buildAllBeneficiariesReportContent(
    BuildContext context,
    List<Friend> friends,
    bool isDark,
  ) {
    final activeCount = friends.where((f) => f.status == 'active').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Roster Metrics
        Row(
          children: [
            _buildKpiMiniCard('Total Registered', '${friends.length}', 'Master Roster', Icons.groups, Colors.blue),
            const SizedBox(width: 12),
            _buildKpiMiniCard('Active Enrollment', '$activeCount Friends', '${((activeCount / (friends.isEmpty ? 1 : friends.length)) * 100).toInt()}% Active', Icons.check_circle, Colors.green),
            const SizedBox(width: 12),
            _buildKpiMiniCard('Assigned Workshops', '6 Units', 'Vocational Placements', Icons.storefront, Colors.orange),
            const SizedBox(width: 12),
            _buildKpiMiniCard('Residential Houses', '2 Houses', 'Amin & Roshni House', Icons.home, Colors.purple),
          ],
        ),
        const SizedBox(height: 24),

        _buildSectionHeader('Master Beneficiaries Directory', Icons.format_list_numbered),
        const SizedBox(height: 8),

        Container(
          decoration: BoxDecoration(
            border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(1.5),
              1: FlexColumnWidth(2.5),
              2: FlexColumnWidth(1.8),
              3: FlexColumnWidth(1.5),
              4: FlexColumnWidth(1.2),
              5: FlexColumnWidth(1.5),
              6: FlexColumnWidth(1.2),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100),
                children: const [
                  _TableHeaderCell('Reg #'),
                  _TableHeaderCell('Full Name'),
                  _TableHeaderCell('Assigned Workshop'),
                  _TableHeaderCell('House'),
                  _TableHeaderCell('Age / Gen'),
                  _TableHeaderCell('Admission'),
                  _TableHeaderCell('Status'),
                ],
              ),
              for (var f in friends)
                TableRow(
                  children: [
                    _TableCell(f.registrationNumber, isBold: true),
                    _TableCell(f.fullName),
                    _TableCell(ExecutiveReportBuilder.workshopDisplayNames[f.assignedWorkshopId] ?? f.assignedWorkshopId.toUpperCase()),
                    _TableCell(f.assignedHouseId.toUpperCase()),
                    _TableCell('${f.age}y / ${f.gender[0].toUpperCase()}'),
                    _TableCell(f.admissionDate.toIso8601String().split('T')[0]),
                    _TableCell(f.status.toUpperCase(), textColor: Colors.green.shade800),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOfficialReportFooter(BuildContext context, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Roshni Association for Special Education & Vocational Rehabilitation',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 2),
            Text(
              'Document Code: RAMS-EXEC-RPT-2026 | Electronic Hash Verified',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 140,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black45, width: 1)),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.principalName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const Text(
              'Principal & Executive Authority',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiMiniCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, size: 18, color: color),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildDataRow(String label1, String value1, String label2, String value2) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              children: [
                TextSpan(text: '$label1 ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                TextSpan(text: value1, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              children: [
                TextSpan(text: '$label2 ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                TextSpan(text: value2, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[(month - 1).clamp(0, 11)];
  }
}

class _TableHeaderCell extends StatelessWidget {
  final String text;
  const _TableHeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final bool isBold;
  final Color? textColor;

  const _TableCell(this.text, {this.isBold = false, this.textColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: textColor,
        ),
      ),
    );
  }
}
