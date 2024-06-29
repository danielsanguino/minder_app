import 'package:flutter/material.dart';
import 'initialization.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Remove debug banner
      home: MinderApp(),
    );
  }
}

class MinderApp extends StatefulWidget {
  @override
  _MinderAppState createState() => _MinderAppState();
}

class _MinderAppState extends State<MinderApp>
    with AutomaticKeepAliveClientMixin {
  bool isTabletCharged = false;
  bool isDeviceCharged = false;
  bool isMDAQConnected = false;
  bool isBioPACConnected = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: SafeArea(
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Color.fromARGB(255, 206, 132, 224),
          ),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: SizedBox()), // Empty column
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Welcome to Minder APP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24.0,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    Expanded(child: SizedBox()), // Empty column
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Expanded(child: SizedBox()), // Empty column
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CheckboxListTile(
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                'Charged the Tablet',
                                style: TextStyle(color: Colors.white),
                              ),
                              value: isTabletCharged,
                              onChanged: (bool? value) {
                                setState(() {
                                  isTabletCharged = value!;
                                });
                              },
                            ),
                            CheckboxListTile(
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                'Charged the Device',
                                style: TextStyle(color: Colors.white),
                              ),
                              value: isDeviceCharged,
                              onChanged: (bool? value) {
                                setState(() {
                                  isDeviceCharged = value!;
                                });
                              },
                            ),
                            CheckboxListTile(
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                'Connect mDAQ device',
                                style: TextStyle(color: Colors.white),
                              ),
                              value: isMDAQConnected,
                              onChanged: (bool? value) {
                                setState(() {
                                  isMDAQConnected = value!;
                                });
                              },
                            ),
                            CheckboxListTile(
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                'Connect BioPAC device',
                                style: TextStyle(color: Colors.white),
                              ),
                              value: isBioPACConnected,
                              onChanged: (bool? value) {
                                setState(() {
                                  isBioPACConnected = value!;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(child: SizedBox()), // Empty column
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: SizedBox()), // Empty column
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ElevatedButton(
                          style: ButtonStyle(
                            minimumSize: MaterialStateProperty.all(
                                Size(200, 60)), // Set the size of the button
                            backgroundColor:
                                MaterialStateProperty.resolveWith<Color>(
                              (Set<MaterialState> states) {
                                if (states.contains(MaterialState.disabled)) {
                                  return const Color.fromARGB(255, 206, 132, 224); // Light red color
                                }
                                return Colors.white; // Green color
                              },
                            ),
                          ),
                          onPressed: isAllChecked()
                              ? () {
                                  // Navigate to the second page
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            InitializationPage()),
                                  );
                                }
                              : null,
                          child: Text(
                            'NEXT ->',
                            style: TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: SizedBox()), // Empty column
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool isAllChecked() {
    return isTabletCharged &&
        isDeviceCharged &&
        isMDAQConnected &&
        isBioPACConnected;
  }
}
