import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefHelper {
  static const String _isDataSavedKey = "isDataSaved";
  static const String _companyNameKey = "companyName";
  static const String _companyStateKey = "companyState";
  static const String _gstRateKey = "gstRate";
  static const String _gstNumberKey = "gstNumber";
  static const String _companyAddressKey = "companyAddress";
  static const String _companyContactKey = "companyContact";
  static const String _isGstApplicableKey = "isGstApplicable";
  static const String _defaultCustomerStateKey = "defaultCustomerState";
  static const String _gstTypeKey = "gstType";

  static Future<void> saveCompanyDetails({
    required String companyName,
    required String companyState,
    required String gstRate,
    required String gstNumber,
    required String companyAddress,
    required String companyContact,
    required bool isGstApplicable,
    required String defaultCustomerState,
    required String gstType,
    String? bankDetails,
    String? tandC,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString("companyName", companyName);
    await prefs.setString("companyState", companyState);
    await prefs.setString("gstRate", gstRate);
    await prefs.setString("gstNumber", gstNumber);
    await prefs.setString("companyAddress", companyAddress);
    await prefs.setString("companyContact", companyContact);

    // ✅ Fix: Store GST applicable flag correctly
    await prefs.setInt("isGstApplicable", isGstApplicable ? 1 : 0);

    await prefs.setString("defaultCustomerState", defaultCustomerState);
    await prefs.setString("gstType", gstType);

    if (bankDetails != null) {
      await prefs.setString("BankDetails", bankDetails);
    }
    if (tandC != null) {
      await prefs.setString("TandC", tandC);
    }

    // ✅ **Mark company data as saved**
    await prefs.setBool("isDataSaved", true); // 🚀 THIS LINE FIXES THE ISSUE
  }




  /// Check if company data is saved
  static Future<bool> isCompanyDataSaved() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isDataSavedKey) ?? false;
  }

  static Future<Map<String, dynamic>> getCompanyDetails() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      "companyName": prefs.getString("companyName") ?? "",
      "companyState": prefs.getString("companyState") ?? "",
      "gstRate": prefs.getString("gstRate") ?? "0.0",
      "gstNumber": prefs.getString("gstNumber") ?? "",
      "companyAddress": prefs.getString("companyAddress") ?? "",
      "companyContact": prefs.getString("companyContact") ?? "",

      // ✅ Fix: Convert stored int (0/1) to bool
      "isGstApplicable": prefs.getInt("isGstApplicable") == 1 ? true : false,

      "defaultCustomerState": prefs.getString("defaultCustomerState") ?? "",
      "gstType": prefs.getString("gstType") ?? "same",
      "BankDetails": prefs.getString("BankDetails") ?? "",
      "TandC": prefs.getString("TandC") ?? "",
    };
  }





  /// Clear saved company data
  static Future<void> clearCompanyData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isDataSavedKey);
    await prefs.remove(_companyNameKey);
    await prefs.remove(_companyStateKey);
    await prefs.remove(_gstRateKey);
    await prefs.remove(_gstNumberKey);
    await prefs.remove(_companyAddressKey);
    await prefs.remove(_companyContactKey);
    await prefs.remove(_isGstApplicableKey);
    await prefs.remove(_defaultCustomerStateKey);
  }
}
