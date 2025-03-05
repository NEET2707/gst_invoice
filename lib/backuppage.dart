import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class BackupPage extends StatefulWidget {
  @override
  _BackupPageState createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  String? backupPath;

  @override
  void initState() {
    super.initState();
    _getBackupPath();
  }

  Future<void> _getBackupPath() async {
    Directory backupDir = await getApplicationDocumentsDirectory();
    setState(() {
      backupPath = join(backupDir.path, "backup_company.db");
    });
  }

  // Backup Database Function
  Future<void> _backupDatabase() async {
    try {
      String dbPath = join(await getDatabasesPath(), "company.db");

      if (!await File(dbPath).exists()) {
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
          SnackBar(content: Text("Database not found!")),
        );
        return;
      }

      await File(dbPath).copy(backupPath!);
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        SnackBar(content: Text("Backup successful! File saved to $backupPath")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        SnackBar(content: Text("Backup failed: $e")),
      );
      print(backupPath);
      print("666666666666666666666666666");
    }
  }

  // Restore Database Function
  Future<void> _restoreDatabase() async {
    try {
      String dbPath = join(await getDatabasesPath(), "company.db");

      if (!await File(backupPath!).exists()) {
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
          SnackBar(content: Text("Backup file not found!")),
        );
        return;
      }

      await File(backupPath!).copy(dbPath);
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        SnackBar(content: Text("Database restored successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        SnackBar(content: Text("Restore failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Backup & Restore")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _backupDatabase,
              icon: Icon(Icons.backup),
              label: Text("Backup Database"),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _restoreDatabase,
              icon: Icon(Icons.restore),
              label: Text("Restore Database"),
            ),
          ],
        ),
      ),
    );
  }
}
