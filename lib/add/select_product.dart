import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gst_invoice/ADD/product.dart';
import 'package:gst_invoice/DATABASE/database_helper.dart';
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
  bool _isSearching = false;

  TextEditingController _searchController = TextEditingController();
  FocusNode searchFocusNode = FocusNode();

  late bool boom;

  @override
  void initState() {
    super.initState();
    fetchProducts();
    _searchController.addListener(() {
      filterProduct(_searchController.text);
    });
  }

  Future<void> fetchProducts() async {
    setState(() {
      isLoading = true;
    });

    final db = await DatabaseHelper.getDatabase();
    final List<Map<String, dynamic>> companyData = await db.query("company", limit: 1);
    bool isGstApplicable = companyData.isNotEmpty ? (companyData.first['is_tax'] == 1) : false;
    String gstType = companyData.isNotEmpty ? (companyData.first['default_state'] ?? "same") : "same";
    double gstRate = companyData.isNotEmpty ? (companyData.first['cgst'] ?? 18.0) * 2 : 18.0;

    final data = await DatabaseHelper().getProducts();

    setState(() {
      productList = data.map((product) {
        if (isGstApplicable && gstType == "same") {
          return {
            ...product,
            'product_gst': gstRate,
          };
        } else {
          return product;
        }
      }).toList();

      product = List.from(productList);
      filteredProducts = List.from(productList);
      isLoading = false;
    });
  }

  void filterProduct(String query) {
    setState(() {
      filteredProducts = productList
          .where((product) =>
      product['product_name'].toLowerCase().contains(query.toLowerCase()) ||
          product['product_code'].toString().contains(query))
          .toList();
    });
  }

  Future<void> deleteProduct(int productId) async {
    await DatabaseHelper().deleteProduct(productId);
    fetchProducts();
  }

  @override
  void dispose() {
    searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.background,
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: "Search Products...",
            border: InputBorder.none,
          ),
        )
            : const Text("Product"),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                _searchController.clear();
                if (!_isSearching) filterProduct('');
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5, bottom: 4, left: 5, right: 5),
          ),
          Expanded(
            child: Card(
              child: isLoading
                  ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
                  : productList.isEmpty
                  ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {},
                      child: Icon(
                        FontAwesomeIcons.warehouse,
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryFixedVariant,
                        size: 80,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {},
                      child: const Text(
                        "No Products Found",
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => Product()),
                        );
                        if (result != null && result == true) {
                          fetchProducts();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.background,
                      ),
                      child: const Text(
                        "Add New Products",
                        style: TextStyle(color: Colors.white),
                      ),
                    )
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4.0, vertical: 4),
                    child: InkWell(
                      onTap: () {
                        if (widget.isyes == true) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Invoice(
                                  product: [{...product, 'qty': 1}]),
                            ),
                          );
                        } else {
                          Navigator.pop(context, product);
                        }
                      },
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .background,
                              child: Text(
                                product['product_name']
                                    .toString()[0]
                                    .toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        product['product_name']
                                            .toString(),
                                        style: const TextStyle(
                                            fontWeight:
                                            FontWeight.w500,
                                            fontSize: 14),
                                        overflow:
                                        TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Padding(
                                      padding:
                                      const EdgeInsets.only(
                                          top: 14.0),
                                      child: Text(
                                        "₹${product['product_price']}",
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight:
                                            FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                        "${product['product_gst']}%",
                                        style: const TextStyle(
                                            fontSize: 11)),
                                    if (product['product_hsn'] !=
                                        null &&
                                        product['product_hsn']
                                            .toString()
                                            .trim()
                                            .isNotEmpty) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                          "/ ${product['product_hsn']}",
                                          style: const TextStyle(
                                              fontSize: 11)),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: Padding(
                              padding:
                              const EdgeInsets.only(left: 18.0),
                              child: Icon(Icons.more_vert,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .scrim),
                            ),
                            onSelected: (value) async {
                              if (value == 'edit') {
                                bool? result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        Product(product: product),
                                  ),
                                );
                                if (result == true) fetchProducts();
                              } else if (value == 'delete') {
                                _confirmDeleteProduct(
                                    context,
                                    product['product_id'],
                                    fetchProducts);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit,
                                        color: Colors.blue,
                                        size: 18),
                                    SizedBox(width: 6),
                                    Text("Edit",
                                        style:
                                        TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete,
                                        color: Colors.red,
                                        size: 18),
                                    SizedBox(width: 6),
                                    Text("Delete",
                                        style:
                                        TextStyle(fontSize: 13)),
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
      floatingActionButton: productList.isNotEmpty
          ? FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.background,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Product()),
          );
          fetchProducts();
        },
        child: const Icon(Icons.add, color: Colors.white, size: 34),
      )
          : null,
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
            Navigator.pop(context);
            _checkProductInInvoices(context, productId, onDelete);
          },
          child: const Text("Delete", style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

void _checkProductInInvoices(BuildContext context, int productId, VoidCallback onDelete) async {
  final db = await DatabaseHelper.getDatabase();

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
              for (var invoice in invoices) {
                await db.delete('invoice', where: 'invoice_id = ?', whereArgs: [invoice['invoice_id']]);
                await db.delete('invoice_line', where: 'invoice_id = ?', whereArgs: [invoice['invoice_id']]);
              }

              await db.delete('product', where: 'product_id = ?', whereArgs: [productId]);

              Navigator.pop(context, true);
              onDelete();
            },
            child: const Text("Delete All", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  } else {
    await db.delete('product', where: 'product_id = ?', whereArgs: [productId]);
    onDelete();
  }
}