import 'package:flutter/material.dart';
import 'package:gst_invoice/color.dart';
import 'DATABASE/sharedprefhelper.dart';
import 'organization_detail.dart';
import 'gst_invoice.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool isDataSaved = await SharedPrefHelper.isCompanyDataSaved();
  Map<String, dynamic> companyDetails = await SharedPrefHelper.getCompanyDetails();

  runApp(MyApp(isDataSaved: isDataSaved, companyDetails: companyDetails));
}

class MyApp extends StatelessWidget {
  final bool isDataSaved;
  final Map<String, dynamic> companyDetails;

  const MyApp({super.key, required this.isDataSaved, required this.companyDetails});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GST Invoice',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: false,
        appBarTheme: AppBarTheme(color: Colors.transparent,elevation: 0,
            // iconTheme: IconThemeData(color: themecolor),titleTextStyle: TextStyle(color: themecolor, fontSize: 20)
        )
      ),
      home: isDataSaved
          ? GstInvoice(
        companyName: companyDetails["companyName"] ?? "",
        companyState: companyDetails["companyState"] ?? "",
        gstRate: companyDetails["gstRate"] ?? "0.0",
      )
          : OrganizationDetail(),
    );
  }
}

