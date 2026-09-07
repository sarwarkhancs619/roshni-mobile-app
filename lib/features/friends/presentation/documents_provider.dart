import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/beneficiary_document.dart';
import '../../../core/storage/hive_storage.dart';
import '../../../core/services/supabase_db_service.dart';

class DocumentsState {
  final List<BeneficiaryDocument> documents;
  final bool isLoading;
  final String? errorMessage;

  DocumentsState({
    this.documents = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  DocumentsState copyWith({
    List<BeneficiaryDocument>? documents,
    bool? isLoading,
    String? errorMessage,
  }) {
    return DocumentsState(
      documents: documents ?? this.documents,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  List<BeneficiaryDocument> forFriend(String friendId) {
    return documents.where((d) => d.friendId == friendId).toList();
  }

  BeneficiaryDocument? findByType(String friendId, String documentType) {
    try {
      return documents.firstWhere((d) => d.friendId == friendId && d.documentType == documentType);
    } catch (_) {
      return null;
    }
  }
}

class DocumentsNotifier extends StateNotifier<DocumentsState> {
  DocumentsNotifier() : super(DocumentsState()) {
    _loadDocuments();
  }

  SupabaseClient get _client => Supabase.instance.client;
  bool get _isSupabaseConfigured => SupabaseDbService.isConfigured;
  final Map<String, Uint8List> _bytesCache = {};

  Uint8List? getDocumentBytes(String docId) => _bytesCache[docId];

  void cacheDocumentBytes(String docId, Uint8List bytes) {
    _bytesCache[docId] = bytes;
  }

  static const Set<String> _fakeFriendIds = {
    'friend_ali_khan',
    'friend_fatima_noor',
    'friend_usman_tariq',
    'friend_zainab_bibi',
    'friend_bilal_ahmed',
  };

  static List<BeneficiaryDocument> getDefaultDocuments() {
    return [];
  }

  Future<void> _loadDocuments() async {
    state = state.copyWith(isLoading: true);
    List<BeneficiaryDocument> localDocs = [];

    try {
      final box = HiveStorage.getBox(HiveStorage.documentsBoxName);
      // Purge any legacy fake documents
      final keysToDelete = <dynamic>[];
      for (var key in box.keys) {
        final val = box.get(key);
        if (val is Map) {
          final fid = val['friendId']?.toString() ?? val['friend_id']?.toString() ?? '';
          final id = val['id']?.toString() ?? '';
          if (_fakeFriendIds.contains(fid) || id.startsWith('doc_init_ali')) {
            keysToDelete.add(key);
          }
        }
      }
      for (var key in keysToDelete) {
        await box.delete(key);
      }

      localDocs = box.values
          .map((item) => BeneficiaryDocument.fromJson(Map<String, dynamic>.from(item)))
          .where((doc) => !_fakeFriendIds.contains(doc.friendId) && !doc.id.startsWith('doc_init_ali'))
          .toList();
    } catch (e) {
      debugPrint('Hive documents load note: $e');
    }

    state = state.copyWith(documents: localDocs, isLoading: false);

    // 2. Fetch from Supabase if configured with timeout
    if (_isSupabaseConfigured) {
      try {
        final List<dynamic> data = await _client
            .from('beneficiary_documents')
            .select()
            .order('created_at', ascending: false)
            .timeout(const Duration(seconds: 5));
        final remoteDocs = data
            .map((json) => BeneficiaryDocument.fromJson(Map<String, dynamic>.from(json)))
            .where((doc) => !_fakeFriendIds.contains(doc.friendId) && !doc.id.startsWith('doc_init_ali'))
            .toList();

        // Sort descending by uploadedAt / created_at
        remoteDocs.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
        state = state.copyWith(documents: remoteDocs);

        try {
          final box = HiveStorage.getBox(HiveStorage.documentsBoxName);
          await box.clear();
          for (var doc in remoteDocs) {
            await box.put(doc.id, doc.toJson());
          }
        } catch (_) {}
      } catch (e) {
        debugPrint('Supabase beneficiary_documents fetch skipped/failed: $e');
      }
    }
  }

  Future<bool> uploadDocument({
    required String friendId,
    required String documentType,
    required String title,
    required Uint8List fileBytes,
    required String fileName,
    required String fileType,
    required String uploadedBy,
    String? localFilePath,
  }) async {
    state = state.copyWith(isLoading: true);
    final docId = const Uuid().v4();
    _bytesCache[docId] = fileBytes;
    String fileUrl = '';

    // 1. Try uploading to Supabase Storage with timeout
    if (_isSupabaseConfigured) {
      try {
        final mime = fileType == 'pdf' ? 'application/pdf' : 'image/jpeg';
        final uploaded = await SupabaseDbService.uploadFile(
          'documents',
          'friends/$friendId/$fileName',
          fileBytes,
          mimeType: mime,
        );
        if (uploaded != null) {
          fileUrl = uploaded;
        }
      } catch (e) {
        debugPrint('Supabase upload skipped/failed: $e');
      }
    }

    // Fallback URL: Lightweight local file reference, avoiding massive base64 strings
    if (fileUrl.isEmpty) {
      if (localFilePath != null && localFilePath.isNotEmpty) {
        fileUrl = 'file://$localFilePath';
      } else {
        fileUrl = 'local://documents/$friendId/$fileName';
      }
    }

    final newDoc = BeneficiaryDocument(
      id: docId,
      friendId: friendId,
      documentType: documentType,
      title: title,
      fileUrl: fileUrl,
      fileName: fileName,
      fileType: fileType,
      uploadedAt: DateTime.now(),
      uploadedBy: uploadedBy,
    );

    // Save to Hive safely
    try {
      final box = HiveStorage.getBox(HiveStorage.documentsBoxName);
      await box.put(newDoc.id, newDoc.toJson());
    } catch (e) {
      debugPrint('Hive document save note: $e');
    }

    // Save to Supabase DB if possible with timeout
    if (_isSupabaseConfigured) {
      try {
        await _client
            .from('beneficiary_documents')
            .upsert(newDoc.toDbMap())
            .timeout(const Duration(seconds: 8));
        debugPrint('Document saved to Supabase DB successfully.');
      } catch (e) {
        debugPrint('Supabase insert beneficiary_documents note: $e');
      }
    }

    // Insert new document at the very top of the list so it is immediately visible!
    final updatedList = List<BeneficiaryDocument>.from(state.documents);
    updatedList.removeWhere((d) => d.id == newDoc.id);
    updatedList.insert(0, newDoc);

    state = state.copyWith(documents: updatedList, isLoading: false);
    return true;
  }

  Future<void> deleteDocument(String documentId) async {
    try {
      final box = HiveStorage.getBox(HiveStorage.documentsBoxName);
      await box.delete(documentId);
    } catch (_) {}

    if (_isSupabaseConfigured) {
      try {
        await _client.from('beneficiary_documents').delete().eq('id', documentId).timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('Supabase delete beneficiary_documents error: $e');
      }
    }

    final updated = state.documents.where((d) => d.id != documentId).toList();
    state = state.copyWith(documents: updated);
  }
}

final documentsProvider = StateNotifierProvider<DocumentsNotifier, DocumentsState>((ref) {
  return DocumentsNotifier();
});
