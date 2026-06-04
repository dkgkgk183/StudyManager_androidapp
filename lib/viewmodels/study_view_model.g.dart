// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'study_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$categoryViewModelHash() => r'55584aeea28de4ed624e7e8459b1c40527189f5c';

/// See also [CategoryViewModel].
@ProviderFor(CategoryViewModel)
final categoryViewModelProvider =
    AutoDisposeAsyncNotifierProvider<
      CategoryViewModel,
      List<Map<String, dynamic>>
    >.internal(
      CategoryViewModel.new,
      name: r'categoryViewModelProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$categoryViewModelHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$CategoryViewModel =
    AutoDisposeAsyncNotifier<List<Map<String, dynamic>>>;
String _$subjectViewModelHash() => r'e62aa9ffede256aeea47790604984b0dc114e0ef';

/// See also [SubjectViewModel].
@ProviderFor(SubjectViewModel)
final subjectViewModelProvider =
    AutoDisposeAsyncNotifierProvider<SubjectViewModel, List<Subject>>.internal(
      SubjectViewModel.new,
      name: r'subjectViewModelProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$subjectViewModelHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SubjectViewModel = AutoDisposeAsyncNotifier<List<Subject>>;
String _$studySessionViewModelHash() =>
    r'98e95c6c70501578b559ce5fcaf5ff9829aec06a';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$StudySessionViewModel
    extends BuildlessAutoDisposeAsyncNotifier<List<Map<String, dynamic>>> {
  late final DateTime date;

  FutureOr<List<Map<String, dynamic>>> build(DateTime date);
}

/// See also [StudySessionViewModel].
@ProviderFor(StudySessionViewModel)
const studySessionViewModelProvider = StudySessionViewModelFamily();

/// See also [StudySessionViewModel].
class StudySessionViewModelFamily
    extends Family<AsyncValue<List<Map<String, dynamic>>>> {
  /// See also [StudySessionViewModel].
  const StudySessionViewModelFamily();

  /// See also [StudySessionViewModel].
  StudySessionViewModelProvider call(DateTime date) {
    return StudySessionViewModelProvider(date);
  }

  @override
  StudySessionViewModelProvider getProviderOverride(
    covariant StudySessionViewModelProvider provider,
  ) {
    return call(provider.date);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'studySessionViewModelProvider';
}

/// See also [StudySessionViewModel].
class StudySessionViewModelProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          StudySessionViewModel,
          List<Map<String, dynamic>>
        > {
  /// See also [StudySessionViewModel].
  StudySessionViewModelProvider(DateTime date)
    : this._internal(
        () => StudySessionViewModel()..date = date,
        from: studySessionViewModelProvider,
        name: r'studySessionViewModelProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$studySessionViewModelHash,
        dependencies: StudySessionViewModelFamily._dependencies,
        allTransitiveDependencies:
            StudySessionViewModelFamily._allTransitiveDependencies,
        date: date,
      );

  StudySessionViewModelProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.date,
  }) : super.internal();

  final DateTime date;

  @override
  FutureOr<List<Map<String, dynamic>>> runNotifierBuild(
    covariant StudySessionViewModel notifier,
  ) {
    return notifier.build(date);
  }

  @override
  Override overrideWith(StudySessionViewModel Function() create) {
    return ProviderOverride(
      origin: this,
      override: StudySessionViewModelProvider._internal(
        () => create()..date = date,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        date: date,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<
    StudySessionViewModel,
    List<Map<String, dynamic>>
  >
  createElement() {
    return _StudySessionViewModelProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is StudySessionViewModelProvider && other.date == date;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, date.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin StudySessionViewModelRef
    on AutoDisposeAsyncNotifierProviderRef<List<Map<String, dynamic>>> {
  /// The parameter `date` of this provider.
  DateTime get date;
}

class _StudySessionViewModelProviderElement
    extends
        AutoDisposeAsyncNotifierProviderElement<
          StudySessionViewModel,
          List<Map<String, dynamic>>
        >
    with StudySessionViewModelRef {
  _StudySessionViewModelProviderElement(super.provider);

  @override
  DateTime get date => (origin as StudySessionViewModelProvider).date;
}

String _$todayChecklistViewModelHash() =>
    r'642dd446aad43341e1278b1adfe08d06ac904b79';

abstract class _$TodayChecklistViewModel
    extends BuildlessAutoDisposeAsyncNotifier<List<Map<String, dynamic>>> {
  late final DateTime date;

  FutureOr<List<Map<String, dynamic>>> build(DateTime date);
}

/// See also [TodayChecklistViewModel].
@ProviderFor(TodayChecklistViewModel)
const todayChecklistViewModelProvider = TodayChecklistViewModelFamily();

/// See also [TodayChecklistViewModel].
class TodayChecklistViewModelFamily
    extends Family<AsyncValue<List<Map<String, dynamic>>>> {
  /// See also [TodayChecklistViewModel].
  const TodayChecklistViewModelFamily();

  /// See also [TodayChecklistViewModel].
  TodayChecklistViewModelProvider call(DateTime date) {
    return TodayChecklistViewModelProvider(date);
  }

  @override
  TodayChecklistViewModelProvider getProviderOverride(
    covariant TodayChecklistViewModelProvider provider,
  ) {
    return call(provider.date);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'todayChecklistViewModelProvider';
}

/// See also [TodayChecklistViewModel].
class TodayChecklistViewModelProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          TodayChecklistViewModel,
          List<Map<String, dynamic>>
        > {
  /// See also [TodayChecklistViewModel].
  TodayChecklistViewModelProvider(DateTime date)
    : this._internal(
        () => TodayChecklistViewModel()..date = date,
        from: todayChecklistViewModelProvider,
        name: r'todayChecklistViewModelProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$todayChecklistViewModelHash,
        dependencies: TodayChecklistViewModelFamily._dependencies,
        allTransitiveDependencies:
            TodayChecklistViewModelFamily._allTransitiveDependencies,
        date: date,
      );

  TodayChecklistViewModelProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.date,
  }) : super.internal();

  final DateTime date;

  @override
  FutureOr<List<Map<String, dynamic>>> runNotifierBuild(
    covariant TodayChecklistViewModel notifier,
  ) {
    return notifier.build(date);
  }

  @override
  Override overrideWith(TodayChecklistViewModel Function() create) {
    return ProviderOverride(
      origin: this,
      override: TodayChecklistViewModelProvider._internal(
        () => create()..date = date,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        date: date,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<
    TodayChecklistViewModel,
    List<Map<String, dynamic>>
  >
  createElement() {
    return _TodayChecklistViewModelProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TodayChecklistViewModelProvider && other.date == date;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, date.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TodayChecklistViewModelRef
    on AutoDisposeAsyncNotifierProviderRef<List<Map<String, dynamic>>> {
  /// The parameter `date` of this provider.
  DateTime get date;
}

class _TodayChecklistViewModelProviderElement
    extends
        AutoDisposeAsyncNotifierProviderElement<
          TodayChecklistViewModel,
          List<Map<String, dynamic>>
        >
    with TodayChecklistViewModelRef {
  _TodayChecklistViewModelProviderElement(super.provider);

  @override
  DateTime get date => (origin as TodayChecklistViewModelProvider).date;
}

String _$statsViewModelHash() => r'e05917fcdb7df5a541dc08b5f2bf854e5caf8da1';

/// See also [StatsViewModel].
@ProviderFor(StatsViewModel)
final statsViewModelProvider =
    AutoDisposeAsyncNotifierProvider<
      StatsViewModel,
      List<Map<String, dynamic>>
    >.internal(
      StatsViewModel.new,
      name: r'statsViewModelProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$statsViewModelHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$StatsViewModel = AutoDisposeAsyncNotifier<List<Map<String, dynamic>>>;
String _$statsSummaryViewModelHash() =>
    r'2bd497a4b9e863b5889636a1eaefb5f010ca2824';

abstract class _$StatsSummaryViewModel
    extends BuildlessAutoDisposeAsyncNotifier<StatsSummary> {
  late final DateTime date;

  FutureOr<StatsSummary> build(DateTime date);
}

/// See also [StatsSummaryViewModel].
@ProviderFor(StatsSummaryViewModel)
const statsSummaryViewModelProvider = StatsSummaryViewModelFamily();

/// See also [StatsSummaryViewModel].
class StatsSummaryViewModelFamily extends Family<AsyncValue<StatsSummary>> {
  /// See also [StatsSummaryViewModel].
  const StatsSummaryViewModelFamily();

  /// See also [StatsSummaryViewModel].
  StatsSummaryViewModelProvider call(DateTime date) {
    return StatsSummaryViewModelProvider(date);
  }

  @override
  StatsSummaryViewModelProvider getProviderOverride(
    covariant StatsSummaryViewModelProvider provider,
  ) {
    return call(provider.date);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'statsSummaryViewModelProvider';
}

/// See also [StatsSummaryViewModel].
class StatsSummaryViewModelProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          StatsSummaryViewModel,
          StatsSummary
        > {
  /// See also [StatsSummaryViewModel].
  StatsSummaryViewModelProvider(DateTime date)
    : this._internal(
        () => StatsSummaryViewModel()..date = date,
        from: statsSummaryViewModelProvider,
        name: r'statsSummaryViewModelProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$statsSummaryViewModelHash,
        dependencies: StatsSummaryViewModelFamily._dependencies,
        allTransitiveDependencies:
            StatsSummaryViewModelFamily._allTransitiveDependencies,
        date: date,
      );

  StatsSummaryViewModelProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.date,
  }) : super.internal();

  final DateTime date;

  @override
  FutureOr<StatsSummary> runNotifierBuild(
    covariant StatsSummaryViewModel notifier,
  ) {
    return notifier.build(date);
  }

  @override
  Override overrideWith(StatsSummaryViewModel Function() create) {
    return ProviderOverride(
      origin: this,
      override: StatsSummaryViewModelProvider._internal(
        () => create()..date = date,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        date: date,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<StatsSummaryViewModel, StatsSummary>
  createElement() {
    return _StatsSummaryViewModelProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is StatsSummaryViewModelProvider && other.date == date;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, date.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin StatsSummaryViewModelRef
    on AutoDisposeAsyncNotifierProviderRef<StatsSummary> {
  /// The parameter `date` of this provider.
  DateTime get date;
}

class _StatsSummaryViewModelProviderElement
    extends
        AutoDisposeAsyncNotifierProviderElement<
          StatsSummaryViewModel,
          StatsSummary
        >
    with StatsSummaryViewModelRef {
  _StatsSummaryViewModelProviderElement(super.provider);

  @override
  DateTime get date => (origin as StatsSummaryViewModelProvider).date;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
