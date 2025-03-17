import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'ADD/invoice.dart';
import 'DATABASE/database_helper.dart';
import 'DATABASE/sharedprefhelper.dart';
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
  String? bankDetailsController ;
  String? termsController ;
  bool isGstApplicable = true;

  @override
  void initState() {
    super.initState();
    fetchInvoiceDetails();
    fetchInvoicesByClientId(widget.clientid);
    fetchProducts(); // Fetch products
    _loadCompanyDetails();
    _loadGstPreference();
    getPreference();
    getGstStatus();
  }

  void getGstStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int gstFlag = prefs.getInt('isGstApplicable') ?? 0;
    setState(() {
      isGstApplicable = gstFlag == 1;
    });
  }

  void getPreference() async {
    final prefs = await SharedPreferences.getInstance();
    int gstPref = prefs.getInt('isGstApplicable') ?? 1;
    isGstApplicable = gstPref == 1;
    print("GST Applicable: $isGstApplicable"); // ✅ Debug print
    setState(() {});
  }


  Future<void> _loadGstPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isGstApplicable = (prefs.getInt("isGstApplicable") ?? 1) == 1;
    });
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
      (SELECT logo FROM companylogo LIMIT 1) AS company_logo,
      (SELECT BankDetails FROM company LIMIT 1) AS BankDetails,
      (SELECT TandC FROM company LIMIT 1) AS TandC
    FROM invoice 
    INNER JOIN client ON invoice.client_id = client.client_id 
    WHERE invoice.invoice_id = ?
  ''', [widget.invoiceId]);

    print("Query Results: $results");  // Debugging

    if (results.isNotEmpty) {
      print("BankDetails: ${results.first['BankDetails']}");  // Debugging
      print("TandC: ${results.first['TandC']}");  // Debugging

      setState(() {
        invoiceDetails = results.first;
      });
    } else {
      print("No data found for invoice_id: ${widget.invoiceId}");
    }
  }

  Future<void> fetchProducts() async {
    final db = await DatabaseHelper.getDatabase();

    final List<Map<String, dynamic>> results = await db.rawQuery('''
    SELECT 
      product.product_name, 
      product.product_price, 
      product.product_gst, 
      product.product_hsn, 
      invoice_line.qty,
      invoice_line.price,
      (invoice_line.price * invoice_line.qty) AS taxableAmount
    FROM invoice_line
    INNER JOIN product ON invoice_line.product_id = product.product_id
    WHERE invoice_line.invoice_id = ?
  ''', [widget.invoiceId]);

    final invoice = invoiceDetails; // already fetched earlier
    final bool isSameState = (invoice?['is_equal_state'] == 1); // true → CGST + SGST, false → IGST

    setState(() {
      productList = results.map((item) {
        double price = item['price'] ?? 0.0;
        int qty = item['qty'] ?? 1;
        double taxableAmount = price * qty;
        double gstRate = item['product_gst'] ?? 0.0;
        double gstAmount = taxableAmount * gstRate / 100;

        return {
          'product_name': item['product_name'],
          'product_price': price,
          'qty': qty,
          'taxableAmount': taxableAmount,
          'gst_rate': gstRate,
          'gst_amount': gstAmount,
          'gst_type': isSameState ? "CGST_SGST" : "IGST",
        };
      }).toList();
    });
  }


  void _loadCompanyDetails() async {
    final dbHelper = DatabaseHelper();
    Map<String, dynamic> companyDetails = await SharedPrefHelper.getCompanyDetails();
    String? savedLogoBase64 = await dbHelper.getCompanyLogo();

    final db = await DatabaseHelper.getDatabase();
    final List<Map<String, dynamic>> companyData = await db.query("company", limit: 1);

    setState(() {
      bankDetailsController = companyDetails["BankDetails"] ?? companyData.firstOrNull?["BankDetails"] ?? "";
      termsController = companyDetails["TandC"] ?? companyData.firstOrNull?["TandC"] ?? "";
    });

    print("BankDetails: ${bankDetailsController}"); // Debugging
    print("TandC: ${termsController}"); // Debugging
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

    double totalCcgst = (invoiceDetails?['total_cgst'] ?? 0.0).toDouble();
    double totalSgst = (invoiceDetails?['total_sgst'] ?? 0.0).toDouble();
    double totalIgst = (invoiceDetails?['total_igst'] ?? 0.0).toDouble();

    String bankDetails = invoiceDetails?['BankDetails'] ?? "N/A";
    String termsAndConditions = invoiceDetails?['TandC'] ?? "N/A";
    print(bankDetails);
    print(termsAndConditions);
    print(invoiceDetails);
    print("999999999999999999999999999999999999999");

    final prefs = await SharedPreferences.getInstance();
    bool isGstApplicable = (prefs.getInt("isGstApplicable") ?? 1) == 1;


    Uint8List? imageBytes;
    if (invoiceDetails?['company_logo'] != null && invoiceDetails?['company_logo'].isNotEmpty) {
      imageBytes = base64Decode(invoiceDetails!['company_logo']);
    }

    bool hasHSN = productList.any((product) =>
    product['product_hsn'] != null && product['product_hsn'].toString().trim().isNotEmpty);


    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: PdfPageFormat.a4.width - 32,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: PdfPageFormat.a4.width * 0.7,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Logo + Company Details
                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              if (imageBytes != null)
                                pw.Container(
                                  width: 100,
                                  height: 100,
                                  margin: pw.EdgeInsets.only(right: 10),
                                  child: pw.Image(pw.MemoryImage(imageBytes)),
                                ),
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text("${invoiceDetails?['client_company'] ?? 'N/A'}",
                                      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                                    ),
                                    pw.Text("Address: ${invoiceDetails?['client_address'] ?? 'N/A'}",
                                      style: pw.TextStyle(fontSize: 12),
                                    ),
                                    pw.Text("GSTIN: ${invoiceDetails?['client_gstin'] ?? 'N/A'}",
                                      style: pw.TextStyle(fontSize: 12),
                                    ),
                                    pw.Text("State: ${invoiceDetails?['client_state'] ?? 'N/A'}",
                                      style: pw.TextStyle(fontSize: 12),
                                    ),
                                    pw.Text("Contact: ${invoiceDetails?['client_contact'].toString() ?? 'N/A'}",
                                      style: pw.TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          pw.SizedBox(height: 10),

                          pw.Text(
                            "Bill To:${invoiceDetails?['client_company'] ?? 'N/A'}",
                            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            "${invoiceDetails?['client_address'] ?? 'N/A'}",
                            style: pw.TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start, // Align everything left
                      children: [
                        pw.Text(
                          "TAX INVOICE:#${invoiceDetails?['invoice_id'] ?? 'N/A'}",
                          style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 10),
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

                        pw.SizedBox(height: 20),

                        pw.Text(
                          "Issue Date: ${invoiceDetails?['invoice_date'] ?? 'N/A'}",
                          style: pw.TextStyle(fontSize: 12),
                        ),
                        pw.Text(
                          "Due Date: ${invoiceDetails?['due_date'] ?? 'N/A'}",
                          style: pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              pw.Column(
                children: [
                  // Table divided into two parts
                  pw.Table(
                    border: pw.TableBorder.all(width: 1, color: PdfColors.grey),
                    columnWidths: hasHSN
                        ? {
                      0: pw.FlexColumnWidth(1), // S No
                      1: pw.FlexColumnWidth(4), // Item Description
                      2: pw.FlexColumnWidth(2), // HSN
                      3: pw.FlexColumnWidth(1), // Qty
                      4: pw.FlexColumnWidth(2), // Price
                      5: pw.FlexColumnWidth(2), // Taxable
                      6: pw.FlexColumnWidth(2), // GST
                      7: pw.FlexColumnWidth(2), // Amount
                    }
                        : {
                      0: pw.FlexColumnWidth(1), // S No
                      1: pw.FlexColumnWidth(4), // Item Description
                      2: pw.FlexColumnWidth(1), // Qty
                      3: pw.FlexColumnWidth(2), // Price
                      4: pw.FlexColumnWidth(2), // Taxable
                      5: pw.FlexColumnWidth(2), // GST
                      6: pw.FlexColumnWidth(2), // Amount
                    },
                    children: [
                      // Header Row
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
                          if (hasHSN)
                            pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text("HSN", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
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
                            child: pw.Text("Taxable Amount", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: pw.EdgeInsets.all(8),
                            child: pw.Text("GST", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
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
                        final price = (product['taxableAmount'] ?? 0) as num;
                        final gstAmount = (product['gst_amount'] ?? 0) as num;
                        final total = price + gstAmount;

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
                            if (hasHSN)
                              pw.Padding(
                                padding: pw.EdgeInsets.all(8),
                                child: pw.Text("${product['product_hsn'] ?? ''}"),
                              ),
                            pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text("${product['qty'] ?? '0'}"),
                            ),
                            pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text("${product['product_price'] ?? ''}"),
                            ),
                            pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text("${product['taxableAmount'] ?? ''}"),
                            ),
                            pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  if (product['gst_type'] == "CGST_SGST") ...[
                                    pw.Text("${((gstAmount) / 2).toStringAsFixed(2)}"),
                                    pw.Text("${((gstAmount) / 2).toStringAsFixed(2)}"),
                                  ] else
                                    pw.Text("${gstAmount.toStringAsFixed(2)}"),
                                ],
                              ),
                            ),
                            pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text(
                                "${total.toStringAsFixed(2)}",
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),

                  pw.SizedBox(height: 10),

                  // Tax & Total Section
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Right Side: Terms & Conditions (50% width)

                        pw.Expanded(
                          flex: 1,
                          child: bankDetailsController!.isNotEmpty ?  pw.Container(
                            height: 150,
                            decoration: pw.BoxDecoration(border: pw.Border.all(width: 1, color: PdfColors.grey)),
                            padding: pw.EdgeInsets.all(8),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text("Bank Details", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                                pw.SizedBox(height: 5),
                                pw.Text(bankDetailsController.toString(), style: pw.TextStyle(fontSize: 12)),
                              ],
                            ),
                          ) : pw.SizedBox(),
                        ),


                      pw.SizedBox(width: 10), // Space between the two sections

                      // Left Side: Summary Table (50% width)
                      pw.Expanded(
                        flex: 1,
                        child: pw.Table(
                          border: pw.TableBorder.all(width: 1, color: PdfColors.grey),
                          columnWidths: {
                            0: pw.FlexColumnWidth(3),
                            1: pw.FlexColumnWidth(2),
                          },
                          children: [
                            _buildSummaryRow("Taxable Amount", taxableAmount.toStringAsFixed(2)),
                            _buildSummaryRow("Discount (${discount.toStringAsFixed(2)}%)", "- ${discountAmount.toStringAsFixed(2)}"),
                            if (isGstApplicable)
                              if (isSameState) ...[
                                _buildSummaryRow("CGST", totalCcgst.toStringAsFixed(2)),
                                _buildSummaryRow("SGST", totalSgst.toStringAsFixed(2)),
                              ] else
                                _buildSummaryRow("IGST", totalIgst.toStringAsFixed(2)),
                            pw.TableRow(
                              decoration: pw.BoxDecoration(color: PdfColors.grey300),
                              children: [
                                pw.Padding(
                                  padding: pw.EdgeInsets.all(8),
                                  child: pw.Text("Grand Total", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                                ),
                                pw.Padding(
                                  padding: pw.EdgeInsets.all(8),
                                  child: pw.Text(
                                    "${(taxableAmount + (isGstApplicable ? (isSameState ? (totalCcgst + totalSgst) : totalIgst) : 0) - discountAmount).toStringAsFixed(2)}",
                                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 10),

                  // Bank Details SectiontermsController
                  if (termsController!.isNotEmpty)
                    pw.Container(
                      width: double.infinity,
                      padding: pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey, width: 1),
                        color: PdfColors.grey100,
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("Terms & Conditions", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 5),
                          pw.Text(termsController.toString(), style: pw.TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),


                  pw.SizedBox(height: 30),

                  // Footer Section
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,

                        children: [
                          pw.Text("Authorized Signatory", style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
                          pw.SizedBox(height: 20),
                          pw.Container(height: 1, width: 100, color: PdfColors.black),
                        ],
                      ),
                    ],
                  ),
                ],
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

  pw.TableRow _buildSummaryRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: pw.EdgeInsets.all(8),
          child: pw.Text(label),
        ),
        pw.Padding(
          padding: pw.EdgeInsets.all(8),
          child: pw.Text(value),
        ),
      ],
    );
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
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Card(
          elevation: 2,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusToggle(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Divider(color: Colors.blue.shade100, thickness: 1,),
                ),
                _buildBuyerDetails(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Divider(color: Colors.blue.shade100, thickness: 1,),
                ),
                _buildInvoiceDetails(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Divider(color: Colors.blue.shade100, thickness: 1,),
                ),
                _buildProductsList(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 50),
                  child: Divider(color: Colors.blue.shade100, thickness: 1,),
                ),
                _buildGST(),
              ],
            ),
          ),
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
    String clientCompany = invoiceDetails?['client_company']?.toString() ?? "N/A";
    String firstLetter = clientCompany.isNotEmpty ? clientCompany[0].toUpperCase() : "?";

    return _buildSection(
      title: "Buyer Details",
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: themecolor, // Ensure `themecolor` is defined
          child: Text(
            firstLetter,
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          clientCompany,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 18),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (invoiceDetails?['client_state']?.toString().isNotEmpty ?? false)
              Text("State: ${invoiceDetails!['client_state']}"),
            if (invoiceDetails?['client_contact']?.toString().isNotEmpty ?? false)
              Text("Contact: ${invoiceDetails!['client_contact']}"),
          ],
        ),
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
      title: "Items Details",
      child: Column(
        children: productList.map((product) {
          print("PRODUCT: $product"); // Debug print

          double price = product['product_price'] ?? 0.0;
          int qty = int.tryParse(product['qty'].toString()) ?? 1;
          double taxableAmount = product['taxableAmount'] ?? (price * qty);
          double gstRate = product['gst_rate']?.toDouble() ?? 0.0;
          double gstAmount = product['gst_amount']?.toDouble() ?? 0.0;
          String gstType = product['gst_type'] ?? '';

          print("GST Applicable: $isGstApplicable, GST Rate: $gstRate, GST Amount: $gstAmount, GST Type: $gstType");

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Line 1: Product name + Price X Qty + Taxable amount
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        "${product['product_name']}",
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 18),
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("${price.toStringAsFixed(2)} X $qty"),
                          Text(
                            "${taxableAmount.toStringAsFixed(0)}",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Line 2: GST breakdown (if applicable)
                if (isGstApplicable && gstRate > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (gstType == "CGST_SGST") ...[
                          Text(
                            "CGST : ${(gstAmount / 2).toStringAsFixed(0)} (${(gstRate / 2).toStringAsFixed(1)}%)",
                            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                          ),
                          Text(
                            "SGST : ${(gstAmount / 2).toStringAsFixed(0)} (${(gstRate / 2).toStringAsFixed(1)}%)",
                            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                          ),
                        ] else ...[
                          Text(
                            "$gstType : ${gstAmount.toStringAsFixed(0)} (${gstRate.toStringAsFixed(0)}%)",
                            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                          ),
                        ],
                      ],
                    ),
                  ),

                // Line 3: Total (taxable + gst)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        "${(taxableAmount + gstAmount).toStringAsFixed(0)}",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGST() {
    bool isSameState = invoiceDetails?['is_equal_state'] == 1;
    double taxableAmount = invoiceDetails?['taxable_amount'] ?? 0.0;
    double discount = (invoiceDetails?['discount'] ?? 0.0).toDouble();
    double totalCcgst = (invoiceDetails?['total_cgst'] ?? 0.0).toDouble();
    double totalSgst = (invoiceDetails?['total_sgst'] ?? 0.0).toDouble();
    double totalIgst = (invoiceDetails?['total_igst'] ?? 0.0).toDouble();
    double discountAmount = (taxableAmount * discount) / 100;
    double totalWithoutGst = taxableAmount - discountAmount;
    double totalWithGst = taxableAmount +
        (isSameState ? (totalCcgst + totalSgst) : totalIgst) -
        discountAmount;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Summary", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          Divider(),
          _buildRow(
            title: "Taxable Amount",
            value: "₹${taxableAmount.toStringAsFixed(2)}",
            isBold: true,
            color: Colors.green,
          ),
          _buildRow(
            title: "Discount (${discount.toStringAsFixed(2)}%)",
            value: "₹${discountAmount.toStringAsFixed(2)}",
          ),
          if (isGstApplicable) ...[
            if (isSameState) ...[
              _buildRow(title: "CGST", value: "₹${totalCcgst.toStringAsFixed(2)}"),
              _buildRow(title: "SGST", value: "₹${totalSgst.toStringAsFixed(2)}"),
            ] else
              _buildRow(title: "IGST", value: "₹${totalIgst.toStringAsFixed(2)}"),
            _buildRow(
              title: "Total Amount",
              value: "₹${(taxableAmount + (isSameState ? (totalCcgst + totalSgst) : totalIgst)).toStringAsFixed(2)}",
            ),
            Divider(),
            _buildRow(
              title: "Final Amount",
              value: "₹${totalWithGst.toStringAsFixed(2)}",
              isBold: true,
              color: Colors.blue,
            ),
          ] else ...[
            Divider(),
            _buildRow(
              title: "Final Amount",
              value: "₹${totalWithoutGst.toStringAsFixed(2)}",
              isBold: true,
              color: Colors.blue,
            ),
          ],
        ],
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
              style: TextStyle(fontSize: 15, fontWeight: isBold ? FontWeight.w500 : FontWeight.normal),
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
      padding: const EdgeInsets.only(bottom: 1.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(1.0),
            color: Colors.white,
            child: Text(title, style: TextStyle(color: themecolor, fontWeight: FontWeight.w600,fontSize: 20)),
          ),
          SizedBox(height: 4),
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
          Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
          Text(value ?? 'N/A'), // Handle null
        ],
      ),
    );
  }

}
