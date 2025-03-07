// Future<String?> picksafdirectory() async {
//   final _safUtil = SafUtil();
//   String? selectedDirectory = await _safUtil.openDirectory();
//   if (selectedDirectory == null) {
//     Fluttertoast.showToast(msg: "No folder selected.");
//     return null;
//   }
//   return selectedDirectory;
// }
//
// Future<void> importCsvFiles(selectedDirectory) async {
//   final _safStreamPlugin = SafStream();
//   final _safUtil = SafUtil();
//
//   EasyLoading.show(status: "Restoring Data...");
//
//   List<SafDocumentFile> files = await _safUtil.list(selectedDirectory);
//
//   String? clientsFilePath;
//   String? transactionsFilePath;
//
//   for (var file in files) {
//     if (file.name == clientsFileName) {
//       clientsFilePath = file.uri;
//     } else if (file.name == transactionsFileName) {
//       transactionsFilePath = file.uri;
//     }
//   }
//   if (clientsFilePath == null || transactionsFilePath == null) {
//     Fluttertoast.showToast(
//         msg: "Clients.csv and Transactions.csv both must be in the folder.");
//     EasyLoading.dismiss();
//     return;
//   }
//
//   Uint8List clientsData = await _safStreamPlugin.readFileBytes(clientsFilePath ?? "");
//
//   String clientsCsv = utf8.decode(clientsData, allowMalformed: true);
//   debugPrint('Clients CSV found: Importing data...');
//   await AppDatabaseHelper().clearAllTables();
//   await AppDatabaseHelper().importClientsFromCsv(clientsCsv);
//   debugPrint('Clients CSV imported.');
//
//   Uint8List? transactionsData =
//   await _safStreamPlugin.readFileBytes(transactionsFilePath ?? "");
//   String transactionsCsv =
//   utf8.decode(transactionsData, allowMalformed: true);
//   debugPrint('Transactions CSV found: Importing data...');
//
//   await AppDatabaseHelper().importTransactionsFromCsv(transactionsCsv);
//   debugPrint('Transactions CSV imported.');
//   EasyLoading.showToast("Restoring Data Successfully");
//   EasyLoading.dismiss();
// }
//
//
