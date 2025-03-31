// SharedPrefHelper.dart (Corrected)
import 'package:shared_preferences/shared_preferences.dart';

enum PrefKey {
  pin,
  password,
}

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

    await prefs.setInt("isGstApplicable", isGstApplicable ? 1 : 0);

    await prefs.setString("defaultCustomerState", defaultCustomerState);
    await prefs.setString("gstType", gstType);

    if (bankDetails != null) {
      await prefs.setString("BankDetails", bankDetails);
    }
    if (tandC != null) {
      await prefs.setString("TandC", tandC);
    }

    await prefs.setBool("isDataSaved", true);
  }

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
      "isGstApplicable": prefs.getInt("isGstApplicable") == 1 ? true : false,
      "defaultCustomerState": prefs.getString("defaultCustomerState") ?? "",
      "gstType": prefs.getString("gstType") ?? "same",
      "BankDetails": prefs.getString("BankDetails") ?? "",
      "TandC": prefs.getString("TandC") ?? "",
    };
  }

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

  static Future<void> deleteSpecific({required PrefKey prefKey}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefKey.name);
  }

  static Future<void> save({required String value, required PrefKey prefKey}) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(prefKey.name, value);
    print("✅ Saved ${prefKey.name}: $value");
  }

  static Future<String?> get({required PrefKey prefKey}) async {
    final prefs = await SharedPreferences.getInstance();
    String? value = prefs.getString(prefKey.name);
    print("🛠 Retrieved ${prefKey.name}: $value");
    print("All SharedPreferences Data: ${prefs.getKeys().map((key) => '$key: ${prefs.get(key)}').join(', ')}");
    return value;
  }

  static Future<void> savePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefKey.pin.name, pin);
    print("✅ Saved PIN: $pin");
  }

  static Future<String?> getPin() async {
    final prefs = await SharedPreferences.getInstance();
    String? pin = prefs.getString(PrefKey.pin.name);
    print("🛠 Retrieved PIN: $pin");
    return pin;
  }
}