import 'package:flutter/material.dart';
import 'package:gst_invoice/color.dart';
import 'package:gst_invoice/settings.dart';
import 'package:intl/intl.dart';

import 'ADD/invoice.dart';
import 'ADD/select_client.dart';
import 'ADD/select_product.dart';
import 'DATABASE/database_helper.dart';
import 'detail.dart';

class GstInvoice extends StatefulWidget {
  final String? companyName;
  final String? companyState;
  final String? gstRate;

  GstInvoice({
    this.companyName,
    this.companyState,
    this.gstRate,
  });

  @override
  State<GstInvoice> createState() => _GstInvoiceState();
}

class _GstInvoiceState extends State<GstInvoice> {
  List<Map<String, dynamic>> invoices = [];
  int _selectedIndex = 0;
  List<Map<String, dynamic>> filteredInvoices = [];
  bool _isSearching = false;
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadInvoices();
  }

  Future<void> loadInvoices() async {
    final data = await fetchInvoices();
    setState(() {
      invoices = data;
      filteredInvoices = data;
    });
  }

  void filterInvoices(String query) {
    if (query.isEmpty) {
      setState(() => filteredInvoices = invoices);
      return;
    }

    setState(() {
      filteredInvoices = invoices.where((invoice) {
        String invoiceId = invoice['invoice_id'].toString(); // Convert to string
        return invoiceId.contains(query);
      }).toList();
    });
  }


  String formatDate(String? date) {
    if (date == null || date.isEmpty) return "No Date";
    try {
      DateTime parsedDate = DateFormat("d MMM yyyy").parse(date);
      return DateFormat("d MMM, yyyy").format(parsedDate);
    } catch (e) {
      return date;
    }
  }

  final List<Widget> _pages = [
    Container(), // Home Page (GstInvoice Content)
    SelectProduct(isyes: true, boom: false,),
    Container(), // Placeholder for FAB
    SelectClient(pass: true, back: false,),
    Settings(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: (_selectedIndex == 1 || _selectedIndex == 3 || _selectedIndex == 4)
          ? null // Hide AppBar for specific pages
          :  AppBar(
        backgroundColor: themecolor,

        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: "Search by Invoice ID...",
            border: InputBorder.none,
          ),
          onChanged: filterInvoices,
        )
            : Text("GST Invoice"),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                _searchController.clear();
                if (!_isSearching) filterInvoices('');
              });
            },
          ),
        ],
      ),

      body: _selectedIndex == 0 ? buildInvoiceList() : _pages[_selectedIndex],

      // Show FAB only on Home Tab (_selectedIndex == 0)
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
        backgroundColor: themecolor,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Invoice()),
          ).then((_) => loadInvoices());
        },
        child: Icon(Icons.add, color: Colors.white, size: 34,),
      )
          : null, // Hide FAB on other tabs

      bottomNavigationBar: BottomAppBar(
        shape: CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Icon(Icons.home, color: _selectedIndex == 0 ? themecolor : Colors.grey),
              onPressed: () => setState(() => _selectedIndex = 0),
            ),
            IconButton(
              icon: Icon(Icons.warehouse, color: _selectedIndex == 1 ? themecolor : Colors.grey),
              onPressed: () => setState(() => _selectedIndex = 1),
            ),
            IconButton(
              icon: Icon(Icons.people, color: _selectedIndex == 3 ? themecolor : Colors.grey),
              onPressed: () => setState(() => _selectedIndex = 3),
            ),
            IconButton(
              icon: Icon(Icons.settings, color: _selectedIndex == 4 ? themecolor : Colors.grey),
              onPressed: () => setState(() => _selectedIndex = 4),
            ),
          ],
        ),
      ),
    );
  }


  Widget buildInvoiceList() {
    return filteredInvoices.isEmpty
        ? Center(
      child: Text(
        "No Invoices Available",
        style: TextStyle(fontSize: 18, color: Colors.grey),
      ),
    )
        : ListView.builder(
      itemCount: filteredInvoices.length,
      itemBuilder: (context, index) {
        final invoice = filteredInvoices[index]; // Use filtered list
        bool isPaid = invoice['is_paid'] == 1;

        return Column(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Detail(
                      invoiceId: invoice['invoice_id'],
                      clientid: int.parse(invoice['client_id'].toString()),
                      onStatusUpdated: loadInvoices,
                    ),
                  ),
                );
              },
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Invoice ID Circle
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: themecolor,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "${invoice['invoice_id']}",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person, size: 16, color: Colors.black54),
                              SizedBox(width: 5),
                              Text(
                                widget.companyName.toString(),
                                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.money, size: 16, color: Colors.black54),
                              SizedBox(width: 5),
                              Text(
                                "₹ ${invoice['total_amount'].toStringAsFixed(2)}",
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 16, color: Colors.black54),
                              SizedBox(width: 5),
                              Text(
                                "${widget.companyState}",
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: isPaid ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            isPaid ? "PAID" : "UNPAID",
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 14, color: Colors.grey),
                            SizedBox(width: 4),
                            Text(
                              formatDate(invoice['invoic_date']),
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Divider(color: Colors.grey.shade300, thickness: 1),
          ],
        );
      },
    );
  }
}
