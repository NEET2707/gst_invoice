import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';

import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static Database? _database;
  static const String dbName = "cashbook.db";

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
      version: 10,
      onCreate: (db, version) async {
        await _createTables(db);
        Fluttertoast.showToast(msg: "db is created");
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await db.execute(
              "ALTER TABLE invoice ADD COLUMN is_paid INTEGER DEFAULT 0");
        }
        if (oldVersion < 4) {
          await db.execute("ALTER TABLE company ADD COLUMN BankDetails TEXT");
        }
        if (oldVersion < 5) {
          await db.execute("ALTER TABLE company ADD COLUMN TandC TEXT");
        }
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
    default_state TEXT,
    BankDetails TEXT,
    TandC TEXT
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
    discount REAL DEFAULT 0,  
    invoic_date DATE,
    due_date DATE,
    date_added DATE,
    date_modified DATE,
    is_equal_state INTEGER,
    is_tax INTEGER,
    is_paid INTEGER DEFAULT 0
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
    discount REAL DEFAULT 0,
    FOREIGN KEY (invoice_id) REFERENCES invoice(invoice_id),
    FOREIGN KEY (product_id) REFERENCES product(product_id)
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

  Future<bool> isCompanyDataAvailable() async {
    final db = await DatabaseHelper.getDatabase();
    final List<Map<String, dynamic>> result =
    await db.query("company", limit: 1);
    return result.isNotEmpty;
  }

  Future<Map<String, dynamic>> getCompanyDetails() async {
    final db = await DatabaseHelper.getDatabase();
    final List<Map<String, dynamic>> result =
    await db.query("company", limit: 1);
    return result.isNotEmpty ? result.first : {};
  }

  Future<int> insertCompany(Map<String, dynamic> companyData) async {
    final db = await getDatabase();

    companyData["BankDetails"] = companyData["BankDetails"]?.isNotEmpty == true
        ? companyData["BankDetails"]
        : null;
    companyData["TandC"] =
    companyData["TandC"]?.isNotEmpty == true ? companyData["TandC"] : null;
    print(companyData);
    print("44444444444444444444444444444444444");

    print("Inserting company data: $companyData");
    int result = await db.insert("company", companyData,
        conflictAlgorithm: ConflictAlgorithm.replace);
    print("Insert result: $result");
    return result;
  }

  Future<int> updateCompany(int id, Map<String, dynamic> companyData) async {
    final db = await getDatabase();
    return await db.update("company", companyData,
        where: "company_id = ?", whereArgs: [id]);
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
      conflictAlgorithm:
      ConflictAlgorithm.replace, // Replace existing entry if conflict
    );
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    final db = await getDatabase();
    final List<Map<String, dynamic>> result =
    await db.query('product'); // Ensure table name is correct
    print("Fetched Products: $result");
    return result;
  }

  Future<int> deleteProduct(int productId) async {
    final db = await getDatabase();
    return await db
        .delete('product', where: 'product_id = ?', whereArgs: [productId]);
  }

  Future<void> deleteProductWithInvoices(int productId) async {
    final db = await getDatabase();

    // Check if the product exists in any invoice line
    List<Map<String, dynamic>> invoiceLines = await db.query(
      'invoice_line',
      where: 'product_id = ?',
      whereArgs: [productId],
    );

    if (invoiceLines.isNotEmpty) {
      // Extract unique invoice IDs related to this product
      List<int> invoiceIds = invoiceLines
          .map((line) => line['invoice_id'] as int)
          .toSet()
          .toList();

      // Delete invoice lines associated with this product
      await db.delete('invoice_line',
          where: 'product_id = ?', whereArgs: [productId]);

      // Check if any invoices are now empty and delete them
      for (int invoiceId in invoiceIds) {
        List<Map<String, dynamic>> remainingLines = await db.query(
          'invoice_line',
          where: 'invoice_id = ?',
          whereArgs: [invoiceId],
        );

        if (remainingLines.isEmpty) {
          // If no more items are in the invoice, delete the invoice
          await db.delete('invoice',
              where: 'invoice_id = ?', whereArgs: [invoiceId]);
        }
      }
    }

    // Finally, delete the product itself
    await db.delete('product', where: 'product_id = ?', whereArgs: [productId]);
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

  static Future<int> saveInvoiceLine(Map<String, dynamic> data) async {
    final db = await getDatabase();
    return await db.insert('invoice_line', data);
  }

  static Future<List<Map<String, dynamic>>> fetchInvoiceLines(
      int invoiceId) async {
    final db = await getDatabase();
    return await db
        .query('invoice_line', where: 'invoice_id = ?', whereArgs: [invoiceId]);
  }

  static Future<int> updateInvoiceLine(int id,
      Map<String, dynamic> data) async {
    final db = await getDatabase();
    return await db.update('invoice_line', data,
        where: 'invoice_line_id = ?', whereArgs: [id]);
  }

  static Future<int> deleteInvoiceLine(int id) async {
    final db = await getDatabase();
    return await db
        .delete('invoice_line', where: 'invoice_line_id = ?', whereArgs: [id]);
  }

  Future<void> saveCompanyLogo(String base64Image) async {
    final db = await DatabaseHelper.getDatabase();
    await db.delete('companylogo');
    await db.insert('companylogo', {'logo': base64Image});
  }

  Future<List<Map<String, dynamic>>> getCompanyDetailsFromDB() async {
    final db = await getDatabase();

    // Explicitly query default_state
    List<Map<String, dynamic>> result = await db.rawQuery('''
    SELECT 
      company_name, 
      company_gstin, 
      company_address, 
      company_state, 
      company_contact, 
      is_tax, 
      cgst, 
      sgst, 
      igst, 
      default_state, -- ✅ Ensure this column is included
      BankDetails, 
      TandC 
    FROM company 
    LIMIT 1
  ''');

    print("🔹 Retrieved Company Data: $result"); // Debugging log
    return result;
  }

  Future<String?> getCompanyLogo() async {
    final db = await DatabaseHelper.getDatabase();
    List<Map<String, dynamic>> result = await db.query('companylogo');
    return result.isNotEmpty ? result.first['logo'] : null;
  }

  static Future<List<Map<String, dynamic>>> getProductWiseReport(
      DateTime selectedDate) async {
    final db = await DatabaseHelper.getDatabase();

    String month = selectedDate.month.toString().padLeft(2, '0');
    String year = selectedDate.year.toString();

    return await db.rawQuery('''
    SELECT 
      p.product_name,
      SUM(il.qty) as total_qty,
      SUM(il.total) as total_amount,
      SUM(il.cgst) as total_cgst,
      SUM(il.sgst) as total_sgst,
      SUM(il.igst) as total_igst,
      SUM(il.discount) as total_discount
    FROM invoice_line il
    JOIN product p ON il.product_id = p.product_id
    WHERE substr(il.dateadded, 4, 2) = ? AND substr(il.dateadded, 7, 4) = ?
    GROUP BY il.product_id
  ''', [month, year]);
  }

  static Future<List<Map<String, dynamic>>> getClientReport(
      DateTime selectedDate) async {
    final db = await DatabaseHelper.getDatabase();

    String month = selectedDate.month.toString().padLeft(2, '0');
    String year = selectedDate.year.toString();

    return await db.rawQuery('''
  SELECT 
    i.invoice_id,  -- Use invoice_id instead of invoice_number if needed
    i.date_added,
    c.client_company,
    i.total_amount
  FROM invoice i
  JOIN client c ON i.client_id = c.client_id
  WHERE substr(i.date_added, 6, 2) = ? AND substr(i.date_added, 1, 4) = ?
  ORDER BY i.date_added
''', [month, year]);
  }

  /// **Request Storage Permission (for Android 13 and below)**
  static Future<bool> requestStoragePermission() async {
    if (await Permission.storage
        .request()
        .isGranted) {
      return true;
    }
    if (await Permission.manageExternalStorage
        .request()
        .isGranted) {
      return true;
    }

    print("❌ Storage permission denied!");
    return false;
  }

  static Future<bool> backupDatabase() async {
    if (!await requestStoragePermission()) {
      print("Storage permission denied!");
      return false;
    }
    final _saf = SafUtil();
    try {
      String? pickedDirectory = await _saf.openDirectory();
      if (pickedDirectory == null) {
        print("❌ No directory selected!");
        return false;
      }

      String filePath = "$pickedDirectory/backup.csv";

      bool success = await exportToCSV(filePath);
      return success;
    } catch (e) {
      print("❌ Error during backup: $e");
      return false;
    }
  }

  static Future<bool> restoreDatabase() async {
    if (!await requestStoragePermission()) {
      print("Storage permission denied!");
      return false;
    }

    try {
      bool success = await importFromCSV();
      return success;
    } catch (e) {
      print("❌ Error during restore: $e");
      return false;
    }
  }

  Future<String?> picksafdirectory() async {
    final _safUtil = SafUtil();
    String? selectedDirectory = await _safUtil.openDirectory();
    if (selectedDirectory == null) {
      Fluttertoast.showToast(msg: "No folder selected.");
      return null;
    }
    return selectedDirectory;
  }

  static Future<bool> exportToCSV(String filePath) async {
    final _safStreamPlugin = SafStream();
    final _safUtil = SafUtil();
    // String? selectedDirectory = await _safUtil.openDirectory();
    try {
      Database db = await getDatabase();
      List<String> tables = [
        'client',
        'product',
        'invoice',
        'invoice_line',
        'companylogo'
      ];

      List<List<String>> csvData = [];
      for (String table in tables) {
        List<Map<String, dynamic>> rows = await db.query(table);
        print("roesssss : $rows");
        if (rows.isNotEmpty) {
          csvData.add([table]); // Table name
          csvData.add(rows.first.keys.toList()); // Column headers
          for (var row in rows) {
            csvData.add(row.values.map((value) => value.toString()).toList());
          }
        }
      }
      String csv = const ListToCsvConverter().convert(csvData);
      Uint8List unitdata = Uint8List.fromList(csv.codeUnits);
      await _safStreamPlugin.writeFileBytes(
          filePath, "backup.csv", "text/csv", unitdata);

      print("✅ Exported Success");
      return true;
    } catch (e) {
      print("❌ Error during export: $e");
      return false;
    }
  }

  static Future<bool> importFromCSV() async {
    final _safUtil = SafUtil();
    String? selectedFilePath =
    await _safUtil.openFile(); // Use openFile() for file selection

    if (selectedFilePath == null) {
      print("❌ No file selected.");
      return false;
    }

    try {
      final _safStreamPlugin = SafStream();
      Uint8List fileBytes =
      await _safStreamPlugin.readFileBytes(selectedFilePath);

      // Convert bytes to string
      String fileContent = utf8.decode(fileBytes);
      List<List<dynamic>> csvData =
      const CsvToListConverter().convert(fileContent);

      print("CSV Data: $csvData");

      Database db = await getDatabase();
      String? currentTable;
      List<String> tables = [
        'client',
        'product',
        'invoice',
        'invoice_line',
        'companylogo'
      ];

      for (int rowIndex = 0; rowIndex < csvData.length; rowIndex++) {
        List<dynamic> row = csvData[rowIndex];

        if (row.isEmpty) continue; // Skip empty rows

        if (row.length == 1 &&
            tables.contains(row[0].toString().trim().toLowerCase())) {
          // Identify new table
          currentTable = row[0].toString().trim();
          print("Switching to table: $currentTable");
        } else if (currentTable != null && rowIndex > 0) {
          // Check if this row is the column headers
          List<String> columns =
          csvData[rowIndex - 1].map((e) => e.toString()).toList();
          if (columns.length <= 1) continue; // Skip invalid headers

          Map<String, dynamic> rowData = {};
          for (int i = 0; i < columns.length; i++) {
            if (i < row.length) {
              rowData[columns[i]] = row[i];
            }
          }

          await db.insert(currentTable, rowData,
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      print("✅ Data imported successfully!");
      return true;
    } catch (e) {
      print("❌ Error during import: $e");
      return false;
    }
  }

  static Future<Map<String, double>> getMonthlyGstReport(
      DateTime selectedDate) async {
    final db = await getDatabase();

    String month = selectedDate.month.toString().padLeft(2, '0');
    String year = selectedDate.year.toString();

    final result = await db.rawQuery('''
    SELECT 
      SUM(total_cgst) as total_cgst,
      SUM(total_sgst) as total_sgst,
      SUM(total_igst) as total_igst
    FROM invoice
    WHERE substr(date_added, 6, 2) = ? AND substr(date_added, 1, 4) = ?
  ''', [month, year]);

    if (result.isNotEmpty) {
      return {
        'cgst': (result[0]['total_cgst'] ?? 0.0) as double,
        'sgst': (result[0]['total_sgst'] ?? 0.0) as double,
        'igst': (result[0]['total_igst'] ?? 0.0) as double,
      };
    }

    return {'cgst': 0.0, 'sgst': 0.0, 'igst': 0.0};
  }

  static Future<List<Map<String, dynamic>>> getGstInvoicesByMonth(
      DateTime selectedDate) async {
    try {
      final db = await getDatabase();

      String month = selectedDate.month.toString().padLeft(2, '0');
      String year = selectedDate.year.toString();

      String sql = '''
        SELECT 
          i.invoice_id,
          i.date_added,
          i.taxable_amount,
          i.total_amount,
          i.total_cgst,
          i.total_sgst,
          i.total_igst,
          c.client_company
        FROM invoice i
        JOIN client c ON i.client_id = c.client_id
        WHERE substr(i.date_added, 6, 2) = ? AND substr(i.date_added, 1, 4) = ?
        ORDER BY i.date_added
      ''';

      print("SQL Query: $sql");
      print("Parameters: [$month, $year]");

      return await db.rawQuery(sql, [month, year]);
    } catch (e) {
      print("Error fetching invoices: $e");
      return [];
    }
  }
}

Future<int> saveInvoice(Map<String, dynamic> invoiceData) async {
  final db = await DatabaseHelper.getDatabase();
  return await db.insert('invoice', invoiceData);
}

Future<List<Map<String, dynamic>>> fetchInvoices() async {
  final db = await DatabaseHelper.getDatabase();
  return await db.rawQuery('''
    SELECT 
      i.*, 
      c.client_company 
    FROM invoice i
    LEFT JOIN client c ON i.client_id = c.client_id
    ORDER BY i.invoice_id DESC
  ''');
}
