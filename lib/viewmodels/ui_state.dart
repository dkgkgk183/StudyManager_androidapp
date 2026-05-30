import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../database/database.dart';

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
  DateTime build() => toStudyDate(DateTime.now());

  void setDate(DateTime date) =>
      state = DateTime(date.year, date.month, date.day);
}

@Riverpod(keepAlive: true)
class AppThemeMode extends _$AppThemeMode {
  @override
  ThemeMode build() => ThemeMode.system;
  void setTheme(ThemeMode mode) => state = mode;
}

