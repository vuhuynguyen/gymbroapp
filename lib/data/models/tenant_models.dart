import '../../core/utils/json.dart';
import '../../domain/enums.dart';

/// `GET /api/tenants/mine` → TenantDto[]. `role` is a plain string (`Owner`/`Client`).
class TenantSummary {
  const TenantSummary({
    required this.id,
    required this.name,
    required this.role,
    this.joinedAt,
    required this.memberCount,
    this.ownerName,
  });

  final String id;
  final String name;
  final TenantRole? role;
  final DateTime? joinedAt;
  final int memberCount;
  final String? ownerName;

  bool get isOwner => role == TenantRole.owner;
  bool get isClient => role == TenantRole.client;

  factory TenantSummary.fromJson(Map<String, dynamic> j) => TenantSummary(
        id: j['id'].toString(),
        name: asString(j['name']) ?? '',
        role: TenantRole.parse(j['role']),
        joinedAt: asDate(j['joinedAt']),
        memberCount: asInt(j['memberCount']) ?? 1,
        ownerName: asString(j['ownerName']),
      );
}

/// `GET /api/tenants/{id}/members` → MemberDto[].
class Member {
  const Member({required this.userId, required this.name, required this.role, this.joinedAt});

  final String userId;
  final String name;
  final TenantRole? role;
  final DateTime? joinedAt;

  factory Member.fromJson(Map<String, dynamic> j) => Member(
        userId: j['userId'].toString(),
        name: asString(j['name']) ?? '',
        role: TenantRole.parse(j['role']),
        joinedAt: asDate(j['joinedAt']),
      );

  bool get isClient => role == TenantRole.client;
}

/// `GET /api/invites` → InviteCodeDto[] (Owner-only).
class InviteCode {
  const InviteCode({
    required this.code,
    this.createdAt,
    this.expiresAt,
    required this.isUsed,
    required this.isExpired,
  });

  final String code;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final bool isUsed;
  final bool isExpired;

  bool get isActive => !isUsed && !isExpired;

  factory InviteCode.fromJson(Map<String, dynamic> j) => InviteCode(
        code: j['code'].toString(),
        createdAt: asDate(j['createdAt']),
        expiresAt: asDate(j['expiresAt']),
        isUsed: asBool(j['isUsed']),
        isExpired: asBool(j['isExpired']),
      );
}
