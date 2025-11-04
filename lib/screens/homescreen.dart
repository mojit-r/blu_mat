import 'package:blu_mat/Theme/theme.dart';
import 'package:blu_mat/widgets/custom_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
          IconButton(
            onPressed: context.read<ThemeProvider>().themeChanger,
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
                Text(
                  'Connection: ',
                  style: TextStyle(fontSize: mq.height * 0.03),
                ),
                SizedBox(width: mq.width * 0.008),
                Image.asset(
                  'assets/images/green_dot.png',
                  height: mq.height * 0.045,
                ),
              ],
            ),
          ),

          const Spacer(),

          // bottom Tab for Networks
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              height: mq.height * 0.6,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.vertical(
                  top: Radius.elliptical(mq.width * 0.1, mq.height * 0.04),
                ),
              ),

              child: Padding(
                padding: EdgeInsets.only(top: mq.height * 0.024),
                child: ListView.builder(
                  itemCount: 2,
                  itemBuilder: (context, index) => const CustomCard(),
                ),
              ),
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: Icon(Icons.bluetooth_searching_rounded, size: mq.height * 0.03),
        label: Text('Scan', style: TextStyle(fontSize: mq.height * 0.02)),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
