import 'package:flutter/material.dart';
import 'package:gst_invoice/color.dart';
import 'package:gst_invoice/ADD/client/select_client.dart';
import 'package:gst_invoice/ADD/select_product.dart';
import 'package:gst_invoice/organization_detail.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'DATABASE/sharedprefhelper.dart';
import 'Report/reportpage.dart';
import 'backuppage.dart';

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
      MaterialPageRoute(
          builder: (context) => OrganizationDetail(
                temp: true,
              )),
    );
    if (result == true) {
      _loadCompanyDetails(); // ✅ Reload data when coming back
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
                MaterialPageRoute(
                    builder: (context) => SelectClient(pass: true, back: true)),
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
                MaterialPageRoute(
                    builder: (context) => SelectProduct(
                          boom: true,
                        )),
              );
            },
          ),
          _buildSettingsItem(
            icon: Icons.settings,
            title: "Company Details",
            subtitle: companyDetails != null
                ? "Company: ${companyDetails!["companyName"]}"
                : "Edit Details Of Your Company",
            onTap: _onOrganizationDetailTap,
          ),
          _buildSettingsItem(
            icon: Icons.assignment,
            title: "Report",
            subtitle: "Products and Party Wise Report",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ReportPage()),
              );
            },
          ),
          _buildSettingsItem(
            icon: Icons.share,
            title: "Share Company Details",
            subtitle: "Share Your Company Details",
            onTap: () {
              if (companyDetails == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('No company details available')),
                );
                return;
              }

              String message = '''
📄 Company Details:

Company Name: ${companyDetails?['companyName'] ?? 'N/A'}
Contact: ${companyDetails?['companyContact'] ?? 'N/A'}
Address: ${companyDetails?['companyAddress'] ?? 'N/A'}
State: ${companyDetails?['companyState'] ?? 'N/A'}
''';

              Share.share(message);
            },
          ),
          _buildSettingsItem(
            icon: Icons.cloud_upload,
            title: "Backup / Restore",
            subtitle: "Backup / Restore your Gst Invoices",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => BackupPage()),
              );
            },
          ),
          _buildSettingsItem(
            icon: Icons.phone,
            title: "Contact Us",
            subtitle: "Communication Details",
            onTap: () {
              _showCompensationDetailsDialog(context);
            },
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
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }
}

Future<void> _launchUrl(String links) async {
  final Uri _url = Uri.parse(links);
  if (!await launchUrl(_url)) {
    throw 'Could not launch $_url';
  }
}

void _showCompensationDetailsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('GST Invoice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('We are thanking you for using this app.'),
            SizedBox(height: 8),
            Text('Write us on'),
            GestureDetector(
              onTap: () {
                _launchUrl("mailto:info@gnhub.com");
              },
              child: Text(
                'info@gnhub.com',
                style: TextStyle(
                    color: Colors.blue, decoration: TextDecoration.underline),
              ),
            ),
            SizedBox(height: 8),
            Text('Generation Next'),
            GestureDetector(
              onTap: () {
                _launchUrl("http://www.gnhub.com/");
              },
              child: Text(
                'http://www.gnhub.com/',
                style: TextStyle(
                    color: Colors.blue, decoration: TextDecoration.underline),
              ),
            ),
            SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                _launchUrl('tel:+912612665403');
              },
              child: Text(
                '+91 261 2665403',
                style: TextStyle(
                    color: Colors.blue, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
            },
            child: Text('OK'),
          ),
        ],
      );
    },
  );
}
