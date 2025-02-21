import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefHelper {
  static const String _isDataSavedKey = "isDataSaved";
  static const String _companyNameKey = "companyName";
  static const String _companyStateKey = "companyState";
  static const String _gstRateKey = "gstRate";

  // Save company details
  static Future<void> saveCompanyDetails(
      {required String companyName, required String companyState, required String gstRate}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isDataSavedKey, true);
    await prefs.setString(_companyNameKey, companyName);
    await prefs.setString(_companyStateKey, companyState);
    await prefs.setString(_gstRateKey, gstRate);
  }

  // Check if data is saved
  static Future<bool> isCompanyDataSaved() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isDataSavedKey) ?? false;
  }

  // Retrieve company details
  static Future<Map<String, String>> getCompanyDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return {
      "companyName": prefs.getString(_companyNameKey) ?? "",
      "companyState": prefs.getString(_companyStateKey) ?? "",
      "gstRate": prefs.getString(_gstRateKey) ?? "0.0",
    };
  }

  // Clear saved data (if needed)
  static Future<void> clearCompanyData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isDataSavedKey);
    await prefs.remove(_companyNameKey);
    await prefs.remove(_companyStateKey);
    await prefs.remove(_gstRateKey);
  }
}
