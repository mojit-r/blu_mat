import 'package:flutter/material.dart';

class CustomCard extends StatelessWidget {
  final String deviceName;
  final String deviceId;
  final bool isConnected;
  final VoidCallback onTap;

  const CustomCard({
    super.key,
    this.deviceName = 'Unknown Device',
    this.deviceId = '00:00:AA:00:00:AA',
    this.isConnected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // The Size of the Screen
    Size mq = MediaQuery.of(context).size;

    // Card
    return Card(
      margin: EdgeInsets.fromLTRB(
        mq.width * 0.03,
        mq.height * 0.01,
        mq.width * 0.03,
        mq.height * 0.01,
      ),
      color: Theme.of(context).colorScheme.surface,

      // List Tile
      child: ListTile(
        contentPadding: EdgeInsets.fromLTRB(
          mq.width * 0.025,
          mq.height * 0.008,
          mq.width * 0.025,
          mq.height * 0.008,
        ),

        // Card Icon
        leading: Icon(
          Icons.bluetooth,
          color: isConnected ? Colors.blue : Colors.grey,
          size: mq.height * 0.04,
        ),

        // Card Title
        title: Text(deviceName, style: TextStyle(fontSize: mq.height * 0.02)),

        // Card Subtitle
        subtitle: Text(deviceId),

        // Card Button
        trailing: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: isConnected
                ? const Color.fromARGB(255, 0, 186, 0)
                : Theme.of(context).colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),

          child: Text(
            isConnected ? 'Connected' : 'Connect',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: mq.height * 0.017,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
