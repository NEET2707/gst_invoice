import 'package:flutter/material.dart';
import 'package:gst_invoice/color.dart';
import 'package:intl/intl.dart';

import '../../DATABASE/database_helper.dart';
import '../../detail.dart';
import '../invoice.dart';

class ClientDetail extends StatefulWidget {
  final int clientId;
  ClientDetail({super.key, required this.clientId});
  @override
  State<ClientDetail> createState() => _ClientDetailState();
}

class _ClientDetailState extends State<ClientDetail> {
  List<Map<String, dynamic>> clientInvoices = [];
  bool isLoading = true;
  Map<String, dynamic>? selectedClient;
  Map<String, dynamic>? clientDetail;

  @override
  void initState() {
    super.initState();
    fetchClientInvoices();
  }

  Future<void> fetchClientInvoices() async {
    final db = await DatabaseHelper.getDatabase();

    // Fetch invoices
    final result = await db.rawQuery('''
    SELECT invoice.*, client.client_company
    FROM invoice
    JOIN client ON invoice.client_id = client.client_id
    WHERE invoice.client_id = ?
    ORDER BY invoice.invoice_id DESC
  ''', [widget.clientId]);

    // Fetch client detail
    final clientResult = await db.query(
      'client',
      where: 'client_id = ?',
      whereArgs: [widget.clientId],
    );

    setState(() {
      clientInvoices = result;
      clientDetail = clientResult.isNotEmpty ? clientResult.first : null;
      isLoading = false;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      appBar: AppBar(
        backgroundColor: themecolor,
        title: Text(
          clientDetail != null ? clientDetail!['client_company'] ?? "" : "",
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            clientDetail == null
                ? Center(child: CircularProgressIndicator())
                : Card(
              child: Padding(
                padding: EdgeInsets.all(10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((clientDetail!['client_gstin'] ?? '').toString().trim().isNotEmpty)
                            Text("${clientDetail!['client_gstin']}",style: TextStyle(fontWeight: FontWeight.w500),),
                          if ((clientDetail!['client_state'] ?? '').toString().trim().isNotEmpty)
                            Text("${clientDetail!['client_state']}",style: TextStyle(fontWeight: FontWeight.w500),),
                          if ((clientDetail!['client_contact'] ?? '').toString().trim().isNotEmpty)
                            Text("${clientDetail!['client_contact']}",style: TextStyle(fontWeight: FontWeight.w500),),
                          if ((clientDetail!['client_address'] ?? '').toString().trim().isNotEmpty)
                            Text("${clientDetail!['client_address']}",style: TextStyle(fontWeight: FontWeight.w500),),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 5),
            Expanded(
              child: Card(
                child: isLoading
                    ? Center(child: CircularProgressIndicator())
                    : clientInvoices.isEmpty
                    ? Center(child: Text("No Invoices Found for this Client"))
                    : ListView.separated(
                  padding: EdgeInsets.all(0),
                  itemCount: clientInvoices.length,
                  separatorBuilder: (context, index) => Divider(),
                  itemBuilder: (context, index) {
                    final invoice = clientInvoices[index];
                    bool isPaid = invoice['is_paid'] == 1;

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Detail(
                              invoiceId: int.parse(invoice['invoice_id'].toString()),
                              clientid: widget.clientId,
                              onStatusUpdated: fetchClientInvoices,
                            ),
                          ),
                        );
                      },
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        dense: true,
                        visualDensity: VisualDensity(vertical: -2),
                        minLeadingWidth: 30,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: themecolor,
                          child: Text(
                            "${invoice['invoice_id']}",
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        title: Text(
                          invoice['client_company'] ?? "No Name",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          formatDate(invoice['invoic_date']),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "₹ ${invoice['total_amount'].toStringAsFixed(2)}",
                              style: TextStyle(fontSize: 13),
                            ),
                            SizedBox(height: 2),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: themecolor,
        onPressed: () async {
          final db = await DatabaseHelper.getDatabase();
          final result = await db.query('client', where: 'client_id = ?', whereArgs: [widget.clientId]);

          if (result.isNotEmpty) {
            selectedClient = {
              'client_id': result[0]['client_id'],
              'client_company': result[0]['client_company'],
              'client_address': result[0]['client_address'],
              'client_gstin': result[0]['client_gstin'],
              'client_state': result[0]['client_state'],
              'client_contact': result[0]['client_contact'],
            };

            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => Invoice(selectedClient: selectedClient)),
            );
          }
          // fetchClients();
        },
        child: Icon(Icons.add , color: Colors.white, size: 34),
      ),
    );
  }
}

