import 'package:flutter/material.dart';

/// Shared palette of the home screen, taken from the UI lab.
///
/// Naming history: the first names (`violet`, `amber`, ...) did not
/// match the rendered hues — `violet` was really a blue, `amber`
/// really an orange. The honest names below (`blue`, `orange`, ...)
/// are canonical; the old names stay as deprecated aliases so the
/// dozen files importing them keep working.
const paper = Color(0xFFFFFFFF);
const ink = Color(0xFF22314A);
const muted = Color(0xFF8494AB);
const line = Color(0xFFDEE9F7);
const blue = Color(0xFF45A3FF);
const blueDark = Color(0xFF1F6FC4);
const teal = Color(0xFF14B8A6);
const tealDark = Color(0xFF0B7E72);
const orange = Color(0xFFFF9500);
const coral = Color(0xFFFF6B6B);
const sky = Color(0xFF8FCBFF);
const trail = Color(0xFFC7E4FF);

/// Legacy aliases (misnamed hues). Use [blue]/[orange] in new code.
@Deprecated('Use blue instead')
const violet = blue;
@Deprecated('Use blueDark instead')
const violetDark = blueDark;
@Deprecated('Use orange instead')
const amber = orange;
