import 'dart:convert';
import 'dart:typed_data';
import 'package:async/async.dart';
import 'package:dropdown_formfield/dropdown_formfield.dart';
import 'package:flutter/material.dart' hide Key;
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_svprogresshud/flutter_svprogresshud.dart';
import 'package:photo_view/photo_view.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_http_post_request/StudentHome.dart';
import 'package:encrypt/encrypt.dart' ;
import 'package:flutter_svg/flutter_svg.dart';
import '/styles/my_icons.dart';

class StudentDetailPage extends StatefulWidget {
  final BluetoothDevice server;
  final String serial;
  const StudentDetailPage({this.server,this.serial});
  @override
  _StudentDetailState createState() => _StudentDetailState(serial);
}

class _StudentDetailState extends State<StudentDetailPage> {
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  BluetoothConnection connection;
  bool isConnecting = true;
  bool showContainer=false;
  bool get isConnected => connection != null && connection.isConnected;
  bool isDisconnecting = false;
  final String serial;
  _StudentDetailState(this.serial);
  String _selectedFrameSize;
  List<List<int>> chunks = <List<int>>[];
  int contentLength = 0;
  Uint8List _bytes;
  final iv = IV.fromLength(128);
  final encrypter = Encrypter(AES(Key.fromUtf8('gp2021encryption'), mode: AESMode.ecb, padding: null));
  List<String> machine = [];
  bool isuploadedflag = false;
  bool isattendflag = false;
  bool attened=false;
  RestartableTimer _timer;
  bool uploaded;
  @override
  void initState() {
    super.initState();
    _selectedFrameSize = '0';
    _getBTConnection();
    _timer = new RestartableTimer(Duration(seconds: 1), _drawImage);
    _stateChangeListener();
  }

  @override
  void dispose() {
    if (isConnected) {
      isDisconnecting = true;
      connection.dispose();
      connection = null;
    }
    _timer.cancel();
    super.dispose();
  }

  _getBTConnection() {
    BluetoothConnection.toAddress(widget.server.address).then((_connection) {
      connection = _connection;
      isConnecting = false;
      isDisconnecting = false;
      setState(() {});
      connection.input.listen(_onDataReceived).onDone(() {
        if (isDisconnecting) {
          print('Disconnecting locally');
          SVProgressHUD.showError(status: "Disconnecting locally");
          SVProgressHUD.dismiss(delay: Duration(milliseconds: 1000));
        } else {
          print('Disconnecting remotely');
          SVProgressHUD.showInfo(status: "Disconnected");
          SVProgressHUD.dismiss(delay: Duration(milliseconds: 1000));
        }
        if (this.mounted) {
          setState(() {});
        }
        Navigator.of(context).pop();
      });
    }).catchError((error) {
      Navigator.of(context).pop();
    });
  }
  _stateChangeListener() {
    FlutterBluetoothSerial.instance
        .onStateChanged()
        .listen((BluetoothState state) {
      _bluetoothState = state;
      if (!(_bluetoothState.isEnabled)) {
        {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) {
            return StudentHome(serial);
          }));
        }
      }
    });
  }
  _drawImage() {
    if (chunks.length == 0 || contentLength == 0) return;

    _bytes = Uint8List(contentLength);
    int offset = 0;
    for (final List<int> chunk in chunks) {
      _bytes.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    print("B: ${String.fromCharCode(_bytes[1])}, L: ${_bytes
        .length}");
    String f="";
    String z="";
    for (final _byte in _bytes) {
      z = String.fromCharCode(_byte);
      if(_byte != 33)
      {
        f = f + z;
        print(f);
      }
      else
      {
        machine.add(f);
        f="";
      }
    }
    print("z");
    print("Rec0: ${(machine[0])}, Reclen: ${machine.length}");
    SVProgressHUD.showSuccess(status: "Downloaded...");
    SVProgressHUD.dismiss(delay: Duration(milliseconds: 1000));
    setState(() {});
    contentLength = 0;
    chunks.clear();
  }

  void _onDataReceived(Uint8List data) {
    machine.clear();
    if (data != null && data.length > 0) {
      chunks.add(data);
      contentLength += data.length;
      _timer.reset();
    }
    print("Data Length: ${String.fromCharCode(chunks[0][1])}, chunks: ${chunks
        .length}");

  }

  void _sendMessage(String text) async {
    text = text.trim();
    if (text.length > 0) {
      try {
        connection.output.add(utf8.encode('0!'+text+"!"+"\r\n"));
        await connection.output.allSent;
      } catch (e) {
        setState(() {});
      }
    }
  }
  void _disconnect()
  {
    connection.finish();
    machine.clear();
    back();
  }
  void back() {
    if (!connection.isConnected)
    {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) {
        return StudentHome(serial);
      }));
    }
  }
  Future<http.Response> saveRecord(String serial) async {
    final response = await http.post(
      Uri.parse('https://attendance.fekracomputers.net/api/saverecordSecured'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'room_id' : machine[1],
        'machine_id': machine[0],
        'card_serial':serial,
        'uploaded_by':'Student App'
      }),
    );
    print(response.statusCode);
    if(response.statusCode==201)
    {
      // SVProgressHUD.showSuccess(status: "Uploaded successfully");
    isuploadedflag = true;
    SVProgressHUD.dismiss(delay: Duration(milliseconds: 1000));
    machine.clear();}
    else {SVProgressHUD.showError(status: "Uploading Failed");
    SVProgressHUD.dismiss(delay: Duration(milliseconds: 1000));}
    setState(() {});

  }

  @override
  Future<void> _showMyDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Disconnection Alert'),
          content: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                Text('Are you sure you want to continue?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Yes'),
              onPressed: () {
                _disconnect();

                print('Confirmed');
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget build(BuildContext context) {
    return new WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
            backgroundColor: Color(0XFFF3F5F7),
            appBar: AppBar(
                backgroundColor: Color(0XFFF3F5F7),
                elevation: 0.0,
                title: Text('Student Panel', style: TextStyle(
                  color: Color(0XFF060834),
                  fontSize: 18.0,
                  fontWeight: FontWeight.w600,)),
                centerTitle: true,
                leading: IconButton(
                  icon: Icon(Icons.bluetooth_disabled),
                  onPressed: () {
                    _showMyDialog();
                  },)

              // TextButton (
              //   onPressed: () {
              //     _showMyDialog();
              //
              //   },
              //
              //   child: Text("Disconnect"),
              // ),
              // leadingWidth: 100, // default is 56
            ),
        body: SafeArea(
          child: isConnected
              ? Column(
            children: <Widget>[
              listView(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: shotButton(),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  //shotButton(),
                  shotButton2(),
                  shotButton3(),
                ],
              ),
            ],
          )
              : Center(
            child: Text(
              "Connecting...",
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),
        )));
  }

  Widget listView() {
    return Expanded(
        child: Container(
          width: double.infinity,
          child: machine.length > 0
              ? Column(
                children: <Widget> [
                  Padding(
                    padding: const EdgeInsets.only(top:20.0, left: 16.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Your attendance is ready to be uploaded!", style: TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[200],
                      ),),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 1,
                    itemBuilder: (BuildContext context, int index) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 10.0),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                            decoration: BoxDecoration(
                              //border: Border.all(width: 1.0, color: Color(0XFF636363)),
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey[350].withOpacity(0.08),
                                  spreadRadius: 5,
                                  blurRadius: 10,
                                  offset: Offset(0, 5), // changes position of shadow
                                ),
                              ],
                            ),
                          child: RichText( text: TextSpan(
                              children: <TextSpan> [
                                TextSpan(text: 'Hall: ' + '${machine[0]} ' +
                                    'MID: ' + '${machine[1]} ',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0XFF060834)
                                    )),
                              ]
                          )
                          ),

                          //Center(child: Text('${machine[index]}',style: TextStyle(fontSize: 24,color: Colors.black))),
                      ),
                        );
                    }
          ),
                  ),
                ],
              ) :
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Row (
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[  isuploadedflag == true || isattendflag == true
                    ? SvgPicture.asset(checkIcon,
                    width: 150.0,
                    height: 150.0,
                  ) : SvgPicture.asset(notesIcon,
                width: 150.0,
                height: 150.0),

                ],
              ),
              Row (
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child:  isuploadedflag == true || isattendflag == true
                          ? Container(
                        child: Text("Attended successfully!",
                          style: TextStyle(fontWeight: FontWeight.w600,
                              fontSize: 14.0,
                              color: Colors.grey[850]),
                        )
                      ) : Container(child: Text("Attendance record is not prepared yet!",
                        style: TextStyle(fontWeight: FontWeight.w600,
                            fontSize: 14.0,
                            color: Colors.grey[850]),
                      )),
                    ),
                  ]
              ),
            ],
          ),
        ));
  }

  Widget shotButton() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 5.0),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
            primary: Color(0XFF060834),
            side: BorderSide(
              color: Color(0XFF060834),
              width: 1.0,
            ),
            minimumSize: Size(100, 100),

            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(100.0)),
            )
        ),
        onPressed: () {

          if(attened==false) {
            print(machine);
            final decrypted = encrypter.decrypt16(serial, iv: iv);
            print(decrypted.toString().substring(0,5));
            _sendMessage(decrypted.toString().substring(0,5));
            // SVProgressHUD.showSuccess(status: "attended succssesfully");
            // SVProgressHUD.dismiss(delay: Duration(milliseconds: 1000));

            attened = true;
            isattendflag = true;
            setState(() {

            });
          }
          else
            {
              SVProgressHUD.showError(status: "you have signed your attendance before");
            SVProgressHUD.dismiss(delay: Duration(milliseconds: 1000));
            }
        }
        ,
        icon: Icon(Icons.assignment_ind_rounded, size: 18),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            'Attend',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }


 /* Widget shotButton2() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: RaisedButton(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.blue)),
        onPressed: (){
          _sendMessage('1');
        },
        color: Colors.blue,
        textColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Prepare my attendance record',
            style: TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
*/
  Widget shotButton2() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 5.0),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
            primary: Color(0XFF060834),
            side: BorderSide(
              color: Color(0XFF060834),
              width: 1.0,
            ),
            minimumSize: Size(88, 36),

            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            )
        ),
        onPressed: (){
          if (attened != true) {
            _sendMessage('1');
            attened = true;
          }
          else
          {
          SVProgressHUD.showError(status: "you have signed your attendance before");
          SVProgressHUD.dismiss(delay: Duration(milliseconds: 1000));
          }
        }
        ,

        icon: Icon(Icons.download, size: 18),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            'Prepare',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
  Widget shotButton3() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 5.0),
      child: RaisedButton.icon(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Color(0XFF060834))),
        onPressed: (){
          if (machine != null) {
            saveRecord(serial);
            print(serial);
          }
          else
            {
            SVProgressHUD.showError(status: "Your record is not ready");
              setState(() {});
            }
        },
        color: Color(0XFF060834),
        textColor: Colors.white,
        icon: Icon(Icons.upload, size: 18),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            'Sign Manually',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
/*
  Widget selectframesize() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: DropDownFormField(
        titleText: 'Records Size',
        hintText: 'Please choose one',
        value: _selectedFrameSize,
        onSaved: (value) {
          _selectedFrameSize = value;
          setState(() {});
        },
        onChanged: (value) {
          _selectedFrameSize = value;
          setState(() {});
        },
        dataSource: [
          {"value": "4", "display": "1600x1200"},
          {"value": "3", "display": "1280x1024"},
          {"value": "2", "display": "1024x768"},
          {"value": "1", "display": "800x600"},
          {"value": "0", "display": "640x480"},
        ],
        textField: 'display',
        valueField: 'value',
      ),
    );
  }
}*/
}
