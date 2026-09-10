import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../../core/theme/theme.dart';
import '../../../core/localization/localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_db_service.dart';
import 'auth_providers.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  String _selectedRole = 'workshop_staff';
  String? _selectedFacility;
  bool _isLoadingUsers = false;
  
  List<Map<String, dynamic>> _users = [];

  static const Set<String> _demoEmails = {
    'principal@roshni.org',
    'bakery@roshni.org',
    'woodwork@roshni.org',
    'textile@roshni.org',
    'house@roshni.org',
    'physio@roshni.org',
    'speech@roshni.org',
    'medical@roshni.org',
    'art@roshni.org',
  };

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoadingUsers = true;
    });

    List<Map<String, dynamic>> loadedUsers = [];
    
    // 1. Load from Supabase Profiles (if configured)
    final isConfigured = SupabaseDbService.isConfigured;
    if (isConfigured) {
      try {
        final List<dynamic> dbProfiles = await Supabase.instance.client
            .from('profiles')
            .select()
            .order('role', ascending: true);
        for (var p in dbProfiles) {
          final email = p['email']?.toString().toLowerCase() ?? '';
          if (_demoEmails.contains(email)) continue;

          loadedUsers.add({
            'uid': p['id'],
            'email': p['email'],
            'fullName': p['full_name'] ?? 'User',
            'role': p['role'] ?? 'workshop_staff',
            'workshopId': p['workshop_id'],
            'isActive': p['is_active'] ?? true,
            'source': 'supabase',
          });
        }
      } catch (e) {
        debugPrint('Error loading profiles from Supabase: $e');
      }
    }
    
    // 2. Load from Hive local storage and merge (purging any demo keys)
    try {
      final box = Hive.box('users');
      final keysToDelete = <dynamic>[];

      for (var key in box.keys) {
        if (key == 'current_session_user') continue;
        final data = box.get(key);
        if (data != null) {
          final map = Map<String, dynamic>.from(data);
          final email = map['email']?.toString().toLowerCase() ?? key.toString().toLowerCase();

          if (_demoEmails.contains(email)) {
            keysToDelete.add(key);
            continue;
          }

          final exists = loadedUsers.any((u) => u['email']?.toString().toLowerCase() == email);
          if (!exists) {
            loadedUsers.add({
              ...map,
              'source': 'local',
            });
          }
        }
      }

      for (final k in keysToDelete) {
        box.delete(k);
      }
    } catch (e) {
      debugPrint('Error loading local Hive users: $e');
    }

    // Sort: Admin first, then Principal, then alphabetical
    loadedUsers.sort((a, b) {
      if (a['role'] == 'admin') return -1;
      if (b['role'] == 'admin') return 1;
      if (a['role'] == 'principal') return -1;
      if (b['role'] == 'principal') return 1;
      return (a['fullName'] ?? '').toString().compareTo((b['fullName'] ?? '').toString());
    });
    
    if (mounted) {
      setState(() {
        _users = loadedUsers;
        _isLoadingUsers = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _createUser() async {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text.trim();

      if (_demoEmails.contains(email)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demo email addresses are disabled. Please use a real staff email.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
      
      final success = await ref.read(authProvider.notifier).registerUser(
        fullName: name,
        email: email,
        password: password,
        role: _selectedRole,
        workshopId: _selectedFacility,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context).translate('user_created')}: $name ($email)'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        _nameController.clear();
        _emailController.clear();
        _passwordController.clear();
        _selectedFacility = null;
        _loadUsers();
      } else if (mounted) {
        final err = ref.read(authProvider).errorMessage ?? 'Registration failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _confirmDeleteUser(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Staff User?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete ${user['fullName']} (${user['email']})?\n\n'
          'This will permanently remove their profile and login credentials from Supabase.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ref.read(authProvider.notifier).deleteUser(
        user['uid']?.toString() ?? '',
        user['email']?.toString() ?? '',
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User ${user['fullName']} deleted successfully.'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          _loadUsers();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete user. Please check permissions.'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  String _formatRoleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Administrator';
      case 'principal':
        return 'Principal';
      case 'workshop_staff':
        return 'Workshop Staff';
      case 'house_staff':
        return 'House Staff';
      case 'physiotherapist':
        return 'Physiotherapist';
      case 'speech_therapist':
        return 'Speech Therapist';
      case 'medical_officer':
        return 'Medical Officer';
      default:
        return role.replaceAll('_', ' ').toUpperCase();
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.purple;
      case 'principal':
        return AppTheme.primaryColor;
      case 'workshop_staff':
        return AppTheme.secondaryColor;
      case 'house_staff':
        return Colors.teal;
      case 'physiotherapist':
        return Colors.indigo;
      case 'speech_therapist':
        return Colors.orange.shade800;
      case 'medical_officer':
        return Colors.red.shade700;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final authState = ref.watch(authProvider);
    final currentUser = authState.user;

    Widget buildFormCard(bool isWide) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(isWide ? 24.0 : 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_add_alt_1, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      localizations.translate('add_user'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryColor),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Create real staff accounts in Supabase DB with instant login credentials.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const Divider(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'e.g. Tariq Alvi / Fatima Noor',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter full name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'e.g. staff@roshni.org',
                    prefixIcon: Icon(Icons.email),
                  ),
                  validator: (val) {
                    if (val == null || !val.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    if (_demoEmails.contains(val.trim().toLowerCase())) {
                      return 'Demo emails are disabled. Please use a real email.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    hintText: 'Minimum 6 characters',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (val) => val == null || val.length < 6 ? 'Password must be at least 6 characters' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'System Role',
                    prefixIcon: Icon(Icons.badge),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('Administrator')),
                    DropdownMenuItem(value: 'principal', child: Text('Principal')),
                    DropdownMenuItem(value: 'workshop_staff', child: Text('Workshop Staff (Bakery, Woodwork, etc.)')),
                    DropdownMenuItem(value: 'house_staff', child: Text('House Mother / Staff (Residential)')),
                    DropdownMenuItem(value: 'physiotherapist', child: Text('Physiotherapist')),
                    DropdownMenuItem(value: 'speech_therapist', child: Text('Speech Therapist')),
                    DropdownMenuItem(value: 'medical_officer', child: Text('Medical Officer / Doctor')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedRole = val;
                        _selectedFacility = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Conditional Facility Dropdown for Workshop Staff
                if (_selectedRole == 'workshop_staff') ...[
                  DropdownButtonFormField<String>(
                    value: _selectedFacility,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Assigned Workshop',
                      prefixIcon: Icon(Icons.construction),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'bakery', child: Text('Bakery Workshop')),
                      DropdownMenuItem(value: 'woodwork', child: Text('Woodwork Workshop')),
                      DropdownMenuItem(value: 'farming', child: Text('Farming Workshop')),
                      DropdownMenuItem(value: 'textile', child: Text('Textile Workshop')),
                      DropdownMenuItem(value: 'artwork', child: Text('Artwork & Handicrafts Workshop')),
                      DropdownMenuItem(value: 'sports', child: Text('Sports & Athletics Workshop')),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedFacility = val;
                      });
                    },
                    validator: (val) => val == null ? 'Please select an assigned workshop' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                // Conditional Facility Dropdown for House Staff
                if (_selectedRole == 'house_staff') ...[
                  DropdownButtonFormField<String>(
                    value: _selectedFacility,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Assigned Residential House',
                      prefixIcon: Icon(Icons.home),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'sunbal_house', child: Text('Sunbal House (Residential)')),
                      DropdownMenuItem(value: 'roshni_house', child: Text('Roshni House (Residential)')),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedFacility = val;
                      });
                    },
                    validator: (val) => val == null ? 'Please select an assigned house' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 8),
                if (authState.isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.person_add),
                      onPressed: _createUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      label: Text(localizations.translate('add_user')),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    Widget buildDirectoryList(bool isWide) {
      if (_isLoadingUsers) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: CircularProgressIndicator(),
          ),
        );
      }

      final list = ListView.separated(
        shrinkWrap: !isWide,
        physics: isWide ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
        itemCount: _users.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final u = _users[index];
          final email = u['email']?.toString() ?? '';
          final role = u['role']?.toString() ?? 'workshop_staff';
          final facility = u['workshopId']?.toString();
          final isCurrentAdmin = email == currentUser?.email || email == 'sarwarkhancs619@gmail.com';

          return ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: isWide ? 16.0 : 8.0, vertical: 4.0),
            leading: CircleAvatar(
              backgroundColor: _getRoleColor(role),
              child: Text(
                (u['fullName']?.toString().isNotEmpty == true)
                    ? u['fullName']!.toString().substring(0, 1).toUpperCase()
                    : 'U',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    u['fullName'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isCurrentAdmin)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: const Text(
                      'YOU (ADMIN)',
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.purple),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  email,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getRoleColor(role).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatRoleLabel(role),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getRoleColor(role),
                        ),
                      ),
                    ),
                    if (facility != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.secondaryColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          facility.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondaryColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            trailing: isCurrentAdmin
                ? const Icon(Icons.verified, color: Colors.purple, size: 20)
                : IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    tooltip: 'Delete user',
                    onPressed: () => _confirmDeleteUser(u),
                  ),
          );
        },
      );

      if (_users.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 32.0),
          child: Center(
            child: Text(
              'No users found in directory.',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ),
        );
      }

      if (isWide) {
        return Expanded(child: list);
      } else {
        return list;
      }
    }

    Widget buildDirectoryCard(bool isWide) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(isWide ? 24.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Staff & Users Directory',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryColor),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                    tooltip: 'Refresh from Supabase',
                    onPressed: _loadUsers,
                  ),
                ],
              ),
              const Text(
                'Active staff accounts in Supabase database.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Divider(height: 20),
              buildDirectoryList(isWide),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.translate('manage_users')),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.blueOrangeGradient,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 850;
          final canManageUsers = currentUser?.role == 'principal' || currentUser?.role == 'admin';

          if (isWide) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (canManageUsers) ...[
                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(child: buildFormCard(true)),
                    ),
                    const SizedBox(width: 24),
                  ],
                  Expanded(
                    flex: 5,
                    child: buildDirectoryCard(true),
                  ),
                ],
              ),
            );
          } else {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (canManageUsers) ...[
                    buildFormCard(false),
                    const SizedBox(height: 16),
                  ],
                  buildDirectoryCard(false),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
