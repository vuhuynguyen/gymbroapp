import 'package:dio/dio.dart';
import 'api_exception.dart';

/// Wrap a Dio call so every failure surfaces as a typed [ApiException].
Future<T> apiCall<T>(Future<T> Function() run) async {
  try {
    return await run();
  } on DioException catch (e) {
    throw ApiException.fromDio(e);
  }
}
