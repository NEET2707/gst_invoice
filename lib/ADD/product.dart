import 'package:flutter/material.dart';
import 'package:gst_invoice/DATABASE/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../color.dart';

class Product extends StatefulWidget {
  final Map<String, dynamic>? product;

  const Product({super.key, this.product});

  @override
  State<Product> createState() => _ProductState();
}

class _ProductState extends State<Product> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _gstController = TextEditingController();
  final TextEditingController _hsnController = TextEditingController();

  int? productId;
  bool _isGstApplicable = false;
  String _gstType = "same"; // Default to "same"

  String? _nameErrorText;
  String? _priceErrorText;
  String? _gstErrorText;



  @override
  void initState() {
    super.initState();
    _initializeProductPage(); // this handles async logic
  }

  Future<void> _initializeProductPage() async {
    await _loadGstPreference(); // Load GST settings from SharedPreferences

    if (widget.product != null) {
      productId = widget.product!['product_id'];
      _nameController.text = widget.product!['product_name'];
      _priceController.text = widget.product!['product_price'].toString();
      _hsnController.text = widget.product!['product_hsn'];

      if (_gstType == "product") {
        _gstController.text = widget.product!['product_gst'].toString();
      } else {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        _gstController.text = prefs.getString("gstRate") ?? "18";
      }
    }

    // Ensure UI is updated
    if (mounted) setState(() {});
  }

  Future<void> _loadGstPreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isGstApplicable = (prefs.getInt("isGstApplicable") ?? 0) == 1;
      _gstType = prefs.getString("gstType") ?? "same";

      if (_gstType == "same") {
        _gstController.text = prefs.getString("gstRate") ?? "18";
      }
    });
  }

  Future<void> saveOrUpdateProduct() async {
    String name = _nameController.text.trim();
    String priceText = _priceController.text.trim();
    String gstText = _gstController.text.trim();

    setState(() {
      _nameErrorText = name.isEmpty ? "This field is required" : null;
      _priceErrorText = priceText.isEmpty ? "This field is required" : null;
      _gstErrorText = (_isGstApplicable && gstText.isEmpty) ? "This field is required" : null;
    });

    if (_nameErrorText != null || _priceErrorText != null || _gstErrorText != null) {
      return;
    }

    double price = double.tryParse(priceText) ?? 0.0;
    double gst = _isGstApplicable
        ? (_gstType == "same" ? 18.0 : (double.tryParse(gstText) ?? 0.0))
        : 0.0;

    if (price <= 0 || (_isGstApplicable && gst < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid price or GST rate!')),
      );
      return;
    }

    Map<String, dynamic> productData = {
      'product_name': name,
      'product_price': price,
      'product_gst': gst,
      'product_hsn': _hsnController.text.trim(),
    };

    if (productId == null) {
      await DatabaseHelper().saveProduct(productData);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Product added successfully!')),
      );
    } else {
      productData['product_id'] = productId;
      await DatabaseHelper().updateProduct(productData);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Product updated successfully!')),
      );
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: themecolor,
        title: Text(productId == null ? "Add Product" : "Edit Product"),
        actions: [
          GestureDetector(
            onTap: saveOrUpdateProduct,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(Icons.check),
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildTextField("Product Name", "Enter Product Name",
                controller: _nameController, errorText: _nameErrorText),

            buildTextField("Price", "Enter Product Price",
                controller: _priceController,
                keyboardType: TextInputType.number,
                errorText: _priceErrorText),

            if (_isGstApplicable)
              buildTextField("GST Rate(%)", "Enter GST Rate",
                  controller: _gstController,
                  keyboardType: TextInputType.number,
                  readOnly: false,
                  errorText: _gstErrorText),

            buildTextField("HSN Code", "Enter HSN Code",
                keyboardType: TextInputType.number,
                controller: _hsnController),
          ],
        ),
      ),
    );
  }
}

Widget buildTextField(String label, String hint,
    {TextEditingController? controller,
      TextInputType? keyboardType,
      bool readOnly = false,
      String? errorText}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: errorText != null ? Colors.red : Colors.black)),
      SizedBox(height: 5),
      Container(
        decoration: BoxDecoration(
          color: readOnly ? Colors.grey.shade200 : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: errorText != null ? Colors.red : Colors.grey.shade300,
              width: 1.5),
        ),
        child: TextField(
          textCapitalization: TextCapitalization.sentences,
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: InputBorder.none,
            hintText: hint,
            hintStyle: TextStyle(
                color: errorText != null ? Colors.red : Colors.grey.shade400),
          ),
        ),
      ),
      if (errorText != null)
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 4),
          child: Text(errorText, style: TextStyle(color: Colors.red, fontSize: 12)),
        ),
      SizedBox(height: 10),
    ],
  );
}



