import 'package:flutter/material.dart';
import 'report.dart'; // Import the report page

class UploadPage extends StatelessWidget {
  final String userId;

  const UploadPage({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 206, 132, 224), // Set the background color for the whole app
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
                    'Upload Data',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24.0,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Your upload logic here
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Add your upload functionality here
                  },
                  child: Text('Upload'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                  ),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Add your merge functionality here
                  },
                  child: Text('Merge'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(vertical: 16.0),
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
                    style: TextStyle(color: Colors.white, fontSize: 20.0),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30.0),
                    border:Border.all(color: Colors.white, width: 2.0),
                  ),
                  child: TextButton.icon(
                    icon: Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size:36.0,
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
                          builder: (context) => ReportPage(userId: userId)),
                          );
                        },
                      ),
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

