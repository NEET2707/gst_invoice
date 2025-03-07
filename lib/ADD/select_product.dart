import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gst_invoice/ADD/product.dart';
import 'package:gst_invoice/DATABASE/database_helper.dart'; // Import Database Helper
import '../color.dart';
import 'invoice.dart';

class SelectProduct extends StatefulWidget {
  bool isyes;
  bool boom;
  SelectProduct({super.key, this.isyes = false, required this.boom});

  @override
  State<SelectProduct> createState() => _SelectProductState();
}

class _SelectProductState extends State<SelectProduct> {
  List<Map<String, dynamic>> productList = [];
  List<Map<String, dynamic>> product = []; // ✅ Declare this
  List<Map<String, dynamic>> filteredProducts = []; // ✅ Declare this

  TextEditingController searchController = TextEditingController();
  late bool boom;

  @override
  void initState() {
    super.initState();
    fetchProducts();
    boom = widget.boom;
    print("00000000000000000000000000000$boom");
  }

  Future<void> fetchProducts() async {
    final data = await DatabaseHelper().getProducts();
    setState(() {
      productList = data;
      print("+++++++++++++++++++++++++++++++++++");
      print(productList);
      product = List.from(productList); // Ensures `product` gets a fresh copy
      filteredProducts = List.from(productList); // Rename and ensure consistency
    });
  }

  void filterProduct(String query) {
    setState(() {
      filteredProducts = productList
          .where((product) =>
      product['product_name']
          .toLowerCase()
          .contains(query.toLowerCase()) ||
          product['product_code'].toString().contains(query)) // Use relevant fields
          .toList();
    });
  }

  Future<void> deleteProduct(int productId) async {
    await DatabaseHelper().deleteProduct(productId);
    fetchProducts(); // Refresh the list after deletion
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: boom,
        backgroundColor: themecolor,
        title: const Text("Select Product"),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.only(top: 10,bottom: 6, left: 5, right: 5),
            child: SizedBox(
              height: 50,
              child: TextField(
                controller: searchController,
                onChanged: filterProduct,
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

          // Display Products in Card View
          Expanded(
            child: productList.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    FontAwesomeIcons.warehouse,
                    color: themecolor,
                    size: 80,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "No Products Found",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            )
                : Card(
              child: ListView.separated(
                itemCount: filteredProducts.length,
                separatorBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Divider(color: Colors.grey.shade300, thickness: 1),
                ),
                itemBuilder: (context, index) {
                  final product = filteredProducts[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: themecolor,
                      child: Text(
                        product['product_name'][0].toUpperCase(),
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(product['product_name'], style: TextStyle(fontWeight: FontWeight.w500, fontSize: 18)),
                    subtitle: Text("₹${product['product_price']} | GST: ${product['product_gst']}%"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: Colors.black54), // Three-dot icon
                          onSelected: (value) async {
                            if (value == 'edit') {
                              bool? result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => Product(product: product), // Pass product data
                                ),
                              );
                              if (result == true) {
                                fetchProducts(); // Refresh the product list after update
                                print("Product list updated");
                              }
                            } else if (value == 'delete') {
                              _confirmDeleteProduct(context, product['product_id']); // Show delete confirmation
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
                        ),

                      ],
                    ),
                    onTap: () {
                      if(widget.isyes == true)
                        Navigator.push(context, MaterialPageRoute(builder: (context) => Invoice(product: productList)));
                      else
                        Navigator.pop(context, product);
                    },
                  );
                                },
                              ),
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: themecolor,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Product()),
          );
          fetchProducts(); // Refresh the product list after adding
        },
        child: Icon(Icons.add, color: Colors.white, size: 34), // Using a store icon as a replacement
      ),
    );
  }
}

void _confirmDeleteProduct(BuildContext context, int productId) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Delete Product"),
      content: const Text("Are you sure you want to delete this product?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () async {
            await DatabaseHelper().deleteProduct(productId);
            await DatabaseHelper().getProducts();
            Navigator.pop(context);
          },
          child: const Text("Delete", style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

