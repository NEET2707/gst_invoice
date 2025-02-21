import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'DATABASE/sharedprefhelper.dart';
import 'organization_detail.dart';
import 'gst_invoice.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool isDataSaved = await SharedPrefHelper.isCompanyDataSaved();
  Map<String, String> companyDetails = isDataSaved
      ? await SharedPrefHelper.getCompanyDetails()
      : {"companyName": "", "companyState": "", "gstRate": "0.0"};

  runApp(MyApp(isDataSaved: isDataSaved, companyDetails: companyDetails));
}

class MyApp extends StatelessWidget {
  final bool isDataSaved;
  final Map<String, String> companyDetails;

  const MyApp({super.key, required this.isDataSaved, required this.companyDetails});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GST Invoice',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: false,
      ),
      home: isDataSaved
          ? GstInvoice(
        companyName: companyDetails["companyName"]!,
        companyState: companyDetails["companyState"]!,
        gstRate: companyDetails["gstRate"]!,
      )
          : OrganizationDetail(),
    );
  }
}
