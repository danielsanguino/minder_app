import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'upload.dart'; // Import the upload page

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


  List<List<dynamic>> _logData = [];
  TextEditingController _eventController = TextEditingController();
  ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _requestPermissionAndInit();
    _clearRecentLogs();
    _loadLog();
  }

  void _clearRecentLogs() {
    setState(() {
      _logData.clear();
    });
  }

  Future<void> _requestPermissionAndInit() async {
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.request();
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
    String documentsPath = '/storage/emulated/0/Documents'; // Update with actual path

    return documentsPath;
  } catch (err) {
    print("Error getting documents directory: $err");
    return null;
  }
}

  void _logEvent(BuildContext context, String eventDescription, String time) async {
  final now = DateTime.now();
  final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final logEntry = [date, time, eventDescription, widget.userId, widget.participantId, widget.experimenterId, widget.sessionId];

  setState(() {
    _logData.add(logEntry);
    _logData.sort((a, b) => '${a[0]} ${a[1]}'.compareTo('${b[0]} ${b[1]}')); // Sort by date and time
  });

  _scrollController.animateTo(
    _scrollController.position.maxScrollExtent,
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
      final csvData = ListToCsvConverter().convert([logEntry]) + '\n'; //test final and see if it still works, if not go back to string
      await file.writeAsString(csvData, mode: fileExists ? FileMode.append : FileMode.write);

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
      final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      List<List<dynamic>> filteredData = [];
      for (var entry in data) {
        if (entry.length <= 7 && entry[0] == today) { 
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
                    _logEvent(context, _eventController.text.trim(), formattedTime);
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

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 206, 132, 224),
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
                        onPressed: () => _logEvent(context, 'Stop', _getCurrentTime()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
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
                            onPressed: () => _logEvent(context, 'Event 1', _getCurrentTime()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyan,
                              padding: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height * 0.03),
                            ),
                            child: Text(
                              'Event 1',
                              style: TextStyle(fontSize: 20.0, color: Colors.white),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _logEvent(context, 'Event 2', _getCurrentTime()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              padding: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height * 0.03),
                            ),
                            child: Text(
                              'Event 2',
                              style: TextStyle(fontSize: 20.0, color: Colors.white),
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
                            onPressed: () => _logEvent(context, 'Event 3', _getCurrentTime()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyan,
                              padding: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height * 0.03),
                            ),
                            child: Text(
                              'Event 3',
                              style: TextStyle(fontSize: 20.0, color: Colors.white),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _logEvent(context, 'Event 4', _getCurrentTime()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              padding: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height * 0.03),
                            ),
                            child: Text(
                              'Event 4',
                              style: TextStyle(fontSize: 20.0, color: Colors.white),
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
                            onPressed: () => _logEvent(context, 'Event 5', _getCurrentTime()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyan,
                              padding: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height * 0.03),
                            ),
                            child: Text(
                              'Event 5',
                              style: TextStyle(fontSize: 20.0, color: Colors.white),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _logEvent(context, 'Event 6', _getCurrentTime()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              padding: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height * 0.03),
                            ),
                            child: Text(
                              'Event 6',
                              style: TextStyle(fontSize: 20.0, color: Colors.white),
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
                                onPressed: () => _logEvent(context, _eventController.text.trim(), _getCurrentTime()),
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 10),
                                  backgroundColor: Colors.cyan,
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
                            height: MediaQuery.of(context).size.height * 0.3,
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
                            color:Colors.white,
                            size:36.0,
                          ),
                          label:Text(
                            "Back",
                            style: TextStyle(color:Colors.white, fontSize:20.0),
                          ),
                          onPressed: (){
                            Navigator.pop(context);
                          },
                        ),
                        TextButton.icon(
                          icon: Icon(
                            Icons.arrow_forward,
                            color: Colors.green,
                            size: 36.0,
                          ),
                          label: Text(
                            "Next",
                            style: TextStyle(
                              color: Colors.green,
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
                                }
                            
                        ),
                      ]
                    )
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
