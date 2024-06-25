import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:usb_serial/usb_serial.dart';
import 'package:usb_serial/transaction.dart';
import 'package:fl_chart/fl_chart.dart';
import 'eventlog.dart';

class SnapshotPage extends StatefulWidget {
  final String userId;
  final String participantId;
  final String mDaqStatus;
  final String bioPacStatus;
  final String experimenterId; // Include experimenterId
  final String sessionId;

  const SnapshotPage({
    Key? key,
    required this.userId,
    required this.participantId,
    required this.mDaqStatus,
    required this.bioPacStatus,
    required this.experimenterId, // Include experimenterId
    required this.sessionId,
  }) : super(key: key);

  @override
  _SnapshotPageState createState() => _SnapshotPageState();
}

class _SnapshotPageState extends State<SnapshotPage> {
  late String userId;
  late String participantId;
  late String mDaqStatus;
  late String bioPacStatus;
  late String experimenterId; // Include experimenterId
  late String sessionId;
  String batteryStatus = 'N/A';
  bool isSnapshotCaptured = false;

  UsbPort? _port;
  UsbDevice? _device;
  String _lastMessageSent = "";
  List<Widget> _serialData = [];

  List<FlSpot> dataPoints1 = [];
  List<FlSpot> dataPoints2 = [];
  List<FlSpot> dataPoints3 = [];
  List<FlSpot> dataPoints4 = [];
  double counter = 0;

  StreamSubscription<Uint8List>? _subscription;
  Transaction<Uint8List>? _transaction;

  @override
  void initState() {
    super.initState();
    userId = widget.userId;
    participantId = widget.participantId;
    mDaqStatus = widget.mDaqStatus;
    bioPacStatus = widget.bioPacStatus;
    experimenterId = widget.experimenterId; // Include experimenterId
    sessionId = widget.sessionId;

    UsbSerial.usbEventStream?.listen((UsbEvent event) {
      _checkDevices();
    });

    _checkDevices();
  }

  @override
  void dispose() {
    _port?.close();
    _subscription?.cancel();
    _transaction?.dispose();
    super.dispose();
  }

  Future<void> _checkDevices() async {
    List<UsbDevice> devices = await UsbSerial.listDevices();
    bool picoWConnected = false;

    for (var device in devices) {
      if (device.productName != null &&
          device.productName!.contains('Pico W')) {
        picoWConnected = true;
        userId = device.productName!;
        await _connectTo(device);
      }
    }

    setState(() {
      mDaqStatus = picoWConnected ? 'Connected' : 'Disconnected';
      bioPacStatus = picoWConnected ? 'Connected' : 'Disconnected';

      if (!picoWConnected) {
        userId = widget
            .userId; // Keep the previous userId when the device is unplugged
      }
      _updateNextButtonState();
    });
  }

  Future<bool> _connectTo(UsbDevice? device) async {
    _port?.close();

    if (device == null) {
      _device = null;
      setState(() {
        mDaqStatus = "Disconnected";
        bioPacStatus = "Disconnected";
        _updateNextButtonState();
      });
      return true;
    }

    _port = await device.create();
    if (await (_port!.open()) != true) {
      setState(() {
        mDaqStatus = "Failed to open port";
        bioPacStatus = "Failed to open port";
        _updateNextButtonState();
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

    _subscription = _transaction!.stream.listen((Uint8List line) {
      _onDataReceived(line);
    });

    setState(() {
      mDaqStatus = "Connected";
      bioPacStatus = "Connected";
      _updateNextButtonState();
    });
    return true;
  }

  void _onDataReceived(Uint8List data) {
    String dataString = utf8.decode(data);
    List<String> parts = dataString
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    for (String part in parts) {
      List<String> messageParts = part.split('\t');
      if (messageParts.length >= 5) {
        try {
          double value1 = double.parse(messageParts[2]);
          double value2 = double.parse(messageParts[3]);
          double value3 = double.parse(messageParts[4]);
          double value4 = double.parse(messageParts[5]);

          setState(() {
            dataPoints1.add(FlSpot(counter, value1));
            dataPoints2.add(FlSpot(counter, value2));
            dataPoints3.add(FlSpot(counter, value3));
            dataPoints4.add(FlSpot(counter, value4));
            counter++;

            if (dataPoints1.length > 300) {
              dataPoints1.removeAt(0);
              dataPoints2.removeAt(0);
              dataPoints3.removeAt(0);
              dataPoints4.removeAt(0);
            }

            if (messageParts.length > 15) {
              batteryStatus = messageParts[15];
            }
          });
        } catch (e) {
          print("Error parsing data: $e");
        }
      }
    }
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

  void _startSnapshot() {
    _sendMessage("#");
    setState(() {
      isSnapshotCaptured = true;
      _updateNextButtonState();
    });
  }

  void _stopSnapshot() {
    _sendMessage("!"); //!
    setState(() {
      isSnapshotCaptured = false;
      _updateNextButtonState();
    });
  }

  void _updateNextButtonState() {
    setState(() {
      isSnapshotCaptured = true;
    });
  }

  double _getMinY(List<FlSpot> dataPoints) {
    if (dataPoints.isEmpty) return 0;
    return dataPoints.map((e) => e.y).reduce((a, b) => a < b ? a : b);
  }

  double _getMaxY(List<FlSpot> dataPoints) {
    if (dataPoints.isEmpty) return 0;
    return dataPoints.map((e) => e.y).reduce((a, b) => a > b ? a : b);
  }

  Widget _buildGraph(String title, List<FlSpot> dataPoints, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minY: _getMinY(dataPoints),
              maxY: _getMaxY(dataPoints),
              lineBarsData: [
                LineChartBarData(
                  spots: dataPoints,
                  isCurved: true,
                  color: color,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(show: false),
                ),
              ],
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: FlGridData(show: true),
              borderData: FlBorderData(show: true),
            ),
          ),
        ),
        Text(
          dataPoints.map((e) => e.y.toStringAsFixed(2)).join(', '),
          style: TextStyle(color: Colors.white),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Color.fromARGB(255, 206, 132, 224),
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Data Quality Check',
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
                            ),
                            padding: EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'USER ID: $userId',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20.0,
                                    ),
                                  ),
                                ),
                                if (participantId.isNotEmpty)
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Participant ID: $participantId',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20.0,
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
                            ),
                            padding: EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'mDAQ Connection ',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20.0,
                                    ),
                                  ),
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    mDaqStatus,
                                    style: TextStyle(
                                      color: mDaqStatus == 'Connected'
                                          ? Colors.green
                                          : Colors.red,
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
                            ),
                            padding: EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'BioPAC Connection ',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20.0,
                                    ),
                                  ),
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    bioPacStatus,
                                    style: TextStyle(
                                      color: bioPacStatus == 'Connected'
                                          ? Colors.green
                                          : Colors.red,
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
                            ),
                            padding: EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Battery ',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20.0,
                                    ),
                                  ),
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    batteryStatus,
                                    style: TextStyle(
                                      color: batteryStatus != 'N/A'
                                          ? Colors.green
                                          : Colors.red,
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: _startSnapshot,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            minimumSize: Size(150, 50),
                          ),
                          child: Text(
                            'Start',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _stopSnapshot,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            minimumSize: Size(150, 50),
                          ),
                          child: Text(
                            'Stop',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Last Message Sent: $_lastMessageSent',
                      style: TextStyle(color: Colors.white),
                    ),
                    _buildGraph("Graph 1", dataPoints1, Colors.blue),
                    _buildGraph("Graph 2", dataPoints2, Colors.red),
                    _buildGraph("Graph 3", dataPoints3, Colors.green),
                    _buildGraph("Graph 4", dataPoints4, Colors.yellow),
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
                            style:
                                TextStyle(color: Colors.white, fontSize: 20.0),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                        TextButton.icon(
                          icon: Icon(
                            Icons.arrow_forward,
                            color: isSnapshotCaptured
                                ? Colors.green
                                : Colors.white,
                            size: 36.0,
                          ),
                          label: Text(
                            "Next",
                            style: TextStyle(
                              color: isSnapshotCaptured
                                  ? Colors.green
                                  : Colors.white,
                              fontSize: 20.0,
                            ),
                          ),
                          onPressed: isSnapshotCaptured
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EventLogPage(
                                        userId: userId,
                                        participantId: participantId,
                                        experimenterId: experimenterId, // Include experimenterId
                                        sessionId: sessionId,
                                        mDaqStatus: mDaqStatus,
                                        bioPacStatus: bioPacStatus,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                        ),
                      ],
                    ),
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
