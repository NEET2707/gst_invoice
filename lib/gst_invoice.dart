import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:gst_invoice/color.dart';
import 'package:gst_invoice/settings.dart';
import 'package:gst_invoice/theme_controlloer.dart';
import 'package:intl/intl.dart';

import 'ADD/invoice.dart';
import 'ADD/client/select_client.dart';
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

class _GstInvoiceState extends State<GstInvoice> {
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
    await _loadCompanyDetails();

    print("Fetched invoices count: ${data.length}");

    setState(() {
      invoices = data;
      filteredInvoices = data;
      _isLoading = false;
    });
  }

  Future<void> _loadCompanyDetails() async {
    final db = await DatabaseHelper.getDatabase();

    final List<Map<String, dynamic>> companyData = await db.query("company", limit: 1);

    setState(() {
      if (companyData.isNotEmpty) {
        companyName = companyData.first['company_name'] ?? "Not Available";
        companyState = companyData.first['company_state'] ?? "Not Available";
      } else {
        companyName = "Not Available";
        companyState = "Not Available";
      }
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
      DateTime parsedDate = DateFormat("d MMM yy").parse(date);
      return DateFormat("d MMM, yy").format(parsedDate);
    } catch (e) {
      return date;
    }
  }

  final List<Widget> _pages = [
    Container(),
    Builder(
      builder: (context) => SelectProduct(isyes: true, boom: false),
    ),
    Container(),
    Builder(
      builder: (context) => SelectClient(pass: true, back: false),
    ),
    Settings(),
  ];

  @override
  Widget build(BuildContext context) {
    ThemeController themeController = Get.put(ThemeController());
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      appBar: (_selectedIndex == 1 || _selectedIndex == 3 || _selectedIndex == 4)
          ? null
          : AppBar(
        backgroundColor: Theme.of(context).colorScheme.background,
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
        child: Card(
          child: Column(
            children: [
              const SizedBox(height: 15),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : buildInvoiceList(),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      )
          : RefreshIndicator(
        onRefresh: () async {
          loadInvoices();
        },
        child: _pages[_selectedIndex],
      ),
      floatingActionButton: _selectedIndex == 0 && filteredInvoices.isNotEmpty // Conditional FAB
          ? FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.background,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Invoice()),
          ).then((_) {
            loadInvoices();
          });
        },
        child: Icon(Icons.add, color: Colors.white, size: 34),
      )
          : null,
      bottomNavigationBar: BottomAppBar(
        shape: CircularNotchedRectangle(),
        height: 65,
        notchMargin: 8.0,
        color: Theme.of(context).colorScheme.background,
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

  Widget _buildNavItem(IconData icon, String label, int index) {
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
          loadInvoices();
        },
        child: SizedBox(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: _selectedIndex == index ? Colors.white : Colors.white,
              ),
              SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: _selectedIndex == index ? Colors.white : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildInvoiceList() {
    return filteredInvoices.isEmpty
        ? Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {},
            child: Icon(
              FontAwesomeIcons.fileInvoice,
              color: Theme.of(context).colorScheme.onPrimaryFixedVariant,
              size: 80,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {},
            child: const Text(
              "No Invoices Available",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Invoice()),
              );
              loadInvoices();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.background,
            ),
            child: const Text(
              "Add New Invoice",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    )
        : ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (context, index) =>
          Divider(color: Colors.grey.shade300, thickness: 1),
      itemCount: filteredInvoices.length,
      itemBuilder: (context, index) {
        final invoice = filteredInvoices[index];
        bool isPaid = invoice['is_paid'] == 1;

        return GestureDetector(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Detail(
                  invoiceId: int.parse(invoice['invoice_id'].toString()),
                  clientid: int.parse(invoice['client_id'].toString()),
                  onStatusUpdated: loadInvoices,
                ),
              ),
            );

            if (result == true) {
              loadInvoices();
            }
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            padding: const EdgeInsets.all(2.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.background,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "${invoice['invoice_id']}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            invoice['client_company'] ?? "No Client",
                            style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 18),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            formatDate(invoice['invoic_date']),
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "₹ ${invoice['total_amount'].toStringAsFixed(2)}",
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: isPaid ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        isPaid ? "PAID" : "UNPAID",
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}