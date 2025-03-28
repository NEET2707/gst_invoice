import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gst_invoice/ADD/client/select_client.dart';
import 'package:gst_invoice/ADD/select_product.dart';
import 'package:gst_invoice/DATABASE/database_helper.dart';
import 'package:gst_invoice/color.dart';
import 'package:gst_invoice/gst_invoice.dart';
import 'package:intl/intl.dart';

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
  bool isGstApplicable = true; // or false as default depending on your app logic


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
        'total_tax': totalGST,
        'taxable_amount': taxableAmount,
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
    final db = await DatabaseHelper.getDatabase();

    // Fetch the first company record
    final List<Map<String, dynamic>> companyData = await db.query("company", limit: 1);

    setState(() {
      if (companyData.isNotEmpty) {
        companyName = companyData.first['company_name'] ?? "Not Available";
        companyState = companyData.first['company_state'] ?? "Not Available";
        isGstApplicable = (companyData.first['is_tax'] == 1);
      } else {
        companyName = "Not Available";
        companyState = "Not Available";
        isGstApplicable = false;
      }
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
      int selectedProductId = selectedProduct['product_id'];
      int existingIndex = selectedProducts.indexWhere((p) => p['product_id'] == selectedProductId);

      setState(() {
        if (existingIndex != -1) {
          // ✅ Product already exists — increase its quantity
          int currentQty = int.tryParse(selectedProducts[existingIndex]['qty'].toString()) ?? 1;
          selectedProducts[existingIndex]['qty'] = currentQty + 1;
        } else {
          // ✅ New product — add with qty = 1
          selectedProducts.add({
            ...selectedProduct,
            'qty': 1,
          });
        }
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

      // Apply discount on price
      double discountedPrice = price - (price * discountPercentage / 100);
      double gstAmount = ((discountedPrice * qty) * gstRate) / 100;

      bool isSameState = selectedClient != null &&
          selectedClient!['client_state'] == companyState;

      double cgst = isSameState ? gstAmount / 2 : 0;
      double sgst = isSameState ? gstAmount / 2 : 0;
      double igst = isSameState ? 0 : gstAmount;

      return sum + cgst + sgst + igst;
    });
  }



  double _getDiscountedTotal() {
    double total = _getTotalPrice();
    if (isGstApplicable) total += _getTotalGST();
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
    int currentQty = selectedProducts[index]['qty'] ?? 1;
    TextEditingController qtyController = TextEditingController(text: currentQty.toString());

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            void updateQty(int value) {
              if (value > 0) {
                setStateDialog(() {
                  currentQty = value;
                  qtyController.text = currentQty.toString();
                });
              }
            }

            return AlertDialog(
              title: const Text("Update Quantity"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: () {
                          if (currentQty > 1) {
                            updateQty(currentQty - 1);
                          }
                        },
                      ),
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20),
                          onChanged: (value) {
                            int? newQty = int.tryParse(value);
                            if (newQty != null && newQty > 0) {
                              setStateDialog(() {
                                currentQty = newQty;
                              });
                            }
                          },
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          updateQty(currentQty + 1);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          int productId = selectedProducts[index]['product_id'];
                          int invoiceId = widget.invoiceId ?? 0;

                          final db = await DatabaseHelper.getDatabase();
                          await db.delete(
                            'invoice_line',
                            where: 'invoice_id = ? AND product_id = ?',
                            whereArgs: [invoiceId, productId],
                          );

                          setState(() {
                            selectedProducts.removeAt(index);
                          });

                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.delete),
                        label: const Text("Delete"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade400,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          setState(() {
                            selectedProducts[index] =
                            Map<String, dynamic>.from(selectedProducts[index]);
                            selectedProducts[index]['qty'] = currentQty;
                          });

                          int productId = selectedProducts[index]['product_id'];
                          int invoiceId = widget.invoiceId ?? 0;

                          final db = await DatabaseHelper.getDatabase();
                          await db.update(
                            'invoice_line',
                            {'qty': currentQty},
                            where: 'invoice_id = ? AND product_id = ?',
                            whereArgs: [invoiceId, productId],
                          );

                          print("Database Updated: Product $productId, New Qty: $currentQty");

                          setState(() {}); // Recalculate totals

                          Navigator.pop(context);
                        },
                        child: const Text("Save"),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
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
                color: isHighlighted ? Theme.of(context).colorScheme.onBackground : Colors.black,
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

  List<Widget> _buildGSTBreakdownRows() {
    bool isSameState = selectedClient != null &&
        selectedClient!['client_state'] == companyState;

    double totalGST = _getTotalGST();
    double totalGstRate = selectedProducts.isNotEmpty
        ? selectedProducts.map((p) => p['product_gst'] ?? 0).reduce((a, b) => a + b) / selectedProducts.length
        : 0;

    // Calculate average GST rate based on products
    if (selectedProducts.isNotEmpty) {
      totalGstRate = selectedProducts
          .map((p) => p['product_gst'] ?? 0)
          .reduce((a, b) => a + b) /
          selectedProducts.length;
    }

    double cgst = isSameState ? totalGST / 2 : 0;
    double sgst = isSameState ? totalGST / 2 : 0;
    double igst = isSameState ? 0 : totalGST;

    List<Widget> rows = [];

    // if (isSameState) {
    //   rows.add(_buildSummaryRow("CGST (${(totalGstRate / 2).toStringAsFixed(2)}%)", "₹${cgst.toStringAsFixed(2)}"));
    //   rows.add(_buildSummaryRow("SGST (${(totalGstRate / 2).toStringAsFixed(2)}%)", "₹${sgst.toStringAsFixed(2)}"));
    // } else {
    //   rows.add(_buildSummaryRow("IGST (${totalGstRate.toStringAsFixed(2)}%)", "₹${igst.toStringAsFixed(2)}"));
    // }
    if (isSameState) {
      rows.add(_buildSummaryRow("CGST", "₹${cgst.toStringAsFixed(2)}"));
      rows.add(_buildSummaryRow("SGST", "₹${sgst.toStringAsFixed(2)}"));
    } else {
      rows.add(_buildSummaryRow("IGST", "₹${igst.toStringAsFixed(2)}"));
    }

    return rows;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.background,
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
        padding: const EdgeInsets.all(4.0),
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
                      _buildDetailRow(FontAwesomeIcons.user, companyName, iconColor:Theme.of(context).colorScheme.onBackground),
                      SizedBox(height: 5),
                      _buildDetailRow(FontAwesomeIcons.map, companyState, iconColor:Theme.of(context).colorScheme.onBackground),
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
      return _buildAddButton("Add Buyer", FontAwesomeIcons.userPlus, Theme.of(context).colorScheme.onBackground ,);
    } else {
      return ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.background, // Ensure `themecolor` is defined
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
              // color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(5),
                topRight: Radius.circular(5),

              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onBackground, fontWeight: FontWeight.w600,fontSize: 20)),
                if (isBuyerSection) ...[
                  IconButton(
                    icon: Icon(Icons.add_circle, color: Theme.of(context).colorScheme.onBackground,size: 28,),
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
                    icon: Icon(Icons.edit, color:Theme.of(context).colorScheme.onBackground),
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

  Widget _buildDetailRow(IconData icon, String text,{Color? iconColor}) {
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
                    width: MediaQuery.of(context).size.width * 0.4,
                    child: Text("Product", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                DataColumn(
                  label: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.2,
                    child: isGstApplicable
                        ? Text("GST", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))
                        : SizedBox(), // 👈 Placeholder header
                  ),
                ),
                DataColumn(
                  label: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.2,
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
                double finalAmount = isGstApplicable
                    ? totalPrice + gstAmount
                    : totalPrice;
                bool isSameState = selectedClient != null &&
                    selectedClient!['client_state'] == companyState;

                return DataRow(
                  cells: [
                    // Product
                    DataCell(
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.4,
                        child: Text(
                          "${product['product_name']}\n$qty x ₹${price.toStringAsFixed(2)}",
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),

                    // GST or empty placeholder
                    isGstApplicable
                        ? DataCell(
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.2,
                        child:Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: "₹${gstAmount.toStringAsFixed(2)}", // Only the GST amount
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500), // Normal size
                              ),
                              TextSpan(
                                text: isSameState
                                    ? " (CGST ₹${((product['product_gst'] ?? 0) / 2).toStringAsFixed(2)}%  SGST ${((product['product_gst'] ?? 0) / 2).toStringAsFixed(2)}%)"
                                    : " (IGST ₹${product['product_gst'].toStringAsFixed(2)}%)",
                                style: TextStyle(fontSize: 10, color: Colors.grey), // Smaller GST rate text
                              ),
                            ],
                          ),
                        )
                      ),
                    )
                        : const DataCell(SizedBox()),

                    // Total
                    DataCell(
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.3,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                "₹${finalAmount.toStringAsFixed(2)}",
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(minWidth: 100),
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
              _buildSummaryRow("Amount", "₹${_getTotalPrice().toStringAsFixed(2)}"),
              _buildSummaryRow(
                "Discount (${discountPercentage.toStringAsFixed(2)}%)",
                "- ₹${(_getTotalPrice() * discountPercentage / 100).toStringAsFixed(2)}",
                isBold: true,
                isHighlighted: true,
              ),
              _buildSummaryRow(
                "Taxable Amount",
                "₹${(_getTotalPrice() - (_getTotalPrice() * discountPercentage / 100)).toStringAsFixed(2)}",
              ),
              if (isGstApplicable)
                if (isGstApplicable)
                  ..._buildGSTBreakdownRows(),

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



