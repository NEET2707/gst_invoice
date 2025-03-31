import 'package:flutter/material.dart';
import 'dart:async';
import 'package:gst_invoice/DATABASE/database_helper.dart';
import 'package:gst_invoice/password/pin_verify.dart';
import '../database/sharedprefhelper.dart';
import '../organization_detail.dart';
import '../gst_invoice.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // checkCompanyData();
    _showSplashScreen();
  }

  Future<void> _showSplashScreen() async {
    await Future.delayed(const Duration(seconds: 1));
    String? savedPin = await SharedPrefHelper.get(prefKey: PrefKey.pin);

    if (savedPin != null) {
      // ✅ Navigate to PIN screen, then decide where to go
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VerifyPinScreen(
            onSuccess: () {
              checkCompanyData();
            },
          ),
        ),
      );
    } else {
      checkCompanyData();
    }
  }

  Future<void> checkCompanyData() async {
    final dbHelper = DatabaseHelper();
    bool isDataSaved = await dbHelper.isCompanyDataAvailable();
    Map<String, dynamic> companyDetails = await dbHelper.getCompanyDetails();

    Timer(Duration(seconds: 2), () {
      print("..............${isDataSaved}..........");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => isDataSaved
              ? GstInvoice(
                  companyName: companyDetails["company_name"] ?? "",
                  companyState: companyDetails["company_state"] ?? "",
                  gstRate: companyDetails["igst"]?.toString() ?? "0.0",
                )
              : OrganizationDetail(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          "assets/images/logo.png",
          width: 200,
          height: 200,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
