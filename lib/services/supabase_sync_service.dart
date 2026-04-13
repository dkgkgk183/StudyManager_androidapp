import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database.dart';

class SupabaseSyncService {
  final _supabase = Supabase.instance.client;
  final AppDatabase _db;

  SupabaseSyncService(this._db);

  Future<void> syncCategory(SubjectCategory category) async {
    try {
      await _supabase.from('categories').upsert({
        'id': category.id,
        'name': category.name,
        'sort_order': category.sortOrder,
      });
    } catch (e) {
      throw Exception('Category sync failed: $e');
    }
  }

  Future<void> syncSubject(Subject subject) async {
    try {
      await _supabase.from('subjects').upsert({
        'id': subject.id,
        'category_id': subject.categoryId,
        'name': subject.name,
        'color_hex': subject.colorHex,
      });
    } catch (e) {
      throw Exception('Subject sync failed: $e');
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      await _supabase.from('categories').delete().eq('id', id);
    } catch (e) {
      throw Exception('Category delete failed: $e');
    }
  }

  Future<void> deleteSubject(String id) async {
    try {
      await _supabase.from('subjects').delete().eq('id', id);
    } catch (e) {
      throw Exception('Subject delete failed: $e');
    }
  }
}