import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static Database? _database;
  static const String dbName = "company.db";

  static Future<Database> getDatabase() async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, dbName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await _createTables(db);
      },
    );
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS client (
        client_id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_contact INTEGER,
        client_company TEXT,
        client_address TEXT,
        client_state TEXT,
        client_gstin TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS product (
        product_id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_name TEXT,
        product_price FLOAT,
        product_gst FLOAT,
        product_hsn TEXT,
        is_delete INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS company (
        company_id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_name TEXT,
        company_gstin TEXT,
        company_address TEXT,
        company_state TEXT,
        company_contact INTEGER,
        is_tax INTEGER,
        cgst FLOAT,
        sgst FLOAT,
        igst FLOAT,
        default_state TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoice (
        invoice_id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id INTEGER,
        total_cgst FLOAT,
        total_sgst FLOAT,
        total_igst FLOAT,
        taxable_amount FLOAT,
        total_tax FLOAT,
        total_amount FLOAT,
        invoic_date DATE,
        due_date DATE,
        date_added DATE,
        date_modified DATE,
        is_equal_state INTEGER,
        is_tax INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoice_line (
        invoice_line_id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER,
        product_id INTEGER,
        lineprodgst FLOAT,
        price FLOAT,
        qty INTEGER,
        total FLOAT,
        cgst FLOAT,
        sgst FLOAT,
        igst FLOAT,
        dateadded DATE,
        discount REAL DEFAULT 0
      )
    ''');



    await db.execute('''
      CREATE TABLE IF NOT EXISTS setting (
        setting_id INTEGER PRIMARY KEY AUTOINCREMENT,
        last_backup_date DATE,
        last_cloude_backup_date DATE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS companylogo (
        logo_id INTEGER PRIMARY KEY AUTOINCREMENT,
        logo TEXT
      )
    ''');
  }

  Future<int> insertCompany(Map<String, dynamic> companyData) async {
    final db = await getDatabase();
    print("Inserting company data: $companyData");
    int result = await db.insert("company", companyData);
    print("Insert result: $result");
    return result;
  }

  Future<int> saveClient(Map<String, dynamic> clientData) async {
    final db = await getDatabase();
    return await db.insert('client', clientData);
  }

  Future<int> saveProduct(Map<String, dynamic> productData) async {
    final db = await getDatabase();
    return await db.insert(
      'product',
      productData,
      conflictAlgorithm: ConflictAlgorithm.replace, // Replace existing entry if conflict
    );
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    final db = await getDatabase();
    final List<Map<String, dynamic>> result = await db.query('product'); // Ensure table name is correct
    print("Fetched Products: $result");
    return result;
  }


  Future<int> deleteProduct(int productId) async {
    final db = await getDatabase();
    return await db.delete('product', where: 'product_id = ?', whereArgs: [productId]);
  }

  Future<int> updateProduct(Map<String, dynamic> product) async {
    final db = await getDatabase();
    return await db.update(
      'product',
      product,
      where: 'product_id = ?',
      whereArgs: [product['product_id']],
    );
  }

  Future<int?> getCompanyId() async {
    final db = await getDatabase();
    List<Map<String, dynamic>> result = await db.query("company");
    if (result.isNotEmpty) {
      return result.first["id"]; // Assuming 'id' is the primary key
    }
    return null;
  }

  Future<int> updateCompany(int id, Map<String, dynamic> companyData) async {
    final db = await getDatabase();
    return await db.update("company", companyData, where: "id = ?", whereArgs: [id]);
  }

  static Future<int> saveInvoiceLine(Map<String, dynamic> data) async {
    final db = await getDatabase();
    return await db.insert('invoice_line', data);
  }

  static Future<List<Map<String, dynamic>>> fetchInvoiceLines(int invoiceId) async {
    final db = await getDatabase();
    return await db.query('invoice_line', where: 'invoice_id = ?', whereArgs: [invoiceId]);
  }

  static Future<int> updateInvoiceLine(int id, Map<String, dynamic> data) async {
    final db = await getDatabase();
    return await db.update('invoice_line', data, where: 'invoice_line_id = ?', whereArgs: [id]);
  }

  static Future<int> deleteInvoiceLine(int id) async {
    final db = await getDatabase();
    return await db.delete('invoice_line', where: 'invoice_line_id = ?', whereArgs: [id]);
  }
}

Future<int> saveInvoice(Map<String, dynamic> invoiceData) async {
  final db = await DatabaseHelper.getDatabase();
  return await db.insert('invoice', invoiceData);
}

Future<List<Map<String, dynamic>>> fetchInvoices() async {
  final db = await DatabaseHelper.getDatabase();
  return await db.query('invoice', orderBy: 'invoice_id DESC');
}



