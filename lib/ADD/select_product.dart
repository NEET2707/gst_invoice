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
  FocusNode searchFocusNode = FocusNode();

  late bool boom;

  @override
  void initState() {
    super.initState();
    fetchProducts();
    boom = widget.boom;
    print("00000000000000000000000000000$boom");
    searchController.addListener(() => setState(() {}));
    searchFocusNode.addListener(() => setState(() {}));
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
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
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
      // ✅ Fixed: Search Bar with Padding
      Padding(
      padding: const EdgeInsets.only(top: 5, bottom: 4, left: 5, right: 5),
      child: SizedBox(
        height: 40,
        child: TextField(
          controller: searchController,
          focusNode: searchFocusNode,
          onChanged: filterProduct,
          decoration: InputDecoration(
            hintText: "Search",
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: searchFocusNode.hasFocus
                ? IconButton(
              icon: const Icon(Icons.clear, size: 20),
              onPressed: () {
                searchController.clear();
                filterProduct('');
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
                separatorBuilder: (context, index) => Divider(
                  color: Colors.grey.shade300,
                  thickness: 0.5,
                  height: 0,
                ),
                itemBuilder: (context, index) {
                  final product = filteredProducts[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4), // tighter spacing
                    child: InkWell(
                      onTap: () {
                        if (widget.isyes == true)
                          Navigator.push(context, MaterialPageRoute(builder: (context) => Invoice(product: productList)));
                        else
                          Navigator.pop(context, product);
                      },
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16, // smaller avatar
                            backgroundColor: themecolor,
                            child: Text(
                              product['product_name'][0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        product['product_name'],
                                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 14.0),
                                      child: Text(
                                        "₹${product['product_price']}",
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text("${product['product_gst']}%", style: const TextStyle(fontSize: 11)),
                                    if (product['product_hsn'] != null && product['product_hsn'].toString().trim().isNotEmpty) ...[
                                      const SizedBox(width: 4),
                                      Text("/ ${product['product_hsn']}", style: const TextStyle(fontSize: 11)),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),

                          PopupMenuButton<String>(
                            icon: Padding(
                              padding: const EdgeInsets.only(left: 24.0),
                              child: Icon(Icons.more_vert,  color: Colors.black54),
                            ),
                            // constraints: BoxConstraints(minWidth: 1000),
                            onSelected: (value) async {
                              if (value == 'edit') {
                                bool? result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => Product(product: product),
                                  ),
                                );
                                if (result == true) fetchProducts();
                              } else if (value == 'delete') {
                                _confirmDeleteProduct(context, product['product_id']);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, color: Colors.blue, size: 18),
                                    SizedBox(width: 6),
                                    Text("Edit", style: TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red, size: 18),
                                    SizedBox(width: 6),
                                    Text("Delete", style: TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
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

