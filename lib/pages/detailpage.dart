import 'dart:convert';
import 'dart:typed_data';
import 'package:async/async.dart';
import 'package:flutter/material.dart' hide Key;
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_http_post_request/HomePage.dart';
import 'package:flutter_svprogresshud/flutter_svprogresshud.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '/styles/my_icons.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:encrypt/encrypt.dart' ;

class DetailPage extends StatefulWidget {
  final BluetoothDevice server;

  const DetailPage({this.server});

  @override
  _DetailPageState createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  BluetoothConnection connection;
  bool isConnecting = true;
  bool showContainer=false;
  bool get isConnected => connection != null && connection.isConnected;
  bool isDisconnecting = false;
  bool syncing = false;
  String _selectedFrameSize;
  final iv = IV.fromLength(128);
  final encrypter = Encrypter(AES(Key.fromUtf8('gp2021encryption'), mode: AESMode.ecb, padding: null));
  List<List<int>> chunks = <List<int>>[];
  int contentLength = 0;
  Uint8List _bytes;
  List<String> records = [];
  String machineID ;
  String roomID ;
  RestartableTimer _timer;
  int value;

  @override
  void initState() {
    super.initState();
    _selectedFrameSize = '1';
    _getBTConnection();
    _timer = new RestartableTimer(Duration(seconds: 1), _drawImage);
    _stateChangeListener();
  }

  @override
  void dispose() {
    if (isConnected ) {
      isDisconnecting = true;
      connection.dispose();
      connection = null;
    }
    else
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
        } else {
          print('Disconnecting remotely');
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
            return HomePage();
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
        records.add(f);
        setState(() {});
        f="";
      }
    }
    print("z");
    print("Rec0: ${(records[0])}, Reclen: ${records.length}");
    SVProgressHUD.showSuccess(status: "Downloaded...");
    SVProgressHUD.dismiss(delay: Duration(milliseconds: 1000));
    machineID=records.last;
    records.removeLast();
    roomID=records.last;
    records.removeLast();
    contentLength = 0;
    chunks.clear();
  }

  void _onDataReceived(Uint8List data) {
    if (data != null && data.length > 0) {
      chunks.add(data);
      contentLength += data.length;
      _timer.reset();
    }
    SVProgressHUD.show(status: 'Syncing');
    print("Data Length: ${String.fromCharCode(chunks[0][1])}, chunks: ${chunks
        .length}");
  }

  void _sendMessage(String text) async {
    text = text.trim();
    if (text.length > 0) {
      try {
        connection.output.add(utf8.encode(text+"\r\n"));

        await connection.output.allSent;
      } catch (e) {
        setState(() {});
      }
    }
  }
  void _disconnect()
  {
    connection.finish();
    back();
  }
  void back() {
    if (!connection.isConnected)
      {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) {
          return HomePage();
        }));
      }
  }
  Future <int> saveRecord(String record, machineID,roomID) async {
    SVProgressHUD.show(status: "Uploading");
    final response = await http.post(
      Uri.parse("https://attendance.fekracomputers.net/api/saverecordSecured"),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'room_id':roomID,
        'card_serial': record,
        'machine_id':machineID,
        'uploaded_by':'Admin App'
      }),
    );
    return response.statusCode;

  }
  void UploadRecord()
  {

    for(final record in records) {
      final encrypted = encrypter.encrypt(record+"xxxxxxxxxxx", iv: iv);
      print(encrypted.base16.toString());
      saveRecord(encrypted.base16.toString(),machineID,roomID).then((value) {
        if (value == 201) {
          SVProgressHUD.showSuccess(status: "Uploaded");
          SVProgressHUD.dismiss(delay: Duration(milliseconds: 1000));
          records.remove(record);
          print(records);
          setState(() {});
        }
        else if (value==406)
        {SVProgressHUD.showError(status: "Record Invalid");
        SVProgressHUD.dismiss(delay: Duration(milliseconds: 1000));}
        else if (value==500)
        {
          SVProgressHUD.showInfo(status: "Removing Duplicted Records");
          SVProgressHUD.dismiss(delay: Duration(milliseconds: 1000));
          records.remove(record);
        }
        setState(() {});
      });

    }

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
                Text('Ending the connection will lose all synced records.'),
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
    child:Scaffold(
        backgroundColor: Color(0XFFF3F5F7),
        appBar: AppBar(
          backgroundColor: Color(0XFFF3F5F7),
          elevation: 0.0,
          title: Text('Records Page', style: TextStyle(
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
              Container(
                decoration: BoxDecoration(
                  color: Color(0XFFF3F5F7),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0X0A536C82),
                      blurRadius: 24,
                      offset: Offset(0, -8), // changes position of shadow
                    ),
                  ],
                ),
                child: Row(
                  //mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    shotButton(),
                    shotButton3(),
                  ],
                ),
              ),
            ],
          )
              : Center(
            child: Text(
              "Connecting..",
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
          child: records.length > 0 //Mahmoud's changes
              ? Column(
                children: <Widget> [
                  Padding(
                    padding: const EdgeInsets.only(top:20.0, left: 16.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Records", style: TextStyle(
                        fontSize: 34.0,
                        fontWeight: FontWeight.bold,
                        color: Color(0XFF060834),
                      ),),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: records.length,
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
                              TextSpan(text: '#' + '${index}  ',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFFDB70B),
                              )),
                              TextSpan(text: 'ID: ' + '${records[index]} ' +
                                  'Hall: ' + '${roomID} ' +
                                  'MID: '+ '${machineID} ',
                                  style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0XFF060834)
                              )),
                            ]
                          )
                           ),
                        ),
                      );
                    }
          ),
                  ),
                ],
              ) : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Row (
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  SvgPicture.asset(notesIcon,
                    width: 150.0,
                    height: 150.0,
                  ),

                ],
              ),
              Row (
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Container(
                        child: Text("No records to show!",
                          style: TextStyle(fontWeight: FontWeight.w600,
                              fontSize: 14.0,
                              color: Colors.grey[850]),
                        ),
                      ),
                    ),
                  ]
              ),
            ],
          )

        ));
  }

  // Widget shotButton() {
  //   return Container(
  //     padding: const EdgeInsets.all(16),
  //     child: RaisedButton(
  //       shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(18),
  //           side: BorderSide(color: Colors.blue)),
  //       onPressed: () {
  //         records.clear();
  //         _sendMessage(_selectedFrameSize);
  //         setState(() {});
  //       },
  //       color: Colors.blue,
  //       textColor: Colors.white,
  //       child: Padding(
  //         padding: const EdgeInsets.all(8.0),
  //         child: Text(
  //           'Sync',
  //           style: TextStyle(fontSize: 24),
  //         ),
  //       ),
  //     ),
  //   );
  // }

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
            minimumSize: Size(88, 36),

            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            )
        ),
        onPressed: () {
          records.clear();
          _sendMessage('1!0!');
          setState(() {});
        },

        icon: Icon(Icons.sync, size: 18),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            'Sync',
            style: TextStyle(fontSize: 18),
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
          setState(() {});
        },
        color: Colors.blue,
        textColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Show Records',
            style: TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }*/
  Widget shotButton3() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 5.0),
      child: RaisedButton.icon(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Color(0XFF060834))),
        onPressed: (){
          UploadRecord();
        },
        color: Color(0XFF060834),
        textColor: Colors.white,
        icon: Icon(Icons.upload, size: 18),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            'Upload Records',
            style: TextStyle(fontSize: 18),
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
