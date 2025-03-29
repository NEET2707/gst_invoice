import 'package:flutter/material.dart';
import 'package:gst_invoice/color.dart';
import 'package:intl/intl.dart';
import '../DATABASE/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupPage extends StatefulWidget {
  @override
  _BackupPageState createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  String lastBackupTime = "";
  // String lastRestoreTime = "Not Available";

  @override
  void initState() {
    super.initState();
    _loadLastBackupRestoreTimes();
  }

  Future<void> _loadLastBackupRestoreTimes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      String saveddate = prefs.getString("lastBackupTime") ?? "";
      lastBackupTime =
          DateFormat("dd MMMM yyyy hh:mm a").format(DateTime.parse(saveddate));
      // lastRestoreTime = prefs.getString("lastRestoreTime") ?? "Not Available";
    });
  }

  Future<void> _saveLastBackupTime() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String currentTime = DateTime.now().toString();
    await prefs.setString("lastBackupTime", currentTime);
    setState(() {
      lastBackupTime = currentTime;
    });
  }

  // Future<void> _saveLastRestoreTime() async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   String currentTime = DateTime.now().toString();
  //   await prefs.setString("lastRestoreTime", currentTime);
  //   setState(() {
  //     lastRestoreTime = currentTime;
  //   });
  // }

  void backupDatabase() async {
    bool success = await DatabaseHelper.backupDatabase();
    if (success) {
      await _saveLastBackupTime();
    }
  }

  void restoreDatabase() async {
    bool success = await DatabaseHelper.restoreDatabase();
    if (success) {
      // await _saveLastRestoreTime();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.background, title: Text("Backup And Restore")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Storage Backup & Restore",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text(
                        "Back up your Accounts and GST Invoice to your Internal storage. You can restore it from Backup file."),
                    SizedBox(height: 8),
                    Text(
                        lastBackupTime == ""
                            ? "No Backup yet"
                            : "Last Backup: $lastBackupTime",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: backupDatabase,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.background,
                        ),
                        child: Text("Backup", style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                      ),
                    ),
                    SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: restoreDatabase,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.background,
                        ),
                        child: Text("Restore", style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
