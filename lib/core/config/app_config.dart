/// Static, compile-time configuration for the GymBro mobile client.
///
/// Two environments are baked in, and the default is **dev → local API** — so a plain `flutter run`
/// (or `flutter test` / `flutter build`) talks to a locally-running API with zero flags. Reach for
/// the live host only when you actually need it:
///
///   flutter run                                          # dev  → http://localhost:5216 (local API)
///   flutter run --dart-define-from-file=config/prod.json # prod → https://gymbro.ddns.net (live)
///   flutter run --dart-define=GYMBRO_ENV=prod            # prod, flag form (no file)
///
/// Resolution order for [apiBaseUrl] (highest priority first):
///   1. GYMBRO_API_BASE_URL — an explicit host wins outright (this is what config/*.json set).
///   2. GYMBRO_ENV          — 'dev' (default) → local host, 'prod' → live host.
///
/// Note: Android emulators can't see the host machine's `localhost`. Point dev at the host loopback:
///   flutter run --dart-define=GYMBRO_DEV_API_BASE_URL=http://10.0.2.2:5216
class AppConfig {
  const AppConfig._();

  /// Target environment when no explicit URL is given: 'dev' (default) or 'prod'.
  static const String environment = String.fromEnvironment(
    'GYMBRO_ENV',
    defaultValue: 'dev',
  );

  /// Local API for development. Defaults to the API's `dotnet run` HTTP port
  /// (see `gymbro/.../launchSettings.json`); override for emulators or a Dockerised API (`:8080`).
  static const String _devApiBaseUrl = String.fromEnvironment(
    'GYMBRO_DEV_API_BASE_URL',
    defaultValue: 'http://localhost:5216',
  );

  /// Live production host (real TLS via Caddy / Let's Encrypt).
  static const String _prodApiBaseUrl = 'https://gymbro.ddns.net';

  /// Explicit override — wins over the [environment] switch when non-empty.
  static const String _explicitApiBaseUrl = String.fromEnvironment(
    'GYMBRO_API_BASE_URL',
    defaultValue: '',
  );

  /// Host root only — request paths include the `/api/...` prefix themselves, and the refresh
  /// cookie is scoped to `/api/auth`, so the base URL must NOT include `/api`.
  static const String apiBaseUrl = _explicitApiBaseUrl == ''
      ? (environment == 'prod' ? _prodApiBaseUrl : _devApiBaseUrl)
      : _explicitApiBaseUrl;

  /// Optional explicit API version. The API treats an absent `X-Api-Version` header as
  /// "latest", which is what we want, so this is empty by default (header omitted).
  static const String apiVersion = String.fromEnvironment(
    'GYMBRO_API_VERSION',
    defaultValue: '',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
