import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ui_state.g.dart';

@Riverpod(keepAlive: true)
class TabIndex extends _$TabIndex {
  @override
  int build() => 0;
  void setTab(int index) => state = index;
}

@Riverpod(keepAlive: true)
class SelectedDate extends _$SelectedDate {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void setDate(DateTime date) =>
      state = DateTime(date.year, date.month, date.day);
}

@Riverpod(keepAlive: true)
class AppThemeMode extends _$AppThemeMode {
  @override
  ThemeMode build() => ThemeMode.system;
  void setTheme(ThemeMode mode) => state = mode;
}

// 현재 진행 중인 세션 ID (타이머 상태)
@Riverpod(keepAlive: true)
class ActiveSessionId extends _$ActiveSessionId {
  @override
  String? build() => null;
  void setSession(String? id) => state = id;
}
