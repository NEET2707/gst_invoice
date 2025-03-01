import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'ADD/invoice.dart';
import 'DATABASE/database_helper.dart';
import 'color.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'dart:convert';


class Detail extends StatefulWidget {
  final int invoiceId;
  final int clientid;
  final VoidCallback onStatusUpdated; // Callback function

  const Detail({
    Key? key,
    required this.invoiceId,
    required this.clientid,
    required this.onStatusUpdated, // Add this
  }) : super(key: key);

  @override
  State<Detail> createState() => _DetailState();
}


class _DetailState extends State<Detail> {
  Map<String, dynamic>? invoiceDetails;
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> productList = [];


  @override
  void initState() {
    super.initState();
    fetchInvoiceDetails();
    fetchInvoicesByClientId(widget.clientid);
    fetchProducts(); // Fetch products
  }

  Future<List<Map<String, dynamic>>> fetchInvoicesByClientId(int clientId) async {
    final db = await DatabaseHelper.getDatabase();

    final List<Map<String, dynamic>> results = await db.rawQuery('''
    SELECT 
      invoice.*, 
      client.client_company, 
      client.client_contact, 
      client.client_address, 
      client.client_state, 
      client.client_gstin 
    FROM invoice 
    INNER JOIN client ON invoice.client_id = client.client_id 
    WHERE invoice.client_id = ?
  ''', [clientId]);

    return results;
  }


  Future<void> fetchInvoiceDetails() async {
    final db = await DatabaseHelper.getDatabase();

    final List<Map<String, dynamic>> results = await db.rawQuery('''
  SELECT 
    invoice.*, 
    client.client_company, 
    client.client_contact, 
    client.client_address, 
    client.client_state, 
    client.client_gstin,
    (SELECT logo FROM companylogo LIMIT 1) AS company_logo  -- Fetch company logo
  FROM invoice 
  INNER JOIN client ON invoice.client_id = client.client_id 
  WHERE invoice.invoice_id = ?
  ''', [widget.invoiceId]);

    if (results.isNotEmpty) {
      setState(() {
        invoiceDetails = results.first;
      });
    }
  }

  Future<void> fetchProducts() async {
    final db = await DatabaseHelper.getDatabase();

    final List<Map<String, dynamic>> results = await db.rawQuery('''
    SELECT 
      product.product_name, 
      product.product_price, 
      product.product_gst, 
      invoice_line.qty,
      (invoice_line.price * invoice_line.qty) AS taxableAmount
    FROM invoice_line
    INNER JOIN product ON invoice_line.product_id = product.product_id
    WHERE invoice_line.invoice_id = ?
  ''', [widget.invoiceId]);

    setState(() {
      productList = results;
    });
  }

  Future<pw.Document> generatePDF() async {
    final pdf = pw.Document();

    bool isPaid = (invoiceDetails?['is_paid'] ?? 0) == 1;
    bool isSameState = invoiceDetails?['is_equal_state'] == 1;
    double taxableAmount = invoiceDetails?['taxable_amount'] ?? 0.0;
    double totalTax = invoiceDetails?['total_tax'] ?? 0.0;
    double totalAmount = (invoiceDetails?['total_amount'] ?? 0.0).toDouble();
    double discount = (invoiceDetails?['discount'] ?? 0.0).toDouble();
    double discountAmount = (totalAmount * discount) / 100;

    Uint8List? imageBytes;
    if (invoiceDetails?['company_logo'] != null && invoiceDetails?['company_logo'].isNotEmpty) {
      imageBytes = base64Decode(invoiceDetails!['company_logo']);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Company Logo and Details
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (imageBytes != null)
                        pw.Container(
                          width: 100,
                          height: 100,
                          child: pw.Image(pw.MemoryImage(imageBytes)),
                        ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        "${invoiceDetails?['client_company'] ?? 'N/A'}",
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        "Address: ${invoiceDetails?['client_address'] ?? 'N/A'}",
                        style: pw.TextStyle(fontSize: 12),
                      ),
                      pw.Text(
                        "GSTIN: ${invoiceDetails?['client_gstin'] ?? 'N/A'}",
                        style: pw.TextStyle(fontSize: 12),
                      ),
                      pw.Text(
                        "State: ${invoiceDetails?['client_state'] ?? 'N/A'}",
                        style: pw.TextStyle(fontSize: 12),
                      ),
                      pw.Text(
                        "Contact: ${invoiceDetails?['client_contact'].toString() ?? 'N/A'}",
                        style: pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),

                  // Invoice Title
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "TAX INVOICE",
                        style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        "#${invoiceDetails?['invoice_id'] ?? 'N/A'}",
                        style: pw.TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // Invoice Status and Dates
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Container(
                    padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(
                      borderRadius: pw.BorderRadius.circular(4),
                      color: isPaid ? PdfColors.green : PdfColors.red,
                    ),
                    child: pw.Text(
                      isPaid ? "PAID" : "UNPAID",
                      style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Text(
                    "Issue Date: ${invoiceDetails?['invoic_date'] ?? 'N/A'}",
                    style: pw.TextStyle(fontSize: 12),
                  ),
                  pw.Text(
                    "Due Date: ${invoiceDetails?['due_date'] ?? 'N/A'}",
                    style: pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // Bill To Section
              pw.Text(
                "Bill To:",
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                "${invoiceDetails?['client_company'] ?? 'N/A'}",
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                "${invoiceDetails?['client_address'] ?? 'N/A'}",
                style: pw.TextStyle(fontSize: 12),
              ),

              pw.SizedBox(height: 20),

              // Product Table
              pw.Table(
                border: pw.TableBorder.all(width: 1, color: PdfColors.grey),
                columnWidths: {
                  0: pw.FlexColumnWidth(1),
                  1: pw.FlexColumnWidth(4),
                  2: pw.FlexColumnWidth(2),
                  3: pw.FlexColumnWidth(2),
                  4: pw.FlexColumnWidth(2),
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text("S No", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text("Item Description", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text("Qty", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text("Price", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text("Amount", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),

                  // Product Rows
                  ...List.generate(productList.length, (index) {
                    final product = productList[index];
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text("${index + 1}"),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(product['product_name'] ?? 'N/A'),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text("${product['qty']}"),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text("${product['product_price']}"),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text("${product['taxableAmount']}"),
                        ),
                      ],
                    );
                  }),

                  // Total Amount Row
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(""),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text("Total Amount", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(""),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(""),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text("${(totalAmount).toStringAsFixed(2)}",
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // Footer Section
              pw.Text(
                "Terms and Conditions:",
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                "1. Payment is due within 30 days of invoice date.\n2. Late payments are subject to a fee of 2% per month.",
                style: pw.TextStyle(fontSize: 10),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  void _editInvoice() async {
    bool? updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Invoice(invoiceId: widget.invoiceId),
      ),
    );

    if (updated == true) {
      fetchInvoiceDetails();
      // fetchProducts();
    }
  }


  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Confirm Delete"),
          content: Text("Are you sure you want to delete this invoice?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
              },
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                _deleteInvoice(); // Call function to delete invoice
                Navigator.pop(context); // Close dialog
              },
              child: Text("Yes", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _deleteInvoice() async {
    final db = await DatabaseHelper.getDatabase();

    // Delete invoice from the `invoice` table
    await db.delete(
      'invoice',
      where: 'invoice_id = ?',
      whereArgs: [widget.invoiceId],
    );

    // Delete related invoice items from `invoice_line`
    await db.delete(
      'invoice_line',
      where: 'invoice_id = ?',
      whereArgs: [widget.invoiceId],
    );

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Invoice deleted successfully!")),
    );

    // Navigate back after deletion
    Navigator.pop(context);
  }


  @override
  Widget build(BuildContext context) {
    if (invoiceDetails == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: themecolor,
          title: Text("Detail"),
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: themecolor,
        title: Text("Detail"),
        actions: [
          GestureDetector(
            onTap: () async {
              final pdf = await generatePDF(); // Generate PDF

              try {
                await Printing.layoutPdf(
                  onLayout: (PdfPageFormat format) async => pdf.save(),
                ); // Open PDF preview
              } catch (e) {
                print("Error while printing PDF: $e");
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(Icons.picture_as_pdf),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (String choice) {
              if (choice == 'Edit') {
                _editInvoice(); // Navigate to Edit Page
              } else if (choice == 'Delete') {
                _confirmDelete(); // Show Delete Confirmation Dialog
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'Edit',
                child: ListTile(
                  leading: Icon(Icons.edit, color: Colors.blue),
                  title: Text('Edit'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'Delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Delete'),
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(Icons.more_vert),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusToggle(),
            _buildBuyerDetails(),
            _buildInvoiceDetails(),
            _buildProductsList(),
            _buildGST(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("Paid", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Switch(
          value: invoiceDetails?['is_paid'] == 1, // Read-only data
          onChanged: (value) async {
            await _updateInvoiceStatus(value);
          },
        ),
      ],
    );
  }

  Future<void> _updateInvoiceStatus(bool isPaid) async {
    final db = await DatabaseHelper.getDatabase();

    await db.update(
      'invoice',
      {'is_paid': isPaid ? 1 : 0},  // ✅ Ensure value is set as 1 (paid) or 0 (unpaid)
      where: 'invoice_id = ?',
      whereArgs: [widget.invoiceId],
    );

    await fetchInvoiceDetails(); // ✅ Refresh UI after update

    widget.onStatusUpdated(); // ✅ Notify GstInvoice to refresh
  }


  Widget _buildBuyerDetails() {
    return _buildSection(
      title: "Buyer Details",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIconText(Icons.business, invoiceDetails?['client_company']?.toString() ?? 'N/A'),
          _buildIconText(Icons.location_on, invoiceDetails?['client_address']?.toString() ?? 'N/A'),
          _buildIconText(Icons.confirmation_number, "GST: ${invoiceDetails?['client_gstin'] ?? 'N/A'}"),
          _buildIconText(Icons.map, invoiceDetails?['client_state']?.toString() ?? 'N/A'),
          _buildIconText(Icons.phone, invoiceDetails?['client_contact']?.toString() ?? 'N/A'),
        ],
      ),
    );
  }


  Widget _buildInvoiceDetails() {
    return _buildSection(
      title: "Invoice Details",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextRow("INVOICE ", "${invoiceDetails!['invoice_id']}"),
          _buildTextRow("Invoice Date", invoiceDetails!['invoic_date']),
          _buildTextRow("Due Date", invoiceDetails!['due_date']),
        ],
      ),
    );
  }

  Widget _buildProductsList() {
    return _buildSection(
      title: "Available Products",
      child: Column(
        children: productList.map((product) {
          double price = product['product_price'] ?? 0.0;
          int qty = product['qty'] ?? 1;
          double taxableAmount = product['taxableAmount'] ?? 0.0;

          return Card(
            elevation: 3,
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start, // Aligns items to the top
                children: [
                  // Product Name (Expands to take available space)
                  Expanded(
                    flex: 2, // Adjust as needed
                    child: Text(
                      "${product['product_name']}",
                      style: TextStyle(fontWeight: FontWeight.normal,fontSize: 20),
                      overflow: TextOverflow.ellipsis, // Prevents overflow
                      softWrap: false, // Keeps text in one line
                    ),
                  ),
                  // Product Details (Price, Quantity, Taxable Amount)
                  Expanded(
                    flex: 1, // Adjust as needed
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end, // Align text to the right
                      children: [
                        Text("${price.toStringAsFixed(2)} X $qty"),
                        Text(
                          "${taxableAmount.toStringAsFixed(2)}",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGST() {
    bool isSameState = invoiceDetails?['is_equal_state'] == 1;
    double taxableAmount = invoiceDetails?['taxable_amount'] ?? 0.0;
    double totalTax = invoiceDetails?['total_tax'] ?? 0.0;
    double totalAmount = (invoiceDetails?['total_amount'] ?? 0.0).toDouble();
    double discount = (invoiceDetails?['discount'] ?? 0.0).toDouble();
    double totalCcgst = (invoiceDetails?['total_cgst'] ?? 0.0).toDouble();
    double totalSgst = (invoiceDetails?['total_sgst'] ?? 0.0).toDouble();
    double totalIgst = (invoiceDetails?['total_igst'] ?? 0.0).toDouble();
    double discountAmount = (taxableAmount * discount) / 100;

    return Card(
      elevation: 3,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "GST & Total",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Divider(),
            _buildRow(
              title: "Taxable Amount",
              value: "₹${(taxableAmount ).toStringAsFixed(2)}",
              isBold: true,
              color: Colors.green,
            ),
            _buildRow(
              title: "Discount (${discount.toStringAsFixed(2)}%)",
              value: "₹${(taxableAmount * discount / 100).toStringAsFixed(2)}",
            ),
            if (isSameState) ...[
              _buildRow(
                title: "CGST",
                value: "₹${(invoiceDetails?['total_cgst'] ?? 0.0).toStringAsFixed(2)}",
              ),
              _buildRow(
                title: "SGST",
                value: "₹${(invoiceDetails?['total_sgst'] ?? 0.0).toStringAsFixed(2)}",
              ),
            ] else
              _buildRow(
                title: "IGST",
                value: "₹${(invoiceDetails?['total_igst'] ?? 0.0).toStringAsFixed(2)}",
              ),

            _buildRow(
              title: "Total Amount",
              value: "₹${(taxableAmount + (isSameState
                  ? (totalCcgst + totalSgst)
                  : totalIgst)).toStringAsFixed(2)}",
            ),

            Divider(),
            _buildRow(
              title: "Final Amount",
              value: "₹${(taxableAmount + (isSameState
                  ? (totalCcgst + totalSgst)
                  : totalIgst) - discountAmount).toStringAsFixed(2)}",
              isBold: true,
              color: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

// Helper method for consistent row formatting
  Widget _buildRow({required String title, required String value, bool isBold = false, Color color = Colors.black}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(8.0),
            color: themecolor,
            child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildTextRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          Text(value ?? 'N/A'), // Handle null
        ],
      ),
    );
  }

  Widget _buildIconText(IconData icon, String? text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          SizedBox(width: 8),
          Text(text ?? 'N/A', style: TextStyle(fontSize: 15)), // Handle null
        ],
      ),
    );
  }
}
