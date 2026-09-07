import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseDbService {
  static SupabaseClient get _client => Supabase.instance.client;

  static bool get isConfigured {
    try {
      final client = Supabase.instance.client;
      final url = client.rest.url;
      if (url.contains('your-project-id')) {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // --- MEDICAL RECORDS ---
  static Future<Map<String, dynamic>?> fetchMedicalRecord(String friendId) async {
    if (!isConfigured) return null;
    try {
      final data = await _client
          .from('medical_records')
          .select('*, medical_prescriptions(*), medical_vitals(*)')
          .eq('friend_id', friendId)
          .maybeSingle();
      return data;
    } catch (e) {
      debugPrint('Error fetching medical record: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> saveMedicalRecord(String friendId, String diagnosis, String history) async {
    if (!isConfigured) return {};
    try {
      final existing = await _client
          .from('medical_records')
          .select('id')
          .eq('friend_id', friendId)
          .maybeSingle();

      if (existing == null) {
        final inserted = await _client.from('medical_records').insert({
          'friend_id': friendId,
          'medical_history': history,
          'clinical_notes': diagnosis,
        }).select('id').single();
        return inserted;
      } else {
        await _client.from('medical_records').update({
          'medical_history': history,
          'clinical_notes': diagnosis,
        }).eq('friend_id', friendId);
        return existing;
      }
    } catch (e) {
      debugPrint('Error saving medical record: $e');
      return {};
    }
  }

  static Future<void> addVitals(String recordId, String bp, int hr, double temp, double weight) async {
    if (!isConfigured) return;
    try {
      await _client.from('medical_vitals').insert({
        'record_id': recordId,
        'blood_pressure': bp,
        'heart_rate': hr,
        'temperature': temp,
        'weight': weight,
      });
    } catch (e) {
      debugPrint('Error adding vitals: $e');
    }
  }

  static Future<void> addPrescription(String recordId, String med, String dose, String freq) async {
    if (!isConfigured) return;
    try {
      await _client.from('medical_prescriptions').insert({
        'record_id': recordId,
        'medication_name': med,
        'dosage': dose,
        'frequency': freq,
        'duration': '30 days',
      });
    } catch (e) {
      debugPrint('Error adding prescription: $e');
    }
  }

  // --- PHYSIOTHERAPY ASSESSMENTS ---
  static Future<Map<String, dynamic>?> fetchPhysioAssessment(String friendId) async {
    if (!isConfigured) return null;
    try {
      final data = await _client
          .from('physiotherapy_assessments')
          .select('*, physiotherapy_sessions(*)')
          .eq('friend_id', friendId)
          .maybeSingle();
      return data;
    } catch (e) {
      debugPrint('Error fetching physio: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> savePhysioAssessment(
    String friendId, 
    String rom, 
    String strength, 
    String balance, 
    String mobility,
  ) async {
    if (!isConfigured) return {};
    try {
      final existing = await _client
          .from('physiotherapy_assessments')
          .select('id')
          .eq('friend_id', friendId)
          .maybeSingle();

      if (existing == null) {
        final inserted = await _client.from('physiotherapy_assessments').insert({
          'friend_id': friendId,
          'range_of_motion': rom,
          'strength': strength,
          'balance': balance,
          'mobility': mobility,
        }).select('id').single();
        return inserted;
      } else {
        await _client.from('physiotherapy_assessments').update({
          'range_of_motion': rom,
          'strength': strength,
          'balance': balance,
          'mobility': mobility,
        }).eq('friend_id', friendId);
        return existing;
      }
    } catch (e) {
      debugPrint('Error saving physio: $e');
      return {};
    }
  }

  static Future<void> addPhysioSession(String assessmentId, int duration, int rating, String notes) async {
    if (!isConfigured) return;
    try {
      await _client.from('physiotherapy_sessions').insert({
        'assessment_id': assessmentId,
        'duration_minutes': duration,
        'performance_rating': rating,
        'notes': notes,
      });
    } catch (e) {
      debugPrint('Error adding physio session: $e');
    }
  }

  // --- SPEECH THERAPY ASSESSMENTS ---
  static Future<Map<String, dynamic>?> fetchSpeechAssessment(String friendId) async {
    if (!isConfigured) return null;
    try {
      final data = await _client
          .from('speech_assessments')
          .select('*, speech_sessions(*)')
          .eq('friend_id', friendId)
          .maybeSingle();
      return data;
    } catch (e) {
      debugPrint('Error fetching speech: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> saveSpeechAssessment(
    String friendId, 
    String speechSkills, 
    String languageDev, 
    String goals,
  ) async {
    if (!isConfigured) return {};
    try {
      final existing = await _client
          .from('speech_assessments')
          .select('id')
          .eq('friend_id', friendId)
          .maybeSingle();

      if (existing == null) {
        final inserted = await _client.from('speech_assessments').insert({
          'friend_id': friendId,
          'speech_skills': speechSkills,
          'language_development': languageDev,
          'communication_goals': goals,
        }).select('id').single();
        return inserted;
      } else {
        await _client.from('speech_assessments').update({
          'speech_skills': speechSkills,
          'language_development': languageDev,
          'communication_goals': goals,
        }).eq('friend_id', friendId);
        return existing;
      }
    } catch (e) {
      debugPrint('Error saving speech: $e');
      return {};
    }
  }

  static Future<void> updateSpeechActivities(String assessmentId, List<String> activities) async {
    if (!isConfigured) return;
    try {
      await _client.from('speech_assessments').update({
        'activities': activities,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', assessmentId);
    } catch (e) {
      debugPrint('Error updating speech activities: $e');
    }
  }

  static Future<void> addSpeechSession(String assessmentId, String notes, String progress) async {
    if (!isConfigured) return;
    try {
      await _client.from('speech_sessions').insert({
        'assessment_id': assessmentId,
        'notes': notes,
        'progress_description': progress,
      });
    } catch (e) {
      debugPrint('Error adding speech session: $e');
    }
  }

  static Future<void> updatePhysioExercises(String assessmentId, List<String> exercises) async {
    if (!isConfigured) return;
    try {
      await _client.from('physiotherapy_assessments').update({
        'exercises': exercises,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', assessmentId);
    } catch (e) {
      debugPrint('Error updating physio exercises: $e');
    }
  }

  static Future<void> updateMedicalAllergiesAndVaccines(String friendId, List<String> allergies, List<String> vaccinations) async {
    if (!isConfigured) return;
    try {
      final existing = await _client.from('medical_records').select('id').eq('friend_id', friendId).maybeSingle();
      if (existing == null) {
        await _client.from('medical_records').insert({
          'friend_id': friendId,
          'allergies': allergies,
          'vaccinations': vaccinations,
          'medical_history': 'Pending detailed history',
          'clinical_notes': 'Initial medical record',
        });
      } else {
        await _client.from('medical_records').update({
          'allergies': allergies,
          'vaccinations': vaccinations,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('friend_id', friendId);
      }
    } catch (e) {
      debugPrint('Error updating allergies & vaccines: $e');
    }
  }

  // --- BATCH FETCH ALL CLINICAL DATA FOR REAL OVERSIGHT ---
  static Future<List<Map<String, dynamic>>> fetchAllPhysioAssessments() async {
    if (!isConfigured) return [];
    try {
      final res = await _client.from('physiotherapy_assessments').select('*, physiotherapy_sessions(*)');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error fetching all physio: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchAllSpeechAssessments() async {
    if (!isConfigured) return [];
    try {
      final res = await _client.from('speech_assessments').select('*, speech_sessions(*)');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error fetching all speech: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchAllMedicalRecords() async {
    if (!isConfigured) return [];
    try {
      final res = await _client.from('medical_records').select('*, medical_vitals(*), medical_prescriptions(*)');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error fetching all medical: $e');
      return [];
    }
  }

  // --- IEP GOALS ---
  static Future<Map<String, dynamic>?> fetchIep(String friendId) async {
    if (!isConfigured) return null;
    try {
      final data = await _client
          .from('iep')
          .select('*, iep_goals(*)')
          .eq('friend_id', friendId)
          .maybeSingle();
      return data;
    } catch (e) {
      debugPrint('Error fetching IEP: $e');
      return null;
    }
  }

  static Future<String> getOrCreateIep(String friendId, String baseline) async {
    if (!isConfigured) return '';
    try {
      final existing = await _client
          .from('iep')
          .select('id')
          .eq('friend_id', friendId)
          .maybeSingle();
      if (existing != null) {
        await _client.from('iep').update({'baseline': baseline}).eq('friend_id', friendId);
        return existing['id'];
      } else {
        final res = await _client.from('iep').insert({
          'friend_id': friendId,
          'academic_year': '2026',
          'baseline': baseline,
        }).select('id').single();
        return res['id'] ?? '';
      }
    } catch (e) {
      debugPrint('Error creating IEP: $e');
      return '';
    }
  }

  static Future<void> saveIepGoal(
    String iepId, 
    String title, 
    String objectives, 
    String strategies, 
    String targetDate,
  ) async {
    if (!isConfigured) return;
    try {
      await _client.from('iep_goals').insert({
        'iep_id': iepId,
        'title': title,
        'objectives': objectives,
        'strategies': strategies,
        'target_date': targetDate,
        'status': 'in_progress',
        'progress_percentage': 0,
      });
    } catch (e) {
      debugPrint('Error saving IEP goal: $e');
    }
  }

  static Future<void> updateGoalProgress(String goalId, int progress, String status) async {
    if (!isConfigured) return;
    try {
      await _client.from('iep_goals').update({
        'progress_percentage': progress,
        'status': status,
      }).eq('id', goalId);
    } catch (e) {
      debugPrint('Error updating goal progress: $e');
    }
  }

  static Future<String?> uploadFile(String bucketName, String path, Uint8List bytes, {String? mimeType}) async {
    if (!isConfigured) return null;
    try {
      final String baseName = path.split('/').last;
      final String sanitizedBase = baseName.replaceAll(RegExp(r'[^a-zA-Z0-9.\-_]'), '_');
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_$sanitizedBase';
      await _client.storage.from(bucketName).uploadBinary(
        fileName,
        bytes,
        fileOptions: FileOptions(contentType: mimeType, cacheControl: '3600'),
      ).timeout(const Duration(seconds: 15));
      final String publicUrl = _client.storage.from(bucketName).getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading file to Supabase: $e');
      return null;
    }
  }
}
