import 'dart:io';
import 'package:flutter/services.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:gst_invoice/color.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'DATABASE/database_helper.dart';
import 'DATABASE/sharedprefhelper.dart';
import 'gst_invoice.dart';
import 'dart:typed_data';
import 'dart:convert';

class OrganizationDetail extends StatefulWidget {
  final bool? temp;
  const OrganizationDetail({super.key, this.temp});

  @override
  State<OrganizationDetail> createState() => _OrganizationDetailState();
}

class _OrganizationDetailState extends State<OrganizationDetail> {
  bool isGstApplicable = false;
  String gstType = "same";
  TextEditingController gstRateController = TextEditingController();
  TextEditingController companyNameController = TextEditingController();
  TextEditingController gstNumberController = TextEditingController();
  TextEditingController addressController = TextEditingController();
  TextEditingController contactController = TextEditingController();
  TextEditingController bankDetailsController = TextEditingController();
  TextEditingController termsController = TextEditingController();
  String? selectedState;
  String? selectedCustomerState;
  // Validation states
  bool isCompanyNameEmpty = false;
  bool isStateEmpty = false;
  bool isGstRateEmpty = false;
  bool temp = false;
  XFile? _pickedImage;
  bool isGstinEmpty = false;

  bool isGstinValid(String gstin) {
    final pattern =
        r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$';
    return RegExp(pattern).hasMatch(gstin);
  }

  @override
  void initState() {
    super.initState();
    _loadCompanyDetails();
    temp = widget.temp ?? false;
  }

  void _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      _removeImage(deleteFromDatabase: false); // Call without await

      Uint8List imageBytes = await image.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      await DatabaseHelper()
          .saveCompanyLogo(base64Image); // Save new image to database

      setState(() {
        _pickedImage = image; // Update UI with new image
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Image saved successfully")),
      );
    }
  }

  void _removeImage({bool deleteFromDatabase = true}) {
    setState(() {
      _pickedImage = null; // Remove selected image from UI
    });

    if (deleteFromDatabase) {
      DatabaseHelper()
          .saveCompanyLogo(""); // Remove image from database (no await)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Image removed successfully")),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadCompanyDetails();
  }

  void _loadCompanyDetails() async {
    final dbHelper = DatabaseHelper();
    Map<String, dynamic> companyDetails =
    await SharedPrefHelper.getCompanyDetails();
    String? savedLogoBase64 = await dbHelper.getCompanyLogo();

    String? savedFilePath;

    if (savedLogoBase64 != null && savedLogoBase64.isNotEmpty) {
      Uint8List imageBytes = base64Decode(savedLogoBase64);
      savedFilePath = await _saveToFile(imageBytes);
    }

    // ✅ Fetch BankDetails & TandC from Database
    final db = await DatabaseHelper.getDatabase();
    final List<Map<String, dynamic>> companyData =
    await db.query("company", limit: 1);

    setState(() {
      companyNameController.text = companyDetails["companyName"] ?? "";
      gstRateController.text = companyDetails["gstRate"] ?? "0.0";
      gstNumberController.text = companyDetails["gstNumber"] ?? "";
      addressController.text = companyDetails["companyAddress"] ?? "";
      contactController.text = companyDetails["companyContact"] ?? "";

      // ✅ Load BankDetails & TandC from Database & Shared Preferences
      bankDetailsController.text = companyDetails["BankDetails"] ??
          companyData.firstOrNull?["BankDetails"] ??
          "";
      termsController.text =
          companyDetails["TandC"] ?? companyData.firstOrNull?["TandC"] ?? "";

      selectedState = states.contains(companyDetails["companyState"])
          ? companyDetails["companyState"]
          : null;
      selectedCustomerState =
      states.contains(companyDetails["defaultCustomerState"])
          ? companyDetails["defaultCustomerState"]
          : null;

      var gstValue = companyDetails["isGstApplicable"];
      isGstApplicable = gstValue is bool
          ? gstValue
          : gstValue.toString().toLowerCase() == "true";
      gstType = companyDetails["gstType"] ?? "same";

      if (savedFilePath != null) {
        _pickedImage = XFile(savedFilePath);
      }
    });

    print("BankDetails: ${bankDetailsController.text}"); // Debugging
    print("TandC: ${termsController.text}"); // Debugging
  }

  Future<String> _saveToFile(Uint8List bytes) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/company_logo.png');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  void validateAndSave() async {
    setState(() {
      isCompanyNameEmpty = companyNameController.text.isEmpty;
      isStateEmpty = selectedState == null;
      isGstinEmpty = isGstApplicable &&
          (gstNumberController.text.trim().isEmpty ||
              !isGstinValid(gstNumberController.text.trim()));
      isGstRateEmpty = isGstApplicable && gstRateController.text.isEmpty;
    });

    if (isCompanyNameEmpty || isStateEmpty || isGstRateEmpty || isGstinEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                "Please fill in all required fields and enter a valid GSTIN.")),
      );
      return; // Prevent saving if validation fails
    }

    DatabaseHelper dbHelper = DatabaseHelper();

    Map<String, dynamic> companyData = {
      "company_name": companyNameController.text,
      "company_gstin": gstNumberController.text,
      "company_address": addressController.text,
      "company_state": selectedState,
      "company_contact": int.tryParse(contactController.text) ?? null,
      "is_tax": isGstApplicable ? 1 : 0,
      "cgst": isGstApplicable
          ? double.tryParse(gstRateController.text) ?? 0.0
          : 0.0,
      "sgst": isGstApplicable
          ? double.tryParse(gstRateController.text) ?? 0.0
          : 0.0,
      "igst": isGstApplicable
          ? double.tryParse(gstRateController.text) ?? 0.0
          : 0.0,
      "default_state": selectedCustomerState,
      "BankDetails": bankDetailsController.text.isNotEmpty
          ? bankDetailsController.text
          : null,
      "TandC": termsController.text.isNotEmpty ? termsController.text : null
    };

    int? existingCompanyId = await dbHelper.getCompanyId();
    if (existingCompanyId != null) {
      await dbHelper.updateCompany(existingCompanyId, companyData);
    } else {
      await dbHelper.insertCompany(companyData);
    }

    // ✅ Save in Shared Preferences
    await SharedPrefHelper.saveCompanyDetails(
      companyName: companyNameController.text,
      companyState: selectedState!,
      gstRate: isGstApplicable ? gstRateController.text : "0.0",
      gstNumber: gstNumberController.text,
      companyAddress: addressController.text,
      companyContact: contactController.text,
      isGstApplicable: isGstApplicable,
      defaultCustomerState: selectedCustomerState ?? "",
      gstType: gstType,
      bankDetails: bankDetailsController.text,
      tandC: termsController.text,
    );

    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Company details updated successfully!")));

    if (temp) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => GstInvoice()));
    }
  }

  final List<String> states = [
    "Andhra Pradesh",
    "Arunachal Pradesh",
    "Assam",
    "Bihar",
    "Chhattisgarh",
    "Goa",
    "Gujarat",
    "Haryana",
    "Himachal Pradesh",
    "Jharkhand",
    "Karnataka",
    "Kerala",
    "Madhya Pradesh",
    "Maharashtra",
    "Manipur",
    "Meghalaya",
    "Mizoram",
    "Nagaland",
    "Odisha",
    "Punjab",
    "Rajasthan",
    "Sikkim",
    "Tamil Nadu",
    "Telangana",
    "Tripura",
    "Uttar Pradesh",
    "Uttarakhand",
    "West Bengal"
  ];

  Widget buildDropdownField(String label, String hint, String? value,
      void Function(String?) onChanged, bool showError, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onBackground, // Dynamic text color
          ),
        ),
        SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface, // Adaptive background
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: showError ? Colors.red : Theme.of(context).colorScheme.outline,
            ),
          ),
          child: DropdownButtonFormField<String>(
            value: value != null && states.contains(value) ? value : null,
            items: states.map((String state) {
              return DropdownMenuItem<String>(
                value: state,
                child: Text(
                  state,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface, // Text color
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
            dropdownColor: Theme.of(context).colorScheme.surface, // Dropdown menu background
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), // Hint text color
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        if (showError)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              "*State is required",
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        SizedBox(height: 10),
      ],
    );
  }


  Widget buildTextField(
      String label,
      String hint, {
        TextEditingController? controller,
        TextInputType? keyboardType,
        bool isRequired = false,
        bool showError = false,
        bool istype = false,
        int? maxLines,
        String? errorMessage,
        List<TextInputFormatter>? inputFormatters,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
                fontWeight: FontWeight.w600
            ),
            children: [
              TextSpan(text: label),
              if (isRequired)
                TextSpan(
                  text: " *required",
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
            ],
          ),
        ),
        SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface, // Adjust for theme
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: showError ? Colors.red : Theme.of(context).colorScheme.outline,
            ),
          ),
          child: TextField(
            textCapitalization: TextCapitalization.sentences,
            controller: controller,
            enabled: !istype,
            readOnly: istype,
            keyboardType: keyboardType ?? TextInputType.text,
            maxLines: maxLines ?? 1,
            style: TextStyle(color: Theme.of(context).colorScheme.onBackground), // Set text color
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: InputBorder.none,
              hintText: hint,
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)), // Adjust for dark mode
            ),
          ),
        ),
        if (showError)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              "*required",
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        SizedBox(height: 10),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: themecolor,
        title:
        Text("Organization Detail", style: TextStyle(color: Colors.white)),
        actions: [
          GestureDetector(
            onTap: () {
              validateAndSave();
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(Icons.check, color: Colors.white),
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildTextField("Company Name", "Enter Your Company Name",
                  controller: companyNameController,
                  showError: isCompanyNameEmpty),
              buildTextField("Address", "Enter Your Address",
                  controller: addressController),
              buildDropdownField("State", "Select State", selectedState,
                      (value) {
                    setState(() {
                      selectedState = value;
                    });
                  }, isStateEmpty,context),
              buildTextField("Contact No", "Enter Contact Number",
                  controller: contactController,
                  keyboardType: TextInputType.phone),
              SizedBox(height: 20),
              Text("GST",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              SwitchListTile(
                title: Text("GST Applicable",
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                value: isGstApplicable,
                onChanged: (value) async {
                  setState(() {
                    isGstApplicable = value;
                    if (isGstApplicable) {
                      gstType = "same";
                      gstRateController.text = "18";
                    } else {
                      gstType = "";
                      gstRateController.clear();
                    }
                  });

                  await SharedPrefHelper.saveCompanyDetails(
                    companyName: companyNameController.text,
                    companyState: selectedState ?? "",
                    gstRate: gstRateController.text,
                    gstNumber: gstNumberController.text,
                    companyAddress: addressController.text,
                    companyContact: contactController.text,
                    isGstApplicable: isGstApplicable,
                    defaultCustomerState: selectedCustomerState ?? "",
                    gstType: gstType,
                  );
                },
              ),
              if (isGstApplicable) ...[
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile(
                        title: Text("Same For All Product",
                            style: TextStyle(fontSize: 12)),
                        value: "same",
                        groupValue: gstType,
                        onChanged: (value) async {
                          setState(() {
                            gstType = value.toString();
                            gstRateController.text = "18";
                          });
                          await SharedPrefHelper.saveCompanyDetails(
                            companyName: companyNameController.text,
                            companyState: selectedState!,
                            gstRate: gstRateController.text,
                            gstNumber: gstNumberController.text,
                            companyAddress: addressController.text,
                            companyContact: contactController.text,
                            isGstApplicable: isGstApplicable,
                            defaultCustomerState: selectedCustomerState ?? "",
                            gstType: gstType,
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile(
                        title: Text("Product wise GST",
                            style: TextStyle(fontSize: 12)),
                        value: "product",
                        groupValue: gstType,
                        onChanged: (value) async {
                          setState(() {
                            gstType = value.toString();
                          });
                          await SharedPrefHelper.saveCompanyDetails(
                            companyName: companyNameController.text,
                            companyState: selectedState!,
                            gstRate: gstRateController.text,
                            gstNumber: gstNumberController.text,
                            companyAddress: addressController.text,
                            companyContact: contactController.text,
                            isGstApplicable: isGstApplicable,
                            defaultCustomerState: selectedCustomerState ?? "",
                            gstType: gstType,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                if (gstType == "same") ...[
                  buildTextField(
                    "GST Rate(%)",
                    "GST(%)",
                    controller: gstRateController,
                    keyboardType: TextInputType.number,
                    showError: isGstRateEmpty,
                    istype: false, // 👈 This makes the field read-only
                  ),
                ],
                buildTextField(
                  "GSTIN",
                  "Enter GST Number (27AAAPA1234A1Z5)",
                  controller: gstNumberController,
                  keyboardType: TextInputType.text,
                  showError: isGstinEmpty,
                  errorMessage: gstNumberController.text.trim().isEmpty
                      ? "*This field is required"
                      : "*Enter valid GSTIN (15 characters)",
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Z]')),
                    LengthLimitingTextInputFormatter(15),
                  ],
                ),
              ],
              buildDropdownField("Default Customer State", "Select State",
                  selectedCustomerState, (value) {
                    setState(() {
                      selectedCustomerState = value;
                    });
                  }, false,context),
              if (temp) ...[
                SizedBox(height: 20),
                Text("Upload Image",
                    style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                SizedBox(height: 10),
                GestureDetector(
                  onTap: _pickImage, // Open image picker
                  child: Container(
                    width: double.infinity,
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.grey.shade200,
                    ),
                    child: _pickedImage == null
                        ? Center(
                        child: Text("Tap to select image",
                            style: TextStyle(color: Colors.grey.shade600)))
                        : Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Positioned.fill(
                          child: Image.file(File(_pickedImage!.path),
                              fit: BoxFit.contain),
                        ),
                        IconButton(
                          icon: Icon(Icons.cancel, color: Colors.red),
                          onPressed:
                          _removeImage, // Remove selected image
                        ),
                      ],
                    ),
                  ),
                ),
                if (_pickedImage != null)
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            child: InteractiveViewer(
                                child: Image.file(File(_pickedImage!.path))),
                          ),
                        );
                      },
                      child: Text("View Image"),
                    ),
                  ),
                SizedBox(
                  height: 10,
                ),
                buildTextField("Bank Details (Appear In Invoice Pdf)",
                    "Bank Name\nAccount Number\nBank IFSC Code",
                    controller: bankDetailsController,
                    maxLines: 4,
                    keyboardType: TextInputType.multiline),
                SizedBox(
                  height: 10,
                ),
                buildTextField("Terms & Conditions (Appear In Invoice Pdf)",
                    "Enter Terms & Conditions",
                    controller: termsController,
                    maxLines: 4,
                    keyboardType: TextInputType.multiline),
              ],
            ],
          ),
        ),
      ),
    );
  }
}