import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_http_post_request/BluetoothDeviceListEntry.dart';
import 'package:flutter_http_post_request/pages/detailpage.dart';
import 'package:flutter_http_post_request/pages/login_page.dart';
class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;

  List<BluetoothDevice> devices = List<BluetoothDevice>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _getBTState();
    _stateChangeListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state.index == 0) {
      //resume
      if (_bluetoothState.isEnabled) {
        _listBondedDevices();
      }
    }
  }

  _getBTState() {
    FlutterBluetoothSerial.instance.state.then((state) {
      _bluetoothState = state;
      if (_bluetoothState.isEnabled) {
        _listBondedDevices();
      }
      setState(() {});
    });
  }

  _stateChangeListener() {
    FlutterBluetoothSerial.instance
        .onStateChanged()
        .listen((BluetoothState state) {
      _bluetoothState = state;
      if (_bluetoothState.isEnabled) {
        _listBondedDevices();

      } else {
        devices.clear();
      }
      print("State isEnabled: ${state.isEnabled}");
      setState(() {});
    });
  }

  _listBondedDevices() {
    FlutterBluetoothSerial.instance
        .getBondedDevices()
        .then((List<BluetoothDevice> bondedDevices) {
      devices = bondedDevices;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return new WillPopScope(
        onWillPop: () async => false,
    child: Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0XFFF3F5F7),
        elevation: 0.0,
        title: Text("Admin Panel", style: TextStyle(
          color: Color(0XFF060834),
          fontSize: 18.0,
          fontWeight: FontWeight.w600,
        ),),
        centerTitle: true,
          leading: TextButton (
            onPressed: () {

            },
            child: RaisedButton(
          shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50),
          side: BorderSide(color: Color(0XFF060834))),
      color: Color(0XFF060834),
      textColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Text("Log Out", style: TextStyle(
          fontSize: 12,
        ),),
      ),
      onPressed: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) {
          return LoginPage();
        }));
      },
    )

          ),
        leadingWidth: 100,
      ),
      body: Container(
        child: Column(
          children: <Widget>[
            // SwitchListTile(
            //   title: const Text('Enable Bluetooth'),
            //   value: _bluetoothState.isEnabled,
            //   onChanged: (bool value) {
            //     // Do the request and update with the true value then
            //     future() async {
            //       // async lambda seems to not working
            //       if (value)
            //         await FlutterBluetoothSerial.instance.requestEnable();
            //       else
            //         await FlutterBluetoothSerial.instance.requestDisable();
            //     }
            //
            //     future().then((_) {
            //       setState(() {});
            //     });
            //   },
            // ),
            ListTile(
              title: Text("Bluetooth Status"),
              subtitle: Text(_bluetoothState.toString().substring(21)),
              // trailing:
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 30.0),
                child: ListView(
                  children: devices
                      .map((_device) => Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: BluetoothDeviceListEntry(
                    device: _device,
                    enabled: true,
                    onTap: () {
                        print("Item");
                        _startCameraConnect(context, _device);
                    },
                  ),
                      ))
                      .toList(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 70.0),
              child: RaisedButton(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                    side: BorderSide(color: Color(0XFF060834))),
                color: Color(0XFF060834),
                textColor: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text("Bluetooth Settings", style: TextStyle(
                    fontSize: 18,
                  ),),
                ),
                onPressed: () {
                  FlutterBluetoothSerial.instance.openSettings();
                },
              ),
            ),
          ],
        ),
      ),
    ));
  }

  void _startCameraConnect(BuildContext context, BluetoothDevice server) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) {
      return DetailPage(server: server);
    }));
  }
}