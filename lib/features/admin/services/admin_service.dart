import 'package:flutter/foundation.dart';
import '../../../core/services/supabase_service.dart';
import '../models/admin_role.dart';

class AdminService {
  static Future<bool> isUserAdmin() async {
    try {
      final user = SupabaseService.getCurrentUser();
      if (user == null) return false;

      final response = await SupabaseService.client
          .from('admin_users')
          .select('role')
          .eq('user_id', user.id)
          .single();

      return response != null;
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }

  static Future<AdminRole?> getUserRole() async {
    try {
      final user = SupabaseService.getCurrentUser();
      if (user == null) return null;

      final response = await SupabaseService.client
          .from('admin_users')
          .select('role')
          .eq('user_id', user.id)
          .single();

      return AdminRole.fromString(response['role'] as String?);
    } catch (e) {
      debugPrint('Error getting admin role: $e');
      return null;
    }
  }

  // Fetch all records from any table with pagination
  static Future<Map<String, dynamic>> fetchTableRecords(
    String tableName, {
    int page = 1,
    int pageSize = 20,
    String? searchQuery,
    String? orderBy,
    bool ascending = true,
  }) async {
    try {
      // First get the total count
      final countQuery = SupabaseService.client.from(tableName).select('id');
      
      // Add search if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        // Add table-specific search conditions
        switch (tableName) {
          case 'profiles':
            countQuery.or('name.ilike.%$searchQuery%,email.ilike.%$searchQuery%');
            break;
          case 'pets':
            countQuery.or('name.ilike.%$searchQuery%,device_key.ilike.%$searchQuery%');
            break;
          case 'devices':
            countQuery.or('name.ilike.%$searchQuery%,device_key.ilike.%$searchQuery%');
            break;
          // Add more cases for other tables as needed
        }
      }

      final count = (await countQuery).length;

      // Now get the actual data with pagination
      dynamic dataQuery = SupabaseService.client.from(tableName).select('*');

      // Add the same search conditions
      if (searchQuery != null && searchQuery.isNotEmpty) {
        switch (tableName) {
          case 'profiles':
            dataQuery = dataQuery.or('name.ilike.%$searchQuery%,email.ilike.%$searchQuery%');
            break;
          case 'pets':
            dataQuery = dataQuery.or('name.ilike.%$searchQuery%,device_key.ilike.%$searchQuery%');
            break;
          case 'devices':
            dataQuery = dataQuery.or('name.ilike.%$searchQuery%,device_key.ilike.%$searchQuery%');
            break;
        }
      }

      // Add ordering
      if (orderBy != null) {
        dataQuery = dataQuery.order(orderBy, ascending: ascending);
      }

      // Add pagination
      dataQuery = dataQuery.range(
        (page - 1) * pageSize,
        (page * pageSize) - 1,
      );

      final data = await dataQuery;

      return {
        'data': data,
        'total': count,
        'page': page,
        'pageSize': pageSize,
        'totalPages': (count / pageSize).ceil(),
      };
    } catch (e) {
      debugPrint('Error fetching $tableName: $e');
      rethrow;
    }
  }

  // Create a new record in any table
  static Future<Map<String, dynamic>> createRecord(
    String tableName,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await SupabaseService.client
          .from(tableName)
          .insert(data)
          .select()
          .single();
      return response;
    } catch (e) {
      debugPrint('Error creating record in $tableName: $e');
      rethrow;
    }
  }

  // Update a record in any table
  static Future<Map<String, dynamic>> updateRecord(
    String tableName,
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await SupabaseService.client
          .from(tableName)
          .update(data)
          .eq('id', id)
          .select()
          .single();
      return response;
    } catch (e) {
      debugPrint('Error updating record in $tableName: $e');
      rethrow;
    }
  }

  // Delete a record from any table
  static Future<void> deleteRecord(String tableName, String id) async {
    try {
      await SupabaseService.client
          .from(tableName)
          .delete()
          .eq('id', id);
    } catch (e) {
      debugPrint('Error deleting record from $tableName: $e');
      rethrow;
    }
  }

  // Get table schema information
  static Future<List<Map<String, dynamic>>> getTableSchema(String tableName) async {
    try {
      final response = await SupabaseService.client
          .rpc('get_table_schema', params: {'input_table_name': tableName});
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting schema for $tableName: $e');
      rethrow;
    }
  }
} 