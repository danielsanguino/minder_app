import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert'; // Add this import
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'report.dart'; // Import the report page

class UploadPage extends StatefulWidget {
  final String userId;

  const UploadPage({Key? key, required this.userId}) : super(key: key);

  @override
  _UploadPageState createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  bool _isUploadButtonEnabled = false;
  bool _isNextButtonEnabled = false;
  double _mergeProgress = 0.0;
  double _uploadProgress = 0.0;

  Future<void> _convertTsvToCsv() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['tsv'],
    );

    if (result != null) {
      File tsvFile = File(result.files.single.path!);
      final input = tsvFile.openRead();
      final fields = await input
          .transform(utf8.decoder)
          .transform(LineSplitter())
          .map((line) => line.split('\t'))
          .toList();

      String csv = const ListToCsvConverter().convert(fields);

      // Hard code the directory
      String documentsDirPath = '/storage/emulated/0/Documents';
      Directory documentsDir = Directory(documentsDirPath);
      if (!await documentsDir.exists()) {
        await documentsDir.create(recursive: true);
      }
      File csvFile = File('${documentsDir.path}/Mdaq_${widget.userId}.csv');

      await csvFile.writeAsString(csv);

      setState(() {
        _isUploadButtonEnabled = true;
      });

      // Notify the user about the location of the converted file
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('TSV file converted to CSV and saved as output.csv in the Documents directory.'),
      ));
    }
  }

  void _startMerge() {
    setState(() {
      _mergeProgress = 0.0;
      _isUploadButtonEnabled = false;
    });

    _convertTsvToCsv();

    Timer.periodic(Duration(milliseconds: 100), (timer) {
      setState(() {
        _mergeProgress += 0.01;
        if (_mergeProgress >= 1.0) {
          _mergeProgress = 1.0;
          timer.cancel();
        }
      });
    });
  }

  void _startUpload() {
    setState(() {
      _uploadProgress = 0.0;
      _isNextButtonEnabled = false;
    });

    Timer.periodic(Duration(milliseconds: 100), (timer) {
      setState(() {
        _uploadProgress += 0.01;
        if (_uploadProgress >= 1.0) {
          _uploadProgress = 1.0;
          _isNextButtonEnabled = true;
          timer.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 206, 132, 224),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Upload Data',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24.0,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: 50),
                      Center(
                        child: ElevatedButton(
                          onPressed: _startMerge,
                          child: Text('Merge'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: EdgeInsets.symmetric(
                                vertical: 24.0, horizontal: 100.0),
                            textStyle: TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      SizedBox(height: 30),
                      Center(
                        child: ElevatedButton(
                          onPressed:
                              _isUploadButtonEnabled ? _startUpload : null,
                          child: Text('Upload'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isUploadButtonEnabled
                                ? Colors.blue
                                : Colors.grey,
                            padding: EdgeInsets.symmetric(
                                vertical: 24.0, horizontal: 100.0),
                            textStyle: TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      SizedBox(height: 50),
                      LinearProgressIndicator(
                        value: _mergeProgress,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Color.fromARGB(255, 122, 231, 112)),
                        minHeight: 50.0, // Increase thickness
                      ),
                      SizedBox(height: 30),
                      LinearProgressIndicator(
                        value: _uploadProgress,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                        minHeight: 50.0, // Increase thickness
                      ),
                      SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    icon: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 36.0,
                    ),
                    label: Text(
                      "Back",
                      style: TextStyle(color: Colors.white, fontSize: 20.0),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30.0),
                      border: _isNextButtonEnabled
                          ? Border.all(color: Colors.white, width: 2.0)
                          : null,
                    ),
                    child: TextButton.icon(
                      icon: Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 36.0,
                      ),
                      label: Text(
                        "Next",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20.0,
                        ),
                      ),
                      onPressed: _isNextButtonEnabled
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        ReportPage(userId: widget.userId)),
                              );
                            }
                          : null,
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
