import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/shared/widgets/responsive_layout.dart';
import '../../../core/theme/theme.dart';
import '../../../core/localization/localization.dart';
import '../../../core/utils/image_utils.dart';
import 'friends_provider.dart';
import '../../auth/presentation/auth_providers.dart';

class FriendListScreen extends ConsumerStatefulWidget {
  const FriendListScreen({super.key});

  @override
  ConsumerState<FriendListScreen> createState() => _FriendListScreenState();
}

class _FriendListScreenState extends ConsumerState<FriendListScreen> {
  String _searchQuery = '';
  String _selectedWorkshop = 'all';
  String _selectedGender = 'all';

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isWorkshopStaff = user?.role == 'workshop_staff';
    final friends = ref.watch(visibleFriendsProvider);

    // Apply search and filter logic
    final filteredFriends = friends.where((friend) {
      final matchesSearch = friend.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          friend.registrationNumber.toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesWorkshop = _selectedWorkshop == 'all' || friend.assignedWorkshopId == _selectedWorkshop;
      
      final matchesGender = _selectedGender == 'all' || friend.gender == _selectedGender;

      return matchesSearch && matchesWorkshop && matchesGender;
    }).toList();

    return ResponsiveLayout(
      title: localizations.translate('friends'),
      currentRoute: '/friends',
      floatingActionButton: (user?.role == 'principal' || user?.role == 'admin')
          ? FloatingActionButton(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
              onPressed: () {
                context.push('/friends/add');
              },
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Search and Filters bar
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Search Textfield
                    TextField(
                      decoration: InputDecoration(
                        hintText: localizations.translate('search'),
                        prefixIcon: const Icon(Icons.search),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final useColumn = constraints.maxWidth < 500;
                        final workshopFilter = DropdownButtonFormField<String>(
                          value: _selectedWorkshop,
                          decoration: const InputDecoration(
                            labelText: 'Workshop',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: [
                            const DropdownMenuItem(value: 'all', child: Text('All Workshops')),
                            DropdownMenuItem(value: 'bakery', child: Text(localizations.translate('bakery'))),
                            DropdownMenuItem(value: 'woodwork', child: Text(localizations.translate('woodwork'))),
                            DropdownMenuItem(value: 'farming', child: Text(localizations.translate('farming'))),
                            DropdownMenuItem(value: 'textile', child: Text(localizations.translate('textile'))),
                            DropdownMenuItem(value: 'artwork', child: Text(localizations.translate('artwork'))),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedWorkshop = value ?? 'all';
                            });
                          },
                        );

                        final genderFilter = DropdownButtonFormField<String>(
                          value: _selectedGender,
                          decoration: const InputDecoration(
                            labelText: 'Gender',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All Genders')),
                            DropdownMenuItem(value: 'male', child: Text('Male')),
                            DropdownMenuItem(value: 'female', child: Text('Female')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedGender = value ?? 'all';
                            });
                          },
                        );

                        if (isWorkshopStaff) {
                          return genderFilter;
                        }

                        if (useColumn) {
                          return Column(
                            children: [
                              workshopFilter,
                              const SizedBox(height: 16),
                              genderFilter,
                            ],
                          );
                        } else {
                          return Row(
                            children: [
                              Expanded(child: workshopFilter),
                              const SizedBox(width: 16),
                              Expanded(child: genderFilter),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Friends List View
            Expanded(
              child: filteredFriends.isEmpty
                  ? const Center(
                      child: Text(
                        'No Friends profiles match your search criteria.',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredFriends.length,
                      itemBuilder: (context, index) {
                        final friend = filteredFriends[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            leading: Hero(
                              tag: 'avatar_${friend.id}',
                              child: CircleAvatar(
                                key: ValueKey('avatar_${friend.id}_${friend.photoUrl}'),
                                radius: 28,
                                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                backgroundImage: getAppImageProvider(friend.photoUrl),
                                onBackgroundImageError: (_, __) {},
                                child: getAppImageProvider(friend.photoUrl) == null
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                            ),
                            title: Text(
                              friend.fullName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('Reg: ${friend.registrationNumber} • Age: ${friend.age}'),
                                const SizedBox(height: 2),
                                Text(
                                  'Workshop: ${localizations.translate(friend.assignedWorkshopId)}',
                                  style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              context.push('/friends/${friend.id}');
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
