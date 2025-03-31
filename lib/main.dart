import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gst_invoice/my_theme.dart';
import 'package:gst_invoice/password/splash_screen.dart';
import 'package:gst_invoice/theme_controlloer.dart';
import 'DATABASE/sharedprefhelper.dart';
import 'organization_detail.dart';
import 'gst_invoice.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool isDataSaved = await SharedPrefHelper.isCompanyDataSaved();
  ThemeController themeController = Get.put(ThemeController());
  Map<String, dynamic> companyDetails = await SharedPrefHelper.getCompanyDetails();

  runApp(MyApp(isDataSaved: isDataSaved, companyDetails: companyDetails));
}

class MyApp extends StatelessWidget {
  final bool isDataSaved;
  final Map<String, dynamic> companyDetails;

  const MyApp({super.key, required this.isDataSaved, required this.companyDetails});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ThemeController>(
      builder: (controller) {
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'GST Invoice',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: controller.isDark.value ? ThemeMode.dark : ThemeMode.light,
          home: SplashScreen(),
          // isDataSaved
          //     ? GstInvoice(
          //   companyName: companyDetails["companyName"] ?? "",
          //   companyState: companyDetails["companyState"] ?? "",
          //   gstRate: companyDetails["gstRate"] ?? "0.0",
          // )
          //     : OrganizationDetail(),
        );
      },
    );
  }
}
