import 'package:flutter/material.dart';
import 'package:gst_invoice/ADD/invoice.dart';
import 'package:gst_invoice/color.dart';
import 'add_client.dart';
import '../../DATABASE/database_helper.dart';
import 'client_detail.dart';

class SelectClient extends StatefulWidget {
  bool pass;
  bool back;
  SelectClient({super.key,  this.pass = false, required this.back});

  @override
  State<SelectClient> createState() => _SelectClientState();
}

class _SelectClientState extends State<SelectClient> {
  List<Map<String, dynamic>> clients = [];
  List<Map<String, dynamic>> filteredClients = [];
  TextEditingController searchController = TextEditingController();
  FocusNode searchFocusNode = FocusNode();
  Map<String, dynamic>? selectedClient;
  late bool back;
  bool isLoading = true;


  @override
  void initState() {
    super.initState();
    fetchClients();
    back = widget.back;
    print("=======================$back");
    searchController.addListener(() => setState(() {}));
    searchFocusNode.addListener(() => setState(() {}));
  }

  Future<void> fetchClients() async {
    setState(() {
      isLoading = true;
    });

    final db = await DatabaseHelper.getDatabase();
    List<Map<String, dynamic>> clientList = await db.query('client');

    setState(() {
      clients = clientList;
      filteredClients = clients;
      isLoading = false;
    });
  }


  void filterClients(String query) {
    setState(() {
      filteredClients = clients
          .where((client) =>
      client['client_company']
          .toLowerCase()
          .contains(query.toLowerCase()) ||
          client['client_contact'].toString().contains(query))
          .toList();
    });
  }

  Future<void> deleteClient(int clientId) async {
    final db = await DatabaseHelper.getDatabase();

    // Check if the client has associated invoices
    final List<Map<String, dynamic>> invoices = await db.query(
      'invoice',
      where: 'client_id = ?',
      whereArgs: [clientId],
    );

    if (invoices.isNotEmpty) {
      // Show confirmation dialog listing associated invoices
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Client Linked to Invoices"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("This client has invoices associated with it. Deleting the client will also delete the following invoices:"),
              const SizedBox(height: 10),
              ...invoices.map((invoice) => Text("Invoice ID: ${invoice['invoice_id']}")),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                // Delete all invoices associated with this client
                for (var invoice in invoices) {
                  await db.delete(
                    'invoice',
                    where: 'invoice_id = ?',
                    whereArgs: [invoice['invoice_id']],
                  );

                  await db.delete(
                    'invoice_line',
                    where: 'invoice_id = ?',
                    whereArgs: [invoice['invoice_id']],
                  );
                }

                // Delete the client after invoices are deleted
                await db.delete('client', where: 'client_id = ?', whereArgs: [clientId]);

                Navigator.pop(context,true); // Close dialog
                fetchClients(); // Refresh UI
              },
              child: const Text("Delete All", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    } else {
      // No invoices found, proceed with client deletion
      await db.delete('client', where: 'client_id = ?', whereArgs: [clientId]);
      fetchClients(); // Refresh UI
    }
  }


  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: back,
        backgroundColor: themecolor,
        title: const Text("Select Client"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // ✅ Fixed: Search Bar with Padding
          Padding(
            padding: const EdgeInsets.only(top: 5, bottom: 4, left: 5, right: 5),
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: searchController,
                focusNode: searchFocusNode,
                onChanged: filterClients,
                decoration: InputDecoration(
                  hintText: "Search",
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: searchFocusNode.hasFocus
                      ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      searchController.clear();
                      filterClients('');
                      FocusScope.of(context).unfocus(); // optional: hide keyboard
                    },
                  )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
          ),

          // Client List
          Expanded(
            child: filteredClients.isEmpty
                ? const Center(child: Text("No Clients Found"))
                : ListView.separated( // ✅ Use ListView.separated
                  itemCount: filteredClients.length,
                  separatorBuilder: (context, index) => Divider(
                    color: Colors.grey.shade300,
                    thickness: 0.5,
                    height: 0,
                    endIndent: 15,
                    indent: 15,
                  ),
                  itemBuilder: (context, index) {
                    final client = filteredClients[index];
                    return GestureDetector(
                        onTap: () async {
                          selectedClient = {
                            'client_id': client['client_id'].toString(),
                            'client_company': client['client_company'].toString(),
                            'client_address': client['client_address'].toString(),
                            'client_gstin': client['client_gstin'].toString(),
                            'client_state': client['client_state'].toString(),
                            'client_contact': client['client_contact'].toString(),
                          };

                          if (widget.pass == true) {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => ClientDetail(clientId: client['client_id'])),
                            );

                            if (result != null) {
                              Navigator.pop(context, result); // ✅ Return selected client back to previous screen (Invoice or Settings)
                            }
                          } else {
                            Navigator.pop(context, selectedClient); // ✅ Basic return if just selecting
                          }
                        },

                        child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                        minLeadingWidth: 0,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: themecolor,
                          child: Text(
                            client['client_company'][0].toUpperCase(), // Show first letter
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    client['client_company'],
                                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  client['client_state'].toString(),
                                  style: const TextStyle(color: Colors.black54, fontSize: 11),
                                ),
                              ],
                            ),
                            SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("${client['client_contact']}", style: TextStyle(fontSize: 11)), // Left side
                                Text("${client['client_gstin']}", style: TextStyle(fontSize: 11)), // Right side
                              ],
                            )
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PopupMenuButton<String>(
                              icon: Padding(
                                padding: const EdgeInsets.only(left: 20),
                                child: Icon(Icons.more_vert, color: Colors.black54),
                              ),
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  bool? result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AddClient(clientData: client),
                                    ),
                                  );
                                  if (result == true) {
                                    fetchClients();
                                    setState(() {});
                                  }
                                } else if (value == 'delete') {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text("Delete Client"),
                                      content: const Text("Are you sure you want to delete this client?"),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text("Cancel"),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            deleteClient(client['client_id']);
                                            Navigator.pop(context);
                                            setState(() {}); // Refresh UI after deletion
                                          },
                                          child: const Text("Delete", style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, color: Colors.blue),
                                      SizedBox(width: 8),
                                      Text("Edit"),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text("Delete"),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),

                    );
                                  },
                                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: themecolor,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddClient()),
          );
          fetchClients();
        },
        child: Icon(Icons.add , color: Colors.white, size: 34),
      ),
    );
  }
}
