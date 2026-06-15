import '../../core/utils/json.dart';
import '../../domain/enums.dart';

/// Wire models for the nutrition surface. Fields mirror the as-built backend response shapes
/// documented in `gymbro/docs/nutrition/API_AND_PERMISSIONS.md` §5 / `DOMAIN_MODEL.md` (camelCase on
/// the wire). Macro fields are all nullable — the catalog often only carries kcal + protein.
///
/// `source` reuses [SessionSource] (`fromAssignment` / `adhoc`) — the same plan-vs-ad-hoc split the
/// session feature already ships, so the wire enum and the `SourceTag` widget are shared verbatim.

/// One logged/planned food item within a meal — the core unit of the Today checklist.
class NutritionItem {
  const NutritionItem({
    required this.id,
    required this.isPlanned,
    required this.foodId,
    required this.foodName,
    required this.status,
    this.kind = FoodKind.food,
    this.planMealItemId,
    this.servingLabel,
    this.quantity = 1,
    this.energyKcal,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.fiberG,
    this.loggedAtUtc,
    this.note,
    this.swappedFromName,
    this.isCustom = false,
    this.isEdited = false,
  });

  final String id;

  /// Null ⇒ an ad-hoc (off-plan) item the trainee added; otherwise the pinned plan-meal-item id.
  final String? planMealItemId;
  final bool isPlanned;
  final String foodId;
  final String foodName;
  final NutritionItemStatus status;

  /// Food / supplement / beverage — a supplement from a plan or a custom one logs the same way.
  final FoodKind kind;
  final String? servingLabel;
  final num quantity;
  final num? energyKcal;
  final num? proteinG;
  final num? carbsG;
  final num? fatG;
  final num? fiberG;
  final DateTime? loggedAtUtc;
  final String? note;

  /// For substituted items — the original planned food's name ("was Oatmeal").
  final String? swappedFromName;

  /// Catalog provenance flags surfaced to a coach (a client-created / edited food is "unverified").
  final bool isCustom;
  final bool isEdited;

  bool get isAdhoc => planMealItemId == null;

  NutritionItem copyWith({
    NutritionItemStatus? status,
    String? foodId,
    String? foodName,
    FoodKind? kind,
    String? servingLabel,
    num? quantity,
    num? energyKcal,
    num? proteinG,
    num? carbsG,
    num? fatG,
    num? fiberG,
    String? swappedFromName,
    DateTime? loggedAtUtc,
  }) =>
      NutritionItem(
        id: id,
        planMealItemId: planMealItemId,
        isPlanned: isPlanned,
        foodId: foodId ?? this.foodId,
        foodName: foodName ?? this.foodName,
        status: status ?? this.status,
        kind: kind ?? this.kind,
        servingLabel: servingLabel ?? this.servingLabel,
        quantity: quantity ?? this.quantity,
        energyKcal: energyKcal ?? this.energyKcal,
        proteinG: proteinG ?? this.proteinG,
        carbsG: carbsG ?? this.carbsG,
        fatG: fatG ?? this.fatG,
        fiberG: fiberG ?? this.fiberG,
        loggedAtUtc: loggedAtUtc ?? this.loggedAtUtc,
        note: note,
        swappedFromName: swappedFromName ?? this.swappedFromName,
        isCustom: isCustom,
        isEdited: isEdited,
      );

  factory NutritionItem.fromJson(Map<String, dynamic> j) => NutritionItem(
        id: j['id'].toString(),
        planMealItemId: asString(j['planMealItemId']),
        isPlanned: asBool(j['isPlanned'], fallback: j['planMealItemId'] != null),
        foodId: (j['foodId'] ?? '').toString(),
        foodName: asString(j['foodName']) ?? 'Food',
        status: NutritionItemStatus.parse(j['status']),
        kind: FoodKind.parse(j['kind']),
        servingLabel: asString(j['servingLabel']),
        quantity: asDouble(j['quantity']) ?? 1,
        energyKcal: asDouble(j['energyKcal']),
        proteinG: asDouble(j['proteinG']),
        carbsG: asDouble(j['carbsG']),
        fatG: asDouble(j['fatG']),
        fiberG: asDouble(j['fiberG']),
        loggedAtUtc: asDate(j['loggedAtUtc']),
        note: asString(j['note']),
        swappedFromName: asString(j['swappedFromName'] ?? j['substitutedFromName']),
        isCustom: asBool(j['isCustom']),
        isEdited: asBool(j['isEdited']),
      );
}

/// A meal section (Breakfast / Pre-workout / …) and its items, in schedule order.
class NutritionMeal {
  const NutritionMeal(
      {required this.name, this.scheduledTime, this.items = const []});

  final String name;

  /// "HH:mm:ss" or null (an unscheduled / ad-hoc bucket).
  final String? scheduledTime;
  final List<NutritionItem> items;

  /// Planned items only — the meal-header completion ring denominator (ad-hoc items aren't "planned").
  List<NutritionItem> get plannedItems =>
      items.where((i) => i.isPlanned).toList(growable: false);

  int get plannedDone =>
      plannedItems.where((i) => i.status.isAdherent).length;

  NutritionMeal copyWithItems(List<NutritionItem> items) =>
      NutritionMeal(name: name, scheduledTime: scheduledTime, items: items);

  factory NutritionMeal.fromJson(Map<String, dynamic> j) => NutritionMeal(
        name: asString(j['name']) ?? 'Meal',
        scheduledTime: asString(j['scheduledTime']),
        items: asList(j['items'], NutritionItem.fromJson),
      );
}

/// A single day's nutrition log — the Today surface and read-only day detail bind to this.
class DailyNutritionLog {
  const DailyNutritionLog({
    required this.id,
    required this.localDate,
    required this.hasPlan,
    required this.isClosed,
    required this.source,
    required this.meals,
    this.traineeId,
    this.serverAdherencePct,
    this.serverPlannedCount,
    this.serverCompletedCount,
    this.consumedKcal = 0,
    this.targetKcal,
  });

  final String id;

  /// `YYYY-MM-DD` (the trainee-local calendar day; nutrition is date-keyed, not timestamp-keyed).
  final String localDate;
  final bool hasPlan;
  final bool isClosed;
  final SessionSource source;
  final List<NutritionMeal> meals;
  final String? traineeId;

  /// Calories consumed today, all-source (planned + ad-hoc self-logged). Server-computed; defaults to
  /// 0 on an older payload that predates the field. This is the *display* total the Log tab shows —
  /// distinct from [loggedKcal], which the ring card recomputes locally from adherent items only.
  final int consumedKcal;

  /// Plan-derived calorie target for today, or null when there's no plan target (a self-logger / no
  /// plan). Null means "no target" — never fabricate a goal; the Log tab then shows consumed-only.
  final int? targetKcal;

  // Server-computed roll-ups. We prefer these on first load, but recompute locally after an optimistic
  // mutation (see [adherencePct]) so the ring moves the instant the user taps.
  final int? serverAdherencePct;
  final int? serverPlannedCount;
  final int? serverCompletedCount;

  /// The lazily-seeded / offline "no nutrition plan" day used when the backend hasn't shipped the
  /// nutrition surface yet (the whole `/api/me/nutrition/*` namespace 404s) — drives the no-plan
  /// empty state instead of an error. Mirrors `session_repository`'s graceful `/api/me/*` fallback.
  factory DailyNutritionLog.noPlan(String localDate) => DailyNutritionLog(
        id: 'noplan-$localDate',
        localDate: localDate,
        hasPlan: false,
        isClosed: false,
        source: SessionSource.adhoc,
        meals: const [],
      );

  List<NutritionItem> get allItems =>
      [for (final m in meals) ...m.items];

  List<NutritionItem> get plannedItems =>
      allItems.where((i) => i.isPlanned).toList(growable: false);

  int get plannedCount => plannedItems.length;
  int get completedCount => plannedItems.where((i) => i.status.isAdherent).length;

  /// Adherence rule (API §5): (completed + substituted planned items) ÷ planned items, 0–100; a day
  /// with **no planned items is 100%**. Recomputed locally so optimistic taps update the ring at once.
  int get adherencePct {
    final planned = plannedCount;
    if (planned == 0) return serverAdherencePct ?? 100;
    return ((completedCount / planned) * 100).round().clamp(0, 100);
  }

  double get adherenceFraction => plannedCount == 0 ? 1 : completedCount / plannedCount;

  /// Summed kcal / protein of adherent (eaten + swapped) items — the ring card's secondary stats.
  num get loggedKcal => allItems
      .where((i) => i.status.isAdherent)
      .fold<num>(0, (a, i) => a + (i.energyKcal ?? 0) * i.quantity);
  num get loggedProtein => allItems
      .where((i) => i.status.isAdherent)
      .fold<num>(0, (a, i) => a + (i.proteinG ?? 0) * i.quantity);

  DailyNutritionLog copyWithMeals(List<NutritionMeal> meals) =>
      DailyNutritionLog(
        id: id,
        localDate: localDate,
        hasPlan: hasPlan,
        isClosed: isClosed,
        source: source,
        meals: meals,
        traineeId: traineeId,
        serverAdherencePct: serverAdherencePct,
        serverPlannedCount: serverPlannedCount,
        serverCompletedCount: serverCompletedCount,
        consumedKcal: consumedKcal,
        targetKcal: targetKcal,
      );

  /// Replace one item (by id) across whatever meal holds it — the optimistic-update primitive.
  DailyNutritionLog withItem(String itemId, NutritionItem Function(NutritionItem) update) =>
      copyWithMeals([
        for (final m in meals)
          m.copyWithItems([
            for (final i in m.items) if (i.id == itemId) update(i) else i,
          ]),
      ]);

  factory DailyNutritionLog.fromJson(Map<String, dynamic> j) {
    final status = asString(j['status'])?.toLowerCase();
    return DailyNutritionLog(
      id: (j['id'] ?? 'today').toString(),
      localDate: asString(j['localDate']) ?? '',
      hasPlan: asBool(j['hasPlan'], fallback: (j['meals'] as List?)?.isNotEmpty ?? false),
      isClosed: status == 'closed',
      source: SessionSource.parse(j['source']),
      meals: asList(j['meals'], NutritionMeal.fromJson),
      traineeId: asString(j['traineeId']),
      serverAdherencePct: asInt(j['adherencePct']),
      serverPlannedCount: asInt(j['plannedCount']),
      serverCompletedCount: asInt(j['completedCount']),
      // Defensive for older payloads: consumed defaults to 0, target stays null when absent.
      consumedKcal: (asInt(j['consumedKcal']) ?? 0).clamp(0, 1 << 30),
      targetKcal: asInt(j['targetKcal']),
    );
  }
}

/// A history/coach-list row — the lightweight per-day summary (no items).
class NutritionDaySummary {
  const NutritionDaySummary({
    required this.id,
    required this.localDate,
    required this.isClosed,
    required this.source,
    required this.adherencePct,
    required this.plannedCount,
    required this.completedCount,
    this.skippedCount = 0,
    this.missedCount = 0,
  });

  final String id;
  final String localDate;
  final bool isClosed;
  final SessionSource source;
  final int adherencePct;
  final int plannedCount;
  final int completedCount;
  final int skippedCount;
  final int missedCount;

  double get adherenceFraction => adherencePct / 100;

  /// Parse a `YYYY-MM-DD` date (local midnight) for grouping/labels; null if malformed.
  DateTime? get date => DateTime.tryParse(localDate);

  factory NutritionDaySummary.fromJson(Map<String, dynamic> j) =>
      NutritionDaySummary(
        id: (j['id'] ?? j['localDate'] ?? '').toString(),
        localDate: asString(j['localDate']) ?? '',
        isClosed: asString(j['status'])?.toLowerCase() == 'closed',
        source: SessionSource.parse(j['source']),
        adherencePct: asInt(j['adherencePct']) ?? 0,
        plannedCount: asInt(j['plannedCount']) ?? 0,
        completedCount: asInt(j['completedCount']) ?? 0,
        skippedCount: asInt(j['skippedCount']) ?? 0,
        missedCount: asInt(j['missedCount']) ?? 0,
      );
}

/// A paged nutrition-day timeline (history / coach monitoring).
class NutritionDayList {
  const NutritionDayList(
      {this.items = const [], this.page = 1, this.pageSize = 50, this.totalCount = 0});

  final List<NutritionDaySummary> items;
  final int page;
  final int pageSize;
  final int totalCount;

  static const empty = NutritionDayList();

  factory NutritionDayList.fromJson(Map<String, dynamic> j) => NutritionDayList(
        items: asList(j['items'], NutritionDaySummary.fromJson),
        page: asInt(j['page']) ?? 1,
        pageSize: asInt(j['pageSize']) ?? 50,
        totalCount: asInt(j['totalCount']) ?? 0,
      );
}

/// A catalog food (the food picker's row + the macro source for an added/swapped item).
class Food {
  const Food({
    required this.id,
    required this.name,
    required this.kind,
    this.brand,
    this.servingLabel,
    this.servingSizeGrams,
    this.energyKcal,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.fiberG,
    this.isCustom = false,
    this.isEdited = false,
    this.mine = false,
  });

  final String id;
  final String name;
  final String? brand;
  final FoodKind kind;
  final String? servingLabel;
  final num? servingSizeGrams;
  final num? energyKcal;
  final num? proteinG;
  final num? carbsG;
  final num? fatG;
  final num? fiberG;

  /// A free-form food the user described themselves (no catalog entry).
  final bool isCustom;

  /// A catalog food whose macros the user adjusted (an "edited variant").
  final bool isEdited;

  /// Saved in the user's device-local "My foods" library.
  final bool mine;

  factory Food.fromJson(Map<String, dynamic> j) => Food(
        id: j['id'].toString(),
        name: asString(j['name']) ?? 'Food',
        brand: asString(j['brand']),
        kind: FoodKind.parse(j['kind']),
        servingLabel: asString(j['servingLabel']),
        servingSizeGrams: asDouble(j['servingSizeGrams']),
        energyKcal: asDouble(j['energyKcal']),
        proteinG: asDouble(j['proteinG']),
        carbsG: asDouble(j['carbsG']),
        fatG: asDouble(j['fatG']),
        fiberG: asDouble(j['fiberG']),
        isCustom: asBool(j['isCustom']),
      );

  /// Local persistence for the device-only "My foods" library — round-trips every field
  /// including the client-only flags the API doesn't carry (mine / edited).
  Map<String, dynamic> toLocalJson() => {
        'id': id,
        'name': name,
        'brand': brand,
        'kind': kind.wire,
        'servingLabel': servingLabel,
        'servingSizeGrams': servingSizeGrams,
        'energyKcal': energyKcal,
        'proteinG': proteinG,
        'carbsG': carbsG,
        'fatG': fatG,
        'fiberG': fiberG,
        'isCustom': isCustom,
        'isEdited': isEdited,
        'mine': mine,
      };

  factory Food.fromLocalJson(Map<String, dynamic> j) => Food(
        id: j['id'].toString(),
        name: asString(j['name']) ?? 'Food',
        brand: asString(j['brand']),
        kind: FoodKind.parse(j['kind']),
        servingLabel: asString(j['servingLabel']),
        servingSizeGrams: asDouble(j['servingSizeGrams']),
        energyKcal: asDouble(j['energyKcal']),
        proteinG: asDouble(j['proteinG']),
        carbsG: asDouble(j['carbsG']),
        fatG: asDouble(j['fatG']),
        fiberG: asDouble(j['fiberG']),
        isCustom: asBool(j['isCustom']),
        isEdited: asBool(j['isEdited']),
        mine: asBool(j['mine']),
      );

  Food copyWith({
    String? id,
    String? name,
    Object? brand = _unset,
    FoodKind? kind,
    Object? servingLabel = _unset,
    num? servingSizeGrams,
    num? energyKcal,
    num? proteinG,
    num? carbsG,
    num? fatG,
    num? fiberG,
    bool? isCustom,
    bool? isEdited,
    bool? mine,
  }) =>
      Food(
        id: id ?? this.id,
        name: name ?? this.name,
        brand: brand == _unset ? this.brand : brand as String?,
        kind: kind ?? this.kind,
        servingLabel:
            servingLabel == _unset ? this.servingLabel : servingLabel as String?,
        servingSizeGrams: servingSizeGrams ?? this.servingSizeGrams,
        energyKcal: energyKcal ?? this.energyKcal,
        proteinG: proteinG ?? this.proteinG,
        carbsG: carbsG ?? this.carbsG,
        fatG: fatG ?? this.fatG,
        fiberG: fiberG ?? this.fiberG,
        isCustom: isCustom ?? this.isCustom,
        isEdited: isEdited ?? this.isEdited,
        mine: mine ?? this.mine,
      );
}

const Object _unset = Object();

/// A paged food-catalog search response.
class FoodList {
  const FoodList(
      {this.items = const [], this.page = 1, this.pageSize = 20, this.totalCount = 0});

  final List<Food> items;
  final int page;
  final int pageSize;
  final int totalCount;

  static const empty = FoodList();

  factory FoodList.fromJson(Map<String, dynamic> j) => FoodList(
        items: asList(j['items'], Food.fromJson),
        page: asInt(j['page']) ?? 1,
        pageSize: asInt(j['pageSize']) ?? 20,
        totalCount: asInt(j['totalCount']) ?? 0,
      );
}

/// A client-logged body metric (the daily check-in), backed by `GET/POST
/// /api/me/nutrition/metrics` (self-scoped; GET returns `{items:[…]}` newest-first).
/// The repository still degrades 404s to empty/no-op for older deployments. The mobile
/// check-in logs weight + sleep; water / mood / photo are future server-side kinds.
class MetricEntry {
  const MetricEntry({
    required this.type,
    required this.value,
    this.unit,
    this.localDate,
    this.loggedAtUtc,
  });

  /// "weight" | "sleep" | … (free-form on the wire; the check-in only reads/writes weight + sleep).
  final String type;
  final num value;
  final String? unit;
  final String? localDate;
  final DateTime? loggedAtUtc;

  Map<String, dynamic> toJson() => {
        'type': type,
        'value': value,
        if (unit != null) 'unit': unit,
        if (localDate != null) 'localDate': localDate,
      };

  factory MetricEntry.fromJson(Map<String, dynamic> j) => MetricEntry(
        type: asString(j['type']) ?? '',
        value: asDouble(j['value']) ?? 0,
        unit: asString(j['unit']),
        localDate: asString(j['localDate']),
        loggedAtUtc: asDate(j['loggedAtUtc']),
      );
}

/// The day's body check-in (latest weight + sleep), read from `GET /api/me/nutrition/metrics`.
class DailyCheckin {
  const DailyCheckin({this.weightKg, this.sleepHours});

  final num? weightKg;
  final num? sleepHours;

  static const empty = DailyCheckin();

  bool get isEmpty => weightKg == null && sleepHours == null;

  DailyCheckin copyWith({num? weightKg, num? sleepHours}) => DailyCheckin(
        weightKg: weightKg ?? this.weightKg,
        sleepHours: sleepHours ?? this.sleepHours,
      );

  /// Collapse a metric list into the latest weight + sleep reading.
  factory DailyCheckin.fromMetrics(List<MetricEntry> metrics) {
    num? weight, sleep;
    for (final m in metrics) {
      switch (m.type.toLowerCase()) {
        case 'weight':
          weight ??= m.value;
        case 'sleep':
          sleep ??= m.value;
      }
    }
    return DailyCheckin(weightKg: weight, sleepHours: sleep);
  }
}
