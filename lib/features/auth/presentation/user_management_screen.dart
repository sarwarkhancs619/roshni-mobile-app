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
  String? _selectedWorkshop;
  
  List<Map<String, dynamic>> _customUsers = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    List<Map<String, dynamic>> loadedUsers = [];
    
    // 1. Load from Supabase Profiles (if configured)
    final isConfigured = SupabaseDbService.isConfigured;
    if (isConfigured) {
      try {
        final List<dynamic> dbProfiles = await Supabase.instance.client
            .from('profiles')
            .select();
        for (var p in dbProfiles) {
          loadedUsers.add({
            'uid': p['id'],
            'email': p['email'],
            'fullName': p['full_name'],
            'role': p['role'],
            'workshopId': p['workshop_id'],
            'isActive': p['is_active'] ?? true,
          });
        }
      } catch (e) {
        debugPrint('Error loading profiles from Supabase: $e');
      }
    }
    
    // 2. Load from Hive local storage and merge
    try {
      final box = Hive.box('users');
      for (var key in box.keys) {
        final data = box.get(key);
        if (data != null) {
          final map = Map<String, dynamic>.from(data);
          final exists = loadedUsers.any((u) => u['email']?.toString().toLowerCase() == map['email']?.toString().toLowerCase());
          if (!exists) {
            loadedUsers.add(map);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading local Hive users: $e');
    }
    
    if (mounted) {
      setState(() {
        _customUsers = loadedUsers;
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
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      
      final success = await ref.read(authProvider.notifier).registerUser(
        fullName: name,
        email: email,
        password: password,
        role: _selectedRole,
        workshopId: _selectedWorkshop,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context).translate('user_created')}: $name'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        _nameController.clear();
        _emailController.clear();
        _passwordController.clear();
        _selectedWorkshop = null;
        _loadUsers();
      } else if (mounted) {
        final err = ref.read(authProvider).errorMessage ?? 'Registration failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final authState = ref.watch(authProvider);

    Widget buildFormCard(bool isWide) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(isWide ? 24.0 : 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  localizations.translate('add_user'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryColor),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Please enter full name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email),
                  ),
                  validator: (val) => val == null || !val.contains('@') ? 'Please enter a valid email' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
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
                    DropdownMenuItem(value: 'workshop_staff', child: Text('Workshop Staff')),
                    DropdownMenuItem(value: 'physiotherapist', child: Text('Physiotherapist')),
                    DropdownMenuItem(value: 'speech_therapist', child: Text('Speech Therapist')),
                    DropdownMenuItem(value: 'medical_officer', child: Text('Medical Officer')),
                    DropdownMenuItem(value: 'house_staff', child: Text('House Mother/Staff')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedRole = val!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (_selectedRole == 'workshop_staff' || _selectedRole == 'house_staff')
                  DropdownButtonFormField<String>(
                    value: _selectedWorkshop,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Assigned Workshop / House',
                      prefixIcon: Icon(Icons.meeting_room),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'bakery', child: Text('Bakery Workshop')),
                      DropdownMenuItem(value: 'woodwork', child: Text('Woodwork Workshop')),
                      DropdownMenuItem(value: 'farming', child: Text('Farming Workshop')),
                      DropdownMenuItem(value: 'textile', child: Text('Textile Workshop')),
                      DropdownMenuItem(value: 'artwork', child: Text('Artwork & Handicrafts')),
                      DropdownMenuItem(value: 'amin_house', child: Text('Amin House (Residential)')),
                      DropdownMenuItem(value: 'roshni_house', child: Text('Roshni House (Residential)')),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedWorkshop = val;
                      });
                    },
                    validator: (val) => val == null ? 'Please assign a facility/workshop' : null,
                  ),
                const SizedBox(height: 24),
                if (authState.isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  ElevatedButton(
                    onPressed: _createUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryColor,
                    ),
                    child: Text(localizations.translate('add_user')),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    Widget buildDirectoryList(bool isWide) {
      final list = ListView(
        shrinkWrap: !isWide,
        physics: isWide ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
        children: [
          if (_customUsers.isNotEmpty) ...[
            ..._customUsers.map((u) => ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: isWide ? 16.0 : 8.0),
              leading: const CircleAvatar(
                backgroundColor: AppTheme.secondaryColor,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(
                u['fullName'] ?? '',
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${u['email']}\nRole: ${u['role']}',
                style: const TextStyle(fontSize: 11),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              trailing: u['workshopId'] != null 
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.secondaryColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      u['workshopId']!.toString().toUpperCase(), 
                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
                    ),
                  ) 
                : null,
            )),
          ] else ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Text(
                  'No users found in directory.',
                  style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ),
            ),
          ],
        ],
      );

      if (isWide) {
        return Expanded(child: list);
      } else {
        return list;
      }
    }

    Widget buildDirectoryCard(bool isWide) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(isWide ? 24.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'System Staff & Users Directory',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryColor),
              ),
              const SizedBox(height: 16),
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
          final currentUser = ref.watch(authProvider).user;
          final isPrincipal = currentUser?.role == 'principal';

          if (isWide) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isPrincipal) ...[
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
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  if (isPrincipal) ...[
                    buildFormCard(false),
                    const SizedBox(height: 20),
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
