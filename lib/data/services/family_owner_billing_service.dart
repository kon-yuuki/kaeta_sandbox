import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FamilyOwnerBillingSnapshot {
  const FamilyOwnerBillingSnapshot({
    required this.ownerId,
    required this.planName,
    required this.lifecycleName,
    required this.isInTrial,
    required this.trialEndsAt,
    required this.accessEndsAt,
  });

  final String ownerId;
  final String planName;
  final String lifecycleName;
  final bool isInTrial;
  final DateTime? trialEndsAt;
  final DateTime? accessEndsAt;

  factory FamilyOwnerBillingSnapshot.fromJson(Map<String, dynamic> json) {
    return FamilyOwnerBillingSnapshot(
      ownerId: json['ownerId'] as String? ?? '',
      planName: json['plan'] as String? ?? 'free',
      lifecycleName: json['lifecycle'] as String? ?? 'neverSubscribed',
      isInTrial: json['isInTrial'] == true,
      trialEndsAt: _parseDate(json['trialEndsAt']),
      accessEndsAt: _parseDate(json['accessEndsAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

class FamilyOwnerBillingService {
  FamilyOwnerBillingService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<FamilyOwnerBillingSnapshot> fetchOwnerBilling(String familyId) async {
    try {
      final response = await _supabase.functions.invoke(
        'family-owner-billing',
        body: {'familyId': familyId},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return FamilyOwnerBillingSnapshot.fromJson(data);
      }
      if (data is Map) {
        return FamilyOwnerBillingSnapshot.fromJson(
          Map<String, dynamic>.from(data),
        );
      }
      throw StateError('Unexpected family-owner-billing response: $data');
    } catch (e, st) {
      debugPrint('family-owner-billing fetch failed: $e');
      debugPrint('$st');
      rethrow;
    }
  }
}
