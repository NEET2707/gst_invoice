import 'package:flutter/material.dart';
import 'package:gst_invoice/Report/partywisereportpage.dart';
import 'package:gst_invoice/Report/productwisereportpage.dart';

import 'gst_report.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      appBar: AppBar(
        title: const Text('Report'),
        backgroundColor: Theme.of(context).colorScheme.background,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildReportCard(
              context,
              icon: Icons.inventory,
              title: 'Product Wise',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProductWiseReportPage()),
                );
              },
            ),
            const SizedBox(height: 30),
            _buildReportCard(
              context,
              icon: Icons.person,
              title: 'Party Wise',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Partywisereportpage()),
                );              },
            ),
            const SizedBox(height: 30),
            _buildReportCard(
              context,
              icon: Icons.person,
              title: 'GST Report',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GstReport()),
                );              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, {required IconData icon, required String title, required Function() onTap}) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Container(
          width: 150,
          height: 150,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 60, color: Colors.blue),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
