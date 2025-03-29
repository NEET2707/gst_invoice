import 'package:flutter/material.dart';

import 'color.dart';

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  useMaterial3: true,
  scaffoldBackgroundColor: lightBgColor,
  primarySwatch: Colors.deepPurple,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.deepPurple,
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 24,
      fontWeight: FontWeight.w500,
    ),
    iconTheme: IconThemeData(
      color: Colors.white,
    ),
  ),
  colorScheme: ColorScheme.light(
    // background: lightBgColor,
    background: lightBgColor,
    onBackground: lightTextColor,
    primary: Colors.white,
    onPrimary: Colors.white,
    surface: lightDivColor,
    onSurface: lightTextColor,
    secondary: buttonColor,
    onSecondary: lightColor,
    onError: Colors.red,
    error: lightDivColor,
    primaryContainer: lightDivColor,
    secondaryContainer: lightDivColor,
    onPrimaryContainer: lightTextColor,
    onSecondaryContainer: lightTextColor,
    outline: lightCircleAvatarColor,
    scrim: lightIconColor,
    inversePrimary: lightbodybgColor,
    onTertiary: lightSettingsColor,
    onPrimaryFixedVariant: lightFiconColor,
  ),
);


final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
  scaffoldBackgroundColor: darkBgColor,
  primarySwatch: Colors.deepOrange,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.grey,
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 24,
      fontWeight: FontWeight.w500,
    ),
    iconTheme: IconThemeData(
      color: Colors.white,
    ),
  ),
  colorScheme: ColorScheme.dark(
    background: darkBgColor,
    onBackground: darkTextColor,
    primary: Colors.white,
    onPrimary: Colors.white,
    surface: darkDivColor,
    onSurface: darkTextColor,
    secondary: buttonColor,
    onSecondary: darkColor,
    onError: Colors.red,
    error: darkDivColor,
    primaryContainer: darkDivColor,
    secondaryContainer: darkDivColor,
    onPrimaryContainer: darkTextColor,
    onSecondaryContainer: darkTextColor,
    outline: darkCircleAvatarColor,
    scrim: darkIconColor,
    inversePrimary: darkbodybgColor,
    onTertiary: darkSettingsColor,
    onPrimaryFixedVariant: darkFiconColor,
  ),
);