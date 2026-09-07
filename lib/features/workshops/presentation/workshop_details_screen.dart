import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/theme.dart';
import '../../../core/localization/localization.dart';
import '../../../core/shared/widgets/responsive_layout.dart';
import '../../../core/utils/image_utils.dart';
import '../../friends/presentation/friends_provider.dart';
import '../../friends/models/friend.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../../core/services/supabase_db_service.dart';
import '../../../core/storage/hive_storage.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;

class WorkshopDetailsScreen extends ConsumerStatefulWidget {
  final String workshopId;
  const WorkshopDetailsScreen({super.key, required this.workshopId});

  @override
  ConsumerState<WorkshopDetailsScreen> createState() => _WorkshopDetailsScreenState();
}

class _WorkshopDetailsScreenState extends ConsumerState<WorkshopDetailsScreen> {
  // 'all' represents the full workshop overview
  String _selectedFriendId = 'all';
  String _mood = 'good';
  
  // Ratings (1.0 to 5.0)
  double _participation = 3.5;
  double _communication = 3.5;
  double _independence = 3.5;
  double _taskCompletion = 3.5;

  // Skills specific to workshops
  final Map<String, List<String>> _workshopSkills = {
    'bakery': ['Mixing', 'Baking', 'Packaging', 'Cleaning'],
    'woodwork': ['Sanding', 'Cutting', 'Assembling', 'Polishing'],
    'farming': ['Composting', 'Animal Care', 'Harvesting', 'Fencing'],
    'textile': ['Cutting', 'Stitching', 'Ironing', 'Packing'],
    'artwork': ['Painting', 'Drawing', 'Clay Crafting', 'Polishing'],
    'sports': ['Physical Fitness', 'Ball Games', 'Athletics & Relay', 'Team Coordination'],
  };

  final Map<String, double> _skillRatings = {};

  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _newActivityController = TextEditingController();
  final List<String> _attachedPhotos = [];
  bool _isUploadingPhoto = false;
  bool _isSavingRecord = false;

  // Speech & Translation
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isTranslating = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _newActivityController.dispose();
    super.dispose();
  }

  Future<void> _loadFriendRecord(String friendId) async {
    final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
    final localData = box.get('record_${widget.workshopId}_$friendId');

    if (localData != null && localData is Map) {
      if (mounted) {
        setState(() {
          _mood = localData['mood']?.toString() ?? 'good';
          _participation = (localData['participation'] as num?)?.toDouble() ?? 3.5;
          _communication = (localData['communication'] as num?)?.toDouble() ?? 3.5;
          _independence = (localData['independence'] as num?)?.toDouble() ?? 3.5;
          _taskCompletion = (localData['task_completion'] as num?)?.toDouble() ?? 3.5;
          if (localData['skill_ratings'] != null) {
            final map = Map<String, dynamic>.from(localData['skill_ratings']);
            for (final e in map.entries) {
              _skillRatings[e.key] = (e.value as num?)?.toDouble() ?? 3.5;
            }
          }
          _notesController.text = localData['behavior_notes']?.toString() ?? localData['notes']?.toString() ?? '';
          _attachedPhotos.clear();
          if (localData['photo_urls'] is List) {
            _attachedPhotos.addAll((localData['photo_urls'] as List).map((e) => e.toString()));
          } else if (localData['attached_photos'] is List) {
            _attachedPhotos.addAll((localData['attached_photos'] as List).map((e) => e.toString()));
          }
        });
      }
    } else {
      // Clean baseline for this friend
      if (mounted) {
        setState(() {
          _mood = 'good';
          _participation = 3.5;
          _communication = 3.5;
          _independence = 3.5;
          _taskCompletion = 3.5;
          _notesController.clear();
          _attachedPhotos.clear();
          final skills = getSkillsForWorkshop(widget.workshopId);
          for (var s in skills) {
            _skillRatings[s] = 3.5;
          }
        });
      }
    }

    // Try fetching latest from Supabase in background
    if (SupabaseDbService.isConfigured) {
      try {
        final client = Supabase.instance.client;
        final activityRow = await client
            .from('activities')
            .select()
            .eq('friend_id', friendId)
            .eq('workshop_id', widget.workshopId)
            .order('date', ascending: false)
            .limit(1)
            .maybeSingle();

        final skillRows = await client
            .from('skills')
            .select()
            .eq('friend_id', friendId)
            .eq('workshop_id', widget.workshopId);

        if (activityRow != null && mounted) {
          setState(() {
            _mood = activityRow['mood']?.toString() ?? _mood;
            _participation = (activityRow['participation'] as num?)?.toDouble() ?? _participation;
            _communication = (activityRow['communication'] as num?)?.toDouble() ?? _communication;
            _independence = (activityRow['independence'] as num?)?.toDouble() ?? _independence;
            _taskCompletion = (activityRow['task_completion'] as num?)?.toDouble() ?? _taskCompletion;
            _notesController.text = activityRow['behavior_notes']?.toString() ?? activityRow['general_notes']?.toString() ?? _notesController.text;
            if (activityRow['photo_urls'] is List) {
              _attachedPhotos.clear();
              _attachedPhotos.addAll((activityRow['photo_urls'] as List).map((e) => e.toString()));
            }
            if (skillRows.isNotEmpty) {
              for (final row in skillRows) {
                final sName = row['skill_name']?.toString();
                final sRating = (row['rating'] as num?)?.toDouble();
                if (sName != null && sRating != null) {
                  _skillRatings[sName] = sRating;
                }
              }
            }
          });
        }
      } catch (e) {
        debugPrint('Supabase background fetch error: $e');
      }
    }
  }

  void _listen() async {
    if (!_isListening) {
      try {
        bool available = await _speech.initialize(
          onStatus: (val) {
            debugPrint('Speech status: $val');
            if (val == 'notListening') {
              if (mounted) setState(() => _isListening = false);
            }
          },
          onError: (val) => debugPrint('Speech error: $val'),
        );
        if (available) {
          setState(() => _isListening = true);
          _speech.listen(
            onResult: (val) {
              if (mounted) {
                setState(() {
                  _notesController.text = val.recognizedWords;
                });
              }
            },
          );
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Speech recognition is not available or permission denied.'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Speech initialization error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Speech recognition is not supported in this environment: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _translateNotes() async {
    final text = _notesController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isTranslating = true;
    });

    try {
      final translated = await _translateTextToEnglish(text);
      if (translated != null && translated.isNotEmpty) {
        setState(() {
          _notesController.text = translated;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notes translated to English successfully!'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } else {
        throw Exception('Translation service unavailable. Please try again.');
      }
    } catch (e) {
      debugPrint('Translation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Translation error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
      }
    }
  }

  Future<String?> _translateTextToEnglish(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    // 1. Primary: Google Client endpoint (Direct CORS Access-Control-Allow-Origin: *, auto-detects Roman Urdu & Urdu script)
    try {
      final url = 'https://clients5.google.com/translate_a/t?client=dict-chrome-ex&sl=auto&tl=en&q=${Uri.encodeComponent(trimmed)}';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 7));
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          final translated = data[0]?.toString().trim();
          if (translated != null && translated.isNotEmpty) {
            return translated;
          }
        }
      }
    } catch (e) {
      debugPrint('Google client translate error: $e');
    }

    // 2. Secondary: MyMemory Translation API (Free, CORS enabled)
    try {
      final myMemoryUrl = 'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(trimmed)}&langpair=ur|en';
      final response = await http.get(Uri.parse(myMemoryUrl)).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        final translatedText = data['responseData']?['translatedText'];
        if (translatedText != null && translatedText.toString().trim().isNotEmpty) {
          final result = translatedText.toString().trim();
          if (!result.toLowerCase().contains('my memory') && !result.toLowerCase().contains('quota exceeded')) {
            return result;
          }
        }
      }
    } catch (e) {
      debugPrint('MyMemory translation error: $e');
    }

    return null;
  }

  void _showVoiceAddActivityDialog() {
    final urduTextController = TextEditingController();
    final englishTextController = TextEditingController();
    bool dialogListening = false;
    bool dialogTranslating = false;
    String? dialogError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void startListening() async {
              try {
                bool available = await _speech.initialize(
                  onStatus: (status) {
                    if (status == 'notListening') {
                      setDialogState(() => dialogListening = false);
                    }
                  },
                  onError: (err) {
                    setDialogState(() {
                      dialogListening = false;
                      dialogError = err.errorMsg;
                    });
                  },
                );

                if (available) {
                  setDialogState(() {
                    dialogListening = true;
                    dialogError = null;
                  });

                  final locales = await _speech.locales();
                  final urduLocale = locales.where((l) => l.localeId.toLowerCase().contains('ur')).firstOrNull;
                  final localeId = urduLocale?.localeId ?? 'ur_PK';

                  _speech.listen(
                    listenOptions: stt.SpeechListenOptions(localeId: localeId),
                    onResult: (result) {
                      setDialogState(() {
                        urduTextController.text = result.recognizedWords;
                      });
                    },
                  );
                } else {
                  setDialogState(() {
                    dialogListening = false;
                    dialogError = 'Microphone not available. You can type directly in Urdu or English below.';
                  });
                }
              } catch (e) {
                setDialogState(() {
                  dialogListening = false;
                  dialogError = 'Speech error: $e';
                });
              }
            }

            void performTranslation() async {
              final raw = urduTextController.text.trim();
              if (raw.isEmpty) return;

              setDialogState(() {
                dialogTranslating = true;
                dialogError = null;
              });

              try {
                final translated = await _translateTextToEnglish(raw);
                if (translated != null && translated.isNotEmpty) {
                  setDialogState(() {
                    englishTextController.text = translated;
                  });
                } else {
                  setDialogState(() {
                    englishTextController.text = raw;
                  });
                }
              } catch (e) {
                setDialogState(() {
                  dialogError = 'Translation failed: $e. You can use typed text.';
                  englishTextController.text = raw;
                });
              } finally {
                setDialogState(() => dialogTranslating = false);
              }
            }

            void confirmAndAdd() {
              String activityName = englishTextController.text.trim();
              if (activityName.isEmpty) {
                activityName = urduTextController.text.trim();
              }
              if (activityName.isEmpty) {
                setDialogState(() {
                  dialogError = 'Please speak or enter an activity name.';
                });
                return;
              }

              if (dialogListening) _speech.stop();
              Navigator.pop(ctx);
              _addActivity(activityName);
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.mic, color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Text('Voice Add Activity (Urdu / Roman)', style: TextStyle(fontSize: 16)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Speak Urdu or Roman Urdu into the mic, then tap Translate to convert it into a standard vocational activity.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: GestureDetector(
                        onTap: dialogListening
                            ? () {
                                _speech.stop();
                                setDialogState(() => dialogListening = false);
                              }
                            : startListening,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: dialogListening ? Colors.red.withValues(alpha: 0.15) : AppTheme.primaryColor.withValues(alpha: 0.1),
                            border: Border.all(
                              color: dialogListening ? Colors.red : AppTheme.primaryColor,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            dialogListening ? Icons.mic : Icons.mic_none,
                            size: 36,
                            color: dialogListening ? Colors.red : AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        dialogListening ? 'Listening... Speak Urdu now...' : 'Tap Mic to Start Speaking',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: dialogListening ? Colors.red : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: urduTextController,
                      decoration: InputDecoration(
                        labelText: 'Urdu / Spoken Text',
                        hintText: 'e.g. roti banana, larki ka kaam...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: englishTextController,
                      decoration: InputDecoration(
                        labelText: 'Activity Name in English',
                        hintText: 'e.g. Baking Preparation',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    if (dialogTranslating) ...[
                      const SizedBox(height: 12),
                      const Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 8),
                            Text('Translating with AI...', style: TextStyle(fontSize: 12, color: Colors.blue)),
                          ],
                        ),
                      ),
                    ],
                    if (dialogError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        dialogError!,
                        style: const TextStyle(fontSize: 11, color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (dialogListening) _speech.stop();
                    Navigator.pop(ctx);
                  },
                  child: const Text('Cancel'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.g_translate, size: 16),
                  label: const Text('Translate'),
                  onPressed: dialogTranslating ? null : performTranslation,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Add Activity'),
                  onPressed: dialogTranslating ? null : confirmAndAdd,
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<String> getSkillsForWorkshop(String workshopId) {
    final defaultSkills = List<String>.from(_workshopSkills[workshopId] ?? ['Task Execution', 'Tool Handling', 'Safety', 'Cleaning']);
    final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
    final List<dynamic>? customSkills = box.get(workshopId);
    final List<dynamic>? deletedSkills = box.get('${workshopId}_deleted');

    final List<String> all = [...defaultSkills, ...(customSkills?.cast<String>() ?? [])];
    if (deletedSkills != null) {
      final toRemove = Set<String>.from(deletedSkills.map((e) => e.toString()));
      all.removeWhere((skill) => toRemove.contains(skill));
    }
    return all.toSet().toList();
  }

  Future<void> _addActivity(String newActivity) async {
    final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
    final List<dynamic> customSkills = box.get(widget.workshopId) ?? [];

    final String deletedKey = '${widget.workshopId}_deleted';
    final List<dynamic>? deletedSkills = box.get(deletedKey);
    if (deletedSkills != null && deletedSkills.contains(newActivity)) {
      final updatedDeleted = List<String>.from(deletedSkills.map((e) => e.toString()))..remove(newActivity);
      await box.put(deletedKey, updatedDeleted);
    }

    if (!customSkills.contains(newActivity)) {
      final updated = [...customSkills, newActivity];
      await box.put(widget.workshopId, updated);
    }

    setState(() {
      _skillRatings[newActivity] = 3.5;
    });
  }

  Future<void> _deleteActivity(String activity) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Activity'),
          ],
        ),
        content: Text('Are you sure you want to remove "$activity" from ${widget.workshopId.toUpperCase()} workshop?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
      final List<dynamic> customSkills = box.get(widget.workshopId) ?? [];
      final updatedCustom = List<String>.from(customSkills.map((e) => e.toString()))..remove(activity);

      final String deletedKey = '${widget.workshopId}_deleted';
      final List<dynamic> deletedSkills = box.get(deletedKey) ?? [];
      final updatedDeleted = List<String>.from(deletedSkills.map((e) => e.toString()));
      if (!updatedDeleted.contains(activity)) {
        updatedDeleted.add(activity);
      }

      await box.put(widget.workshopId, updatedCustom);
      await box.put(deletedKey, updatedDeleted);

      setState(() {
        _skillRatings.remove(activity);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Activity "$activity" removed.'),
            backgroundColor: Colors.grey.shade800,
          ),
        );
      }
    }
  }

  Future<void> _saveRecords() async {
    if (_selectedFriendId == 'all') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an individual Friend profile to record daily evaluations.')),
      );
      return;
    }

    final friendId = _selectedFriendId;
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    setState(() => _isSavingRecord = true);

    try {
      // 1. Save to local Hive
      final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
      final recordData = {
        'friend_id': friendId,
        'workshop_id': widget.workshopId,
        'date': todayStr,
        'mood': _mood,
        'participation': _participation.round(),
        'communication': _communication.round(),
        'independence': _independence.round(),
        'task_completion': _taskCompletion.round(),
        'skill_ratings': Map<String, double>.from(_skillRatings),
        'behavior_notes': _notesController.text,
        'general_notes': _notesController.text,
        'photo_urls': List<String>.from(_attachedPhotos),
        'updated_at': DateTime.now().toIso8601String(),
      };
      await box.put('record_${widget.workshopId}_$friendId', recordData);

      // 2. Save to Supabase if configured
      if (SupabaseDbService.isConfigured) {
        try {
          final client = Supabase.instance.client;

          // Check if activity row exists for today
          final existing = await client
              .from('activities')
              .select('id')
              .eq('friend_id', friendId)
              .eq('workshop_id', widget.workshopId)
              .eq('date', todayStr)
              .maybeSingle();

          final payload = {
            'friend_id': friendId,
            'workshop_id': widget.workshopId,
            'date': todayStr,
            'mood': _mood,
            'participation': _participation.round().clamp(1, 5),
            'communication': _communication.round().clamp(1, 5),
            'independence': _independence.round().clamp(1, 5),
            'task_completion': _taskCompletion.round().clamp(1, 5),
            'behavior_notes': _notesController.text,
            'general_notes': _notesController.text,
            'photo_urls': _attachedPhotos,
          };

          if (existing != null) {
            await client.from('activities').update(payload).eq('id', existing['id']);
          } else {
            await client.from('activities').insert(payload);
          }

          // Save skills
          for (final entry in _skillRatings.entries) {
            final existingSkill = await client
                .from('skills')
                .select('id')
                .eq('friend_id', friendId)
                .eq('workshop_id', widget.workshopId)
                .eq('skill_name', entry.key)
                .maybeSingle();

            final skillPayload = {
              'friend_id': friendId,
              'workshop_id': widget.workshopId,
              'skill_name': entry.key,
              'rating': entry.value.round().clamp(1, 5),
            };

            if (existingSkill != null) {
              await client.from('skills').update(skillPayload).eq('id', existingSkill['id']);
            } else {
              await client.from('skills').insert(skillPayload);
            }
          }
        } catch (e) {
          debugPrint('Supabase workshop activity save error: $e');
        }
      }

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle_outline, color: AppTheme.successColor, size: 48),
          title: const Text('Workshop Records Saved'),
          content: const Text('Daily activities, behavior assessment, and vocational skills have been recorded successfully.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error saving records: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving records: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingRecord = false);
    }
  }

  void _showPhotoPreview(String url) {
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
                    child: const Text('Failed to load image', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white, size: 18),
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getFriendSummary(Friend friend, int index) {
    final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
    final local = box.get('record_${widget.workshopId}_${friend.id}');
    if (local != null && local is Map) {
      return {
        'mood': local['mood']?.toString() ?? 'good',
        'participation': (local['participation'] as num?)?.toDouble() ?? 0.0,
        'independence': (local['independence'] as num?)?.toDouble() ?? 0.0,
        'taskCompletion': (local['task_completion'] as num?)?.toDouble() ?? 0.0,
        'hasCustomRecord': true,
        'notes': local['behavior_notes']?.toString() ?? local['notes']?.toString() ?? '',
        'photosCount': (local['photo_urls'] as List?)?.length ?? (local['attached_photos'] as List?)?.length ?? 0,
      };
    }
    return {
      'mood': 'pending',
      'participation': 0.0,
      'independence': 0.0,
      'taskCompletion': 0.0,
      'hasCustomRecord': false,
      'notes': 'Pending daily evaluation by workshop staff.',
      'photosCount': 0,
    };
  }

  Map<String, dynamic> _computeWorkshopStats(List<Friend> friends) {
    double partSum = 0;
    double indSum = 0;
    double compSum = 0;
    int evaluatedCount = 0;
    final Map<String, int> moodCounts = {
      'excellent': 0,
      'good': 0,
      'neutral': 0,
      'agitated': 0,
      'withdrawn': 0,
    };

    for (int i = 0; i < friends.length; i++) {
      final summary = _getFriendSummary(friends[i], i);
      if (summary['hasCustomRecord'] == true) {
        evaluatedCount++;
        final mood = summary['mood']?.toString() ?? 'good';
        if (moodCounts.containsKey(mood)) {
          moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
        }
        partSum += (summary['participation'] as num).toDouble();
        indSum += (summary['independence'] as num).toDouble();
        compSum += (summary['taskCompletion'] as num).toDouble();
      }
    }

    return {
      'evaluatedCount': evaluatedCount,
      'totalCount': friends.length,
      'avgParticipation': evaluatedCount > 0 ? (partSum / evaluatedCount).clamp(1.0, 5.0) : 0.0,
      'avgIndependence': evaluatedCount > 0 ? (indSum / evaluatedCount).clamp(1.0, 5.0) : 0.0,
      'avgCompletion': evaluatedCount > 0 ? (compSum / evaluatedCount).clamp(1.0, 5.0) : 0.0,
      'moodCounts': moodCounts,
    };
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final friends = ref.watch(friendsProvider);
    final workshopFriends = friends.where((f) => f.assignedWorkshopId == widget.workshopId).toList();
    final user = ref.read(authProvider).user;
    final isStaff = user?.role == 'workshop_staff';
    final isPrincipalOrAdmin = user?.role == 'principal' || user?.role == 'admin';
    final canSaveWorkshop = isStaff; // Only workshop staff can write evaluations

    final skills = getSkillsForWorkshop(widget.workshopId);

    // Initialize default skill ratings if not present
    for (var skill in skills) {
      if (!_skillRatings.containsKey(skill)) {
        _skillRatings[skill] = 3.5;
      }
    }

    // Identify currently selected friend
    Friend? currentFriend;
    if (_selectedFriendId != 'all') {
      currentFriend = workshopFriends.where((f) => f.id == _selectedFriendId).firstOrNull ??
          friends.where((f) => f.id == _selectedFriendId).firstOrNull;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final workshopName = localizations.translate(widget.workshopId);

    return ResponsiveLayout(
      title: '$workshopName Live Console',
      currentRoute: '/workshops/${widget.workshopId}',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Role Status Banner
            _buildRoleBanner(isStaff, isPrincipalOrAdmin, user?.fullName ?? 'User'),
            const SizedBox(height: 16),

            // 2. Friend Profile & Scope Selector Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
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
                          child: const Icon(Icons.people_alt_outlined, color: AppTheme.primaryColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select Beneficiary or Workshop Overview',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Text(
                                'Choose "All Friends" for aggregate overview or pick a friend to inspect records.',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Quick Switch Segmented Chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          avatar: const Icon(Icons.groups, size: 16),
                          label: Text('All Friends Overview (${workshopFriends.length})'),
                          selected: _selectedFriendId == 'all',
                          selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedFriendId = 'all');
                            }
                          },
                        ),
                        ...workshopFriends.map((f) {
                          final isSelected = _selectedFriendId == f.id;
                          return ChoiceChip(
                            avatar: _buildProfileAvatar(f.photoUrl, f.fullName, radius: 10),
                            label: Text(f.fullName),
                            selected: isSelected,
                            selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedFriendId = f.id);
                                _loadFriendRecord(f.id);
                              }
                            },
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Formal Dropdown Selector (Always Enabled for all roles!)
                    DropdownButtonFormField<String>(
                      value: _selectedFriendId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Active Inspection Profile',
                        prefixIcon: const Icon(Icons.badge_outlined, color: AppTheme.primaryColor),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: [
                        DropdownMenuItem<String>(
                          value: 'all',
                          child: Row(
                            children: [
                              const Icon(Icons.groups, color: AppTheme.primaryColor, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                '✨ All Friends (${workshopFriends.length} Enrolled) - Workshop Overview',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        ...workshopFriends.map((f) {
                          return DropdownMenuItem<String>(
                            value: f.id,
                            child: Row(
                              children: [
                                _buildProfileAvatar(f.photoUrl, f.fullName, radius: 12),
                                const SizedBox(width: 10),
                                Text(f.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(width: 8),
                                Text(
                                  '(${f.registrationNumber})',
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedFriendId = val);
                          if (val != 'all') {
                            _loadFriendRecord(val);
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 3. Main View: Workshop Overview OR Individual Friend Record
            if (_selectedFriendId == 'all')
              _buildAllFriendsOverview(context, workshopFriends, workshopName, canSaveWorkshop, isDark)
            else
              _buildSingleFriendView(context, currentFriend, workshopName, skills, canSaveWorkshop, isDark),
          ],
        ),
      ),
    );
  }

  // --- ROLE BANNER ---
  Widget _buildRoleBanner(bool isStaff, bool isPrincipalOrAdmin, String userName) {
    if (isStaff) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.edit_note, color: Colors.green.shade700, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Signed in as Workshop Staff ($userName). You have full authorization to record daily behavior evaluations and vocational skills.',
                style: TextStyle(color: Colors.green.shade900, fontSize: 13, fontWeight: FontWeight.w500),
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
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined, color: Color(0xFF1D4ED8), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Principal / Administrative Oversight Console (Read-Only Mode)',
                  style: TextStyle(color: Color(0xFF1E3A8A), fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Text(
                  'You are reviewing live workshop activity, behavior assessments, and vocational progress. Only assigned workshop staff can alter daily evaluations.',
                  style: TextStyle(color: Colors.blueGrey.shade800, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E40AF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'READ ONLY',
              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  // --- VIEW 1: ALL FRIENDS WORKSHOP OVERVIEW ---
  Widget _buildAllFriendsOverview(
    BuildContext context,
    List<Friend> workshopFriends,
    String workshopName,
    bool canSaveWorkshop,
    bool isDark,
  ) {
    final stats = _computeWorkshopStats(workshopFriends);
    final avgParticipation = stats['avgParticipation'] as double;
    final avgIndependence = stats['avgIndependence'] as double;
    final avgCompletion = stats['avgCompletion'] as double;
    final moodCounts = stats['moodCounts'] as Map<String, int>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Workshop KPI Summary Header Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.storefront, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$workshopName Master Roster',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Institutional Workshop Activity & Behavioral Audit',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${workshopFriends.length} Enrolled Beneficiaries',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // KPI Metric Cards Row
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 500;
                  final evaluatedCount = stats['evaluatedCount'] as int? ?? 0;
                  final partLabel = evaluatedCount > 0 ? '${avgParticipation.toStringAsFixed(1)} / 5.0' : 'Pending';
                  final indLabel = evaluatedCount > 0 ? '${avgIndependence.toStringAsFixed(1)} / 5.0' : 'Pending';
                  final compLabel = evaluatedCount > 0 ? '${avgCompletion.toStringAsFixed(1)} / 5.0' : 'Pending';

                  return isWide
                      ? Row(
                          children: [
                            Expanded(child: _buildKpiTile('Avg Participation', partLabel, Icons.volunteer_activism)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildKpiTile('Avg Independence', indLabel, Icons.self_improvement)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildKpiTile('Avg Completion', compLabel, Icons.task_alt)),
                          ],
                        )
                      : Column(
                          children: [
                            _buildKpiTile('Avg Participation', partLabel, Icons.volunteer_activism),
                            const SizedBox(height: 8),
                            _buildKpiTile('Avg Independence', indLabel, Icons.self_improvement),
                            const SizedBox(height: 8),
                            _buildKpiTile('Avg Completion', compLabel, Icons.task_alt),
                          ],
                        );
                },
              ),
              const SizedBox(height: 16),

              // Mood Breakdown Chips
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildMoodCountBadge('Excellent', moodCounts['excellent'] ?? 0, Colors.greenAccent),
                  _buildMoodCountBadge('Good', moodCounts['good'] ?? 0, Colors.tealAccent),
                  _buildMoodCountBadge('Neutral', moodCounts['neutral'] ?? 0, Colors.lightBlueAccent),
                  _buildMoodCountBadge('Agitated', moodCounts['agitated'] ?? 0, Colors.orangeAccent),
                  _buildMoodCountBadge('Withdrawn', moodCounts['withdrawn'] ?? 0, Colors.grey.shade300),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Section Title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Enrolled Beneficiaries in $workshopName (${workshopFriends.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Tap any friend to inspect full dossier',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Friends Roster List
        if (workshopFriends.isEmpty)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.person_off_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'No beneficiaries are currently assigned to $workshopName.',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Assign friends to this workshop from the Beneficiaries management screen.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: workshopFriends.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final friend = workshopFriends[index];
              final summary = _getFriendSummary(friend, index);
              final mood = summary['mood'] as String;
              final participation = summary['participation'] as double;
              final independence = summary['independence'] as double;
              final taskCompletion = summary['taskCompletion'] as double;
              final hasCustom = summary['hasCustomRecord'] as bool;
              final notes = summary['notes'] as String;
              final photosCount = summary['photosCount'] as int;

              return Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() => _selectedFriendId = friend.id);
                    _loadFriendRecord(friend.id);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildProfileAvatar(friend.photoUrl, friend.fullName, radius: 26),
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
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildMoodPill(mood),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          friend.registrationNumber,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blueGrey),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'House: ${friend.assignedHouseId.replaceAll('_', ' ').toUpperCase()}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                      if (hasCustom) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.green.shade300, width: 0.8),
                                          ),
                                          child: const Text('Saved Evaluation', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.arrow_forward, size: 14),
                              label: const Text('Inspect', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                setState(() => _selectedFriendId = friend.id);
                                _loadFriendRecord(friend.id);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 12),

                        // Metric indicators row
                        Row(
                          children: [
                            Expanded(child: _buildMiniScoreBar('Participation', participation)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildMiniScoreBar('Independence', independence)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildMiniScoreBar('Completion', taskCompletion)),
                          ],
                        ),

                        if (notes.isNotEmpty || photosCount > 0) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (notes.isNotEmpty)
                                Expanded(
                                  child: Text(
                                    'Note: "$notes"',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                                  ),
                                ),
                              if (photosCount > 0) ...[
                                const SizedBox(width: 8),
                                Icon(Icons.photo_outlined, size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text('$photosCount photos', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // --- VIEW 2: INDIVIDUAL FRIEND RECORD (READ-ONLY FOR PRINCIPAL, EDIT FOR STAFF) ---
  Widget _buildSingleFriendView(
    BuildContext context,
    Friend? friend,
    String workshopName,
    List<String> skills,
    bool canSaveWorkshop,
    bool isDark,
  ) {
    if (friend == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.error_outline, color: Colors.orange, size: 40),
                const SizedBox(height: 12),
                const Text('Friend profile not found.'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => setState(() => _selectedFriendId = 'all'),
                  child: const Text('Back to Workshop Overview'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Beneficiary Header Card with "Back to Overview"
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                _buildProfileAvatar(friend.photoUrl, friend.fullName, radius: 28),
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildMoodPill(_mood),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${friend.registrationNumber}  •  House: ${friend.assignedHouseId.replaceAll('_', ' ').toUpperCase()}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.arrow_back, size: 14),
                  label: const Text('All Friends'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onPressed: () => setState(() => _selectedFriendId = 'all'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 1. Daily Activity & Behavior Card
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
                    const Text('Daily Activity & Behavior Assessment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    if (!canSaveWorkshop)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Read-Only', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Mood Assessment
                const Text('Mood Assessment', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                if (canSaveWorkshop)
                  DropdownButtonFormField<String>(
                    value: _mood,
                    isExpanded: true,
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
                    items: const [
                      DropdownMenuItem(value: 'excellent', child: Text('😊 Excellent / Energetic')),
                      DropdownMenuItem(value: 'good', child: Text('🙂 Good / Happy')),
                      DropdownMenuItem(value: 'neutral', child: Text('😐 Neutral / Calm')),
                      DropdownMenuItem(value: 'agitated', child: Text('⚠️ Agitated / Unsettled')),
                      DropdownMenuItem(value: 'withdrawn', child: Text('🌧️ Withdrawn / Passive')),
                    ],
                    onChanged: (val) => setState(() => _mood = val!),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        _buildMoodPill(_mood),
                        const SizedBox(width: 12),
                        Text(
                          _getMoodLabel(_mood),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),

                // Participation Rating
                _buildRatingRow('Participation Level', _participation, canSaveWorkshop ? (val) => setState(() => _participation = val) : null),
                // Communication
                _buildRatingRow('Communication', _communication, canSaveWorkshop ? (val) => setState(() => _communication = val) : null),
                // Independence
                _buildRatingRow('Independence / Self-help', _independence, canSaveWorkshop ? (val) => setState(() => _independence = val) : null),
                // Task Completion
                _buildRatingRow('Task Completion Rate', _taskCompletion, canSaveWorkshop ? (val) => setState(() => _taskCompletion = val) : null),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 2. Vocational Skills Progress Card
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
                      child: Text(
                        'Vocational Skills - $workshopName',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    if (canSaveWorkshop)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.mic, size: 16, color: AppTheme.primaryColor),
                        label: const Text('Voice Add (Urdu)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          side: const BorderSide(color: AppTheme.primaryColor),
                        ),
                        onPressed: _showVoiceAddActivityDialog,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                ...skills.map((skill) {
                  return _buildRatingRow(
                    skill,
                    _skillRatings[skill] ?? 3.5,
                    canSaveWorkshop ? (val) => setState(() => _skillRatings[skill] = val) : null,
                    onDelete: canSaveWorkshop ? () => _deleteActivity(skill) : null,
                  );
                }),
                if (canSaveWorkshop) ...[
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _newActivityController,
                          decoration: const InputDecoration(
                            hintText: 'Type or use mic to add activity...',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.mic, color: Colors.blue),
                        tooltip: 'Add via Voice (Urdu)',
                        onPressed: _showVoiceAddActivityDialog,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: AppTheme.primaryColor, size: 28),
                        tooltip: 'Add Activity',
                        onPressed: () {
                          final act = _newActivityController.text.trim();
                          if (act.isNotEmpty) {
                            _addActivity(act);
                            _newActivityController.clear();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 3. Daily Progress Notes & Photos
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
                    const Text('Daily Progress Notes & Photos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    if (canSaveWorkshop)
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _isListening ? Icons.mic : Icons.mic_none,
                              color: _isListening ? Colors.red : AppTheme.primaryColor,
                            ),
                            tooltip: _isListening ? 'Stop recording' : 'Record notes with mic',
                            onPressed: _listen,
                          ),
                          if (_isTranslating)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.translate, color: AppTheme.primaryColor),
                              tooltip: 'Translate notes to English',
                              onPressed: _translateNotes,
                            ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (canSaveWorkshop)
                  TextFormField(
                    controller: _notesController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: _isListening 
                          ? 'Listening... Speak now...' 
                          : 'Describe general performance, challenges faced, behavioral triggers or successes...',
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                    ),
                    child: Text(
                      _notesController.text.trim().isNotEmpty
                          ? _notesController.text.trim()
                          : 'No specific daily behavioral notes recorded for this friend today.',
                      style: TextStyle(
                        color: _notesController.text.trim().isNotEmpty ? null : Colors.grey,
                        fontStyle: _notesController.text.trim().isNotEmpty ? FontStyle.normal : FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Attached Photos List
                if (_attachedPhotos.isNotEmpty) ...[
                  const Text(
                    'Attached Progress Photos (Tap to enlarge):',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 90,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _attachedPhotos.length + (_isUploadingPhoto ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _attachedPhotos.length && _isUploadingPhoto) {
                          return Container(
                            width: 80,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }

                        final photoUrl = _attachedPhotos[index];
                        return Stack(
                          children: [
                            GestureDetector(
                              onTap: () => _showPhotoPreview(photoUrl),
                              child: Container(
                                width: 80,
                                height: 80,
                                margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                  image: DecorationImage(
                                    image: NetworkImage(photoUrl),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            if (canSaveWorkshop)
                              Positioned(
                                top: 0,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _attachedPhotos.removeAt(index);
                                    });
                                  },
                                  child: const CircleAvatar(
                                    radius: 9,
                                    backgroundColor: Colors.red,
                                    child: Icon(Icons.close, color: Colors.white, size: 10),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (canSaveWorkshop)
                  OutlinedButton.icon(
                    onPressed: _isUploadingPhoto ? null : _pickProgressPhoto,
                    icon: _isUploadingPhoto 
                        ? const SizedBox(
                            width: 16, 
                            height: 16, 
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.primaryColor),
                          )
                        : const Icon(Icons.add_a_photo_outlined),
                    label: Text(_isUploadingPhoto ? 'Uploading...' : 'Add Photos / Attachments'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primaryColor),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 4. Save Button (Visible ONLY to Workshop Staff)
        if (canSaveWorkshop)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _isSavingRecord
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined),
              label: Text(_isSavingRecord ? 'Saving Records...' : 'Save Daily Records for ${friend.fullName}'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _isSavingRecord ? null : _saveRecords,
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.grey),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Evaluation verified. This record is displayed in read-only mode for Principal & Administrative executive oversight.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // --- HELPER COMPONENT WIDGETS ---
  Widget _buildKpiTile(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodCountBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $count',
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar(String? photoUrl, String fallbackName, {double radius = 24}) {
    final provider = getAppImageProvider(photoUrl);
    return CircleAvatar(
      radius: radius,
      backgroundImage: provider,
      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
      child: provider == null
          ? Text(
              fallbackName.isNotEmpty ? fallbackName[0].toUpperCase() : '?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: radius * 0.75, color: AppTheme.primaryColor),
            )
          : null,
    );
  }

  Widget _buildMoodPill(String mood) {
    Color bg;
    Color fg;
    String text;
    IconData icon;

    switch (mood.toLowerCase()) {
      case 'pending':
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
        text = 'Pending Eval';
        icon = Icons.hourglass_empty;
        break;
      case 'excellent':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        text = 'Excellent';
        icon = Icons.sentiment_very_satisfied;
        break;
      case 'good':
        bg = Colors.teal.shade50;
        fg = Colors.teal.shade800;
        text = 'Good';
        icon = Icons.sentiment_satisfied_alt;
        break;
      case 'agitated':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        text = 'Agitated';
        icon = Icons.warning_amber_rounded;
        break;
      case 'withdrawn':
        bg = Colors.blueGrey.shade50;
        fg = Colors.blueGrey.shade800;
        text = 'Withdrawn';
        icon = Icons.sentiment_dissatisfied;
        break;
      case 'neutral':
      default:
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        text = 'Calm';
        icon = Icons.sentiment_neutral;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _getMoodLabel(String mood) {
    switch (mood) {
      case 'excellent':
        return 'Excellent / Energetic';
      case 'good':
        return 'Good / Happy';
      case 'agitated':
        return 'Agitated / Unsettled';
      case 'withdrawn':
        return 'Withdrawn / Passive';
      case 'pending':
        return 'Pending Evaluation';
      case 'neutral':
      default:
        return 'Neutral / Calm';
    }
  }

  Widget _buildMiniScoreBar(String label, double score) {
    final normalized = (score / 5.0).clamp(0.0, 1.0);
    final isUnrated = score <= 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text(
              isUnrated ? 'Unrated' : '${score.toStringAsFixed(1)}/5',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isUnrated ? Colors.grey : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: normalized,
            minHeight: 5,
            backgroundColor: Colors.grey.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(
              isUnrated
                  ? Colors.grey.shade300
                  : (score >= 4.0 ? Colors.green : (score >= 3.0 ? AppTheme.primaryColor : Colors.orange)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingRow(
    String label,
    double rating,
    ValueChanged<double>? onChanged, {
    VoidCallback? onDelete,
  }) {
    final isReadOnly = onChanged == null;
    final clampedRating = rating.clamp(1.0, 5.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${clampedRating.toStringAsFixed(1)} / 5',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryColor),
                    ),
                  ),
                  if (onDelete != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                      tooltip: 'Delete Activity',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: onDelete,
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (isReadOnly)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: clampedRating / 5.0,
                  minHeight: 7,
                  backgroundColor: Colors.grey.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    clampedRating >= 4.0 ? Colors.green : (clampedRating >= 3.0 ? AppTheme.primaryColor : Colors.orange),
                  ),
                ),
              ),
            )
          else
            Slider(
              value: clampedRating,
              min: 1.0,
              max: 5.0,
              divisions: 8,
              activeColor: AppTheme.primaryColor,
              inactiveColor: Colors.grey.shade200,
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }

  Future<void> _pickProgressPhoto() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      setState(() {
        _isUploadingPhoto = true;
      });

      final file = result.files.first;
      Uint8List? bytes;
      if (kIsWeb) {
        bytes = file.bytes;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }

      if (bytes == null) {
        throw Exception('Could not read file data');
      }

      String finalUrl;
      if (SupabaseDbService.isConfigured) {
        final uploadedUrl = await SupabaseDbService.uploadFile(
          'progress-photos',
          file.name,
          bytes,
        );
        if (uploadedUrl != null) {
          finalUrl = uploadedUrl;
        } else {
          final base64String = base64Encode(bytes);
          finalUrl = 'data:image/png;base64,$base64String';
        }
      } else {
        final base64String = base64Encode(bytes);
        finalUrl = 'data:image/png;base64,$base64String';
      }

      setState(() {
        _attachedPhotos.add(finalUrl);
        _isUploadingPhoto = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo attached successfully!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      setState(() {
        _isUploadingPhoto = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading picture: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
