import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gst_invoice/ADD/product.dart';
import 'package:gst_invoice/DATABASE/database_helper.dart'; // Import Database Helper
import 'package:shared_preferences/shared_preferences.dart';
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
  List<Map<String, dynamic>> product = [];
  List<Map<String, dynamic>> filteredProducts = [];
  bool isLoading = true;

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
    setState(() {
      isLoading = true;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isGstApplicable = (prefs.getInt("isGstApplicable") ?? 0) == 1;
    String gstType = prefs.getString("gstType") ?? "same";
    String gstRate = prefs.getString("gstRate") ?? "18";

    final data = await DatabaseHelper().getProducts();

    setState(() {
      productList = data.map((product) {
        if (isGstApplicable && gstType == "same") {
          return {
            ...product,
            'product_gst': double.tryParse(gstRate) ?? 18.0,
          };
        } else {
          return product;
        }
      }).toList();

      product = List.from(productList);
      filteredProducts = List.from(productList);
      isLoading = false; // Done loading
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
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : productList.isEmpty
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
                : ListView.separated(
                  itemCount: filteredProducts.length,
                  separatorBuilder: (context, index) => Divider(
                    color: Colors.grey.shade300,
                    thickness: 0.5,
                    height: 0,
                    indent: 15,
                    endIndent: 15,
                  ),
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4), // tighter spacing
                      child: InkWell(
                        onTap: () {
                          if (widget.isyes == true)
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => Invoice(product: [{...product, 'qty': 1}]), // 👈 Add qty here
                              ),
                            );
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
                                padding: const EdgeInsets.only(left: 18.0),
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
                                  _confirmDeleteProduct(context, product['product_id'], fetchProducts);
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

void _confirmDeleteProduct(BuildContext context, int productId, VoidCallback onDelete) {
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
            Navigator.pop(context); // Close first dialog
            _checkProductInInvoices(context, productId, onDelete); // Proceed to second check
          },
          child: const Text("Delete", style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

void _checkProductInInvoices(BuildContext context, int productId, VoidCallback onDelete) async {
  final db = await DatabaseHelper.getDatabase();

  // Fetch invoices where this product is present
  final List<Map<String, dynamic>> invoices = await db.rawQuery(
    '''
    SELECT DISTINCT invoice.invoice_id 
    FROM invoice 
    JOIN invoice_line ON invoice.invoice_id = invoice_line.invoice_id
    WHERE invoice_line.product_id = ?
    ''',
    [productId],
  );

  if (invoices.isNotEmpty) {
    // Show confirmation dialog listing associated invoices
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Product Linked to Invoices"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("This product is used in the following invoices. Deleting it will also delete these invoices:"),
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
              // Delete related invoices and product
              for (var invoice in invoices) {
                await db.delete('invoice', where: 'invoice_id = ?', whereArgs: [invoice['invoice_id']]);
                await db.delete('invoice_line', where: 'invoice_id = ?', whereArgs: [invoice['invoice_id']]);
              }

              // Delete product after invoices are removed
              await db.delete('product', where: 'product_id = ?', whereArgs: [productId]);

              Navigator.pop(context,true); // Close dialog
              onDelete(); // Refresh product list
            },
            child: const Text("Delete All", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  } else {
    // If product is not linked to any invoices, delete it directly
    await db.delete('product', where: 'product_id = ?', whereArgs: [productId]);
    onDelete(); // Refresh product list
  }
}

