import 'package:flutter/material.dart';
import 'package:gst_invoice/color.dart';
import 'package:gst_invoice/settings.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ADD/invoice.dart';
import 'ADD/select_client.dart';
import 'ADD/select_product.dart';
import 'DATABASE/database_helper.dart';
import 'detail.dart';

class GstInvoice extends StatefulWidget {
  final String? companyName;
  final String? companyState;
  final String? gstRate;

  GstInvoice({this.companyName, this.companyState, this.gstRate});

  @override
  State<GstInvoice> createState() => _GstInvoiceState();
}

class _GstInvoiceState extends State<GstInvoice>{
  List<Map<String, dynamic>> invoices = [];
  List<Map<String, dynamic>> filteredInvoices = [];
  bool _isLoading = true;
  bool _isSearching = false;
  int _selectedIndex = 0;
  String companyName = "Not Available";
  String companyState = "Not Available";
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadInvoices();
  }


  Future<void> loadInvoices() async {
    setState(() => _isLoading = true);

    final data = await fetchInvoices();
    await _loadCompanyDetails(); // ✅ Fetch latest company details

    setState(() {
      invoices = data;
      filteredInvoices = data;
      _isLoading = false;
    });
  }

  Future<void> _loadCompanyDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      companyName = prefs.getString('companyName') ?? "Not Available"; // ✅ Store locally
      companyState = prefs.getString('companyState') ?? "Not Available";
    });
  }

  void filterInvoices(String query) {
    if (query.isEmpty) {
      setState(() => filteredInvoices = invoices);
      return;
    }

    setState(() {
      filteredInvoices = invoices.where((invoice) {
        String invoiceId = invoice['invoice_id'].toString();
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
    Container(),
    SelectProduct(isyes: true, boom: false),
    Container(),
    SelectClient(pass: true, back: false),
    Settings(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: (_selectedIndex == 1 || _selectedIndex == 3 || _selectedIndex == 4)
          ? null
          : AppBar(
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
      body: _selectedIndex == 0
          ? RefreshIndicator(
        onRefresh: loadInvoices,
        child: _isLoading  // ✅ Show loader if data is fetching
            ? Center(child: CircularProgressIndicator())
            : buildInvoiceList(),
      )
          : _pages[_selectedIndex],
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
        backgroundColor: themecolor,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Invoice()),
          ).then((_) {
            loadInvoices(); // ✅ Reload invoices AND company details
          });
        },
        child: Icon(Icons.add, color: Colors.white, size: 34),
      )
          : null,
      bottomNavigationBar: BottomAppBar(
        shape: CircularNotchedRectangle(),
        height: 55,
        notchMargin: 8.0,
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home, "Home", 0),
            _buildNavItem(Icons.warehouse, "Product", 1),
            _buildNavItem(Icons.people, "Clients", 3),
            _buildNavItem(Icons.settings, "Settings", 4),
          ],
        ),
      ),
    );
  }

  // ✅ Move this function OUTSIDE the `build` method
  Widget _buildNavItem(IconData icon, String label, int index) {
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _selectedIndex == index ? themecolor : Colors.grey),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: _selectedIndex == index ? themecolor : Colors.grey,
            ),
          ),
        ],
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
        : Card(
          child: ListView.builder(
                itemCount: filteredInvoices.length,
                itemBuilder: (context, index) {
          final invoice = filteredInvoices[index];
          bool isPaid = invoice['is_paid'] == 1;
          
          return Column(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Detail(
                        invoiceId: int.parse(invoice['invoice_id'].toString()), // Convert to int
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
                                Text(
                        companyName,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 18),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  formatDate(invoice['invoic_date']),
                                  style:
                                  TextStyle(color: Colors.grey, fontSize: 14),
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
                          Row(
                            children: [
                              Text(
                                "₹ ${invoice['total_amount'].toStringAsFixed(2)}",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Container(
                            padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: isPaid ? Colors.green : Colors.red,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              isPaid ? "PAID" : "UNPAID",
                              style: TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Divider(color: Colors.grey.shade300, thickness: 1),
              ),
            ],
          );
                },
              ),
        );
  }
}
