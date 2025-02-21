import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gst_invoice/select_client.dart';
import 'package:gst_invoice/select_product.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Invoice extends StatefulWidget {
  const Invoice({super.key});

  @override
  State<Invoice> createState() => _InvoiceState();
}

class _InvoiceState extends State<Invoice> {
  TextEditingController invoiceDateController = TextEditingController();
  TextEditingController dueDateController = TextEditingController();

  Map<String, dynamic>? selectedClient;
  List<Map<String, dynamic>> selectedProducts = [];
  String companyName = "company_state";
  String companyState = "company_state";

  @override
  void initState() {
    super.initState();
    String formattedDate = DateFormat("dd MMM yyyy").format(DateTime.now());
    invoiceDateController.text = formattedDate;
    dueDateController.text = formattedDate;
    _loadCompanyDetails();
  }

  Future<void> _loadCompanyDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      companyName = prefs.getString('companyName') ?? "Not Available";
      print("companyName");
      companyState = prefs.getString('companyState') ?? "Not Available";
    });
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() {
        controller.text = DateFormat("dd MMM yyyy").format(pickedDate);
      });
    }
  }

  void _selectProduct() async {
    final selectedProduct = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SelectProduct()),
    );

    if (selectedProduct != null) {
      setState(() {
        selectedProducts.add(selectedProduct); // Add product to the list
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text("Invoice"),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: GestureDetector(
                onTap: () {},
                child: const Text(
                  "SAVE",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildSection(
              title: "Buyer Details",
              child: GestureDetector(
                onTap: () async {
                  final client = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SelectClient()),
                  );
                  if (client != null) {
                    setState(() {
                      selectedClient = client;
                    });
                  }
                },
                child: _buildBuyerDetails(),
              ),
            ),

            _buildSection(
              title: "Invoice Details",
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDateField("Invoice Date", invoiceDateController),
                  _buildDateField("Due Date", dueDateController),
                ],
              ),
            ),

            _buildSection(
              title: "Items Details",
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _selectProduct,
                    child: _buildAddButton("Add Item", FontAwesomeIcons.plusCircle, Colors.green),
                  ),
                  const SizedBox(height: 10),

                  // Show selected products in a list
                  Column(
                    children: selectedProducts.isEmpty
                        ? [const Text("No products selected")]
                        : selectedProducts.map((product) {
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        child: ListTile(
                          title: Text(product['product_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("₹${product['product_price']} | GST: ${product['product_gst']}%"),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            _buildSection(
              title: "Company Details",
              isEditable: true,
              child: Column(
                children: [
                  _buildDetailRow(FontAwesomeIcons.user, companyName),
                  SizedBox(height: 10),
                  _buildDetailRow(FontAwesomeIcons.map, companyState),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildBuyerDetails() {
    if (selectedClient == null) {
      return _buildAddButton("Add Buyer", FontAwesomeIcons.userPlus, Colors.green);
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selectedClient!['client_company'] != null)
            _buildDetailRow(FontAwesomeIcons.user, selectedClient!['client_company']),
          if (selectedClient!['client_address'] != null)
            _buildDetailRow(FontAwesomeIcons.mapMarkerAlt, selectedClient!['client_address']),
          if (selectedClient!['client_gstin'] != null)
            Text("GSTIN: ${selectedClient!['client_gstin']}", style: const TextStyle(fontWeight: FontWeight.bold)),
          if (selectedClient!['client_state'] != null)
            _buildDetailRow(FontAwesomeIcons.map, selectedClient!['client_state']),
          if (selectedClient!['client_contact'] != null)
            _buildDetailRow(FontAwesomeIcons.phone, selectedClient!['client_contact']),
        ],
      );
    }
  }

  Widget _buildSection({required String title, required Widget child, bool isEditable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 3,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  if (isEditable)
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: () {},
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(String text, IconData icon, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDateField(String label, TextEditingController controller) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        GestureDetector(
          onTap: () => _selectDate(context, controller),  // Ensure context is available
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(controller.text),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, color: Colors.black),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
