// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'study_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$categoryViewModelHash() => r'3e7bfe0d93f1e349d585ee2c4669b8553e98f685';

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
String _$subjectViewModelHash() => r'68922c6fe604b9cfdc624f52f7bb0a7a3d028698';

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
String _$studyPlanViewModelHash() =>
    r'902b911a5fdc3bdc54d23ef2eefcaf2c44298ec0';

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

abstract class _$StudyPlanViewModel
    extends BuildlessAutoDisposeAsyncNotifier<List<Map<String, dynamic>>> {
  late final DateTime date;

  FutureOr<List<Map<String, dynamic>>> build(DateTime date);
}

/// See also [StudyPlanViewModel].
@ProviderFor(StudyPlanViewModel)
const studyPlanViewModelProvider = StudyPlanViewModelFamily();

/// See also [StudyPlanViewModel].
class StudyPlanViewModelFamily
    extends Family<AsyncValue<List<Map<String, dynamic>>>> {
  /// See also [StudyPlanViewModel].
  const StudyPlanViewModelFamily();

  /// See also [StudyPlanViewModel].
  StudyPlanViewModelProvider call(DateTime date) {
    return StudyPlanViewModelProvider(date);
  }

  @override
  StudyPlanViewModelProvider getProviderOverride(
    covariant StudyPlanViewModelProvider provider,
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
  String? get name => r'studyPlanViewModelProvider';
}

/// See also [StudyPlanViewModel].
class StudyPlanViewModelProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          StudyPlanViewModel,
          List<Map<String, dynamic>>
        > {
  /// See also [StudyPlanViewModel].
  StudyPlanViewModelProvider(DateTime date)
    : this._internal(
        () => StudyPlanViewModel()..date = date,
        from: studyPlanViewModelProvider,
        name: r'studyPlanViewModelProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$studyPlanViewModelHash,
        dependencies: StudyPlanViewModelFamily._dependencies,
        allTransitiveDependencies:
            StudyPlanViewModelFamily._allTransitiveDependencies,
        date: date,
      );

  StudyPlanViewModelProvider._internal(
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
    covariant StudyPlanViewModel notifier,
  ) {
    return notifier.build(date);
  }

  @override
  Override overrideWith(StudyPlanViewModel Function() create) {
    return ProviderOverride(
      origin: this,
      override: StudyPlanViewModelProvider._internal(
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
    StudyPlanViewModel,
    List<Map<String, dynamic>>
  >
  createElement() {
    return _StudyPlanViewModelProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is StudyPlanViewModelProvider && other.date == date;
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
mixin StudyPlanViewModelRef
    on AutoDisposeAsyncNotifierProviderRef<List<Map<String, dynamic>>> {
  /// The parameter `date` of this provider.
  DateTime get date;
}

class _StudyPlanViewModelProviderElement
    extends
        AutoDisposeAsyncNotifierProviderElement<
          StudyPlanViewModel,
          List<Map<String, dynamic>>
        >
    with StudyPlanViewModelRef {
  _StudyPlanViewModelProviderElement(super.provider);

  @override
  DateTime get date => (origin as StudyPlanViewModelProvider).date;
}

String _$studySessionViewModelHash() =>
    r'0ccd74643894fcfe14bcf37b9d9f9d1d5adb5555';

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

String _$statsViewModelHash() => r'4bebfbc19e7cdd807d18e9511512133468dd0a26';

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
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
