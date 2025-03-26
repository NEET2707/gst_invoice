import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gst_invoice/DATABASE/database_helper.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ProductWiseReportPage extends StatefulWidget {
  const ProductWiseReportPage({super.key});

  @override
  State<ProductWiseReportPage> createState() => _ProductWiseReportPageState();
}

class _ProductWiseReportPageState extends State<ProductWiseReportPage> {
  DateTime selectedDate = DateTime.now();
  List<Map<String, dynamic>> reportData = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> fetchReport() async {
    setState(() {
      isLoading = true;
    });

    try {
      // await DatabaseHelper.checkInvoiceLineDates(); // Check dates first
      reportData = await DatabaseHelper.getProductWiseReport(selectedDate);
      print('Report Data: $reportData');
    } catch (e) {
      debugPrint('Error fetching report: $e');
      reportData = [];
    } finally {
      setState(() {
        isLoading = false;
      });
    }
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

  Future<void> generatePDF() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Text(
                'Party Wise Report - ${DateFormat('MMMM yyyy').format(selectedDate)}',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 16),
              pw.Table.fromTextArray(
                headers: ['S No','Date', 'Buyer', 'Amount'],
                data: reportData.asMap().entries.map((entry) {
                  int index = entry.key + 1;
                  var row = entry.value;
                  return [
                    index.toString(),
                    row['product_name'].toString(),
                    row['total_qty'].toString(),
                    row['total_amount'].toString(),
                  ];
                }).toList(),
                border: pw.TableBorder.all(),
                cellAlignment: pw.Alignment.center,
              ),
            ],
          );
        },
      ),
    );

    // Share the PDF (allows opening, saving, or printing)
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }


  @override
  Widget build(BuildContext context) {
    String monthYear = DateFormat('MMM yyyy').format(selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Wise Report'),
        backgroundColor: Colors.blue,
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
            ? const Center(child: CircularProgressIndicator())
            : reportData.isEmpty
            ? Center(
          child: Text(
            'No Data Found for ${DateFormat('MMMM-yyyy').format(selectedDate)}',
            style: const TextStyle(fontSize: 20),
          ),
        )
            : Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                DateFormat('MMMM-yyyy').format(selectedDate),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Table(
                border: TableBorder.all(),
                columnWidths: const {
                  0: FlexColumnWidth(1),
                  1: FlexColumnWidth(3),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(2),
                },
                children: [
                  // Header Row
                  const TableRow(
                    decoration: BoxDecoration(color: Color(0xFFE0E0E0)),
                    children: [
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('S No', textAlign: TextAlign.center),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('Product Name', textAlign: TextAlign.center),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('Qty', textAlign: TextAlign.center),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('Total', textAlign: TextAlign.center),
                      ),
                    ],
                  ),
                  // Data Rows
                  ...reportData.asMap().entries.map((entry) {
                    int index = entry.key + 1;
                    var row = entry.value;
                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text('$index', textAlign: TextAlign.center),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text('${row['product_name']}', textAlign: TextAlign.center),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text('${row['total_qty']}', textAlign: TextAlign.center),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text('${row['total_amount']}', textAlign: TextAlign.center),
                        ),
                      ],
                    );
                  }).toList(),
                  // Total Row
                  // TableRow(
                  //   decoration: const BoxDecoration(color: Color(0xFFE0E0E0)),
                  //   children: [
                  //     const SizedBox(),
                  //     const Padding(
                  //       padding: EdgeInsets.all(8.0),
                  //       child: Text('Total', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                  //     ),
                  //     const SizedBox(),
                  //     Padding(
                  //       padding: const EdgeInsets.all(8.0),
                  //       child: Text(
                  //         '${reportData.fold(0, (sum, row) => sum + (row['total_amount'] ?? 0))}',
                  //         textAlign: TextAlign.center,
                  //         style: const TextStyle(fontWeight: FontWeight.bold),
                  //       ),
                  //     ),
                  //   ],
                  // ),
                ],
              ),
            ],
          ),
        ),
      floatingActionButton: FloatingActionButton(
        onPressed: generatePDF,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.download),
      ),
    );
  }
}
