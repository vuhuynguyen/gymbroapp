import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_call.dart';
import '../../core/providers.dart';
import '../models/tenant_models.dart';

class TenantRepository {
  TenantRepository(this._dio);
  final Dio _dio;

  Future<List<TenantSummary>> myTenants() => apiCall(() async {
        final res = await _dio.get<List<dynamic>>('/api/tenants/mine');
        return (res.data ?? [])
            .whereType<Map<String, dynamic>>()
            .map(TenantSummary.fromJson)
            .toList(growable: false);
      });

  Future<List<Member>> members(String tenantId) => apiCall(() async {
        final res = await _dio.get<List<dynamic>>('/api/tenants/$tenantId/members');
        return (res.data ?? [])
            .whereType<Map<String, dynamic>>()
            .map(Member.fromJson)
            .toList(growable: false);
      });

  /// Redeem an invite code → returns the joined tenant id. (Any authenticated user.)
  /// Codes are uppercase-only (charset excludes 0/O/1/I), so normalize before sending.
  Future<String> joinByCode(String code) => apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '/api/invites/join',
          data: {'code': code.trim().toUpperCase()},
        );
        return res.data!['tenantId'].toString();
      });

  Future<void> leave(String tenantId) => apiCall(() async {
        await _dio.delete<dynamic>('/api/tenants/$tenantId/leave');
      });

  // ── Owner-only invite management (coach-lite) ──────────────────────────
  Future<String> generateInvite() => apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>('/api/invites/generate');
        return res.data!['code'].toString();
      });

  Future<List<InviteCode>> invites() => apiCall(() async {
        final res = await _dio.get<List<dynamic>>('/api/invites');
        return (res.data ?? [])
            .whereType<Map<String, dynamic>>()
            .map(InviteCode.fromJson)
            .toList(growable: false);
      });

  Future<void> revokeInvite(String code) => apiCall(() async {
        await _dio.delete<dynamic>('/api/invites/$code');
      });
}

final tenantRepositoryProvider =
    Provider<TenantRepository>((ref) => TenantRepository(ref.read(apiDioProvider)));
