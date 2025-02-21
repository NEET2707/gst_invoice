// import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart';
//
// class DBHelper {
//   static Database? _database;
//
//   static Future<Database> getDatabase() async {
//     if (_database != null) {
//       return _database!;
//     }
//
//     _database = await _initDB();
//     return _database!;
//   }
//
//   static Future<Database> _initDB() async {
//     String path = join(await getDatabasesPath(), 'app_database.db');
//
//     return await openDatabase(
//       path,
//       version: 1,
//       onCreate: (db, version) async {
//         await _createTables(db);
//       },
//     );
//   }
//
//   static Future<void> _createTables(Database db) async {
//     await db.execute('''
//       CREATE TABLE IF NOT EXISTS client (
//         client_id INTEGER PRIMARY KEY AUTOINCREMENT,
//         client_contact INTEGER,
//         client_company TEXT,
//         client_address TEXT,
//         client_state TEXT,
//         client_gstin TEXT
//       )
//     ''');
//
//     await db.execute('''
//       CREATE TABLE IF NOT EXISTS invoice (
//         invoice_id INTEGER PRIMARY KEY AUTOINCREMENT,
//         client_id INTEGER,
//         total_cgst FLOAT,
//         total_sgst FLOAT,
//         total_igst FLOAT,
//         taxable_amount FLOAT,
//         total_tax FLOAT,
//         total_amount FLOAT,
//         invoic_date DATE,
//         due_date DATE,
//         date_added DATE,
//         date_modified DATE,
//         is_equal_state INTEGER,
//         is_tax INTEGER
//       )
//     ''');
//
//     await db.execute('''
//       CREATE TABLE IF NOT EXISTS invoice_line (
//         invoice_line_id INTEGER PRIMARY KEY AUTOINCREMENT,
//         invoice_id INTEGER,
//         product_id INTEGER,
//         lineprodgst FLOAT,
//         price FLOAT,
//         qty INTEGER,
//         total FLOAT,
//         cgst FLOAT,
//         sgst FLOAT,
//         igst FLOAT,
//         dateadded DATE
//       )
//     ''');
//
//     await db.execute('''
//       CREATE TABLE IF NOT EXISTS product (
//         product_id INTEGER PRIMARY KEY AUTOINCREMENT,
//         product_name TEXT,
//         product_price FLOAT,
//         product_gst FLOAT,
//         product_hsn TEXT,
//         is_delete INTEGER
//       )
//     ''');
//
//     await db.execute('''
//       CREATE TABLE IF NOT EXISTS company (
//         company_id INTEGER PRIMARY KEY AUTOINCREMENT,
//         company_name TEXT,
//         company_gstin TEXT,
//         company_address TEXT,
//         company_state TEXT,
//         company_contact INTEGER,
//         is_tax INTEGER,
//         cgst FLOAT,
//         sgst FLOAT,
//         igst FLOAT,
//         default_state TEXT
//       )
//     ''');
//
//     await db.execute('''
//       CREATE TABLE IF NOT EXISTS setting (
//         setting_id INTEGER PRIMARY KEY AUTOINCREMENT,
//         last_backup_date DATE,
//         last_cloude_backup_date DATE
//       )
//     ''');
//
//     await db.execute('''
//       CREATE TABLE IF NOT EXISTS companylogo (
//         logo_id INTEGER PRIMARY KEY AUTOINCREMENT,
//         logo TEXT
//       )
//     ''');
//   }
// }
