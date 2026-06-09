import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/tenant_models.dart';
import '../../data/repositories/tenant_repository.dart';
import '../../domain/enums.dart';

class TenantData {
  const TenantData(this.tenants, this.activeTenantId);

  final List<TenantSummary> tenants;
  final String? activeTenantId;

  static const empty = TenantData([], null);

  TenantSummary? get active {
    for (final t in tenants) {
      if (t.id == activeTenantId) return t;
    }
    return null;
  }

  TenantData copyWith({List<TenantSummary>? tenants, String? activeTenantId}) =>
      TenantData(tenants ?? this.tenants, activeTenantId ?? this.activeTenantId);
}

/// Loads the caller's memberships and resolves the active workspace, mirroring it into [TenantStore]
/// (the synchronous header source for the interceptor). Switching resets tenant-scoped state via
/// [activeTenantIdProvider], which every scoped data provider watches.
class TenantController extends AsyncNotifier<TenantData> {
  @override
  Future<TenantData> build() async {
    if (!ref.read(tokenStoreProvider).isAuthenticated) return TenantData.empty;

    final repo = ref.read(tenantRepositoryProvider);
    final store = ref.read(tenantStoreProvider);
    final tenants = await repo.myTenants();
    if (tenants.isEmpty) {
      await store.clear();
      return const TenantData([], null);
    }

    // Prefer the persisted choice; else a coach (Client) workspace — this is the trainee app — else
    // the user's own (Owner) workspace as a fallback.
    var activeId = store.activeTenantId;
    final stillValid = activeId != null && tenants.any((t) => t.id == activeId);
    if (!stillValid) {
      final client = tenants.where((t) => t.isClient);
      activeId = (client.isNotEmpty ? client.first : tenants.first).id;
    }
    await store.setActive(activeId);
    store.setRole(_roleFor(tenants, activeId));
    return TenantData(tenants, activeId);
  }

  static TenantRole? _roleFor(List<TenantSummary> tenants, String? id) {
    for (final t in tenants) {
      if (t.id == id) return t.role;
    }
    return null;
  }

  Future<void> switchTenant(String id) async {
    final data = state.valueOrNull;
    if (data == null || data.activeTenantId == id) return;
    final store = ref.read(tenantStoreProvider);
    await store.setActive(id);
    store.setRole(_roleFor(data.tenants, id));
    state = AsyncData(data.copyWith(activeTenantId: id));
  }

  /// Join a coach's workspace by invite code, then refresh the list and switch to it.
  Future<void> joinByCode(String code) async {
    final newTenantId = await ref.read(tenantRepositoryProvider).joinByCode(code);
    final tenants = await ref.read(tenantRepositoryProvider).myTenants();
    final store = ref.read(tenantStoreProvider);
    await store.setActive(newTenantId);
    store.setRole(_roleFor(tenants, newTenantId));
    state = AsyncData(TenantData(tenants, newTenantId));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<void> clear() async {
    await ref.read(tenantStoreProvider).clear();
    state = const AsyncData(TenantData.empty);
  }
}

final tenantControllerProvider =
    AsyncNotifierProvider<TenantController, TenantData>(TenantController.new);

/// The active `X-Tenant-Id`, derived. Tenant-scoped data providers watch this so they refetch (and
/// reset) on a workspace switch — the Portal's "reset scoped state on tenant switch" rule, declared.
final activeTenantIdProvider = Provider<String?>(
  (ref) => ref.watch(tenantControllerProvider.select((s) => s.valueOrNull?.activeTenantId)),
);
