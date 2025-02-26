import 'package:flutter/material.dart';
import 'package:gst_invoice/color.dart';
import 'package:gst_invoice/settings.dart';
import 'package:intl/intl.dart';

import 'ADD/invoice.dart';
import 'DATABASE/database_helper.dart';
import 'detail.dart';

class GstInvoice extends StatefulWidget {
  final String companyName;
  final String companyState;
  final String gstRate;

  GstInvoice({
    required this.companyName,
    required this.companyState,
    required this.gstRate,
  });

  @override
  State<GstInvoice> createState() => _GstInvoiceState();
}

class _GstInvoiceState extends State<GstInvoice> {
  List<Map<String, dynamic>> invoices = [];

  @override
  void initState() {
    super.initState();
    loadInvoices();

  }

  Future<void> loadInvoices() async {
    final data = await fetchInvoices();
    setState(() {
      invoices = data;
    });
  }

  String formatDate(String? date) {
    if (date == null || date.isEmpty) return "No Date";

    try {
      // Try parsing with known format
      DateTime parsedDate = DateFormat("d MMM yyyy").parse(date);
      return DateFormat("d MMM, yyyy").format(parsedDate);
    } catch (e) {
      return date; // Return original date if parsing fails
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: themecolor,
        title: Text("GST Invoice (2020-2021)"),
        actions: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Settings()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(Icons.settings),
            ),
          )
        ],
      ),
      body: invoices.isEmpty
          ? Center(
        child: Text(
          "No Invoices Available",
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      )
          : ListView.builder(
        itemCount: invoices.length,
        itemBuilder: (context, index) {
          final invoice = invoices[index];
          bool isPaid = invoice['is_paid'] == 1;
          print(invoice);
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Detail(
                    invoiceId: invoice['invoice_id'],
                    clientid: int.parse(invoice['client_id'].toString()),
                    onStatusUpdated: loadInvoices, // Pass the function to refresh list
                  ),
                ),
              );
            },
            child: Card(
              elevation: 3,
              margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "INVOICE #${invoice['invoice_id']}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPaid ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            isPaid ? "paid" : "unpaid",
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        Spacer(),
                        Icon(Icons.access_time, size: 16, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          formatDate(invoice['invoic_date']),
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.person, size: 18, color: Colors.black54),
                        SizedBox(width: 5),
                        Text(
                          widget.companyName,
                          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                        ),
                      ],
                    ),
                    SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.money, size: 18, color: Colors.black54),
                        SizedBox(width: 5),
                        Text(
                          "₹ ${invoice['total_amount'].toStringAsFixed(2)}",
                          style: TextStyle(fontSize: 15),
                        ),
                      ],
                    ),
                    SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 18, color: Colors.black54),
                        SizedBox(width: 5),
                        Text(
                          "${widget.companyName}, ${widget.companyState}",
                          style: TextStyle(fontSize: 15),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: themecolor,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Invoice()),
          ).then((_) => loadInvoices()); // Refresh after returning
        },
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
