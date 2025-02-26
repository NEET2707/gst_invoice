import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gst_invoice/color.dart';
import 'add_client.dart';
import '../DATABASE/database_helper.dart';

class SelectClient extends StatefulWidget {
  const SelectClient({super.key});

  @override
  State<SelectClient> createState() => _SelectClientState();
}

class _SelectClientState extends State<SelectClient> {
  List<Map<String, dynamic>> clients = [];
  List<Map<String, dynamic>> filteredClients = [];
  TextEditingController searchController = TextEditingController();
  Map<String, dynamic>? selectedClient;


  @override
  void initState() {
    super.initState();
    fetchClients();
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
        backgroundColor: themecolor,
        title: const Text("Select Client"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(FontAwesomeIcons.userPlus),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddClient()),
              );
              fetchClients(); // Refresh list after adding a client
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(10.0),
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

                    Navigator.pop(context, selectedClient);
                    print("================");
                    print(selectedClient);
                  },

                  child: Card(
                    margin:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
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
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => AddClient(clientData: client,),));
                            },
                          ),
                          // Delete Button
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text("Delete Client"),
                                  content: const Text(
                                      "Are you sure you want to delete this client?"),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text("Cancel"),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        deleteClient(client['id']);
                                        Navigator.pop(context);
                                      },
                                      child: const Text("Delete",
                                          style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
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
    );
  }
}
