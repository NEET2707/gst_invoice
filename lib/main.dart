import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gst_invoice/color.dart';
import 'package:gst_invoice/my_theme.dart';
import 'splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GST Invoice',
      // theme: ThemeData(
      //   colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      //   useMaterial3: false,
      //   appBarTheme: AppBarTheme(
      //     color: Colors.transparent,
      //     elevation: 0,
      //   ),
      // ),
      theme: lightTheme,
      darkTheme: darkTheme,
      home: SplashScreen(), // ✅ Start with SplashScreen
    );
  }
}
