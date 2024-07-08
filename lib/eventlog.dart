import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'upload.dart'; // Import the upload page
import 'package:usb_serial/usb_serial.dart';
import 'package:usb_serial/transaction.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';

class EventLogPage extends StatefulWidget {
  final String userId;
  final String participantId;
  final String experimenterId;
  final String sessionId;
  final String mDaqStatus;
  final String bioPacStatus;

  const EventLogPage({
    Key? key,
    required this.userId,
    required this.participantId,
    required this.experimenterId,
    required this.sessionId,
    required this.mDaqStatus,
    required this.bioPacStatus,
  }) : super(key: key);

  @override
  _EventLogPageState createState() => _EventLogPageState();
}

class _EventLogPageState extends State<EventLogPage> {
  late String userId;
  late String participantId;
  late String mDaqStatus;
  late String bioPacStatus;
  late String experimenterId; // Include experimenterId
  late String sessionId;

  UsbPort? _port;
  UsbDevice? _device;
  String _lastMessageSent = "";
  List<Widget> _serialData = [];

  List<List<dynamic>> _logData = [];
  TextEditingController _eventController = TextEditingController();
  ScrollController _scrollController = ScrollController();

  bool _stopButtonEnabled = true;

  @override
  void dispose() {
    _scrollController.dispose();
    _eventController.dispose();
    _port?.close();
    super.dispose();
  }

  StreamSubscription<Uint8List>? _subscription;
  Transaction<Uint8List>? _transaction;

  @override
  void initState() {
    super.initState();
    _initializeVariables();
    _requestPermissionAndInit();
    _clearRecentLogs();
    _loadLog();

    UsbSerial.usbEventStream?.listen((UsbEvent event) {
      _checkDevices();
    });

    _checkDevices();
  }

  void _initializeVariables() {
    userId = widget.userId;
    participantId = widget.participantId;
    mDaqStatus = widget.mDaqStatus;
    bioPacStatus = widget.bioPacStatus;
    experimenterId = widget.experimenterId;
    sessionId = widget.sessionId;
  }

  void _sendMessage(String text) async {
    if (text.isNotEmpty) {
      try {
        _port!.write(Uint8List.fromList(utf8.encode(text + "\n")));
        setState(() {
          _lastMessageSent = text;
        });
        print('Message sent: $text');
      } catch (e) {
        print('Error sending message: $e');
      }
    }
  }

  void _stopEventLog() {
    _sendMessage("!"); //!
  }

  void _clearRecentLogs() {
    setState(() {
      _logData.clear();
    });
  }

  Future<void> _checkDevices() async {
    List<UsbDevice> devices = await UsbSerial.listDevices();
    bool picoWConnected = false;
    UsbDevice? connectedDevice; ////

    for (var device in devices) {
      if (device.productName != null &&
          device.productName!.contains('Pico W')) {
        picoWConnected = true;
        connectedDevice = device;
        break;
      }
    }

    setState(() {
      mDaqStatus = picoWConnected ? 'Connected' : 'Disconnected';
      bioPacStatus = picoWConnected ? 'Connected' : 'Disconnected';
      _stopButtonEnabled = picoWConnected;

      if (!picoWConnected) {
        userId = widget
            .userId; // Keep the previous userId when the device is unplugged
      }
    });

    if (picoWConnected && _device != connectedDevice) {
      await _connectTo(connectedDevice);
    }
  }

  Future<bool> _connectTo(UsbDevice? device) async {
    _port?.close();

    if (device == null) {
      _device = null;
      setState(() {
        mDaqStatus = "Disconnected";
        bioPacStatus = "Disconnected";
      });
      return false;
    }

    _port = await device.create();
    if (await (_port!.open()) != true) {
      setState(() {
        mDaqStatus = "Failed to open port";
        bioPacStatus = "Failed to open port";
      });
      return false;
    }
    _device = device;

    await _port!.setDTR(true);
    await _port!.setRTS(true);
    await _port!.setPortParameters(
        115200, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

    _transaction = Transaction.terminated(
        _port!.inputStream!, Uint8List.fromList([13, 10]));

    setState(() {
      mDaqStatus = "Connected";
      bioPacStatus = "Connected";
    });
    return true;
  }

  Future<void> _requestPermissionAndInit() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage
          .request(); //used to be permission.manageexternalstorage.status
      if (!status.isGranted) {
        print('Storage permission denied');
        return;
      }
    }
    print('Storage permission granted');
  }

  Future<String?> _getDocumentsDirectoryPath() async {
    try {
      // Assuming 'Documents' folder is directly accessible
      String documentsPath =
          '/storage/emulated/0/Documents'; // Update with actual path
      return documentsPath;
    } catch (err) {
      print("Error getting documents directory: $err");
      return null;
    }
  }

  void _logEvent(
      BuildContext context, String eventDescription, String time) async {
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final logEntry = [
      date,
      time,
      eventDescription,
      userId,
      participantId,
      experimenterId,
      sessionId
    ];

    setState(() {
      _logData.insert(0, logEntry);
      _logData.sort((a, b) => '${b[0]} ${b[1]}'
          .compareTo('${a[0]} ${a[1]}')); // Sort by date and time
    });

    _scrollController.animateTo(
      0,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );

    final documentsDir = await _getDocumentsDirectoryPath();
    if (documentsDir != null) {
      final filePath = join(documentsDir, '${widget.userId}.csv');
      final file = File(filePath);

      try {
        bool fileExists = await file.exists();

        // Append the new log entry to the CSV file
        final csvData = ListToCsvConverter().convert([logEntry]) + '\n';
        await file.writeAsString(csvData,
            mode: fileExists ? FileMode.append : FileMode.write);

        print('Log Entry: $logEntry');
        print('CSV file saved at: $filePath');
      } catch (e) {
        print('Error writing to file: $e');
      }
    } else {
      print('Failed to get documents directory');
    }
  }

  void _loadLog() async {
    final documentsDir = await _getDocumentsDirectoryPath();
    if (documentsDir != null) {
      final path = join(documentsDir, '${widget.userId}.csv');
      final file = File(path);

      if (await file.exists()) {
        final input = await file.readAsString();
        List<List<dynamic>> data = CsvToListConverter().convert(input);

        // Add filtering logic here to filter logs by date or session
        final now = DateTime.now();
        final today =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

        List<List<dynamic>> filteredData = [];
        for (var entry in data) {
          if (entry.length >= 7 && entry[0] == today) {
            filteredData.add(entry);
          }
        }

        setState(() {
          _logData = filteredData;
        });
      } else {
        setState(() {
          _logData = [];
        });
      }
    }
  }

  Widget _buildLogList() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _logData.length,
      itemBuilder: (context, index) {
        final entry = _logData[index];
        return ListTile(
          title: Text('${entry[2]}'),
          subtitle: Text('${entry[0]} ${entry[1]}'),
        );
      },
    );
  }

  Future<void> _showCravingIntensityDialog(BuildContext context) async {
    int selectedCravingIntensity = 0;

    return showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('Choose Craving Intensity'),
              content:
                  Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                DropdownButton<int>(
                  value: selectedCravingIntensity,
                  onChanged: (value) {
                    setState(() {
                      selectedCravingIntensity = value!;
                    });
                  },
                  items: List.generate(
                    101,
                    (index) => DropdownMenuItem(
                      value: index,
                      child: Text(index.toString().padLeft(2, '0')),
                    ),
                  ),
                ),
              ]),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _logEvent(context, 'Cow Score $selectedCravingIntensity',
                        _getCurrentTime());
                    Navigator.of(context).pop();
                  },
                  child: Text('Log Event'),
                ),
              ],
            );
          });
        });
  }

  Future<void> _showCowScoreDialog(BuildContext context) async {
    int selectedCowScore = 0;

    return showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('Choose Cow Score'),
              content:
                  Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                DropdownButton<int>(
                  value: selectedCowScore,
                  onChanged: (value) {
                    setState(() {
                      selectedCowScore = value!;
                    });
                  },
                  items: List.generate(
                    31,
                    (index) => DropdownMenuItem(
                      value: index,
                      child: Text(index.toString().padLeft(2, '0')),
                    ),
                  ),
                ),
              ]),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _logEvent(context, 'Cow Score $selectedCowScore',
                        _getCurrentTime());
                    Navigator.of(context).pop();
                  },
                  child: Text('Log Event'),
                ),
              ],
            );
          });
        });
  }

  Future<void> _showManualEventDialog(BuildContext context) async {
    int selectedHour = 0;
    int selectedMinute = 0;
    int selectedSecond = 0;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('Log Manual Event'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: _eventController,
                    decoration: InputDecoration(
                      labelText: 'Event Description',
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: DropdownButton<int>(
                          value: selectedHour,
                          onChanged: (value) {
                            setState(() {
                              selectedHour = value!;
                            });
                          },
                          items: List.generate(
                            24,
                            (index) => DropdownMenuItem(
                              value: index,
                              child: Text(index.toString().padLeft(2, '0')),
                            ),
                          ),
                        ),
                      ),
                      Text(':'),
                      Expanded(
                        child: DropdownButton<int>(
                          value: selectedMinute,
                          onChanged: (value) {
                            setState(() {
                              selectedMinute = value!;
                            });
                          },
                          items: List.generate(
                            60,
                            (index) => DropdownMenuItem(
                              value: index,
                              child: Text(index.toString().padLeft(2, '0')),
                            ),
                          ),
                        ),
                      ),
                      Text(':'),
                      Expanded(
                        child: DropdownButton<int>(
                          value: selectedSecond,
                          onChanged: (value) {
                            setState(() {
                              selectedSecond = value!;
                            });
                          },
                          items: List.generate(
                            60,
                            (index) => DropdownMenuItem(
                              value: index,
                              child: Text(index.toString().padLeft(2, '0')),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    String formattedTime =
                        '${selectedHour.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')}:${selectedSecond.toString().padLeft(2, '0')}';
                    _logEvent(
                        context, _eventController.text.trim(), formattedTime);
                    Navigator.of(context).pop();
                  },
                  child: Text('Log Event'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showStopConfirmationDialog(BuildContext context) async {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Stop'),
          content: const Text('Are you sure you want to stop?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Stop'),
              onPressed: () {
                Navigator.of(context).pop();
                _stopEventLog(); // Call the stop function
                _logEvent(context, 'Stop', _getCurrentTime());
              },
            ),
          ],
        );
      },
    );
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 234, 122, 244),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Event Log',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24.0,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Flexible(
                          child: Container(
                            height: 80,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white),
                              borderRadius: BorderRadius.circular(8.0),
                              color: Colors.white.withOpacity(0.5),
                            ),
                            padding: EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'USER ID: ${widget.userId}',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 16.0,
                                    ),
                                  ),
                                ),
                                if (widget.participantId.isNotEmpty)
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Participant: ${widget.participantId}',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 16.0,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Flexible(
                          child: Container(
                            height: 80,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white),
                              borderRadius: BorderRadius.circular(8.0),
                              color: Colors.white.withOpacity(0.5),
                            ),
                            padding: EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Session ID',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 16.0,
                                    ),
                                  ),
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    widget.sessionId,
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 16.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Flexible(
                          child: Container(
                            height: 80,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white),
                              borderRadius: BorderRadius.circular(8.0),
                              color: Colors.white.withOpacity(0.5),
                            ),
                            padding: EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Experimenter',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 16.0,
                                    ),
                                  ),
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    widget.experimenterId,
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 16.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _stopButtonEnabled
                            ? () => _showStopConfirmationDialog(context)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _stopButtonEnabled ? Colors.red : Colors.grey,
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                        ),
                        child: Text(
                          'Stop',
                          style: TextStyle(fontSize: 20.0, color: Colors.white),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _logEvent(
                                context, 'Break Start', _getCurrentTime()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color.fromARGB(255,58,134,255),
                              padding: EdgeInsets.symmetric(
                                  vertical: MediaQuery.of(context).size.height *
                                      0.03),
                            ),
                            child: Text(
                              'Break Start',
                              style: TextStyle(
                                  fontSize: 20.0, color: Colors.white),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _logEvent(
                                context, 'Break End', _getCurrentTime()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color.fromARGB(255,58,134,255),
                              padding: EdgeInsets.symmetric(
                                  vertical: MediaQuery.of(context).size.height *
                                      0.03),
                            ),
                            child: Text(
                              'Break End',
                              style: TextStyle(
                                  fontSize: 20.0, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _logEvent(context,
                                'Medication Intake', _getCurrentTime()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color.fromARGB(255, 131, 56, 236),
                              padding: EdgeInsets.symmetric(
                                  vertical: MediaQuery.of(context).size.height *
                                      0.03),
                            ),
                            child: Text(
                              'Medication Intake',
                              style: TextStyle(
                                  fontSize: 20.0, color: Colors.white),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _logEvent(
                                context, 'Event 4', _getCurrentTime()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color.fromARGB(255, 131, 56, 236),
                              padding: EdgeInsets.symmetric(
                                  vertical: MediaQuery.of(context).size.height *
                                      0.03),
                            ),
                            child: Text(
                              'Event 4',
                              style: TextStyle(
                                  fontSize: 20.0, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              await _showCowScoreDialog(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color.fromARGB(255, 74, 214, 109),
                              padding: EdgeInsets.symmetric(
                                  vertical: MediaQuery.of(context).size.height *
                                      0.03),
                            ),
                            child: Text(
                              'Choose Cow Score',
                              style: TextStyle(
                                  fontSize: 20.0, color: Colors.white),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              await _showCravingIntensityDialog(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color.fromARGB(255, 74, 214, 109),
                              padding: EdgeInsets.symmetric(
                                  vertical: MediaQuery.of(context).size.height *
                                      0.03),
                            ),
                            child: Text(
                              'Choose Craving Intensity',
                              style: TextStyle(
                                  fontSize: 20.0, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.white),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _eventController,
                            decoration: InputDecoration(
                              labelText: 'Manual Event Input',
                              fillColor: Colors.white,
                              filled: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                          SizedBox(height: 8.0),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    await _showManualEventDialog(context);
                                  },
                                  child: Text('Choose Time'),
                                ),
                              ),
                              SizedBox(width: 18.0),
                              ElevatedButton(
                                onPressed: () => _logEvent(
                                    context,
                                    _eventController.text.trim(),
                                    _getCurrentTime()),
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 50, vertical: 10),
                                  backgroundColor: Colors.white,
                                ),
                                child: Text('Save'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.white),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recent Logs',
                            style: TextStyle(
                              fontSize: 20.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 16.0),
                          Container(
                            height: MediaQuery.of(context).size.height * 0.25,
                            child: _buildLogList(),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
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
                              style: TextStyle(
                                  color: Colors.white, fontSize: 20.0),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                          ),
                          Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30.0),
                                border:
                                    Border.all(color: Colors.white, width: 2.0),
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
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => UploadPage(
                                          userId: userId,
                                        ),
                                      ),
                                    );
                                  }))
                        ])
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}