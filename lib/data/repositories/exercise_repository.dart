import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_call.dart';
import '../../core/providers.dart';
import '../models/exercise_models.dart';

/// The global exercise catalog, used by the live session's add/substitute pickers.
/// `GET /api/exercises` returns a bare array (not a paged envelope).
class ExerciseRepository {
  ExerciseRepository(this._dio);
  final Dio _dio;

  Future<ExerciseDetail> getById(String id) => apiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>('/api/exercises/$id');
        return ExerciseDetail.fromJson(res.data!);
      });

  Future<List<ExerciseSummary>> search({String? query, int pageSize = 200}) =>
      apiCall(() async {
        final res = await _dio.get<List<dynamic>>(
          '/api/exercises',
          queryParameters: {
            'page': 1,
            'pageSize': pageSize,
            if (query != null && query.trim().isNotEmpty)
              'search': query.trim(),
          },
        );
        return (res.data ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ExerciseSummary.fromJson)
            .toList(growable: false);
      });
}

final exerciseRepositoryProvider = Provider<ExerciseRepository>(
    (ref) => ExerciseRepository(ref.read(apiDioProvider)));

/// Global exercise catalog keyed by id (cached across the session) — used to resolve muscle group /
/// equipment for the live-session meta pills. Best-effort: returns {} if the catalog can't load.
final exerciseCatalogProvider =
    FutureProvider<Map<String, ExerciseSummary>>((ref) async {
  try {
    final list = await ref.read(exerciseRepositoryProvider).search();
    return {for (final e in list) e.id: e};
  } catch (_) {
    return const {};
  }
});
