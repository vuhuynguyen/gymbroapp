import 'package:flutter/foundation.dart';
import '../../domain/enums.dart';
import '../storage/secure_store.dart';

/// Holds the active `X-Tenant-Id` synchronously for the AuthInterceptor + the active role for the
/// router's role-adaptive redirect, and persists the tenant choice across launches. The tenant
/// *list* lives in the Riverpod TenantController — this is only the header/redirect-relevant state.
class TenantStore extends ChangeNotifier {
  TenantStore(this._store);

  final SecureStore _store;
  static const _key = 'gymbro_active_tenant_id';

  String? _activeTenantId;
  String? get activeTenantId => _activeTenantId;

  /// Role in the active workspace (Owner=coach shell, Client=trainee shell). Mirrored from the
  /// TenantController so the synchronous router redirect can adapt navigation. Null until resolved.
  TenantRole? _activeRole;
  TenantRole? get activeRole => _activeRole;

  Future<void> load() async {
    _activeTenantId = await _store.read(_key);
    notifyListeners();
  }

  Future<void> setActive(String id) async {
    if (_activeTenantId == id) return;
    _activeTenantId = id;
    notifyListeners();
    await _store.write(_key, id);
  }

  void setRole(TenantRole? role) {
    if (_activeRole == role) return;
    _activeRole = role;
    notifyListeners();
  }

  Future<void> clear() async {
    _activeTenantId = null;
    _activeRole = null;
    notifyListeners();
    await _store.delete(_key);
  }
}
