import 'package:flutter/foundation.dart';

enum AdminRole {
  superAdmin,
  admin,
  moderator;

  static AdminRole? fromString(String? value) {
    if (value == null) return null;
    try {
      // Convert database values (lowercase) to enum values
      switch (value.toLowerCase()) {
        case 'superadmin':
          return AdminRole.superAdmin;
        case 'admin':
          return AdminRole.admin;
        case 'moderator':
          return AdminRole.moderator;
        default:
          debugPrint('Invalid admin role: $value');
          return null;
      }
    } catch (e) {
      debugPrint('Error parsing admin role: $e');
      return null;
    }
  }

  bool get canManageAdmins => this == AdminRole.superAdmin;
  bool get canManageUsers => this == AdminRole.superAdmin || this == AdminRole.admin;
  bool get canManageContent => true; // All admin roles can manage content
} 