import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/auth_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../tenant/tenant_controller.dart';

/// Auth/profile state. The *authenticated?* truth lives in [TokenStore] (a Listenable the router
/// watches); this controller owns the `me` profile and the imperative auth actions. Action methods
/// rethrow [ApiException] so screens can show inline errors; on success the router redirect navigates.
class AuthController extends AsyncNotifier<Me?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<Me?> build() async {
    if (!ref.read(tokenStoreProvider).isAuthenticated) return null;
    return _repo.me();
  }

  Future<void> login(String email, String password) async {
    await _repo.login(email, password);
    ref.invalidateSelf();
    await future;
    ref.invalidate(tenantControllerProvider);
  }

  Future<void> register(String email, String password, String fullName) async {
    await _repo.register(email, password, fullName);
    ref.invalidateSelf();
    await future;
    ref.invalidate(tenantControllerProvider);
  }

  Future<void> forgotPassword(String email) => _repo.forgotPassword(email);

  Future<void> resetPassword(String email, String token, String newPassword) =>
      _repo.resetPassword(email, token, newPassword);

  Future<void> changePassword(String currentPassword, String newPassword) =>
      _repo.changePassword(currentPassword, newPassword);

  Future<void> logout() async {
    await _repo.logout();
    await ref.read(tenantControllerProvider.notifier).clear();
    state = const AsyncData(null);
  }

  Future<void> logoutAll() async {
    await _repo.logoutAll();
    await ref.read(tenantControllerProvider.notifier).clear();
    state = const AsyncData(null);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, Me?>(AuthController.new);
