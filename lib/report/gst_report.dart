import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gst_invoice/color.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import '../DATABASE/database_helper.dart';

class GstReport extends StatefulWidget {
  const GstReport({super.key});

  @override
  State<GstReport> createState() => _GstReportState();
}

class _GstReportState extends State<GstReport> {
  DateTime selectedDate = DateTime.now();
  Map<String, double> gstData = {'cgst': 0.0, 'sgst': 0.0, 'igst': 0.0};
  bool isLoading = true;
  List<Map<String, dynamic>> gstInvoices = [];

  Widget _buildSummaryRow(String title, double? amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 16)),
          Text("₹ ${amount?.toStringAsFixed(2) ?? '0.00'}", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ],
      ),
    );
  }

  Future<void> fetchReport() async {
    setState(() => isLoading = true);
    gstData = await DatabaseHelper.getMonthlyGstReport(selectedDate);
    gstInvoices = await DatabaseHelper.getGstInvoicesByMonth(selectedDate);

    print("GST Data: $gstData");
    print("GST Invoices: $gstInvoices");

    setState(() => isLoading = false);
  }

  @override
  void initState() {
    super.initState();
    fetchReport();
  }

  void _showMonthYearPicker() {
    int tempMonth = selectedDate.month;
    int tempYear = selectedDate.year;

    showModalBottomSheet(
      context: context,
      builder: (BuildContext builder) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 40,
                        scrollController: FixedExtentScrollController(
                            initialItem: tempMonth - 1),
                        onSelectedItemChanged: (index) {
                          tempMonth = index + 1;
                        },
                        children: List.generate(
                          12,
                              (index) => Center(
                            child: Text(
                                DateFormat('MMM').format(DateTime(0, index + 1))),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 40,
                        scrollController: FixedExtentScrollController(
                            initialItem: DateTime.now().year - tempYear),
                        onSelectedItemChanged: (index) {
                          tempYear = DateTime.now().year - index;
                        },
                        children: List.generate(
                          50,
                              (index) =>
                              Center(child: Text('${DateTime.now().year - index}')),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCEL'),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        selectedDate = DateTime(tempYear, tempMonth);
                      });
                      Navigator.pop(context);
                      print(selectedDate);
                      print("mmmmmmmmmmmmmmmmmmmmmmm");
                      fetchReport();
                    },
                    child: const Text('DONE'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();

    final monthLabel = DateFormat('MMMM yyyy').format(selectedDate);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Text('GST Report for $monthLabel',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Text('Total CGST: ${gstData['cgst']?.toStringAsFixed(2) ?? '0.00'}'),
          pw.Text('Total SGST: ${gstData['sgst']?.toStringAsFixed(2) ?? '0.00'}'),
          pw.Text('Total IGST: ${gstData['igst']?.toStringAsFixed(2) ?? '0.00'}'),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: [
              'Sr.',
              'Date',
              'Name',
              'Amount',
              'IGST',
              'CGST',
              'SGST',
              'Total'
            ],
            data: List.generate(gstInvoices.length, (index) {
              final row = gstInvoices[index];
              final double amount = (row['taxable_amount'] ?? 0.0) as double;
              final double igst = (row['total_igst'] ?? 0.0) as double;
              final double cgst = (row['total_cgst'] ?? 0.0) as double;
              final double sgst = (row['total_sgst'] ?? 0.0) as double;
              final double total = amount + igst + cgst + sgst;

              return [
                "${index + 1}",
                "${row['date_added']}",
                "${row['client_company']}",
                "${amount.toStringAsFixed(2)}",
                "${igst.toStringAsFixed(2)}",
                "${cgst.toStringAsFixed(2)}",
                "${sgst.toStringAsFixed(2)}",
                "${total.toStringAsFixed(2)}",
              ];
            }),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: pw.TextStyle(fontSize: 10),
            border: pw.TableBorder.all(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }


  @override
  Widget build(BuildContext context) {
    String monthYear = DateFormat('MMM yyyy').format(selectedDate);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.background,
        title: Text("GST Report"),
        actions: [
          TextButton(
            onPressed: _showMonthYearPicker,
            child: Text(
              monthYear.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("GST Report for ${DateFormat('MMMM yyyy').format(selectedDate)}",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            _buildSummaryRow("Total CGST", gstData['cgst']),
            _buildSummaryRow("Total SGST", gstData['sgst']),
            _buildSummaryRow("Total IGST", gstData['igst']),
            SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateColor.resolveWith((_) => Colors.blue.shade50),
                  columns: const [
                    DataColumn(label: Text("Sr.")),
                    DataColumn(label: Text("Date")),
                    DataColumn(label: Text("Name")),
                    DataColumn(label: Text("Amount")),
                    DataColumn(label: Text("IGST")),
                    DataColumn(label: Text("CGST")),
                    DataColumn(label: Text("SGST")),
                    DataColumn(label: Text("Total")),
                  ],
                  rows: List.generate(gstInvoices.length, (index) {
                    final row = gstInvoices[index];
                    final double amount = (row['taxable_amount'] ?? 0.0) as double;
                    final double igst = (row['total_igst'] ?? 0.0) as double;
                    final double cgst = (row['total_cgst'] ?? 0.0) as double;
                    final double sgst = (row['total_sgst'] ?? 0.0) as double;
                    final double total = amount + igst + cgst + sgst;

                    return DataRow(cells: [
                      DataCell(Text("${index + 1}")),
                      DataCell(Text("${row['date_added']}")),
                      DataCell(Text("${row['client_company']}")),
                      DataCell(Text("${amount.toStringAsFixed(2)}")),
                      DataCell(Text("${igst.toStringAsFixed(2)}")),
                      DataCell(Text("${cgst.toStringAsFixed(2)}")),
                      DataCell(Text("${sgst.toStringAsFixed(2)}")),
                      DataCell(Text("${total.toStringAsFixed(2)}")),
                    ]);
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _generatePdf,
        backgroundColor: Colors.white,
        child: Icon(Icons.picture_as_pdf,color: Theme.of(context).colorScheme.background,),
      ),
    );
  }
}


