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

  /// Save company details
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
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isDataSavedKey, true);
    await prefs.setString(_companyNameKey, companyName);
    await prefs.setString(_companyStateKey, companyState);
    await prefs.setString(_gstRateKey, gstRate);
    await prefs.setString(_gstNumberKey, gstNumber);
    await prefs.setString(_companyAddressKey, companyAddress);
    await prefs.setString(_companyContactKey, companyContact);
    await prefs.setInt(_isGstApplicableKey, isGstApplicable ? 1 : 0);
    await prefs.setString(_defaultCustomerStateKey, defaultCustomerState);
    await prefs.setString(_gstTypeKey, gstType);
  }

  /// Check if company data is saved
  static Future<bool> isCompanyDataSaved() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isDataSavedKey) ?? false;
  }

  /// Retrieve company details
  static Future<Map<String, dynamic>> getCompanyDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return {
      "companyName": prefs.getString(_companyNameKey) ?? "",
      "companyState": prefs.getString(_companyStateKey) ?? "",
      "gstRate": prefs.getString(_gstRateKey) ?? "0.0",
      "gstNumber": prefs.getString(_gstNumberKey) ?? "",
      "companyAddress": prefs.getString(_companyAddressKey) ?? "",
      "companyContact": prefs.getString(_companyContactKey) ?? "",
      "isGstApplicable": (prefs.getInt(_isGstApplicableKey) ?? 0) == 1,
      "defaultCustomerState": prefs.getString(_defaultCustomerStateKey) ?? "",
      "gstType": prefs.getString(_gstTypeKey) ?? "same", // ✅ Retrieve gstType
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
