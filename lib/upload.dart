import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

class UploadPage extends StatefulWidget {
  final String userId;

  const UploadPage({Key? key, required this.userId}) : super(key: key);

  @override
  _UploadPageState createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  bool _isUploadButtonEnabled = false;
  bool _isNextButtonEnabled = false;
  bool _isMergeButtonEnabled = false;
  double _mergeProgress = 0.0;
  double _uploadProgress = 0.0;
  String _fileContent = '';
  List<String> _statusMessages = [];
  late Timer _usbCheckTimer;

  @override
  void initState() {
    super.initState();
    _requestPermission();
    _checkUsbStorage();
    _startUsbCheckTimer();
  }

  void _startUsbCheckTimer() {
    _usbCheckTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      _checkUsbStorage();
    });
  }

  @override
  void dispose() {
    _usbCheckTimer.cancel();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
      if (!status.isGranted) {
        print('Storage permission denied');
        return;
      }
    }
    print('Storage permission granted');
    _checkUsbStorage();
  }

  Future<void> _checkUsbStorage() async {
    final directoryPath = '/mnt/media_rw/42C5-B60E';
    final filePath = '$directoryPath/sample.txt';

    if (await Directory(directoryPath).exists()) {
      if (await File(filePath).exists()) {
        final fileContent = await File(filePath).readAsString();
        setState(() {
          _fileContent = fileContent;
          _isMergeButtonEnabled = true;
        });
      } else {
        setState(() {
          _fileContent = 'sample.txt not found.';
        });
        _showSampleFileDialog();
      }
    } else {
      setState(() {
        _isMergeButtonEnabled = false;
      });
      _showUsbDialog();
    }
  }

  void _showUsbDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('USB Storage not detected'),
          content: Text('Please insert a USB storage device to continue.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _checkUsbStorage(); // Check again after closing the dialog
              },
              child: Text('Retry'),
            ),
          ],
        );
      },
    );
  }

  void _showSampleFileDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('sample.txt not found'),
          content: Text('Please make sure the USB storage device contains a sample.txt file.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _checkUsbStorage(); // Check again after closing the dialog
              },
              child: Text('Retry'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _convertTsvToCsv(File tsvFile, Directory mergedDir) async {
    final input = tsvFile.openRead();
    final fields = await input
        .transform(utf8.decoder)
        .transform(LineSplitter())
        .map((line) => line.split('\t'))
        .toList();

    String csv = const ListToCsvConverter().convert(fields);

    String fileName = tsvFile.uri.pathSegments.last.replaceAll('.tsv', '.csv');
    File csvFile = File('${mergedDir.path}/$fileName');

    await csvFile.writeAsString(csv);

    setState(() {
      _statusMessages.add('Converted $fileName to CSV and saved in Merged directory.');
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('TSV file ${tsvFile.uri.pathSegments.last} converted to CSV and saved in Merged directory.'),
    ));
  }

  Future<void> _startMerge() async {
    if (!_isMergeButtonEnabled) {
      _showUsbDialog();
      return;
    }

    setState(() {
      _mergeProgress = 0.0;
      _isUploadButtonEnabled = false;
      _statusMessages.clear(); // Clear previous status messages
    });

    final usbDirectoryPath = '/mnt/media_rw/42C5-B60E';
    final documentsDir = Directory('/storage/emulated/0/Documents');
    final mergedDir = Directory('${documentsDir.path}/Merged');
    final usbDirectory = Directory(usbDirectoryPath);

    // Ensure directories exist
    if (!await documentsDir.exists()) {
      await documentsDir.create(recursive: true);
    }
    if (!await mergedDir.exists()) {
      await mergedDir.create(recursive: true);
    }

    if (await usbDirectory.exists()) {
      List<FileSystemEntity> files = usbDirectory.listSync();
      int totalFiles = files.where((file) => file is File && file.path.endsWith('.tsv')).length;
      int processedFiles = 0;

      for (FileSystemEntity file in files) {
        if (file is File && file.path.endsWith('.tsv')) {
          final fileName = file.uri.pathSegments.last;
          final copiedFilePath = '${documentsDir.path}/$fileName';

          try {
            // Copy the file to Documents directory
            await file.copy(copiedFilePath);
            setState(() {
              _statusMessages.add('Copied $fileName to Documents directory.');
            });

            // Convert and save to Merged directory
            await _convertTsvToCsv(File(copiedFilePath), mergedDir);
          } catch (e) {
            print('Error processing $fileName: $e');
            setState(() {
              _statusMessages.add('Error processing $fileName.');
            });
          }

          processedFiles++;
          setState(() {
            _mergeProgress = processedFiles / totalFiles;
          });
        }
      }

      // After all files are processed, handle the Pico W.csv logs
      await _processPicoWLogs(documentsDir, mergedDir);

      Timer.periodic(Duration(milliseconds: 100), (timer) {
        setState(() {
          _mergeProgress += 0.01;
          if (_mergeProgress >= 1.0) {
            _mergeProgress = 1.0;
            timer.cancel();
            _isUploadButtonEnabled = true;
          }
        });
      });
    } else {
      _showUsbDialog();
    }
  }

  Future<void> _processPicoWLogs(Directory documentsDir, Directory mergedDir) async {
    final picoWFilePath = '${documentsDir.path}/Pico W.csv';
    final picoWFile = File(picoWFilePath);

    if (await picoWFile.exists()) {
      final picoWContents = await picoWFile.readAsString();
      final picoWLogs = const CsvToListConverter().convert(picoWContents);

      for (List<dynamic> log in picoWLogs) {
        if (log.isNotEmpty && log[0] is String) {
          final humanReadableTimestamp = log[0] as String;
          final epochTimestamp = _convertToEpoch(humanReadableTimestamp);

          if (epochTimestamp != null) {
            await _addLogToFile(epochTimestamp, log, mergedDir);
          }
        }
      }
    }
  }

  int? _convertToEpoch(String humanReadableTimestamp) {
    try {
      final format = DateFormat('M/d/yyyy HH:mm:ss'); // Adjust the format as per your timestamps
      final dateTime = format.parse(humanReadableTimestamp);
      return dateTime.millisecondsSinceEpoch ~/ 1000;
    } catch (e) {
      print('Error converting timestamp: $e');
      return null;
    }
  }

  Future<void> _addLogToFile(int epochTimestamp, List<dynamic> logData, Directory mergedDir) async {
    List<FileSystemEntity> mergedFiles = mergedDir.listSync();
    List<File> csvFiles = mergedFiles.whereType<File>().toList();

    csvFiles.sort((a, b) {
      final aTimestamp = int.tryParse(a.uri.pathSegments.last.split('.').first) ?? 0;
      final bTimestamp = int.tryParse(b.uri.pathSegments.last.split('.').first) ?? 0;
      return aTimestamp.compareTo(bTimestamp);
    });

    File? closestFile;
    for (File file in csvFiles) {
      final fileTimestamp = int.tryParse(file.uri.pathSegments.last.split('.').first) ?? 0;
      if (fileTimestamp > epochTimestamp) {
        closestFile = file;
        break;
      }
    }

    if (closestFile != null) {
      final csvContent = await closestFile.readAsString();
      final csvData = const CsvToListConverter().convert(csvContent);
      csvData.add(logData);

      final newCsvContent = const ListToCsvConverter().convert(csvData);
      await closestFile.writeAsString(newCsvContent);

      setState(() {
        _statusMessages.add('Added log to ${closestFile?.uri.pathSegments.last}.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload and Merge TSV Files'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _isUploadButtonEnabled ? () {} : null,
              child: Text('Upload Data'),
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _isNextButtonEnabled ? () {} : null,
              child: Text('Next'),
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _isMergeButtonEnabled ? _startMerge : null,
              child: Text('Merge TSV to CSV'),
            ),
            SizedBox(height: 16.0),
            LinearProgressIndicator(value: _mergeProgress),
            SizedBox(height: 16.0),
            LinearProgressIndicator(value: _uploadProgress),
            SizedBox(height: 16.0),
            Text('File Content: $_fileContent'),
            SizedBox(height: 16.0),
            Text(
              'Status:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.0),
            Expanded(
              child: ListView.builder(
                itemCount: _statusMessages.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(_statusMessages[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: UploadPage(userId: '12345'),
  ));
}
