import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gst_invoice/ADD/select_client.dart';
import 'package:gst_invoice/ADD/select_product.dart';
import 'package:gst_invoice/DATABASE/database_helper.dart';
import 'package:gst_invoice/color.dart';
import 'package:gst_invoice/gst_invoice.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../color.dart';
import '../organization_detail.dart';

class Invoice extends StatefulWidget {
  Map<String, dynamic>? selectedClient;
  List<Map<String, dynamic>>? product;
  final int? invoiceId; // Add invoiceId parameter

  Invoice({Key? key, this.invoiceId, this.selectedClient,  this.product}) : super(key: key);

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
  late String todayDate;


  @override
  void initState() {
    super.initState();
    String formattedDate = DateFormat("dd MMM yyyy").format(DateTime.now());
    invoiceDateController.text = formattedDate;
    dueDateController.text = formattedDate;
    todayDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
    selectedClient = widget.selectedClient;
    selectedProducts = widget.product ?? [];

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
      selectedProducts = List.from(productData);    });
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
          'dateadded': todayDate,
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
      MaterialPageRoute(builder: (context) => SelectProduct(boom: true)),
    );

    if (selectedProduct != null) {
      setState(() {
        selectedProducts = List.from(selectedProducts)..add({...selectedProduct, 'qty': 1});
      });
    }
  }


  double _getTotalPrice() {
    return selectedProducts.fold(0, (sum, product) {
      int qty = int.tryParse(product['qty'].toString()) ?? 1;
      double price = product['product_price'];
      return sum + (price * qty);
    });
  }

  double _getTotalGST() {
    return selectedProducts.fold(0, (sum, product) {
      int qty = int.tryParse(product['qty'].toString()) ?? 1;
      double price = product['product_price'];
      double gstRate = product['product_gst'];
      double gstAmount = ((price * qty) * gstRate) / 100;

      bool isSameState = selectedClient != null && selectedClient!['client_state'] == companyState;
      double cgst = isSameState ? gstAmount / 2 : 0;
      double sgst = isSameState ? gstAmount / 2 : 0;
      double igst = isSameState ? 0 : gstAmount;

      return sum + cgst + sgst + igst;
    });
  }


  double _getDiscountedTotal() {
    double total = _getTotalPrice() + _getTotalGST();
    return total - ((_getTotalPrice() * discountPercentage) / 100);
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
          title: const Text("Update Quantity"),
          content: TextField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Enter new qty",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                int updatedQty = int.tryParse(qtyController.text) ?? 1;

                setState(() {
                  selectedProducts[index] = Map<String, dynamic>.from(selectedProducts[index]);
                  selectedProducts[index]['qty'] = updatedQty;
                });

                int productId = selectedProducts[index]['product_id'];
                int invoiceId = widget.invoiceId ?? 0;

                // ✅ Update Database with New Quantity
                final db = await DatabaseHelper.getDatabase();
                await db.update(
                  'invoice_line',
                  {'qty': updatedQty},
                  where: 'invoice_id = ? AND product_id = ?',
                  whereArgs: [invoiceId, productId],
                );

                print("Database Updated: Product $productId, New Qty: $updatedQty");

                // ✅ No need to reload all products, just recalculate totals
                setState(() {});

                Navigator.pop(context); // Close the dialog
              },
              child: const Text("Save"),
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
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: isHighlighted ? Colors.green : Colors.black,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onOrganizationDetailTap() async {
    bool? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => OrganizationDetail(temp: true,)),
    );
    if (result == true) {
      _loadCompanyDetails();  // ✅ Reload data when coming back
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
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildSection(
                  title: "Buyer Details",

                  isBuyerSection: true,  // Set to true for the Buyer Details section
                  child: GestureDetector(
                    onTap: () async {
                        final client = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) =>  SelectClient(back: true,)),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Divider(color: Colors.blue.shade100, thickness: 1,),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Divider(color: Colors.blue.shade100, thickness: 1,),
                ),
                _buildSection(
                  title: "Items Details",
                  child: _buildItemTable(),
                  // Column(
                  //   children: [
                  //     // "Clear All Items" Button
                  //     if (selectedProducts.isNotEmpty)
                  //       GestureDetector(
                  //         onTap: () {
                  //           setState(() {
                  //             selectedProducts.clear();
                  //           });
                  //         },
                  //         child: const Text(
                  //           "Clear all Items",
                  //           style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  //         ),
                  //       ),
                  //     const SizedBox(height: 8),
                  //
                  //
                  //     ListView.builder(
                  //       shrinkWrap: true,
                  //       physics: const NeverScrollableScrollPhysics(),
                  //       itemCount: selectedProducts.length,
                  //       itemBuilder: (context, index) {
                  //         var product = selectedProducts[index];
                  //
                  //         // Get product details
                  //         double price = product['product_price'];
                  //         int qty = product['qty'] ?? 1;
                  //         double gstRate = product['product_gst'];
                  //
                  //         // Calculate new total price based on quantity
                  //         double totalPrice = price * qty;
                  //         double gstAmount = totalPrice * gstRate / 100;
                  //
                  //         // Determine if IGST or CGST & SGST should be applied
                  //         bool isSameState = selectedClient != null &&
                  //             selectedClient!['client_state'] == companyState;
                  //
                  //         return ListTile(
                  //           title: Center(
                  //             child: Text(
                  //               product['product_name'],
                  //               style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 25),
                  //             ),
                  //           ),
                  //           subtitle: Column(
                  //             crossAxisAlignment: CrossAxisAlignment.start,
                  //             children: [
                  //               Row(
                  //                 children: [
                  //                   // Remove Product Button
                  //                   IconButton(
                  //                     icon: const Icon(Icons.remove_circle, color: Colors.red),
                  //                     onPressed: () {
                  //                       setState(() {
                  //                         selectedProducts.removeAt(index);
                  //                       });
                  //                     },
                  //                   ),
                  //                   // Edit Product Button
                  //                   IconButton(
                  //                     icon: const Icon(Icons.edit, color: Colors.blue),
                  //                     onPressed: () {
                  //                       _editProduct(context, index);
                  //                     },
                  //                   ),
                  //                   // Quantity & Price
                  //                   Text(
                  //                     "$qty X ₹${price.toStringAsFixed(2)}",
                  //                     style: const TextStyle(fontWeight: FontWeight.bold),
                  //                   ),
                  //                 ],
                  //               ),
                  //               // GST Details
                  //               if (isSameState) ...[
                  //                 Text("CGST: ₹${(gstAmount / 2).toStringAsFixed(2)} (${(gstRate / 2).toStringAsFixed(2)}%)"),
                  //                 Text("SGST: ₹${(gstAmount / 2).toStringAsFixed(2)} (${(gstRate / 2).toStringAsFixed(2)}%)"),
                  //               ] else ...[
                  //                 Text("IGST: ₹${gstAmount.toStringAsFixed(2)} (${gstRate.toStringAsFixed(2)}%)"),
                  //               ],
                  //               // Updated Total Price
                  //               Text(
                  //                 "Total: ₹${(totalPrice + gstAmount).toStringAsFixed(2)}",
                  //                 style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                  //               ),
                  //             ],
                  //           ),
                  //         );
                  //       },
                  //     ),
                  //
                  //     const SizedBox(height: 10),
                  //
                  //     // Add Item Button
                  //     GestureDetector(
                  //       onTap: _selectProduct,
                  //       child: _buildAddButton("Add Item", FontAwesomeIcons.plusCircle, Colors.green),
                  //     ),
                  //
                  //     const SizedBox(height: 10),
                  //
                  //     // Discount Option (if needed)
                  //     GestureDetector(
                  //       onTap: () => _applyDiscount(context),
                  //       child: const Text("Add a Discount", style: TextStyle(color: Colors.blue)),
                  //     ),
                  //
                  //     const SizedBox(height: 10),
                  //
                  //     // Total Calculation Section
                  //     Padding(
                  //       padding: const EdgeInsets.all(10.0),
                  //       child: Column(
                  //         crossAxisAlignment: CrossAxisAlignment.start,
                  //         children: [
                  //           _buildSummaryRow("Taxable Amount", "₹${_getTotalPrice().toStringAsFixed(2)}"),
                  //           _buildSummaryRow(
                  //             "$discountPercentage% Discount",
                  //             "- ₹${(_getTotalPrice() ) * discountPercentage / 100}",
                  //             isBold: true,
                  //             isHighlighted: true,
                  //           ),
                  //           if (_getTotalGST() > 0)
                  //             _buildSummaryRow("Total GST", "₹${_getTotalGST().toStringAsFixed(2)}"),
                  //           _buildSummaryRow(
                  //             "Total Amount",
                  //             // "- ₹${((_getTotalPrice() ) * discountPercentage / 100) + _getTotalGST()}",
                  //             "₹${(_getTotalPrice() + _getTotalGST()).toStringAsFixed(2)}",
                  //             isBold: true,
                  //             isHighlighted: true,
                  //           ),
                  //
                  //           _buildSummaryRow(
                  //             "Total Amount (After Discount)",
                  //             "₹${_getDiscountedTotal().toStringAsFixed(2)}",
                  //             isBold: true,
                  //             isHighlighted: true,
                  //           ),
                  //         ],
                  //       ),
                  //     ),
                  //   ],
                  // ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Divider(color: Colors.blue.shade100, thickness: 1,),
                ),
                _buildSection(
                  title: "Company Details",
                  isEditable: true,
                  child: Column(
                    children: [
                      _buildDetailRow(FontAwesomeIcons.user, companyName),
                      SizedBox(height: 5),
                      _buildDetailRow(FontAwesomeIcons.map, companyState),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildBuyerDetails() {
    if (selectedClient == null) {
      return _buildAddButton("Add Buyer", FontAwesomeIcons.userPlus, Colors.green);
    } else {
      return ListTile(
        leading: CircleAvatar(
          backgroundColor: themecolor, // Ensure `themecolor` is defined
          child: Text(
            selectedClient!['client_company'][0].toUpperCase(), // First letter
            style: TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          selectedClient!['client_company'].toString(),
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 18),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // if (selectedClient!['client_address'] != null)
            //   Text("Address: ${selectedClient!['client_address']}"),
            // if (selectedClient!['client_gstin'] != null)
            //   Text("GSTIN: ${selectedClient!['client_gstin']}"),
            if (selectedClient!['client_state'] != null)
              Text("${selectedClient!['client_state']}"),
            if (selectedClient!['client_contact'] != null)
              Text("${selectedClient!['client_contact']}"),
          ],
        ),
        // trailing: PopupMenuButton<String>(
        //   icon: const Icon(Icons.more_vert, color: Colors.black54),
        //   onSelected: (value) async {
        //     if (value == 'edit') {
        //       bool? result = await Navigator.push(
        //         context,
        //         MaterialPageRoute(
        //           builder: (context) => AddClient(clientData: selectedClient),
        //         ),
        //       );
        //
        //       if (result == true) {
        //         setState(() {}); // Refresh UI after editing
        //       }
        //     } else if (value == 'delete') {
        //       showDialog(
        //         context: context,
        //         builder: (context) => AlertDialog(
        //           title: const Text("Delete Client"),
        //           content: const Text("Are you sure you want to delete this client?"),
        //           actions: [
        //             TextButton(
        //               onPressed: () => Navigator.pop(context),
        //               child: const Text("Cancel"),
        //             ),
        //             TextButton(
        //               onPressed: () {
        //                 deleteClient(selectedClient!['id']);
        //                 Navigator.pop(context);
        //                 setState(() {}); // Refresh UI after deletion
        //               },
        //               child: const Text("Delete", style: TextStyle(color: Colors.red)),
        //             ),
        //           ],
        //         ),
        //       );
        //     }
        //   },
        //   itemBuilder: (context) => [
        //     PopupMenuItem(
        //       value: 'edit',
        //       child: Row(
        //         children: [
        //           Icon(Icons.edit, color: Colors.blue),
        //           SizedBox(width: 8),
        //           Text("Edit"),
        //         ],
        //       ),
        //     ),
        //     PopupMenuItem(
        //       value: 'delete',
        //       child: Row(
        //         children: [
        //           Icon(Icons.delete, color: Colors.red),
        //           SizedBox(width: 8),
        //           Text("Delete"),
        //         ],
        //       ),
        //     ),
        //   ],
        // ),
      );
    }
  }

  Widget _buildSection({required String title, required Widget child, bool isEditable = false, bool isBuyerSection = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(5),
                topRight: Radius.circular(5),

              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(color: themecolor, fontWeight: FontWeight.w600,fontSize: 20)),
                if (isBuyerSection) ...[
                  IconButton(
                    icon: Icon(Icons.add_circle, color: themecolor,size: 28,),
                    //   (
                    //   selectedClient == null ? Icons.add_circle : Icons.edit,
                    //   color: Colors.white,
                    // ),
                    onPressed: () async {
                      final client = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) =>  SelectClient(back: true,)),
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
                    icon: Icon(Icons.edit, color:themecolor),
                    onPressed: _onOrganizationDetailTap,
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(5),
            child: child,
          ),
        ],
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

  Widget _buildItemTable() {
    return Column(
      children: [
        if (selectedProducts.isNotEmpty)
          // Align(
          //   alignment: Alignment.centerRight,
          //   child: TextButton(
          //     onPressed: () {
          //       setState(() {
          //         selectedProducts.clear();
          //         discountPercentage = 0; // Reset discount
          //       });
          //     },
          //     child: const Text(
          //       "Clear all Items",
          //       style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          //     ),
          //   ),
          // ),
          SizedBox(
            width: MediaQuery.of(context).size.width, // Full width
            child: DataTable(
              columnSpacing: 5, // Reduce spacing to prevent overflow
              horizontalMargin: 5,
              headingRowColor: MaterialStateColor.resolveWith(
                    (states) => Colors.blue.withOpacity(0.1),
              ),
              columns: [
                DataColumn(
                  label: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.4, // 40% width
                    child: Text("Product", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                DataColumn(
                  label: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.2, // 20% width
                    child: Text("GST", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                DataColumn(
                  label: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.2, // Consistent width for "Total"
                    child: Text("Total", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
              rows: selectedProducts.asMap().entries.map((entry) {
                int index = entry.key;
                var product = entry.value;
                double price = product['product_price'];
                int qty = int.tryParse(product['qty'].toString()) ?? 1;
                double gstRate = product['product_gst'];
                double totalPrice = price * qty;
                double gstAmount = totalPrice * gstRate / 100;
                bool isSameState = selectedClient != null &&
                    selectedClient!['client_state'] == companyState;

                return DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.4, // 40% width
                        child: Text(
                          "${product['product_name']}\n$qty x ₹${price.toStringAsFixed(2)}",
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.2, // 20% width
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: isSameState
                                    ? "₹${(gstAmount / 2).toStringAsFixed(2)}"
                                    : "₹${gstAmount.toStringAsFixed(2)}\n",
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                              TextSpan(
                                text: isSameState ? "" : "(IGST)",
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.3, // 20% width
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                "₹${(totalPrice + gstAmount).toStringAsFixed(2)}",
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(minWidth: 100), // Adjust constraints
                              onSelected: (String value) {
                                if (value == 'edit') {
                                  _editProduct(context, index);
                                } else if (value == 'delete') {
                                  setState(() {
                                    selectedProducts.removeAt(index);
                                  });
                                }
                              },
                              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                const PopupMenuItem<String>(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, color: Colors.blue),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),


        const SizedBox(height: 10),

        // Add Product Button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
          ),
          onPressed: _selectProduct,
          icon: const Icon(FontAwesomeIcons.plusCircle, color: Colors.white),
          label: const Text("Add Item", style: TextStyle(color: Colors.white)),
        ),

        const SizedBox(height: 5),

        // Apply Discount Button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
          ),
          onPressed: () => _applyDiscount(context),
          icon: const Icon(Icons.percent, color: Colors.white),
          label: const Text("Apply Discount", style: TextStyle(color: Colors.white)),
        ),

        const SizedBox(height: 15),

        // Summary Section
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              _buildSummaryRow("Taxable Amount", "₹${_getTotalPrice().toStringAsFixed(2)}"),
              _buildSummaryRow("Total GST", "₹${_getTotalGST().toStringAsFixed(2)}"),
              _buildSummaryRow(
                "Discount (${discountPercentage.toStringAsFixed(2)}%)",
                "- ₹${(_getTotalPrice() * discountPercentage / 100).toStringAsFixed(2)}",
                isBold: true,
                isHighlighted: true,
              ),
              _buildSummaryRow(
                "Total Amount After Discount",
                "₹${_getDiscountedTotal().toStringAsFixed(2)}",
                isBold: true,
                isHighlighted: true,
              ),
            ],
          ),
        ),
      ],
    );
  }


}



