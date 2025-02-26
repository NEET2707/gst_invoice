import 'package:flutter/material.dart';
import 'package:gst_invoice/color.dart';
import 'package:gst_invoice/ADD/select_client.dart';
import 'package:gst_invoice/ADD/select_product.dart';
import 'package:gst_invoice/organization_detail.dart';
import 'DATABASE/sharedprefhelper.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  Map<String, dynamic>? companyDetails;


  @override
  void initState() {
    super.initState();
    _loadCompanyDetails();
  }

  void _loadCompanyDetails() async {
    companyDetails = await SharedPrefHelper.getCompanyDetails();
    setState(() {
      print("Updated Company Details: $companyDetails");
    });
  }


  Future<void> _onOrganizationDetailTap() async {
    bool? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => OrganizationDetail()),
    );
    if (result == true) {
      _loadCompanyDetails();  // ✅ Reload data when coming back
    }

  }


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
            subtitle: companyDetails != null
                ? "Company: ${companyDetails!["companyName"]}"
                : "Edit Details Of Your Company",
            onTap: _onOrganizationDetailTap,
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
    Function()? onTap,
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
        onTap: onTap,
      ),
    );
  }
}
