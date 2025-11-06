import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/Theme/theme.dart';
import '/provider/bluetooth_provider.dart';
import '/widgets/custom_card.dart';

class Homescreen extends StatelessWidget {
  const Homescreen({super.key});

  @override
  Widget build(BuildContext context) {
    // the Size of the Screen
    Size mq = MediaQuery.of(context).size;

    return Scaffold(
      // AppBar of the HomeScreen
      appBar: AppBar(
        title: const Text('B L U M A T'),
        centerTitle: true,
        leading: Padding(
          padding: EdgeInsets.only(left: mq.height * 0.005),
          child: Image.asset('assets/images/icon.png'),
        ),
        actions: [
          // Toggle to Switch between Bluetooth Modes
          IconButton(
            onPressed: context.read<BluetoothProvider>().toggleBleMode,
            tooltip: 'bluetooth toggler',
            icon: Selector<BluetoothProvider, bool>(
              selector: (context, provider) => provider.isBleMode,
              builder: (context, isBleMode, _) => isBleMode
                  ? const Icon(Icons.bluetooth)
                  : const Icon(Icons.bluetooth_audio),
            ),
          ),

          // Toggle to Switch Themes
          IconButton(
            onPressed: context.read<ThemeProvider>().themeChanger,
            tooltip: 'theme toggler',
            icon: Selector<ThemeProvider, IconData>(
              selector: (context, provider) => provider.themeIcon,
              builder: (context, themeIcon, _) => Icon(themeIcon),
            ),
          ),
        ],
      ),

      // Body of the HomeScreen
      body: Column(
        children: [
          SizedBox(height: mq.height * 0.02),
          // Upper Tab for Connection Status
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              // crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Selector<BluetoothProvider, bool>(
                  selector: (context, provider) => provider.isBleMode,
                  builder: (context, isBleMode, _) => Text(
                    isBleMode
                        ? 'Connection to BLE Device: '
                        : 'Connection to Classic Device',
                    style: TextStyle(fontSize: mq.height * 0.024),
                  ),
                ),
                SizedBox(width: mq.width * 0.008),
              ],
            ),
          ),

          const Spacer(),

          // bottom Tab for Networks
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              height: mq.height * 0.7,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.vertical(
                  top: Radius.elliptical(mq.width * 0.1, mq.height * 0.04),
                ),
              ),

              child: Padding(
                padding: EdgeInsets.only(top: mq.height * 0.024),
                // Bluetooth List View Builder
                child: Consumer<BluetoothProvider>(
                  builder: (context, value, child) => ListView.builder(
                    itemCount: value.devices.length,
                    itemBuilder: (context, index) {
                      final device = value.devices[index];
                      // custom Card
                      return CustomCard(
                        deviceName: device.name ?? 'Unknown Device',
                        deviceId: value.isBleMode ? device.id : device.address,
                        isConnected:
                            value.connectedDevice != null &&
                            (value.isBleMode
                                ? device.id == value.connectedDevice.id
                                : device.address ==
                                      value.connectedDevice.address),
                        onTap: () {
                          final isThisDeviceConnected =
                              value.connectedDevice != null &&
                              (value.isBleMode
                                  ? value.connectedDevice.id == device.id
                                  : value.connectedDevice.address ==
                                        device.address);

                          if (isThisDeviceConnected) {
                            value.disconnect();
                          } else {
                            value.connectToDevice(device);
                          }
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      floatingActionButton: Consumer<BluetoothProvider>(
        builder: (context, value, child) => FloatingActionButton.extended(
          onPressed: () {
            value.isScanning ? value.stopScan() : value.startScan();
          },
          icon: Icon(Icons.bluetooth_searching_rounded, size: mq.height * 0.03),
          label: Text(
            value.isScanning
                ? (value.isBleMode ? 'Stop Scanning' : 'Scanning...')
                : (value.isBleMode
                      ? 'Scan Ble Devices'
                      : 'Scan Classic Devices'),
            style: TextStyle(fontSize: mq.height * 0.02),
          ),
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
