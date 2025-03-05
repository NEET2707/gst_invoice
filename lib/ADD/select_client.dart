import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gst_invoice/ADD/invoice.dart';
import 'package:gst_invoice/color.dart';
import 'add_client.dart';
import '../DATABASE/database_helper.dart';

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
  Map<String, dynamic>? selectedClient;
  late bool back;


  @override
  void initState() {
    super.initState();
    fetchClients();
    back = widget.back;
    print("=======================$back");
  }

  Future<void> fetchClients() async {
    final db = await DatabaseHelper.getDatabase();
    List<Map<String, dynamic>> clientList = await db.query('client');

    setState(() {
      clients = clientList;
      filteredClients = clients; // Initially, show all clients
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
    await db.delete('client', where: 'id = ?', whereArgs: [clientId]);
    fetchClients(); // Refresh list after deletion
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: back,
        backgroundColor: themecolor,
        title: const Text("Select Client"),
        // leading: IconButton(
        //   icon: const Icon(Icons.arrow_back),
        //   onPressed: () => Navigator.pop(context),
        // ),
        // actions: [
        //   IconButton(
        //     icon: const Icon(FontAwesomeIcons.userPlus),
        //     onPressed: () async {
        //       await Navigator.push(
        //         context,
        //         MaterialPageRoute(builder: (context) => AddClient()),
        //       );
        //       fetchClients(); // Refresh list after adding a client
        //     },
        //   ),
        // ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              height: 50,
              child: TextField(
                controller: searchController,
                onChanged: filterClients,
                decoration: InputDecoration(
                  hintText: "Search",
                  prefixIcon: const Icon(Icons.search),
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
                : ListView.builder(
              itemCount: filteredClients.length,
              itemBuilder: (context, index) {
                final client = filteredClients[index];
                return GestureDetector(
                  onTap: () {
                    selectedClient = {
                      'client_id':client['client_id'].toString(),
                      'client_company': client['client_company'].toString(),
                      'client_address': client['client_address'].toString(),
                      'client_gstin': client['client_gstin'].toString(),
                      'client_state': client['client_state'].toString(),
                      'client_contact': client['client_contact'].toString(),
                    };


                    if(widget.pass == true)
                      Navigator.push(context, MaterialPageRoute(builder: (context) => Invoice(selectedClient: selectedClient,)));
                    else
                      Navigator.pop(context, selectedClient);

                    print("================");
                    print(selectedClient);
                  },

                  child: Card(
                    margin:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: themecolor,
                        child: Text(
                          client['client_company'][0].toUpperCase(), // Show first letter
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        client['client_company'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("State: ${client['client_state']}"),
                          // Text("Contact: ${client['client_contact']}"),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Edit Button
                      PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.black54),
                      onSelected: (value) async {
                        if (value == 'edit') {
                          bool? result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddClient(clientData: client),
                            ),
                          );

                          if (result == true) {
                            setState(() {}); // Refresh UI after editing
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
                                    deleteClient(client['id']);
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
        child: Icon(Icons.supervised_user_circle , color: Colors.white, size: 30),
      ),
    );
  }
}
