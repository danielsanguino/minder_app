import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:usb_serial/usb_serial.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'synctime.dart';

class InitializationPage extends StatefulWidget {
  @override
  _InitializationPageState createState() => _InitializationPageState();
}

class _InitializationPageState extends State<InitializationPage>
    with WidgetsBindingObserver {
  String userId = '';
  String participantId = '';
  String sessionId = '';
  String experimenterId = '';

  FocusNode participantFocusNode = FocusNode();
  FocusNode sessionFocusNode = FocusNode();
  FocusNode experimenterFocusNode = FocusNode();

  TextEditingController participantController = TextEditingController();
  TextEditingController sessionController = TextEditingController();
  TextEditingController experimenterController = TextEditingController();

  String mDaqStatus = 'Disconnected';
  String bioPacStatus = 'Disconnected';
  String picoWDeviceName = '';
  bool isNextButtonActive = false;

  UsbPort? _port;
  UsbDevice? _device;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFromCache();

    participantFocusNode.addListener(() {
      if (participantFocusNode.hasFocus) {
        setState(() {});
      }
    });

    sessionFocusNode.addListener(() {
      if (sessionFocusNode.hasFocus) {
        setState(() {});
      }
    });

    experimenterFocusNode.addListener(() {
      if (experimenterFocusNode.hasFocus) {
        setState(() {});
      }
    });

    UsbSerial.usbEventStream?.listen((UsbEvent event) {
      _checkDevices();
    });

    _checkDevices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    participantFocusNode.removeListener(() {});
    sessionFocusNode.removeListener(() {});
    experimenterFocusNode.removeListener(() {});

    participantFocusNode.dispose();
    sessionFocusNode.dispose();
    experimenterFocusNode.dispose();

    participantController.dispose();
    sessionController.dispose();
    experimenterController.dispose();

    _port?.close();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      _clearCache();
    }
  }

  Future<void> _clearCache() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove('participantId');
    prefs.remove('sessionId');
    prefs.remove('experimenterId');
  }

  Future<void> _checkDevices() async {
    List<UsbDevice> devices = await UsbSerial.listDevices();
    bool picoWConnected = false;

    for (var device in devices) {
      if (device.productName != null) {
        if (device.productName!.contains('Pico W')) {
          picoWConnected = true;
          picoWDeviceName = device.productName!;
          userId = device.productName!;
          _connectTo(device);
        }
      }
    }

    setState(() {
      mDaqStatus = picoWConnected ? 'Connected' : 'Disconnected';
      bioPacStatus = picoWConnected ? 'Connected' : 'Disconnected';
      _updateNextButtonState();

      if (!picoWConnected) {
        userId = '--'; // Reset userId when the device is unplugged
        picoWDeviceName = '';
      }
    });
  }

  Future<bool> _connectTo(UsbDevice? device) async {
    _port?.close();

    if (device == null) {
      _device = null;
      setState(() {
        mDaqStatus = "Disconnected";
        bioPacStatus = "Disconnected";
      });
      return true;
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

    setState(() {
      mDaqStatus = "Connected";
      bioPacStatus = "Connected";
      _updateNextButtonState();
    });
    return true;
  }

  void _updateNextButtonState() {
    setState(() {
      isNextButtonActive = mDaqStatus == 'Connected' &&
          bioPacStatus == 'Connected' &&
          participantId.isNotEmpty &&
          sessionId.isNotEmpty &&
          experimenterId.isNotEmpty;
    });
  }

  void _saveToCache(String key, String value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(key, value);
  }

  Future<void> _loadFromCache() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      participantId = prefs.getString('participantId') ?? '';
      sessionId = prefs.getString('sessionId') ?? '';
      experimenterId = prefs.getString('experimenterId') ?? '';
    });

    participantController.text = participantId;
    sessionController.text = sessionId;
    experimenterController.text = experimenterId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
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
                    'Initialize the Experiment',
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
                      Center(
                        child: SizedBox(
                          width: 600,
                          child: Row(
                            children: [
                              ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  minimumSize: Size(200, 50),
                                ),
                                child: Text('Participant ID'),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  height: 50,
                                  child: TextField(
                                    focusNode: participantFocusNode,
                                    controller: participantController,
                                    onChanged: (value) {
                                      setState(() {
                                        participantId = value;
                                        _saveToCache('participantId', value);
                                        _updateNextButtonState();
                                      });
                                    },
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Colors.grey[700],
                                      border: OutlineInputBorder(),
                                      hintText: participantFocusNode.hasFocus
                                          ? ''
                                          : 'Enter Participant ID',
                                      hintStyle: TextStyle(color: Colors.white),
                                    ),
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Center(
                        child: SizedBox(
                          width: 600,
                          child: Row(
                            children: [
                              ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  minimumSize: Size(200, 50),
                                ),
                                child: Text('Session ID'),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  height: 50,
                                  child: TextField(
                                    focusNode: sessionFocusNode,
                                    controller: sessionController,
                                    onChanged: (value) {
                                      setState(() {
                                        sessionId = value;
                                        _saveToCache('sessionId', value);
                                        _updateNextButtonState();
                                      });
                                    },
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Colors.grey[700],
                                      border: OutlineInputBorder(),
                                      hintText: sessionFocusNode.hasFocus
                                          ? ''
                                          : 'Enter Session ID',
                                      hintStyle: TextStyle(color: Colors.white),
                                    ),
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Center(
                        child: SizedBox(
                          width: 600,
                          child: Row(
                            children: [
                              ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  minimumSize: Size(200, 50),
                                ),
                                child: Text('Experimenter ID'),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  height: 50,
                                  child: TextField(
                                    focusNode: experimenterFocusNode,
                                    controller: experimenterController,
                                    onChanged: (value) {
                                      setState(() {
                                        experimenterId = value;
                                        _saveToCache('experimenterId', value);
                                        _updateNextButtonState();
                                      });
                                    },
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Colors.grey[700],
                                      border: OutlineInputBorder(),
                                      hintText: experimenterFocusNode.hasFocus
                                          ? ''
                                          : 'Enter Experimenter ID',
                                      hintStyle: TextStyle(color: Colors.white),
                                    ),
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
                                ? () async {
                                    await saveToCsv();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SyncTimePage(
                                          userId: userId,
                                          participantId: participantId,
                                          mDaqStatus: mDaqStatus,
                                          bioPacStatus: bioPacStatus,
                                          experimenterId:
                                              experimenterId, // Include experimenterId
                                          sessionId: sessionId,
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                          ),
                        ],
                      ),
                      Text(
                        'Connected Device: $picoWDeviceName',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> saveToCsv() async {
    List<List<String>> data = [
      ['Session ID', 'Experimenter ID'],
      [sessionId, experimenterId]
    ];

    String csvData = const ListToCsvConverter().convert(data);

    try {
      final directory = await getDownloadsDirectory();
      final path = '${directory!.path}/$participantId.csv';
      final file = File(path);

      await file.writeAsString(csvData);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Data saved to $userId.csv'),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error saving file: $e'),
      ));
    }
  }
}
