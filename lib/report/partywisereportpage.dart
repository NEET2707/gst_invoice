import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gst_invoice/DATABASE/database_helper.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class Partywisereportpage extends StatefulWidget {
  const Partywisereportpage({super.key});

  @override
  State<Partywisereportpage> createState() => _PartywisereportpageState();
}

class _PartywisereportpageState extends State<Partywisereportpage> {
  DateTime selectedDate = DateTime.now();
  List<Map<String, dynamic>> reportData = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchReport();
  }

  Future<void> fetchReport() async {
    setState(() {
      isLoading = true;
    });

    try {
      reportData = await DatabaseHelper.getClientReport(selectedDate);
      print('Client Report Data: $reportData');
    } catch (e) {
      debugPrint('Error fetching client report: $e');
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
                              (index) => Center(
                              child: Text('${DateTime.now().year - index}')),
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
                headers: ['Invoice No', 'Date', 'Buyer', 'Amount'],
                data: reportData.asMap().entries.map((entry) {
                  int index = entry.key + 1;
                  var row = entry.value;
                  return [
                    // index.toString(),
                    row['invoice_id'].toString(),
                    row['date_added'].toString(),
                    row['client_company'].toString(),
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
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      appBar: AppBar(
        title: const Text('Party Wise Report'),
        backgroundColor: Theme.of(context).colorScheme.background,
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
            Expanded(
              child: ListView(
                children: [
                  Container(
                    width: double.infinity, // Make sure the table uses full width
                    child: Table(
                      border: TableBorder.all(color: Colors.black),
                      columnWidths: const {
                        0: FixedColumnWidth(80), // Invoice No
                        1: FixedColumnWidth(95), // Date
                        2: FixedColumnWidth(60),  // Buyer
                        3: FixedColumnWidth(90), // Amount
                      },
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      children: [
                        const TableRow(
                          decoration: BoxDecoration(color: Color(0xFFE0E0E0)),
                          children: [
                            Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Text('Invoice No', textAlign: TextAlign.center),
                            ),
                            Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Text('Date', textAlign: TextAlign.center),
                            ),
                            Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Text('Buyer', textAlign: TextAlign.center),
                            ),
                            Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Text('Amount', textAlign: TextAlign.center),
                            ),
                          ],
                        ),
                        ...reportData.map((row) {
                          return TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Text('${row['invoice_id']}', textAlign: TextAlign.center),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Text('${row['date_added']}', textAlign: TextAlign.center),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Text('${row['client_company']}', textAlign: TextAlign.center),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Text('${row['total_amount']}', textAlign: TextAlign.center),
                              ),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: generatePDF,
        backgroundColor: Colors.white,
        child: Icon(Icons.download, color: Theme.of(context).colorScheme.background,size: 30,),
      ),
    );
  }
}
