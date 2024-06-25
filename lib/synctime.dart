import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:usb_serial/usb_serial.dart';
import 'package:usb_serial/transaction.dart';
import 'snapshot.dart';

class SyncTimePage extends StatefulWidget {
  final String userId;
  final String participantId;
  final String mDaqStatus;
  final String bioPacStatus;
  final String experimenterId; // Include experimenterId
  final String sessionId;

  const SyncTimePage({
    Key? key,
    required this.userId,
    required this.participantId,
    required this.mDaqStatus,
    required this.bioPacStatus,
    required this.experimenterId, // Include experimenterId
    required this.sessionId,
  }) : super(key: key);

  @override
  _SyncTimePageState createState() => _SyncTimePageState();
}

class _SyncTimePageState extends State<SyncTimePage> {
  late String userId;
  late String participantId;
  late String mDaqStatus;
  late String bioPacStatus;
  late String experimenterId; // Include experimenterId
  late String sessionId;
  bool isTimeSynced = false;
  bool isNextButtonActive = false;

  UsbPort? _port;
  UsbDevice? _device;
  String _lastMessageSent = "";
  List<Widget> _serialData = [];

  StreamSubscription<String>? _subscription;
  Transaction<String>? _transaction;

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
        _connectTo(device);
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

    _transaction = Transaction.stringTerminated(
        _port!.inputStream as Stream<Uint8List>, Uint8List.fromList([13, 10]));

    _subscription = _transaction!.stream.listen((String line) {
      setState(() {
        _serialData.add(Text(line));
        if (_serialData.length > 20) {
          _serialData.removeAt(0);
        }
      });
    });

    setState(() {
      mDaqStatus = "Connected";
      bioPacStatus = "Connected";
      _updateNextButtonState();
    });
    return true;
  }

  void _syncTime() {
    DateTime now = DateTime.now();
    String formattedTime =
        ("%\n${now.second},${now.minute},${now.hour},${now.weekday},${now.day},${now.month},${now.year}\n");
    _sendMessage(formattedTime);
    setState(() {
      isTimeSynced = true;
      _updateNextButtonState();
    });
  }

  void _sendMessage(String text) async {
    if (text.isNotEmpty) {
      try {
        _port!.write(Uint8List.fromList(utf8.encode(text)));
        setState(() {
          _lastMessageSent = text;
        });
        print('Message sent: $text');
      } catch (e) {
        print('Error sending message: $e');
        setState(() {});
      }
    }
  }

  void _updateNextButtonState() {
    setState(() {
      isNextButtonActive =
          (mDaqStatus == 'Connected' || bioPacStatus == 'Connected') &&
              isTimeSynced;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height,
          padding: EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Color.fromARGB(255, 206, 132, 224),
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Device Handshaking',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24.0,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: Column(
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
                      ],
                    ),
                    ElevatedButton(
                      onPressed: _syncTime,
                      style: ElevatedButton.styleFrom(
                        shape: CircleBorder(),
                        padding: EdgeInsets.all(80),
                      ),
                      child: Text(
                        'Sync the Time',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    Text(
                      'Last Message Sent: $_lastMessageSent',
                      style: TextStyle(color: Colors.white),
                    ),
                    ..._serialData,
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
                            color: isNextButtonActive
                                ? Colors.green
                                : Colors.white,
                            size: 36.0,
                          ),
                          label: Text(
                            "Next",
                            style: TextStyle(
                              color: isNextButtonActive
                                  ? Colors.green
                                  : Colors.white,
                              fontSize: 20.0,
                            ),
                          ),
                          onPressed: isNextButtonActive
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SnapshotPage(
                                        userId: userId,
                                        participantId: participantId,
                                        mDaqStatus: mDaqStatus,
                                        bioPacStatus: bioPacStatus,
                                        experimenterId: experimenterId,
                                        sessionId: sessionId,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
