import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:gst_invoice/color.dart';
import 'DATABASE/database_helper.dart';
import 'DATABASE/sharedprefhelper.dart';
import 'gst_invoice.dart';

class OrganizationDetail extends StatefulWidget {
  const OrganizationDetail({super.key});

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
  String? selectedState;
  String? selectedCustomerState;
  // Validation states
  bool isCompanyNameEmpty = false;
  bool isStateEmpty = false;
  bool isGstRateEmpty = false;

  void validateAndSave() async {
    setState(() {
      isCompanyNameEmpty = companyNameController.text.isEmpty;
      isStateEmpty = selectedState == null;
      isGstRateEmpty = isGstApplicable && gstRateController.text.isEmpty;
    });

    if (isCompanyNameEmpty || isStateEmpty || isGstRateEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill in all required fields, including selecting a state.")),
      );
      return;
    }

    DatabaseHelper dbHelper = DatabaseHelper();
    Map<String, dynamic> companyData = {
      "company_name": companyNameController.text,
      "company_gstin": gstNumberController.text,
      "company_address": addressController.text,
      "company_state": selectedState,
      "company_contact": int.tryParse(contactController.text) ?? null,
      "is_tax": isGstApplicable ? 1 : 0,
      "cgst": isGstApplicable ? double.tryParse(gstRateController.text) ?? 0.0 : 0.0,
      "sgst": isGstApplicable ? double.tryParse(gstRateController.text) ?? 0.0 : 0.0,
      "igst": isGstApplicable ? double.tryParse(gstRateController.text) ?? 0.0 : 0.0,
      "default_state": selectedCustomerState
    };

    int id = await dbHelper.insertCompany(companyData);

    if (id > 0) {
      // Save in SharedPreferences
      await SharedPrefHelper.saveCompanyDetails(
        companyName: companyNameController.text,
        companyState: selectedState!,
        gstRate: isGstApplicable ? gstRateController.text : "0.0",
      );

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Company details saved successfully!"))
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GstInvoice(
            companyName: companyNameController.text,
            companyState: selectedState!,
            gstRate: isGstApplicable ? gstRateController.text : "0.0",
          ),
        ),
      );
    }
  }

  final List<String> states = [
    "Andhra Pradesh", "Arunachal Pradesh", "Assam", "Bihar", "Chhattisgarh",
    "Goa", "Gujarat", "Haryana", "Himachal Pradesh", "Jharkhand",
    "Karnataka", "Kerala", "Madhya Pradesh", "Maharashtra", "Manipur",
    "Meghalaya", "Mizoram", "Nagaland", "Odisha", "Punjab",
    "Rajasthan", "Sikkim", "Tamil Nadu", "Telangana", "Tripura",
    "Uttar Pradesh", "Uttarakhand", "West Bengal"
  ];

  Widget buildDropdownField(String label, String hint, String? value, void Function(String?) onChanged, bool showError) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w600)),
        SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: showError ? Colors.red : Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 5,
                spreadRadius: 2,
              ),
            ],
          ),
          child: DropdownSearch<String>(
            items: states,
            selectedItem: value,
            onChanged: onChanged,
            dropdownDecoratorProps: DropDownDecoratorProps(
              baseStyle: TextStyle(color: Colors.black),
              textAlignVertical: TextAlignVertical.center,
              dropdownSearchDecoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                hintStyle: TextStyle(color: Colors.grey.shade400),
              ),
            ),
            popupProps: PopupProps.menu(
              showSearchBox: true,
              searchFieldProps: TextFieldProps(
                decoration: InputDecoration(
                  hintText: "Search State...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        ),
        if (showError)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text("*State is required", style: TextStyle(color: Colors.red, fontSize: 12)),
          ),
        SizedBox(height: 10),
      ],
    );
  }

  Widget buildTextField(String label, String hint, {TextEditingController? controller, TextInputType? keyboardType, bool isRequired = false, bool showError = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
            children: [
              TextSpan(text: label),
              if (isRequired)
                TextSpan(text: " *required", style: TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ),
        ),
        SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: showError ? Colors.red : Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 5,
                spreadRadius: 2,
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: InputBorder.none,
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400),
            ),
          ),
        ),
        if (showError)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text("*required", style: TextStyle(color: Colors.red, fontSize: 12)),
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
        title: Text("Organization Detail", style: TextStyle(color: Colors.white)),
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
              buildTextField("Company Name", "Enter Your Company Name", controller: companyNameController,  showError: isCompanyNameEmpty),
              buildTextField("Address", "Enter Your Address", controller: addressController),

              buildDropdownField("State", "Select State", selectedState, (value) {
                setState(() {
                  selectedState = value;
                });
              }, isStateEmpty),


              buildTextField("Contact No", "Enter Contact Number", controller: contactController, keyboardType: TextInputType.phone),

              SizedBox(height: 20),
              Text("GST", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              SwitchListTile(
                title: Text("GST Applicable", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                value: isGstApplicable,
                onChanged: (value) {
                  setState(() {
                    isGstApplicable = value;
                  });
                },
              ),

              if (isGstApplicable) ...[
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile(
                        title: Text("Same For All Product", style: TextStyle(fontSize: 12)),
                        value: "same",
                        groupValue: gstType,
                        onChanged: (value) {
                          setState(() {
                            gstType = value.toString();
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile(
                        title: Text("Product wise GST", style: TextStyle(fontSize: 12)),
                        value: "product",
                        groupValue: gstType,
                        onChanged: (value) {
                          setState(() {
                            gstType = value.toString();
                          });
                        },
                      ),
                    ),
                  ],
                ),
                if (gstType == "same") ...[
                  buildTextField("GST Rate(%)", "GST(%)", controller: gstRateController, keyboardType: TextInputType.number,showError: isGstRateEmpty),
                ],
                buildTextField("GSTIN", "Enter Your GST Number", controller: gstNumberController),
              ],

              buildDropdownField("Default Customer State", "Select State", selectedCustomerState, (value) {
                setState(() {
                  selectedCustomerState = value;
                });
              },false),
            ],
          ),
        ),
      ),
    );
  }
}
