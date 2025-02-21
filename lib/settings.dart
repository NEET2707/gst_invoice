import 'package:flutter/material.dart';
import 'package:gst_invoice/color.dart';
import 'package:gst_invoice/select_client.dart';
import 'package:gst_invoice/select_product.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: themecolor,
        title: const Text("Settings"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          _buildSettingsItem(
            icon: Icons.person,
            title: "Manage Clients",
            subtitle: "Manage All Client - Edit/Delete",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SelectClient()),
              );
            },
          ),
          _buildSettingsItem(
            icon: Icons.inventory,
            title: "Manage Products",
            subtitle: "Manage All Products - Edit/Delete",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SelectProduct()),
              );
            },
          ),
          _buildSettingsItem(
            icon: Icons.settings,
            title: "Settings",
            subtitle: "Edit Details Of Your Company",
          ),
          _buildSettingsItem(
            icon: Icons.assignment,
            title: "Report",
            subtitle: "Products and Party Wise Report",
          ),
          _buildSettingsItem(
            icon: Icons.share,
            title: "Share Company Details",
            subtitle: "Share Your Company Details",
          ),
          _buildSettingsItem(
            icon: Icons.cloud_upload,
            title: "Cloud Backup",
            subtitle: "Backup on your Google Drive",
          ),
          _buildSettingsItem(
            icon: Icons.phone,
            title: "Contact Us",
            subtitle: "Communication Details",
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    Function()? onTap, // Optional navigation function
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(icon, size: 30, color: Colors.grey[700]),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        onTap: onTap, // Navigate if onTap is provided
      ),
    );
  }
}
