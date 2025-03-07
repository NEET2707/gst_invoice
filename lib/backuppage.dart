import 'package:flutter/material.dart';
import '../DATABASE/database_helper.dart';

class BackupPage extends StatefulWidget {
  @override
  _BackupPageState createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  String statusMessage = "Ready";

  void backupDatabase() async {
    bool success = await DatabaseHelper.backupDatabase();
    setState(() {
      statusMessage = success ? "✅ Backup Successful!" : "❌ Backup Failed!";
    });
  }

  void restoreDatabase() async {
    bool success = await DatabaseHelper.restoreDatabase();
    setState(() {
      statusMessage = success ? "✅ Restore Successful!" : "❌ Restore Failed!";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Backup & Restore")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: backupDatabase,
              icon: Icon(Icons.backup),
              label: Text("Backup Database (CSV)"),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: restoreDatabase,
              icon: Icon(Icons.restore),
              label: Text("Restore Database (CSV)"),
            ),
            SizedBox(height: 20),
            Text(statusMessage, style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
