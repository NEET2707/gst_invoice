import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gst_invoice/ADD/select_client.dart';
import 'package:gst_invoice/ADD/select_product.dart';
import 'package:gst_invoice/DATABASE/database_helper.dart';
import 'package:gst_invoice/gst_invoice.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Invoice extends StatefulWidget {
  final int? invoiceId; // Add invoiceId parameter

  const Invoice({Key? key, this.invoiceId}) : super(key: key);

  @override
  State<Invoice> createState() => _InvoiceState();
}


class _InvoiceState extends State<Invoice> {
  TextEditingController invoiceDateController = TextEditingController();
  TextEditingController dueDateController = TextEditingController();
  TextEditingController qtyController = TextEditingController();
  TextEditingController discountController = TextEditingController();


  Map<String, dynamic>? selectedClient;
  List<Map<String, dynamic>> selectedProducts = [];
  String companyName = "company_state";
  String companyState = "company_state";
  double discountPercentage = 0;


  @override
  void initState() {
    super.initState();
    String formattedDate = DateFormat("dd MMM yyyy").format(DateTime.now());
    invoiceDateController.text = formattedDate;
    dueDateController.text = formattedDate;

    _loadCompanyDetails();

    if (widget.invoiceId != null) {
      _loadInvoiceDetails(widget.invoiceId!); // Load previous data
    }
  }

  Future<void> _loadInvoiceDetails(int invoiceId) async {
    final db = await DatabaseHelper.getDatabase();

    // Get invoice details
    final List<Map<String, dynamic>> invoiceData = await db.query(
      'invoice',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );

    if (invoiceData.isNotEmpty) {
      setState(() {
        final invoice = invoiceData.first;
        invoiceDateController.text = invoice['invoic_date'] ?? "";
        dueDateController.text = invoice['due_date'] ?? "";

        // ✅ Fetch discount from invoice table (NOT invoice_line)
        discountPercentage = (invoice['discount'] ?? 0).toDouble();
        discountController.text = discountPercentage.toString(); // Update UI
      });
    }

    // Get client details
    final List<Map<String, dynamic>> clientData = await db.rawQuery('''
    SELECT c.* FROM client c
    INNER JOIN invoice i ON i.client_id = c.client_id
    WHERE i.invoice_id = ?
  ''', [invoiceId]);

    if (clientData.isNotEmpty) {
      setState(() {
        selectedClient = clientData.first;
      });
    }

    // Get product details
    final List<Map<String, dynamic>> productData = await db.rawQuery('''
    SELECT p.*, il.qty, il.price, il.total
    FROM invoice_line il
    INNER JOIN product p ON il.product_id = p.product_id
    WHERE il.invoice_id = ?
  ''', [invoiceId]);

    setState(() {
      selectedProducts = productData;
    });
  }

  Future<void> saveInvoice() async {
    if (selectedClient == null || selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please add a buyer and at least one product")),
      );
      return;
    }

    final db = await DatabaseHelper.getDatabase();

    double taxableAmount = _getTotalPrice();
    double totalGST = _getTotalGST();
    double totalAmount = _getDiscountedTotal();
    double totalCGST = 0, totalSGST = 0, totalIGST = 0;

    bool isSameState = selectedClient!['client_state'] == companyState;

    if (isSameState) {
      totalCGST = totalGST / 2;
      totalSGST = totalGST / 2;
    } else {
      totalIGST = totalGST;
    }

    int invoiceId;

    if (widget.invoiceId == null) {
      // **Insert New Invoice**
      invoiceId = await db.insert('invoice', {
        'client_id': selectedClient!['client_id'],
        'total_cgst': totalCGST,
        'total_sgst': totalSGST,
        'total_igst': totalIGST,
        'taxable_amount': taxableAmount,
        'total_tax': totalGST,
        'total_amount': totalAmount,
        'invoic_date': invoiceDateController.text,
        'due_date': dueDateController.text,
        'date_added': DateFormat("yyyy-MM-dd").format(DateTime.now()),
        'date_modified': DateFormat("yyyy-MM-dd").format(DateTime.now()),
        'is_equal_state': isSameState ? 1 : 0,
        'is_tax': 1,
        'discount': discountPercentage, // ✅ Save discount at the invoice level
      });
    } else {
      // **Update Existing Invoice**
      invoiceId = widget.invoiceId!;
      await db.update(
        'invoice',
        {
          'client_id': selectedClient!['client_id'],
          'total_cgst': totalCGST,
          'total_sgst': totalSGST,
          'total_igst': totalIGST,
          'taxable_amount': taxableAmount,
          'total_tax': totalGST,
          'total_amount': totalAmount,
          'invoic_date': invoiceDateController.text,
          'due_date': dueDateController.text,
          'date_modified': DateFormat("yyyy-MM-dd").format(DateTime.now()),
          'discount': discountPercentage, // ✅ Save discount at the invoice level
        },
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
      );
    }


    // **Save or Update Invoice Line Items**
    for (var product in selectedProducts) {
      int? existingProductId = product['product_id'];

      final List<Map<String, dynamic>> existingInvoiceLines = await db.query(
        'invoice_line',
        where: 'invoice_id = ? AND product_id = ?',
        whereArgs: [invoiceId, existingProductId],
      );

      if (existingInvoiceLines.isNotEmpty) {
        // **Update existing product**
        await db.update(
          'invoice_line',
          {
            'price': product['product_price'],
            'qty': product['qty'],
            'total': product['total'],
            'cgst': isSameState ? totalCGST : 0,
            'sgst': isSameState ? totalSGST : 0,
            'igst': isSameState ? 0 : totalIGST,
            'discount': discountPercentage, // Save discount value
          },
          where: 'invoice_id = ? AND product_id = ?',
          whereArgs: [invoiceId, existingProductId],
        );
      } else {
        // **Insert new product**
        await db.insert('invoice_line', {
          'invoice_id': invoiceId,
          'product_id': product['product_id'],
          'price': product['product_price'],
          'qty': product['qty'],
          'total': product['total'],
          'cgst': isSameState ? totalCGST : 0,
          'sgst': isSameState ? totalSGST : 0,
          'igst': isSameState ? 0 : totalIGST,
          'discount': discountPercentage, // Save discount value
        });
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Invoice saved successfully!")),
    );

    Navigator.pop(context, true); // Return `true` to indicate update success
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
        // Ensure the list is mutable before adding a new product
        selectedProducts = List.from(selectedProducts)..add({...selectedProduct, 'qty': 1});
      });
    }
  }


  double _getTotalPrice() {
    return selectedProducts.fold(0, (sum, product) {
      int qty = product['qty'] ?? 1;
      double price = product['product_price'];
      return sum + (price * qty);
    });
  }

  double _getTotalGST() {
    return selectedProducts.fold(0, (sum, product) {
      int qty = product['qty'] ?? 1;
      double price = product['product_price'];
      double gstRate = product['product_gst'];
      return sum + ((price * qty) * gstRate / 100);
    });
  }

  double _getDiscountedTotal() {
    double total = _getTotalPrice() + _getTotalGST();
    return total - (total * discountPercentage / 100);
  }


  void _applyDiscount(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Apply Discount"),
          content: TextField(
            controller: discountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "Enter Discount (%)",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  discountPercentage = double.tryParse(discountController.text) ?? 0;
                });
                Navigator.pop(context);
              },
              child: Text("Apply"),
            ),
          ],
        );
      },
    );
  }

  void _editProduct(BuildContext context, int index) {
    qtyController.text = selectedProducts[index]['qty'].toString();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Update Quantity"),
          content: TextField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "Enter new qty",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                int updatedQty = int.tryParse(qtyController.text) ?? 1;

                setState(() {
                  // Create a mutable copy of the selected product
                  Map<String, dynamic> updatedProduct = {...selectedProducts[index]};

                  // Update quantity
                  updatedProduct['qty'] = updatedQty;

                  // Recalculate total price
                  double price = updatedProduct['product_price'];
                  double gstRate = updatedProduct['product_gst'];
                  double totalPrice = price * updatedQty;
                  double gstAmount = (totalPrice * gstRate) / 100;

                  // Determine CGST, SGST, IGST
                  bool isSameState = selectedClient!['client_state'] == companyState;
                  updatedProduct['total'] = totalPrice + gstAmount;
                  updatedProduct['cgst'] = isSameState ? gstAmount / 2 : 0;
                  updatedProduct['sgst'] = isSameState ? gstAmount / 2 : 0;
                  updatedProduct['igst'] = isSameState ? 0 : gstAmount;

                  // Update the list in a way Flutter detects the change
                  selectedProducts = List.from(selectedProducts)..[index] = updatedProduct;
                });

                // Update database
                int productId = selectedProducts[index]['product_id'];
                int invoiceId = selectedProducts[index]['invoice_id'] ?? 0;

                final db = await DatabaseHelper.getDatabase();
                final List<Map<String, dynamic>> invoiceLine = await db.query(
                  'invoice_line',
                  where: 'invoice_id = ? AND product_id = ?',
                  whereArgs: [invoiceId, productId],
                );

                if (invoiceLine.isNotEmpty) {
                  int invoiceLineId = invoiceLine.first['invoice_line_id'];
                  await DatabaseHelper.updateInvoiceLine(invoiceLineId, {
                    'qty': updatedQty,
                    'total': selectedProducts[index]['total'],
                    'cgst': selectedProducts[index]['cgst'],
                    'sgst': selectedProducts[index]['sgst'],
                    'igst': selectedProducts[index]['igst'],
                  });

                  print("Invoice line updated successfully!");
                }

                Navigator.pop(context);
              },
              child: Text("Save"),
            ),
          ],
        );
      },
    );
  }


  Widget _buildSummaryRow(String label, String value, {bool isBold = false, bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isHighlighted ? Colors.green : Colors.black,
            ),
          ),
        ],
      ),
    );
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
                onTap: () async {
                  // await _saveInvoice();
                  // await saveInvoiceDetails();
                  await saveInvoice();
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => GstInvoice(),));
                },
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
              isBuyerSection: true,  // Set to true for the Buyer Details section
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
                  // "Clear All Items" Button
                  if (selectedProducts.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedProducts.clear();
                        });
                      },
                      child: const Text(
                        "Clear all Items",
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  const SizedBox(height: 8),


                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: selectedProducts.length,
                    itemBuilder: (context, index) {
                      var product = selectedProducts[index];

                      // Get product details
                      double price = product['product_price'];
                      int qty = product['qty'] ?? 1;
                      double gstRate = product['product_gst'];

                      // Calculate new total price based on quantity
                      double totalPrice = price * qty;
                      double gstAmount = totalPrice * gstRate / 100;

                      // Determine if IGST or CGST & SGST should be applied
                      bool isSameState = selectedClient != null &&
                          selectedClient!['client_state'] == companyState;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        child: ListTile(
                          title: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 110),
                            child: Text(
                              product['product_name'],
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 25),
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Remove Product Button
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        selectedProducts.removeAt(index);
                                      });
                                    },
                                  ),
                                  // Edit Product Button
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () {
                                      _editProduct(context, index);
                                    },
                                  ),
                                  // Quantity & Price
                                  Text(
                                    "$qty X ₹${price.toStringAsFixed(2)}",
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              // GST Details
                              if (isSameState) ...[
                                Text("CGST: ₹${(gstAmount / 2).toStringAsFixed(2)} (${(gstRate / 2).toStringAsFixed(2)}%)"),
                                Text("SGST: ₹${(gstAmount / 2).toStringAsFixed(2)} (${(gstRate / 2).toStringAsFixed(2)}%)"),
                              ] else ...[
                                Text("IGST: ₹${gstAmount.toStringAsFixed(2)} (${gstRate.toStringAsFixed(2)}%)"),
                              ],
                              // Updated Total Price
                              Text(
                                "Total: ₹${(totalPrice + gstAmount).toStringAsFixed(2)}",
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 10),

                  // Add Item Button
                  GestureDetector(
                    onTap: _selectProduct,
                    child: _buildAddButton("Add Item", FontAwesomeIcons.plusCircle, Colors.green),
                  ),

                  const SizedBox(height: 10),

                  // Discount Option (if needed)
                  GestureDetector(
                    onTap: () => _applyDiscount(context),
                    child: const Text("Add a Discount", style: TextStyle(color: Colors.blue)),
                  ),

                  const SizedBox(height: 10),

                  // Total Calculation Section
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryRow("Taxable Amount", "₹${_getTotalPrice().toStringAsFixed(2)}"),
                          if (_getTotalGST() > 0)
                            _buildSummaryRow("Total GST", "₹${_getTotalGST().toStringAsFixed(2)}"),
                          _buildSummaryRow(
                            "Total Amount",
                            "₹${(_getTotalPrice() + _getTotalGST()).toStringAsFixed(2)}",
                            isBold: true,
                            isHighlighted: true,
                          ),
                          _buildSummaryRow(
                            "$discountPercentage% Discount",
                            "- ₹${(_getTotalPrice() + _getTotalGST()) * discountPercentage / 100}",
                            isBold: true,
                            isHighlighted: true,
                          ),
                          _buildSummaryRow(
                            "Total Amount (After Discount)",
                            "₹${_getDiscountedTotal().toStringAsFixed(2)}",
                            isBold: true,
                            isHighlighted: true,
                          ),
                        ],
                      ),
                    ),
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
            _buildDetailRow(FontAwesomeIcons.user, selectedClient!['client_company'].toString()), // ✅ Convert to String

          if (selectedClient!['client_address'] != null)
            _buildDetailRow(FontAwesomeIcons.mapMarkerAlt, selectedClient!['client_address'].toString()), // ✅ Convert to String

          if (selectedClient!['client_gstin'] != null)
            Text("GSTIN: ${selectedClient!['client_gstin']}", style: const TextStyle(fontWeight: FontWeight.bold)),

          if (selectedClient!['client_state'] != null)
            _buildDetailRow(FontAwesomeIcons.map, selectedClient!['client_state'].toString()), // ✅ Convert to String

          if (selectedClient!['client_contact'] != null)
            _buildDetailRow(FontAwesomeIcons.phone, selectedClient!['client_contact'].toString()), // ✅ Convert to String
        ],
      );
    }
  }

  Widget _buildSection({required String title, required Widget child, bool isEditable = false, bool isBuyerSection = false}) {
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
                  if (isBuyerSection) ...[
                    IconButton(
                      icon: Icon(Icons.add_circle_outline, color: Colors.white),
                      //   (
                      //   selectedClient == null ? Icons.add_circle : Icons.edit,
                      //   color: Colors.white,
                      // ),
                      onPressed: () async {
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
                    ),
                  ] else if (isEditable) ...[
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: () {},
                    ),
                  ],
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
