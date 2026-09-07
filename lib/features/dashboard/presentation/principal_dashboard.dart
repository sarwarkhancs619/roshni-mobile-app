import 'dart:convert' show base64Decode;
import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/shared/widgets/responsive_layout.dart';
import '../../../core/theme/theme.dart';
import '../../../core/localization/localization.dart';
import '../../../core/utils/platform_file_viewer.dart';
import '../../../core/utils/image_utils.dart';
import '../../friends/presentation/friends_provider.dart';
import '../../friends/presentation/documents_provider.dart';
import '../../friends/models/friend.dart';
import '../../friends/models/beneficiary_document.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../reports/presentation/widgets/executive_report_view.dart';
import '../../../core/storage/hive_storage.dart';

class PrincipalDashboardScreen extends ConsumerStatefulWidget {
  const PrincipalDashboardScreen({super.key});

  @override
  ConsumerState<PrincipalDashboardScreen> createState() => _PrincipalDashboardScreenState();
}

class _PrincipalDashboardScreenState extends ConsumerState<PrincipalDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final TextEditingController _searchController;
  String _searchQuery = '';
  String _selectedWorkshopFilter = 'all';
  String _vaultViewMode = 'all_docs'; // 'all_docs' or 'by_beneficiary'
  String _docCategoryFilter = 'all';

  // Clinical & Therapies Oversight state
  int _clinicalSegmentIndex = 0; // 0: Physio, 1: Speech, 2: Medical
  String? _selectedClinicalFriendId;
  late final TextEditingController _clinicalSearchController;
  String _clinicalSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _clinicalSearchController = TextEditingController();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    _clinicalSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final authState = ref.watch(authProvider);
    final user = authState.user;

    // Security guard: Accessible to Principal and Admin
    if (user == null || (user.role != 'principal' && user.role != 'admin')) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Principal Access Required'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 72, color: AppTheme.primaryColor),
                const SizedBox(height: 16),
                Text(
                  user == null ? 'Session Expired / Not Logged In' : 'Principal Access Required',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  user == null
                      ? 'Please sign in to access the Principal Dashboard and Beneficiary Documentation Vault.'
                      : 'You are currently signed in as ${user.fullName} (${user.role}). This dashboard is restricted to Principal and Admin accounts.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, height: 1.5),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Go to Login'),
                      onPressed: () => context.go('/login'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final friends = ref.watch(friendsProvider);
    final docsState = ref.watch(documentsProvider);

    // Calculate real metrics
    final totalFriends = friends.length;
    final totalDocsUploaded = docsState.documents.length;
    final activeFriends = friends.where((f) => f.status == 'active').length;

    // Filtered friends
    final filteredFriends = friends.where((f) {
      final matchesSearch = f.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          f.registrationNumber.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesWorkshop = _selectedWorkshopFilter == 'all' || f.assignedWorkshopId == _selectedWorkshopFilter;
      return matchesSearch && matchesWorkshop;
    }).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ResponsiveLayout(
      title: 'Principal Executive Console - RAMS',
      currentRoute: '/dashboard/principal',
      actions: [
        if (_tabController.index == 0)
          Builder(
            builder: (context) {
              final isNarrow = MediaQuery.of(context).size.width < 650;
              if (isNarrow) {
                return IconButton(
                  icon: const Icon(Icons.cloud_upload),
                  tooltip: 'Upload Document',
                  onPressed: () => _handleUploadPressed(context, filteredFriends, user.fullName),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.cloud_upload, size: 18),
                  label: const Text('Upload Document', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: () => _handleUploadPressed(context, filteredFriends, user.fullName),
                ),
              );
            },
          ),
        const SizedBox(width: 8),
      ],
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              heroTag: 'fab_upload_confidential',
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Upload Confidential Document', style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
              onPressed: () => _handleUploadPressed(context, filteredFriends, user.fullName),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sticky top TabBar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color ?? (isDark ? const Color(0xFF1E293B) : Colors.white),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
              indicatorColor: Theme.of(context).colorScheme.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
              tabs: const [
                Tab(
                  icon: Icon(Icons.security),
                  text: 'Confidential Document Vault',
                ),
                Tab(
                  icon: Icon(Icons.school_outlined),
                  text: 'Beneficiaries & Individual Plans (IP)',
                ),
                Tab(
                  icon: Icon(Icons.assessment_outlined),
                  text: 'Executive Reports & Workshops',
                ),
                Tab(
                  icon: Icon(Icons.health_and_safety_outlined),
                  text: 'Therapies & Clinical Oversight',
                ),
              ],
            ),
          ),

          // TabBarView with fully scrollable content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Document Vault
                _buildVaultTab(
                  context: context,
                  friends: filteredFriends,
                  docsState: docsState,
                  principalName: user.fullName,
                  totalFriends: totalFriends,
                  activeFriends: activeFriends,
                  totalDocsUploaded: totalDocsUploaded,
                ),
                // Tab 2: Beneficiaries & IP List
                _buildBeneficiaryListTab(
                  context: context,
                  friends: filteredFriends,
                  localizations: localizations,
                  principalName: user.fullName,
                  totalFriends: totalFriends,
                  activeFriends: activeFriends,
                  totalDocsUploaded: totalDocsUploaded,
                ),
                // Tab 3: Executive Reports & Workshops
                ExecutiveReportView(
                  principalName: user.fullName,
                  isEmbeddedInDashboard: true,
                ),
                // Tab 4: Therapies & Clinical Oversight
                _buildClinicalOversightTab(
                  context: context,
                  friends: friends,
                  localizations: localizations,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrincipalBanner(BuildContext context, String userName, List<Friend> friends) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, $userName',
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Principal Exclusive Executive Console & Document Repository',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock, color: Colors.amber, size: 16),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'CONFIDENTIAL AREA: Accessible exclusively by the Principal',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.cloud_upload, size: 18),
                label: const Text('Upload Confidential Document', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade500,
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  elevation: 2,
                ),
                onPressed: () => _handleUploadPressed(context, friends, userName),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.person_add, size: 16, color: Colors.white),
                label: const Text('Add Friend & Setup IP', style: TextStyle(color: Colors.white, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white70),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: () => context.push('/friends/add'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade700,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(icon, color: color, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveMetricsRow(
    BuildContext context,
    int totalFriends,
    int activeFriends,
    int totalDocsUploaded,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 650) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Beneficiaries',
                      value: '$totalFriends',
                      subtitle: '$activeFriends Active',
                      icon: Icons.people_alt_outlined,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Vault Files',
                      value: '$totalDocsUploaded',
                      subtitle: 'Documents Stored',
                      icon: Icons.folder_shared_outlined,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildMetricCard(
                title: 'Workshops',
                value: '5 Active Units',
                subtitle: 'Bakery, Woodwork, Farming, Textile, Artwork',
                icon: Icons.storefront_outlined,
                color: AppTheme.secondaryColor,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Beneficiaries',
                value: '$totalFriends',
                subtitle: '$activeFriends Active',
                icon: Icons.people_alt_outlined,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                title: 'Confidential Files',
                value: '$totalDocsUploaded',
                subtitle: 'Vault Stored',
                icon: Icons.folder_shared_outlined,
                color: const Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                title: 'Workshops',
                value: '5 Active',
                subtitle: 'Vocational Units',
                icon: Icons.storefront_outlined,
                color: AppTheme.secondaryColor,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVaultTab({
    required BuildContext context,
    required List<Friend> friends,
    required DocumentsState docsState,
    required String principalName,
    required int totalFriends,
    required int activeFriends,
    required int totalDocsUploaded,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final friendMap = {for (var f in friends) f.id: f};

    final filteredDocs = docsState.documents.where((doc) {
      final query = _searchQuery.toLowerCase();
      final friend = friendMap[doc.friendId];
      final friendName = friend?.fullName.toLowerCase() ?? '';

      final matchesSearch = query.isEmpty ||
          doc.title.toLowerCase().contains(query) ||
          doc.fileName.toLowerCase().contains(query) ||
          doc.uploadedBy.toLowerCase().contains(query) ||
          friendName.contains(query);

      final matchesCategory = _docCategoryFilter == 'all' || doc.documentType == _docCategoryFilter;

      final matchesWorkshop = _selectedWorkshopFilter == 'all' ||
          (friend != null && friend.assignedWorkshopId == _selectedWorkshopFilter) ||
          (doc.friendId == 'general_institute' || doc.friendId == 'institute_general');

      return matchesSearch && matchesCategory && matchesWorkshop;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        _buildPrincipalBanner(context, principalName, friends),
        const SizedBox(height: 16),
        _buildResponsiveMetricsRow(context, totalFriends, activeFriends, totalDocsUploaded),
        const SizedBox(height: 16),

        // Action Banner with responsive layout and prominent Upload button
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 650;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE8F0FE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFB8D0F8)),
              ),
              child: isNarrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.cloud_upload_outlined,
                              color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF0D47A1),
                              size: 26,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Upload Confidential Documents (PDF)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF0D47A1),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Attach Admission Forms, Undertakings, or Profile PDFs directly to beneficiary records.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFFCBD5E1) : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.upload_file, size: 18),
                            label: const Text('Upload Document'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? const Color(0xFF2563EB) : const Color(0xFF0D47A1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onPressed: () => _handleUploadPressed(context, friends, principalName),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF0D47A1),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Upload Confidential Documents (PDF)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF0D47A1),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Attach Admission Forms, Undertakings, or Profile PDFs directly to beneficiary records.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFFCBD5E1) : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.upload_file, size: 18),
                          label: const Text('Upload Document'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF2563EB) : const Color(0xFF0D47A1),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onPressed: () => _handleUploadPressed(context, friends, principalName),
                        ),
                      ],
                    ),
            );
          },
        ),
        const SizedBox(height: 16),

        // Vault View Toggle: Uploaded Documents vs Beneficiary Folders
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _vaultViewMode = 'all_docs'),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _vaultViewMode == 'all_docs'
                          ? (isDark ? const Color(0xFF2563EB) : const Color(0xFF0D47A1))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 16,
                          color: _vaultViewMode == 'all_docs' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Uploaded Documents (${filteredDocs.length})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _vaultViewMode == 'all_docs' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _vaultViewMode = 'by_beneficiary'),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _vaultViewMode == 'by_beneficiary'
                          ? (isDark ? const Color(0xFF2563EB) : const Color(0xFF0D47A1))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_shared_outlined,
                          size: 16,
                          color: _vaultViewMode == 'by_beneficiary' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Beneficiary Folders (${friends.length})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _vaultViewMode == 'by_beneficiary' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Filter & Search bar
        _buildSearchBar(),
        const SizedBox(height: 16),

        if (_vaultViewMode == 'all_docs') ...[
          // Category filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryChip('all', 'All Files (${docsState.documents.length})'),
                const SizedBox(width: 8),
                _buildCategoryChip('psychological_assessment', 'Psychological Assessments'),
                const SizedBox(width: 8),
                _buildCategoryChip('admission_form', 'Admission Forms'),
                const SizedBox(width: 8),
                _buildCategoryChip('disability_certificate', 'Disability Certs'),
                const SizedBox(width: 8),
                _buildCategoryChip('medical_report', 'Medical Reports'),
                const SizedBox(width: 8),
                _buildCategoryChip('general_confidential', 'Executive SOPs'),
                const SizedBox(width: 8),
                _buildCategoryChip('undertaking', 'Undertakings'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (filteredDocs.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_open_outlined, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      'No uploaded confidential documents found.',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap "Upload Document" to attach psychological evaluations, admission forms, or institute files.',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Upload Confidential Document'),
                      onPressed: () => _handleUploadPressed(context, friends, principalName),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filteredDocs.map((doc) {
              final friend = friendMap[doc.friendId];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _buildUploadedDocCard(context, doc, friend, principalName),
              );
            }),
        ] else ...[
          if (friends.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_search, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      'No beneficiaries found in the database.',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Load Roshni beneficiaries or onboard your first beneficiary to start managing confidential files.',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.download_done),
                          label: const Text('Load Roshni Beneficiaries'),
                          onPressed: () async {
                            await ref.read(friendsProvider.notifier).seedDefaultFriends();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Roshni beneficiaries loaded successfully!'),
                                  backgroundColor: AppTheme.successColor,
                                ),
                              );
                            }
                          },
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.person_add),
                          label: const Text('Add Friend & Setup IP'),
                          onPressed: () => context.push('/friends/add'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else
            ...friends.map((friend) {
              final friendDocs = docsState.forFriend(friend.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: _buildBeneficiaryVaultCard(context, friend, friendDocs, principalName),
              );
            }),
        ],
      ],
    );
  }

  Widget _buildCategoryChip(String category, String label) {
    final isSelected = _docCategoryFilter == category;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppTheme.primaryColor : null,
        ),
      ),
      selected: isSelected,
      selectedColor: AppTheme.primaryColor.withOpacity(0.15),
      onSelected: (val) {
        if (val) {
          setState(() {
            _docCategoryFilter = category;
          });
        }
      },
    );
  }

  Color _getDocTypeColor(String type) {
    switch (type) {
      case 'admission_form':
        return const Color(0xFF0284C7);
      case 'profile_form':
        return const Color(0xFF0D9488);
      case 'undertaking':
        return const Color(0xFFD97706);
      case 'picture':
        return const Color(0xFF4F46E5);
      case 'psychological_assessment':
        return const Color(0xFF7C3AED);
      case 'medical_report':
        return const Color(0xFFDC2626);
      case 'disability_certificate':
        return const Color(0xFF2563EB);
      case 'legal_guardianship':
        return const Color(0xFFB45309);
      case 'general_confidential':
        return const Color(0xFF475569);
      default:
        return const Color(0xFF0284C7);
    }
  }

  String _formatDocType(String type) {
    switch (type) {
      case 'admission_form':
        return 'Admission Form';
      case 'profile_form':
        return 'Profile Form';
      case 'undertaking':
        return 'Undertaking';
      case 'picture':
        return 'Official Picture';
      case 'psychological_assessment':
        return 'Psychological Assessment';
      case 'medical_report':
        return 'Medical Report';
      case 'disability_certificate':
        return 'Disability Certificate';
      case 'legal_guardianship':
        return 'Legal & Guardianship';
      case 'general_confidential':
        return 'Executive Record';
      default:
        return type.replaceAll('_', ' ').toUpperCase();
    }
  }

  Widget _buildUploadedDocCard(
    BuildContext context,
    BeneficiaryDocument doc,
    Friend? friend,
    String principalName,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _getDocTypeColor(doc.documentType);
    final isGeneral = doc.friendId == 'general_institute' || doc.friendId == 'institute_general';
    final beneficiaryText = isGeneral
        ? '🏛️ Roshni Executive / Institute Record'
        : (friend != null
            ? '👤 Beneficiary: ${friend.fullName} (${friend.registrationNumber}) • ${friend.assignedWorkshopId.toUpperCase()}'
            : '👤 Beneficiary ID: ${doc.friendId}');

    final dateStr = doc.uploadedAt.toString().length >= 16
        ? doc.uploadedAt.toString().substring(0, 16)
        : doc.uploadedAt.toString();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Leading File Icon Badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      doc.fileType == 'pdf' ? Icons.picture_as_pdf : Icons.insert_drive_file,
                      color: color,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Title and badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _formatDocType(doc.documentType),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              beneficiaryText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // Action Buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, color: AppTheme.primaryColor, size: 22),
                      tooltip: 'Open File',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _openDocument(context, doc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                      tooltip: 'Delete Document',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _confirmDeleteDoc(context, doc),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'File: ${doc.fileName}',
                    style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  dateStr,
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : Colors.grey.shade500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleUploadPressed(BuildContext context, List<Friend> friends, String principalName) {
    if (friends.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Text('Beneficiary Required'),
            ],
          ),
          content: const Text(
            'Documents in the vault are associated directly with beneficiary records. Would you like to load the standard Roshni beneficiaries, or add a new beneficiary now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.person_add),
              label: const Text('Add Beneficiary'),
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/friends/add');
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.download_done),
              label: const Text('Load Beneficiaries'),
              onPressed: () async {
                Navigator.pop(ctx);
                await ref.read(friendsProvider.notifier).seedDefaultFriends();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Roshni beneficiaries loaded successfully!'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      );
    } else {
      _openQuickUploadDialog(context, friends, principalName);
    }
  }

  void _openQuickUploadDialog(
    BuildContext context,
    List<Friend> friends,
    String principalName, {
    String? preselectedFriendId,
  }) {
    String selectedFriendId = preselectedFriendId ?? (friends.isNotEmpty ? friends.first.id : 'institute_general');
    String selectedDocType = 'admission_form';
    final titleController = TextEditingController(text: 'Admission Form');

    final List<DropdownMenuItem<String>> beneficiaryDropdownItems = [
      ...friends.map((f) => DropdownMenuItem(
        value: f.id,
        child: Text('${f.fullName} (${f.registrationNumber})'),
      )),
      const DropdownMenuItem(
        value: 'institute_general',
        child: Text('🏛️ General Institute / Executive Record'),
      ),
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.upload_file, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Text('Upload Confidential Document'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Beneficiary or Institute File:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedFriendId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: beneficiaryDropdownItems,
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedFriendId = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  const Text('Document Type:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedDocType,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'admission_form', child: Text('📄 Admission Form (PDF)')),
                      DropdownMenuItem(value: 'profile_form', child: Text('📄 Profile & Assessment Form (PDF)')),
                      DropdownMenuItem(value: 'undertaking', child: Text('📄 Undertaking / Agreement (PDF)')),
                      DropdownMenuItem(value: 'medical_report', child: Text('🩺 Medical / Psychological Assessment (PDF)')),
                      DropdownMenuItem(value: 'picture', child: Text('🖼️ Beneficiary Official Picture')),
                      DropdownMenuItem(value: 'institute_policy', child: Text('🏛️ Institute Policy / Executive Order (PDF)')),
                      DropdownMenuItem(value: 'audit_report', child: Text('📑 Inspection / Audit Report (PDF)')),
                      DropdownMenuItem(value: 'other', child: Text('📎 Other Confidential Document (PDF)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedDocType = val;
                          if (val == 'admission_form') titleController.text = 'Admission Form';
                          if (val == 'profile_form') titleController.text = 'Profile Form';
                          if (val == 'undertaking') titleController.text = 'Undertaking Form';
                          if (val == 'picture') titleController.text = 'Beneficiary Picture';
                          if (val == 'other') titleController.text = 'Supporting Document';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  const Text('Document Title:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.file_upload),
                label: const Text('Choose File & Upload'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  final isPdf = selectedDocType != 'picture';
                  _pickAndUploadDocument(
                    context: this.context,
                    friendId: selectedFriendId,
                    documentType: selectedDocType,
                    title: titleController.text.trim().isNotEmpty ? titleController.text.trim() : 'Document',
                    isPdfOnly: isPdf,
                    principalName: principalName,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search beneficiary by name or Reg No...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _searchController.clear();
                        });
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        DropdownButton<String>(
          value: _selectedWorkshopFilter,
          underline: const SizedBox(),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Workshops')),
            DropdownMenuItem(value: 'bakery', child: Text('Bakery')),
            DropdownMenuItem(value: 'woodwork', child: Text('Woodwork')),
            DropdownMenuItem(value: 'farming', child: Text('Farming')),
            DropdownMenuItem(value: 'textile', child: Text('Textile')),
            DropdownMenuItem(value: 'artwork', child: Text('Artwork')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedWorkshopFilter = val;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildBeneficiaryVaultCard(
    BuildContext context,
    Friend friend,
    List<BeneficiaryDocument> docs,
    String principalName,
  ) {
    final admissionDoc = docs.where((d) => d.documentType == 'admission_form').firstOrNull;
    final profileDoc = docs.where((d) => d.documentType == 'profile_form').firstOrNull;
    final undertakingDoc = docs.where((d) => d.documentType == 'undertaking').firstOrNull;
    final pictureDoc = docs.where((d) => d.documentType == 'picture').firstOrNull;
    final standardTypes = {'admission_form', 'profile_form', 'undertaking', 'picture'};
    final otherDocs = docs.where((d) => !standardTypes.contains(d.documentType)).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
          backgroundImage: getAppImageProvider(friend.photoUrl),
          onBackgroundImageError: (_, __) {},
          child: getAppImageProvider(friend.photoUrl) == null
              ? Text(
                  friend.fullName.isNotEmpty ? friend.fullName[0].toUpperCase() : 'B',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                )
              : null,
        ),
        title: Text(
          friend.fullName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          'Reg: ${friend.registrationNumber} • Workshop: ${friend.assignedWorkshopId.toUpperCase()}',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCompletionBadge(admissionDoc != null, profileDoc != null, undertakingDoc != null),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.cloud_upload, size: 14),
              label: const Text('Upload', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => _openQuickUploadDialog(context, [friend], principalName, preselectedFriendId: friend.id),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Required Confidential Documents Checklist:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 12),

                // 1. Admission Form (PDF)
                _buildDocumentRow(
                  context: context,
                  title: 'Admission Form',
                  type: 'admission_form',
                  doc: admissionDoc,
                  friendId: friend.id,
                  principalName: principalName,
                  isPdfOnly: true,
                ),

                // 2. Profile Form (PDF)
                _buildDocumentRow(
                  context: context,
                  title: 'Profile Form',
                  type: 'profile_form',
                  doc: profileDoc,
                  friendId: friend.id,
                  principalName: principalName,
                  isPdfOnly: true,
                ),

                // 3. Undertaking (PDF)
                _buildDocumentRow(
                  context: context,
                  title: 'Undertaking / Agreement',
                  type: 'undertaking',
                  doc: undertakingDoc,
                  friendId: friend.id,
                  principalName: principalName,
                  isPdfOnly: true,
                ),

                // 4. Beneficiary Official Picture
                _buildDocumentRow(
                  context: context,
                  title: 'Official Beneficiary Picture',
                  type: 'picture',
                  doc: pictureDoc,
                  friendId: friend.id,
                  principalName: principalName,
                  isPdfOnly: false,
                ),

                // 5. Additional PDF Documents
                if (otherDocs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Other Uploaded Documents:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  ...otherDocs.map((doc) => _buildDocumentRow(
                        context: context,
                        title: doc.title,
                        type: 'other',
                        doc: doc,
                        friendId: friend.id,
                        principalName: principalName,
                        isPdfOnly: true,
                      )),
                ],

                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.note_add_outlined, size: 18),
                    label: const Text('Add Extra Supporting PDF'),
                    onPressed: () => _uploadCustomDocumentDialog(context, friend.id, principalName),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionBadge(bool hasAdmission, bool hasProfile, bool hasUndertaking) {
    int count = (hasAdmission ? 1 : 0) + (hasProfile ? 1 : 0) + (hasUndertaking ? 1 : 0);
    final isComplete = count == 3;
    return Chip(
      label: Text(
        '$count / 3 Required',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isComplete ? Colors.green.shade800 : Colors.orange.shade800,
        ),
      ),
      backgroundColor: isComplete ? Colors.green.shade50 : Colors.orange.shade50,
      side: BorderSide(color: isComplete ? Colors.green.shade300 : Colors.orange.shade300),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildDocumentRow({
    required BuildContext context,
    required String title,
    required String type,
    required BeneficiaryDocument? doc,
    required String friendId,
    required String principalName,
    required bool isPdfOnly,
  }) {
    final isUploaded = doc != null;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isUploaded ? Colors.green.shade50.withOpacity(0.5) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isUploaded ? Colors.green.shade200 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            isPdfOnly ? Icons.picture_as_pdf : Icons.image,
            color: isUploaded ? AppTheme.primaryColor : Colors.grey,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                if (isUploaded)
                  Text(
                    'Uploaded: ${doc.uploadedAt.day}/${doc.uploadedAt.month}/${doc.uploadedAt.year} • ${doc.fileName}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  )
                else
                  const Text(
                    'Not uploaded (Required)',
                    style: TextStyle(color: Colors.redAccent, fontSize: 11),
                  ),
              ],
            ),
          ),
          if (isUploaded) ...[
            IconButton(
              icon: const Icon(Icons.visibility_outlined, color: AppTheme.primaryColor, size: 20),
              tooltip: 'Open File',
              onPressed: () => _openDocument(context, doc),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              tooltip: 'Remove Document',
              onPressed: () => _confirmDeleteDoc(context, doc),
            ),
          ],
          ElevatedButton.icon(
            icon: Icon(isUploaded ? Icons.refresh : Icons.upload_file, size: 16),
            label: Text(isUploaded ? 'Replace' : 'Upload', style: const TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => _pickAndUploadDocument(
              context: context,
              friendId: friendId,
              documentType: type,
              title: title,
              isPdfOnly: isPdfOnly,
              principalName: principalName,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadDocument({
    required BuildContext context,
    required String friendId,
    required String documentType,
    required String title,
    required bool isPdfOnly,
    required String principalName,
  }) async {
    try {
      FilePickerResult? result;
      try {
        result = await FilePicker.pickFiles(
          type: isPdfOnly ? FileType.custom : FileType.any,
          allowedExtensions: isPdfOnly ? ['pdf'] : null,
          withData: true,
        );
      } catch (pickerErr) {
        // Fallback for platform pickers with strict mime filters
        result = await FilePicker.pickFiles(
          type: FileType.any,
          withData: true,
        );
      }

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      Uint8List? bytes = file.bytes;

      // On desktop (Windows/macOS/Linux) or native mobile, read directly from file path if bytes are null
      if (bytes == null && !kIsWeb && file.path != null && file.path!.isNotEmpty) {
        try {
          final diskFile = File(file.path!);
          if (await diskFile.exists()) {
            bytes = await diskFile.readAsBytes();
          }
        } catch (readErr) {
          debugPrint('Error reading file from disk path: $readErr');
        }
      }

      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read file content. Please try selecting again.')),
          );
        }
        return;
      }

      final fileExt = file.extension?.toLowerCase() ?? (isPdfOnly ? 'pdf' : 'jpg');
      final fileType = fileExt == 'pdf' ? 'pdf' : 'image';

      final success = await ref.read(documentsProvider.notifier).uploadDocument(
            friendId: friendId,
            documentType: documentType,
            title: title,
            fileBytes: bytes,
            fileName: file.name,
            fileType: fileType,
            uploadedBy: principalName,
            localFilePath: file.path,
          );

      if (success && mounted) {
        setState(() {
          _vaultViewMode = 'all_docs';
          _docCategoryFilter = 'all';
          _searchQuery = '';
          _selectedWorkshopFilter = 'all';
          _searchController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ "$title" uploaded successfully to Vault!'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _uploadCustomDocumentDialog(BuildContext context, String friendId, String principalName) async {
    final titleController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Extra Supporting PDF'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'Document Title (e.g. Medical Certificate, Disciplinary Note)',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                Navigator.pop(ctx);
                _pickAndUploadDocument(
                  context: context,
                  friendId: friendId,
                  documentType: 'other',
                  title: title,
                  isPdfOnly: true,
                  principalName: principalName,
                );
              }
            },
            child: const Text('Choose PDF'),
          ),
        ],
      ),
    );
  }

  Future<void> _openDocument(BuildContext context, BeneficiaryDocument doc) async {
    final cachedBytes = ref.read(documentsProvider.notifier).getDocumentBytes(doc.id);
    final isImage = doc.fileType == 'image' ||
        doc.fileName.toLowerCase().endsWith('.jpg') ||
        doc.fileName.toLowerCase().endsWith('.jpeg') ||
        doc.fileName.toLowerCase().endsWith('.png') ||
        doc.fileName.toLowerCase().endsWith('.webp');

    if (!kIsWeb && isImage) {
      _showImagePreviewModal(context, doc, cachedBytes);
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('Opening "${doc.fileName}"...')),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    final opened = await openPlatformFile(
      fileUrl: doc.fileUrl,
      fileName: doc.fileName,
      fileType: doc.fileType,
      bytes: cachedBytes,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open "${doc.fileName}" directly.'),
          backgroundColor: AppTheme.warningColor,
          action: SnackBarAction(
            label: 'Details',
            textColor: Colors.white,
            onPressed: () => _viewDocumentModal(context, doc),
          ),
        ),
      );
    }
  }

  void _showImagePreviewModal(BuildContext context, BeneficiaryDocument doc, Uint8List? cachedBytes) {
    Uint8List? imageBytes = cachedBytes;

    if (imageBytes == null && doc.fileUrl.startsWith('data:image')) {
      try {
        final comma = doc.fileUrl.indexOf(',');
        if (comma != -1) {
          imageBytes = base64Decode(doc.fileUrl.substring(comma + 1));
        }
      } catch (_) {}
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        Widget imageWidget;
        if (imageBytes != null && imageBytes.isNotEmpty) {
          imageWidget = Image.memory(imageBytes, fit: BoxFit.contain);
        } else if (doc.fileUrl.startsWith('http://') || doc.fileUrl.startsWith('https://')) {
          imageWidget = Image.network(
            doc.fileUrl,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const Center(child: CircularProgressIndicator()),
            errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 64, color: Colors.grey)),
          );
        } else if (!kIsWeb && doc.fileUrl.startsWith('file://')) {
          String path = doc.fileUrl.replaceFirst('file://', '');
          final f = File(path);
          if (f.existsSync()) {
            imageWidget = Image.file(f, fit: BoxFit.contain);
          } else {
            imageWidget = const Center(child: Icon(Icons.broken_image, size: 64, color: Colors.grey));
          }
        } else {
          imageWidget = const Center(child: Icon(Icons.image, size: 64, color: AppTheme.primaryColor));
        }

        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 650),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.image_outlined, color: AppTheme.primaryColor, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          doc.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.open_in_new, size: 20),
                        tooltip: 'Open Externally',
                        onPressed: () => openPlatformFile(
                          fileUrl: doc.fileUrl,
                          fileName: doc.fileName,
                          fileType: doc.fileType,
                          bytes: imageBytes,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Container(
                    color: isDark ? Colors.black26 : Colors.grey.shade100,
                    padding: const EdgeInsets.all(8),
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Center(child: imageWidget),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          doc.fileName,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _viewDocumentModal(BuildContext context, BeneficiaryDocument doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(doc.fileType == 'pdf' ? Icons.picture_as_pdf : Icons.image, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Expanded(child: Text(doc.title, overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File Name: ${doc.fileName}'),
            const SizedBox(height: 6),
            Text('Type: ${doc.documentType.replaceAll('_', ' ').toUpperCase()}'),
            const SizedBox(height: 6),
            Text('Uploaded On: ${doc.uploadedAt}'),
            const SizedBox(height: 6),
            Text('Uploaded By: ${doc.uploadedBy}'),
            if (doc.fileType == 'image' && doc.fileUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: doc.fileUrl.startsWith('http')
                    ? Image.network(
                        doc.fileUrl,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 48)),
                      )
                    : Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.image, size: 48, color: AppTheme.primaryColor),
                        ),
                      ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Document authenticated and secured in Principal Vault.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteDoc(BuildContext context, BeneficiaryDocument doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document?'),
        content: Text('Are you sure you want to delete "${doc.title}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              ref.read(documentsProvider.notifier).deleteDocument(doc.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildBeneficiaryListTab({
    required BuildContext context,
    required List<Friend> friends,
    required AppLocalizations localizations,
    required String principalName,
    required int totalFriends,
    required int activeFriends,
    required int totalDocsUploaded,
  }) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildPrincipalBanner(context, principalName, friends),
        const SizedBox(height: 16),
        _buildResponsiveMetricsRow(context, totalFriends, activeFriends, totalDocsUploaded),
        const SizedBox(height: 16),
        _buildSearchBar(),
        const SizedBox(height: 16),
        if (friends.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'No beneficiaries registered yet.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Friend & Setup IP'),
                    onPressed: () => context.push('/friends/add'),
                  ),
                ],
              ),
            ),
          )
        else
          ...friends.map((friend) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    backgroundImage: getAppImageProvider(friend.photoUrl),
                    onBackgroundImageError: (_, __) {},
                    child: getAppImageProvider(friend.photoUrl) == null
                        ? Text(
                            friend.fullName.isNotEmpty ? friend.fullName[0].toUpperCase() : 'B',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                          )
                        : null,
                  ),
                  title: Text(friend.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Reg No: ${friend.registrationNumber} • Age: ${friend.age}'),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              localizations.translate(friend.assignedWorkshopId),
                              style: const TextStyle(fontSize: 11, color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              friend.status.toUpperCase(),
                              style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.assignment_outlined, color: AppTheme.primaryColor),
                        tooltip: 'View / Edit Individual Plan (IP)',
                        onPressed: () => context.push('/iep/${friend.id}'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                        tooltip: 'Edit Friend Profile',
                        onPressed: () => context.push('/friends/${friend.id}/edit'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
  // ==========================================
  // TAB 4: THERAPIES & CLINICAL OVERSIGHT
  // ==========================================

  List<Map<String, dynamic>> _getFriendPhysioSessions(String friendId) {
    try {
      final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
      final raw = box.get('physio_sessions_$friendId');
      if (raw is List) {
        return List<Map<String, dynamic>>.from(raw.map((e) => Map<String, dynamic>.from(e as Map)));
      }
    } catch (_) {}
    return [];
  }

  List<Map<String, dynamic>> _getFriendSpeechSessions(String friendId) {
    try {
      final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
      final raw = box.get('speech_sessions_$friendId');
      if (raw is List) {
        return List<Map<String, dynamic>>.from(raw.map((e) => Map<String, dynamic>.from(e as Map)));
      }
    } catch (_) {}
    return [];
  }

  List<Map<String, dynamic>> _getFriendVitals(String friendId) {
    try {
      final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
      final raw = box.get('vitals_$friendId');
      if (raw is List) {
        return List<Map<String, dynamic>>.from(raw.map((e) => Map<String, dynamic>.from(e as Map)));
      }
    } catch (_) {}
    return [];
  }

  List<Map<String, dynamic>> _getFriendPrescriptions(String friendId) {
    try {
      final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
      final raw = box.get('prescriptions_$friendId');
      if (raw is List) {
        return List<Map<String, dynamic>>.from(raw.map((e) => Map<String, dynamic>.from(e as Map)));
      }
    } catch (_) {}
    return [];
  }

  Map<String, dynamic>? _getFriendPhysioAssessment(String friendId) {
    try {
      final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
      final raw = box.get('physio_assessment_$friendId');
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
    } catch (_) {}
    return null;
  }

  List<Map<String, dynamic>> _getFriendPhysioExercises(String friendId) {
    try {
      final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
      final raw = box.get('physio_exercises_$friendId');
      if (raw is List) {
        return List<Map<String, dynamic>>.from(raw.map((e) {
          if (e is Map) return Map<String, dynamic>.from(e);
          return {'title': e.toString(), 'focus': 'Mobility', 'target': 'Standard'};
        }));
      }
    } catch (_) {}
    return [];
  }

  Map<String, dynamic>? _getFriendSpeechAssessment(String friendId) {
    try {
      final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
      final raw = box.get('speech_assessment_$friendId');
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
    } catch (_) {}
    return null;
  }

  List<Map<String, dynamic>> _getFriendSpeechActivities(String friendId) {
    try {
      final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
      final raw = box.get('speech_activities_$friendId');
      if (raw is List) {
        return List<Map<String, dynamic>>.from(raw.map((e) {
          if (e is Map) return Map<String, dynamic>.from(e);
          return {'title': e.toString(), 'category': 'General'};
        }));
      }
    } catch (_) {}
    return [];
  }

  Map<String, dynamic>? _getFriendMedicalRecord(String friendId) {
    try {
      final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
      final raw = box.get('medical_record_$friendId');
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
    } catch (_) {}
    return null;
  }

  List<String> _getFriendMedicalAllergies(String friendId) {
    try {
      final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
      final raw = box.get('medical_allergies_$friendId');
      if (raw is List) {
        return List<String>.from(raw.map((e) => e.toString()));
      }
    } catch (_) {}
    return [];
  }

  List<String> _getFriendMedicalVaccines(String friendId) {
    try {
      final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
      final raw = box.get('medical_vaccines_$friendId');
      if (raw is List) {
        return List<String>.from(raw.map((e) => e.toString()));
      }
    } catch (_) {}
    return [];
  }

  Widget _buildClinicalOversightTab({
    required BuildContext context,
    required List<Friend> friends,
    required AppLocalizations localizations,
    required bool isDark,
  }) {
    // Filtered friends for clinical view
    final clinicalFilteredFriends = friends.where((f) {
      final query = _clinicalSearchQuery.toLowerCase();
      final matchesSearch = f.fullName.toLowerCase().contains(query) ||
          f.registrationNumber.toLowerCase().contains(query);
      return matchesSearch;
    }).toList();

    Friend? selectedFriend;
    if (_selectedClinicalFriendId != null) {
      try {
        selectedFriend = friends.firstWhere((f) => f.id == _selectedClinicalFriendId);
      } catch (_) {}
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Banner
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 700;
              final consoleBtn = ElevatedButton.icon(
                icon: Icon(
                  _clinicalSegmentIndex == 0
                      ? Icons.accessibility_new
                      : _clinicalSegmentIndex == 1
                          ? Icons.record_voice_over
                          : Icons.local_hospital,
                  size: 16,
                ),
                label: Text(
                  _clinicalSegmentIndex == 0
                      ? 'Open Physio Console'
                      : _clinicalSegmentIndex == 1
                          ? 'Open Speech Console'
                          : 'Open Medical Console',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF004D40),
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: () {
                  if (_clinicalSegmentIndex == 0) {
                    context.push('/dashboard/physio');
                  } else if (_clinicalSegmentIndex == 1) {
                    context.push('/dashboard/speech');
                  } else {
                    context.push('/dashboard/medical');
                  }
                },
              );

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                        : [const Color(0xFF00695C), const Color(0xFF004D40)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: isNarrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.health_and_safety, color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Therapies & Clinical Oversight Console',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Institutional monitoring of beneficiary physiotherapy rehabilitation, speech development, and medical healthcare dossiers.',
                            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85), height: 1.4),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: consoleBtn,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.health_and_safety, color: Colors.white, size: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Therapies & Clinical Oversight Console',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Institutional monitoring of beneficiary physiotherapy rehabilitation, speech development, and medical healthcare dossiers.',
                                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          consoleBtn,
                        ],
                      ),
              );
            },
          ),
          const SizedBox(height: 20),

          // 2. Department Segment Switcher
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;
              final navButtons = [
                _buildDepartmentNavButton(
                  index: 0,
                  label: 'Physiotherapy',
                  icon: Icons.accessibility_new,
                  subtitle: 'Mobility & Rehab',
                  isSelected: _clinicalSegmentIndex == 0,
                  color: Colors.blue.shade700,
                ),
                _buildDepartmentNavButton(
                  index: 1,
                  label: 'Speech Therapy',
                  icon: Icons.record_voice_over,
                  subtitle: 'Language & Articulation',
                  isSelected: _clinicalSegmentIndex == 1,
                  color: Colors.purple.shade700,
                ),
                _buildDepartmentNavButton(
                  index: 2,
                  label: 'Medical & Health',
                  icon: Icons.local_hospital,
                  subtitle: 'Vitals & Prescriptions',
                  isSelected: _clinicalSegmentIndex == 2,
                  color: Colors.teal.shade700,
                ),
              ];

              return Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: isNarrow
                      ? Column(
                          children: [
                            navButtons[0],
                            const SizedBox(height: 8),
                            navButtons[1],
                            const SizedBox(height: 8),
                            navButtons[2],
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: navButtons[0]),
                            const SizedBox(width: 10),
                            Expanded(child: navButtons[1]),
                            const SizedBox(width: 10),
                            Expanded(child: navButtons[2]),
                          ],
                        ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // 3. Beneficiary Selector & Scope Bar
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;
              final scopeChip = ChoiceChip(
                label: const Text('All Beneficiaries Overview'),
                selected: _selectedClinicalFriendId == null,
                selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                onSelected: (val) {
                  if (val) setState(() => _selectedClinicalFriendId = null);
                },
              );

              final dropdown = DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedClinicalFriendId,
                  hint: const Text('Or select individual beneficiary to inspect...'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All Beneficiaries (Roster View)', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    ...friends.map((f) => DropdownMenuItem<String>(
                          value: f.id,
                          child: Text('${f.fullName} (${f.registrationNumber}) - ${localizations.translate(f.assignedWorkshopId)}'),
                        )),
                  ],
                  onChanged: (val) => setState(() => _selectedClinicalFriendId = val),
                ),
              );

              final clearBtn = _selectedClinicalFriendId != null
                  ? TextButton.icon(
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Clear Selection'),
                      onPressed: () => setState(() => _selectedClinicalFriendId = null),
                    )
                  : null;

              return Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: isNarrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.filter_list, size: 20, color: AppTheme.primaryColor),
                                const SizedBox(width: 8),
                                const Text('Scope:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(width: 8),
                                Expanded(child: scopeChip),
                              ],
                            ),
                            const SizedBox(height: 8),
                            dropdown,
                            if (clearBtn != null) ...[
                              const SizedBox(height: 4),
                              clearBtn,
                            ],
                          ],
                        )
                      : Row(
                          children: [
                            const Icon(Icons.filter_list, size: 20, color: AppTheme.primaryColor),
                            const SizedBox(width: 10),
                            const Text('Oversight Scope:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(width: 12),
                            scopeChip,
                            const SizedBox(width: 12),
                            Expanded(child: dropdown),
                            if (clearBtn != null) ...[
                              const SizedBox(width: 8),
                              clearBtn,
                            ],
                          ],
                        ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // 4. Content Area: Either All Friends Overview OR Single Friend Inspection
          if (selectedFriend == null)
            _buildAllFriendsClinicalOverview(
              context: context,
              friends: clinicalFilteredFriends,
              allFriends: friends,
              localizations: localizations,
              isDark: isDark,
            )
          else
            _buildSingleFriendClinicalDossier(
              context: context,
              friend: selectedFriend,
              localizations: localizations,
              isDark: isDark,
            ),
        ],
      ),
    );
  }

  Widget _buildDepartmentNavButton({
    required int index,
    required String label,
    required IconData icon,
    required String subtitle,
    required bool isSelected,
    required Color color,
  }) {
    return InkWell(
      onTap: () => setState(() => _clinicalSegmentIndex = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: isSelected ? color : Colors.grey.shade200,
              child: Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey.shade700),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isSelected ? color : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllFriendsClinicalOverview({
    required BuildContext context,
    required List<Friend> friends,
    required List<Friend> allFriends,
    required AppLocalizations localizations,
    required bool isDark,
  }) {
    // Compute department stats
    int totalPhysioSessions = 0;
    int totalSpeechSessions = 0;
    int totalVitals = 0;
    int totalPrescriptions = 0;
    int totalPhysioRating = 0;
    int physioAssessedCount = 0;
    int speechAssessedCount = 0;
    int totalSpeechActivities = 0;
    int totalMedicalAlerts = 0;

    for (final f in allFriends) {
      final physioSessions = _getFriendPhysioSessions(f.id);
      totalPhysioSessions += physioSessions.length;
      for (final s in physioSessions) {
        if (s['rating'] is num) {
          totalPhysioRating += (s['rating'] as num).toInt();
        }
      }
      final physioAssess = _getFriendPhysioAssessment(f.id);
      final physioEx = _getFriendPhysioExercises(f.id);
      if (physioAssess != null || physioEx.isNotEmpty) physioAssessedCount++;

      final speechSessions = _getFriendSpeechSessions(f.id);
      totalSpeechSessions += speechSessions.length;
      final speechAssess = _getFriendSpeechAssessment(f.id);
      final speechActs = _getFriendSpeechActivities(f.id);
      totalSpeechActivities += speechActs.length;
      if (speechAssess != null || speechActs.isNotEmpty) speechAssessedCount++;

      final vitals = _getFriendVitals(f.id);
      totalVitals += vitals.length;

      final pres = _getFriendPrescriptions(f.id);
      totalPrescriptions += pres.length;

      final allergies = _getFriendMedicalAllergies(f.id);
      totalMedicalAlerts += allergies.length;
    }

    final String physioAvgRating = totalPhysioSessions > 0
        ? '${(totalPhysioRating / totalPhysioSessions).toStringAsFixed(1)} / 5'
        : 'No ratings';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI Summary Cards based on current segment
        if (_clinicalSegmentIndex == 0) ...[
          // Physio KPIs
          _buildResponsiveKpiGrid([
            _buildClinicalMetricCard(
              title: 'Enrolled in Physio',
              value: '${allFriends.length}',
              subtitle: 'Active Beneficiary Caseload',
              icon: Icons.groups,
              color: Colors.blue.shade700,
            ),
            _buildClinicalMetricCard(
              title: 'Rehab Sessions',
              value: '$totalPhysioSessions',
              subtitle: 'Sessions Logged',
              icon: Icons.fitness_center,
              color: Colors.indigo.shade700,
            ),
            _buildClinicalMetricCard(
              title: 'Clinical Coverage',
              value: '$physioAssessedCount of ${allFriends.length}',
              subtitle: 'Evaluated by Physio',
              icon: Icons.verified_outlined,
              color: Colors.green.shade700,
            ),
            _buildClinicalMetricCard(
              title: 'Performance Score',
              value: physioAvgRating,
              subtitle: 'Average Session Rating',
              icon: Icons.speed,
              color: Colors.amber.shade800,
            ),
          ]),
        ] else if (_clinicalSegmentIndex == 1) ...[
          // Speech KPIs
          _buildResponsiveKpiGrid([
            _buildClinicalMetricCard(
              title: 'Speech Beneficiaries',
              value: '${allFriends.length}',
              subtitle: 'Active Caseload',
              icon: Icons.groups,
              color: Colors.purple.shade700,
            ),
            _buildClinicalMetricCard(
              title: 'Therapy Sessions',
              value: '$totalSpeechSessions',
              subtitle: 'Recorded Sessions',
              icon: Icons.record_voice_over,
              color: Colors.deepPurple.shade700,
            ),
            _buildClinicalMetricCard(
              title: 'Clinical Coverage',
              value: '$speechAssessedCount of ${allFriends.length}',
              subtitle: 'Evaluated by Speech Path.',
              icon: Icons.verified_outlined,
              color: Colors.teal.shade700,
            ),
            _buildClinicalMetricCard(
              title: 'Target Goals',
              value: '$totalSpeechActivities',
              subtitle: 'Configured Targets',
              icon: Icons.track_changes,
              color: Colors.amber.shade800,
            ),
          ]),
        ] else ...[
          // Medical KPIs
          _buildResponsiveKpiGrid([
            _buildClinicalMetricCard(
              title: 'Clinical Dossiers',
              value: '${allFriends.length}',
              subtitle: 'Beneficiaries Monitored',
              icon: Icons.health_and_safety,
              color: Colors.teal.shade700,
            ),
            _buildClinicalMetricCard(
              title: 'Vitals Recorded',
              value: '$totalVitals',
              subtitle: 'BP, Pulse & Temp Logs',
              icon: Icons.monitor_heart,
              color: Colors.blue.shade700,
            ),
            _buildClinicalMetricCard(
              title: 'Active Prescriptions',
              value: '$totalPrescriptions',
              subtitle: 'Medications Monitored',
              icon: Icons.medication,
              color: Colors.orange.shade800,
            ),
            _buildClinicalMetricCard(
              title: 'Medical Alerts',
              value: '$totalMedicalAlerts Active',
              subtitle: 'Allergies & High-Priority Flags',
              icon: Icons.crisis_alert,
              color: Colors.green.shade700,
            ),
          ]),
        ],
        const SizedBox(height: 24),

        // Search & Filter Row
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _clinicalSearchController,
                decoration: InputDecoration(
                  hintText: 'Search beneficiary by name or registration ID...',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
                  suffixIcon: _clinicalSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _clinicalSearchController.clear();
                            setState(() => _clinicalSearchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (val) => setState(() => _clinicalSearchQuery = val.trim()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Beneficiary Clinical Roster Cards
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
                    final isNarrow = constraints.maxWidth < 650;
                    final titleWidget = Text(
                      _clinicalSegmentIndex == 0
                          ? 'Physiotherapy Caseload & Rehabilitation Roster'
                          : _clinicalSegmentIndex == 1
                              ? 'Speech & Language Articulation Roster'
                              : 'Medical Clinical Health Roster',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    );
                    final badgeWidget = Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.visibility, size: 12, color: Colors.amber),
                          SizedBox(width: 4),
                          Text('Principal Oversight Mode (Read-Only)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber)),
                        ],
                      ),
                    );

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          titleWidget,
                          const SizedBox(height: 8),
                          badgeWidget,
                        ],
                      );
                    }
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: titleWidget),
                        const SizedBox(width: 8),
                        badgeWidget,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (friends.isEmpty)
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
                    itemCount: friends.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, index) {
                      final friend = friends[index];
                      final provider = getAppImageProvider(friend.photoUrl);
                      final physioCount = _getFriendPhysioSessions(friend.id).length;
                      final speechCount = _getFriendSpeechSessions(friend.id).length;
                      final vitalsCount = _getFriendVitals(friend.id).length;
                      final rxCount = _getFriendPrescriptions(friend.id).length;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: LayoutBuilder(
                          builder: (context, itemConstraints) {
                            final isNarrow = itemConstraints.maxWidth < 650;
                            final avatarAndInfo = Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundImage: provider,
                                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                                  child: provider == null
                                      ? Text(friend.fullName.isNotEmpty ? friend.fullName[0] : 'B', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor))
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
                                      if (_clinicalSegmentIndex == 0)
                                        Builder(
                                          builder: (_) {
                                            final physioAssess = _getFriendPhysioAssessment(friend.id);
                                            final physioEx = _getFriendPhysioExercises(friend.id);
                                            final isAssessed = physioAssess != null || physioEx.isNotEmpty;
                                            return Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                _buildClinicalBadge(isAssessed ? 'Status: Evaluated' : 'Pending Evaluation', isAssessed ? Colors.green : Colors.grey),
                                                _buildClinicalBadge('${physioEx.length} Exercise Targets', Colors.teal),
                                                _buildClinicalBadge('$physioCount Sessions Logged', Colors.blue),
                                              ],
                                            );
                                          },
                                        )
                                      else if (_clinicalSegmentIndex == 1)
                                        Builder(
                                          builder: (_) {
                                            final speechAssess = _getFriendSpeechAssessment(friend.id);
                                            final speechActs = _getFriendSpeechActivities(friend.id);
                                            final artic = speechAssess?['articulation_score']?.toString() ?? 'Pending Eval';
                                            return Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                _buildClinicalBadge('Artic: $artic', Colors.purple),
                                                _buildClinicalBadge('${speechActs.length} Target Goals', Colors.teal),
                                                _buildClinicalBadge('$speechCount Speech Sessions', Colors.deepPurple),
                                              ],
                                            );
                                          },
                                        )
                                      else
                                        Builder(
                                          builder: (_) {
                                            final allergies = _getFriendMedicalAllergies(friend.id);
                                            return Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                _buildClinicalBadge(
                                                  allergies.isNotEmpty ? '${allergies.length} Alerts' : 'No Allergies',
                                                  allergies.isNotEmpty ? Colors.red : Colors.teal,
                                                ),
                                                _buildClinicalBadge('$vitalsCount Vitals Logged', Colors.blue),
                                                _buildClinicalBadge('$rxCount Active Prescriptions', Colors.orange),
                                              ],
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            );

                            final actionButtons = [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.manage_search, size: 16),
                                label: const Text('Inspect Dossier', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                onPressed: () => setState(() => _selectedClinicalFriendId = friend.id),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.open_in_new, size: 14),
                                label: const Text('Full View', style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                onPressed: () {
                                  if (_clinicalSegmentIndex == 0) {
                                    context.push('/therapy/physiotherapy/${friend.id}');
                                  } else if (_clinicalSegmentIndex == 1) {
                                    context.push('/therapy/speech/${friend.id}');
                                  } else {
                                    context.push('/medical/${friend.id}');
                                  }
                                },
                              ),
                            ];

                            if (isNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  avatarAndInfo,
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(child: actionButtons[0]),
                                      const SizedBox(width: 8),
                                      Expanded(child: actionButtons[1]),
                                    ],
                                  ),
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: avatarAndInfo),
                                const SizedBox(width: 12),
                                Wrap(
                                  spacing: 8,
                                  children: actionButtons,
                                ),
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
    );
  }

  Widget _buildResponsiveKpiGrid(List<Widget> cards) {
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
            for (int i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: cards[i]),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSingleFriendClinicalDossier({
    required BuildContext context,
    required Friend friend,
    required AppLocalizations localizations,
    required bool isDark,
  }) {
    final provider = getAppImageProvider(friend.photoUrl);
    final physioSessions = _getFriendPhysioSessions(friend.id);
    final speechSessions = _getFriendSpeechSessions(friend.id);
    final vitals = _getFriendVitals(friend.id);
    final prescriptions = _getFriendPrescriptions(friend.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Beneficiary Header Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 650;
                final backBtn = OutlinedButton.icon(
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back to All Beneficiaries'),
                  onPressed: () => setState(() => _selectedClinicalFriendId = null),
                );

                final infoRow = Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: provider,
                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                      child: provider == null
                          ? Text(friend.fullName.isNotEmpty ? friend.fullName[0] : 'B', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.primaryColor))
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  friend.fullName,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(friend.registrationNumber, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Workshop: ${localizations.translate(friend.assignedWorkshopId)} • House: ${friend.assignedHouseId.replaceAll('_', ' ').toUpperCase()} • Age: ${friend.age} • Blood Group: ${friend.bloodGroup}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      infoRow,
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: backBtn,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: infoRow),
                    const SizedBox(width: 12),
                    backBtn,
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Read-Only Warning Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;
              final dedicatedBtn = ElevatedButton.icon(
                icon: const Icon(Icons.fullscreen, size: 16),
                label: const Text('Open Dedicated Screen', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  if (_clinicalSegmentIndex == 0) {
                    context.push('/therapy/physiotherapy/${friend.id}');
                  } else if (_clinicalSegmentIndex == 1) {
                    context.push('/therapy/speech/${friend.id}');
                  } else {
                    context.push('/medical/${friend.id}');
                  }
                },
              );

              final textWidget = Row(
                children: [
                  Icon(Icons.lock_outline, color: Colors.amber.shade900, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Principal Clinical Oversight Mode — This dossier is in Read-Only view. Direct modifications, therapy assessments, and session recording are restricted to certified specialists.',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    textWidget,
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: dedicatedBtn),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: textWidget),
                  const SizedBox(width: 10),
                  dedicatedBtn,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 20),

        // Specific Department Content
        if (_clinicalSegmentIndex == 0) ...[
          // PHYSIOTHERAPY DOSSIER
          _buildPhysioDossierView(friend, physioSessions),
        ] else if (_clinicalSegmentIndex == 1) ...[
          // SPEECH THERAPY DOSSIER
          _buildSpeechDossierView(friend, speechSessions),
        ] else ...[
          // MEDICAL DOSSIER
          _buildMedicalDossierView(friend, vitals, prescriptions),
        ],
      ],
    );
  }

  Widget _buildPhysioDossierView(Friend friend, List<Map<String, dynamic>> sessions) {
    final assessment = _getFriendPhysioAssessment(friend.id);
    final exercises = _getFriendPhysioExercises(friend.id);

    final rom = (assessment?['range_of_motion'] ?? '').toString();
    final strength = (assessment?['muscle_strength'] ?? '').toString();
    final balance = (assessment?['balance'] ?? '').toString();
    final postureGait = (assessment?['posture_gait'] ?? '').toString();
    final isAssessed = assessment != null || exercises.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Physical Assessment Summary Card
        Card(
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.accessibility_new, color: AppTheme.primaryColor),
                        SizedBox(width: 8),
                        Text('Physical Therapy Clinical Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isAssessed ? Colors.green.shade50 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: isAssessed ? Colors.green.shade200 : Colors.grey.shade300),
                      ),
                      child: Text(
                        isAssessed ? 'Evaluated' : 'Pending Evaluation',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isAssessed ? Colors.green.shade800 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildDossierField('Range of Motion (ROM)', rom.isNotEmpty ? rom : 'Pending evaluation by specialist')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDossierField('Muscle Strength', strength.isNotEmpty ? strength : 'Pending evaluation by specialist')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildDossierField('Static & Dynamic Balance', balance.isNotEmpty ? balance : 'Pending evaluation by specialist')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDossierField('Mobility & Gait Profile', postureGait.isNotEmpty ? postureGait : 'Pending evaluation by specialist')),
                  ],
                ),
                if (exercises.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Active Exercise Targets & Regimen', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: exercises.map((ex) {
                      final title = ex['title'] ?? 'Exercise';
                      final focus = ex['focus'] ?? 'Mobility';
                      final target = ex['target'] ?? '10 reps';
                      return Chip(
                        backgroundColor: Colors.teal.shade50,
                        avatar: const Icon(Icons.fitness_center, size: 14, color: Colors.teal),
                        label: Text('$title ($focus • $target)', style: TextStyle(fontSize: 11, color: Colors.teal.shade900, fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Session Logs
        Card(
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Physiotherapy Session Logs (${sessions.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      sessions.isEmpty ? 'No sessions logged yet' : 'Latest session on ${sessions.first['date'] ?? 'Recent'}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (sessions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: Text('No physiotherapy sessions recorded for this beneficiary yet.', style: TextStyle(color: Colors.grey))),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final s = sessions[idx];
                      final rating = (s['rating'] as num?)?.toInt() ?? 4;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade50,
                          child: const Icon(Icons.fitness_center, color: Colors.blue, size: 20),
                        ),
                        title: Row(
                          children: [
                            Text('Date: ${s['date'] ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(width: 10),
                            Text('(${s['duration'] ?? 30} mins)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(s['notes'] != null && s['notes'].toString().isNotEmpty ? s['notes'] : 'General mobility and gait exercises completed.', style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 4),
                            Row(
                              children: List.generate(
                                5,
                                (i) => Icon(i < rating ? Icons.star : Icons.star_border, size: 14, color: Colors.amber),
                              ),
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
    );
  }

  Widget _buildSpeechDossierView(Friend friend, List<Map<String, dynamic>> sessions) {
    final assessment = _getFriendSpeechAssessment(friend.id);
    final activities = _getFriendSpeechActivities(friend.id);

    final artic = (assessment?['articulation_score'] ?? '').toString();
    final receptive = (assessment?['receptive_language'] ?? '').toString();
    final expressive = (assessment?['expressive_language'] ?? '').toString();
    final targetGoal = (assessment?['target_goal'] ?? '').toString();
    final isAssessed = assessment != null || activities.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Speech Assessment Card
        Card(
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.record_voice_over, color: Colors.purple),
                        SizedBox(width: 8),
                        Text('Speech & Communication Clinical Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isAssessed ? Colors.purple.shade50 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: isAssessed ? Colors.purple.shade200 : Colors.grey.shade300),
                      ),
                      child: Text(
                        isAssessed ? 'Evaluated' : 'Pending Evaluation',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isAssessed ? Colors.purple.shade900 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildDossierField('Articulation Level', artic.isNotEmpty ? artic : 'Pending evaluation by specialist')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDossierField('Receptive Language', receptive.isNotEmpty ? receptive : 'Pending evaluation by specialist')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildDossierField('Expressive Communication', expressive.isNotEmpty ? expressive : 'Pending evaluation by specialist')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDossierField('Quarterly Speech Goal', targetGoal.isNotEmpty ? targetGoal : 'Pending goal setting')),
                  ],
                ),
                if (activities.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Active Communication Targets & Exercises', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: activities.map((act) {
                      final title = act['title'] ?? 'Activity';
                      final cat = act['category'] ?? 'General';
                      return Chip(
                        backgroundColor: Colors.purple.shade50,
                        avatar: const Icon(Icons.record_voice_over, size: 14, color: Colors.purple),
                        label: Text('$title ($cat)', style: TextStyle(fontSize: 11, color: Colors.purple.shade900, fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Session Logs
        Card(
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Speech Therapy Session Logs (${sessions.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      sessions.isEmpty ? 'No sessions logged yet' : 'Latest session on ${sessions.first['date'] ?? 'Recent'}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (sessions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: Text('No speech therapy sessions recorded for this beneficiary yet.', style: TextStyle(color: Colors.grey))),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final s = sessions[idx];
                      final rating = (s['rating'] as num?)?.toInt() ?? 4;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: Colors.purple.shade50,
                          child: const Icon(Icons.record_voice_over, color: Colors.purple, size: 20),
                        ),
                        title: Row(
                          children: [
                            Text('Date: ${s['date'] ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(width: 10),
                            Text('(${s['duration'] ?? 30} mins)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(s['notes'] != null && s['notes'].toString().isNotEmpty ? s['notes'] : 'Verbal articulation and picture exchange practice.', style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 4),
                            Row(
                              children: List.generate(
                                5,
                                (i) => Icon(i < rating ? Icons.star : Icons.star_border, size: 14, color: Colors.amber),
                              ),
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
    );
  }

  Widget _buildMedicalDossierView(Friend friend, List<Map<String, dynamic>> vitals, List<Map<String, dynamic>> prescriptions) {
    final medicalRecord = _getFriendMedicalRecord(friend.id);
    final allergies = _getFriendMedicalAllergies(friend.id);
    final vaccines = _getFriendMedicalVaccines(friend.id);

    final diagnosis = (medicalRecord?['diagnosis'] ?? '').toString();
    final history = (medicalRecord?['history'] ?? '').toString();

    final diagStr = diagnosis.isNotEmpty
        ? diagnosis
        : (friend.medicalNotesSummary.isNotEmpty ? friend.medicalNotesSummary : 'Pending clinical diagnosis');
    final histStr = history.isNotEmpty ? history : 'No medical history summary recorded on file';
    final allergyStr = allergies.isNotEmpty ? allergies.join(', ') : 'No known drug allergies or health alerts recorded';
    final vaxStr = vaccines.isNotEmpty ? vaccines.join(', ') : 'No immunization records on file';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Health Alerts & Vitals Overview
        Card(
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.local_hospital, color: Colors.teal),
                        SizedBox(width: 8),
                        Text('Medical Health Profile & Vital Records', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: allergies.isNotEmpty ? Colors.red.shade50 : Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: allergies.isNotEmpty ? Colors.red.shade200 : Colors.teal.shade200),
                      ),
                      child: Text(
                        allergies.isNotEmpty ? '${allergies.length} Alert(s) Flagged' : 'No Critical Alerts',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: allergies.isNotEmpty ? Colors.red.shade900 : Colors.teal.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildDossierField('Known Allergies & Medical Alerts', allergyStr)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDossierField('Clinical Diagnosis', diagStr)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildDossierField('Medical History Summary', histStr)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDossierField('Immunizations & Vaccinations', vaxStr)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildDossierField('Blood Group & Factor', friend.bloodGroup.isNotEmpty ? friend.bloodGroup : 'Not specified')),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Vitals History
        Card(
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Vitals Log (${vitals.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      vitals.isEmpty ? 'No recent logs' : 'Latest: ${vitals.first['date'] ?? 'Recent'}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (vitals.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(child: Text('No vitals recorded for this beneficiary yet.', style: TextStyle(color: Colors.grey))),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: vitals.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final v = vitals[idx];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.shade50,
                          child: const Icon(Icons.monitor_heart, color: Colors.teal, size: 20),
                        ),
                        title: Text('BP: ${v['bp'] ?? '120/80'} • Heart Rate: ${v['pulse'] ?? '75'} bpm', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('Temp: ${v['temp'] ?? '98.6'}°F • Weight: ${v['weight'] ?? '58'} kg • Recorded: ${v['date'] ?? 'N/A'}', style: const TextStyle(fontSize: 12)),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Active Prescriptions & Document Scans
        Card(
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Active Prescriptions & Medical Documents (${prescriptions.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Text('Official Doctor Prescriptions', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 12),
                if (prescriptions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(child: Text('No active prescriptions recorded for this beneficiary.', style: TextStyle(color: Colors.grey))),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: prescriptions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final p = prescriptions[idx];
                      final hasDoc = p['attachment_url'] != null && p['attachment_url'].toString().isNotEmpty;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.orange.shade50,
                              child: const Icon(Icons.medication, color: Colors.orange, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p['medication_name'] ?? 'Medication', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text('Dosage: ${p['dosage'] ?? 'As directed'} • Frequency: ${p['frequency'] ?? 'Daily'} • Doctor: ${p['doctor_name'] ?? 'Medical Officer'}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                  Text('Prescribed: ${p['date'] ?? 'N/A'}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ),
                            if (hasDoc)
                              ElevatedButton.icon(
                                icon: const Icon(Icons.description, size: 14),
                                label: const Text('View Scan / PDF', style: TextStyle(fontSize: 11)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                onPressed: () {
                                  openPlatformFile(
                                    fileUrl: p['attachment_url'].toString(),
                                    fileName: 'Prescription_${p['medication_name'] ?? 'Doc'}',
                                    fileType: p['attachment_url'].toString().toLowerCase().endsWith('.pdf') ? 'pdf' : 'image',
                                  );
                                },
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('No Scan Attached', style: TextStyle(fontSize: 11, color: Colors.grey)),
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
    );
  }

  Widget _buildDossierField(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildClinicalMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(icon, size: 16, color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildClinicalBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
