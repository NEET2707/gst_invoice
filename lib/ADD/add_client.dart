import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:gst_invoice/color.dart';

import '../DATABASE/database_helper.dart';
import '../DATABASE/sharedprefhelper.dart';

class AddClient extends StatefulWidget {
  final Map<String, dynamic>? clientData;

  const AddClient({super.key, this.clientData});
  @override
  State<AddClient> createState() => _AddClientState();
}

class _AddClientState extends State<AddClient> {
  late TextEditingController companyNameController = TextEditingController();
  late TextEditingController gstinController = TextEditingController();
  late TextEditingController contactController = TextEditingController();
  late TextEditingController addressController = TextEditingController();
  String? selectedState;
  bool isStateEmpty = false;
  bool isCompanyNameEmpty = false;
  bool isGstinEmpty = false;

  bool isGstinValid(String gstin) {
    final pattern = r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$';
    return RegExp(pattern).hasMatch(gstin);
  }


  @override
  void initState() {
    super.initState();
    companyNameController.text = widget.clientData?['client_company']?.toString() ?? "";
    gstinController.text = widget.clientData?['client_gstin']?.toString() ?? "";
    contactController.text = widget.clientData?['client_contact']?.toString() ?? "";
    addressController.text = widget.clientData?['client_address']?.toString() ?? "";

    // Set state from clientData or fallback to defaultCustomerState
    selectedState = widget.clientData?['client_state']?.toString();

    if (selectedState == null || selectedState!.isEmpty) {
      _loadDefaultCustomerState();
    }
  }

  void _loadDefaultCustomerState() async {
    final companyDetails = await SharedPrefHelper.getCompanyDetails();
    final defaultCustomerState = companyDetails["defaultCustomerState"];

    if (mounted && states.contains(defaultCustomerState)) {
      setState(() {
        selectedState = defaultCustomerState;
      });
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
          child: DropdownButtonFormField<String>(
            value: states.contains(value) ? value : null, // Ensure the selected value exists
            items: states.map((String state) {
              return DropdownMenuItem<String>(
                value: state,
                child: Text(state),
              );
            }).toList(),
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              hintStyle: TextStyle(color: Colors.grey.shade400),
            ),
          )


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

  Future<void> saveClientData() async {
    setState(() {
      isCompanyNameEmpty = companyNameController.text.trim().isEmpty;
      isGstinEmpty = gstinController.text.trim().isEmpty || !isGstinValid(gstinController.text.trim());
      isStateEmpty = selectedState == null || selectedState!.isEmpty;
    });

    if (isCompanyNameEmpty || isGstinEmpty || isStateEmpty) {
      return;
    }

    try {
      Map<String, dynamic> clientData = {
        'client_company': companyNameController.text.trim(),
        'client_gstin': gstinController.text.trim(),
        'client_contact': int.tryParse(contactController.text) ?? 0,
        'client_address': addressController.text.trim(),
        'client_state': selectedState,
      };

      final db = await DatabaseHelper.getDatabase();

      if (widget.clientData == null) {
        int id = await db.insert('client', clientData);
        if (id > 0) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Client saved successfully!")));
        }
      } else {
        await db.update(
          'client',
          clientData,
          where: 'client_id = ?',
          whereArgs: [widget.clientData!['client_id']],
        );
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Client updated successfully!")));
      }

      Navigator.pop(context, true);
    } catch (e) {
      print("Error saving client: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("An error occurred while saving client.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: themecolor,
        title: Text("ADD Client"),
        actions: [
          IconButton(
            icon: Icon(Icons.check),
            onPressed: saveClientData,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildTextField("Client / Company Name", "Enter Name", controller: companyNameController, showError: isCompanyNameEmpty),
              buildTextField(
                "GSTIN",
                "Enter GST Number",
                controller: gstinController,
                showError: isGstinEmpty,
                errorMessage: gstinController.text.trim().isEmpty
                    ? "*This field is required"
                    : "*Enter valid GSTIN (15 characters)",
              ),
              buildTextField("Contact", "Enter Contact Number", controller: contactController, keyboardType: TextInputType.phone),
              buildTextField("Address", "Enter Address", controller: addressController),
              buildDropdownField("State", "Select State", selectedState, (value) {
                setState(() {
                  selectedState = value;
                  isStateEmpty = false;
                });
              }, isStateEmpty),
            ],
          ),
        ),
      ),
    );
  }
}

Widget buildTextField(
    String label,
    String hint, {
      TextEditingController? controller,
      TextInputType? keyboardType,
      bool showError = false,
      String? errorMessage,
    }) {
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
        child: TextField(
          textCapitalization: TextCapitalization.sentences,
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
          child: Text(errorMessage ?? "*This field is required", style: TextStyle(color: Colors.red, fontSize: 12)),
        ),
      SizedBox(height: 10),
    ],
  );
}
