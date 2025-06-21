import '../view/Homepage.dart';
import '../view/marketPlace.dart';

import '../controller/statecontroller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final double height;
  final List<Widget>? centerButtons;

  const CustomAppBar({
    super.key,
    this.height = kToolbarHeight,
    this.centerButtons,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final stateController = Provider.of<StateController>(context);
    final selectedIndex = stateController.selectedIndex;

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 2,
      flexibleSpace: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/img/logo.png',
                      height: 62,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'DockBox',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: centerButtons ??
                    [
                      TextButton(
                        onPressed: () {
                          stateController.setSelectedIndex(0);
                          Navigator.pushReplacement(context,MaterialPageRoute(builder: (context) => const Homepage()));
                        },
                        style: ButtonStyle(
                          padding: WidgetStateProperty.all(
                            const EdgeInsets.symmetric(horizontal: 64, vertical: 15),
                          ),
                          textStyle: WidgetStateProperty.all(
                            const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          backgroundColor: WidgetStateProperty.all(
                            selectedIndex == 0 ? Colors.black : Colors.transparent,
                          ),
                          foregroundColor: WidgetStateProperty.all(
                            selectedIndex == 0 ? Colors.white : Colors.black,
                          ),
                          overlayColor: WidgetStateProperty.all(Colors.transparent),
                        ),
                        child: const Text('Home'),
                      ),
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: () {
                          stateController.setSelectedIndex(1);
                          Navigator.pushReplacement(context,MaterialPageRoute(builder: (context) => const Marketplace()));
                        },
                        style: ButtonStyle(
                          padding: WidgetStateProperty.all(
                            const EdgeInsets.symmetric(horizontal: 38, vertical: 12),
                          ),
                          textStyle: WidgetStateProperty.all(
                            const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          backgroundColor: WidgetStateProperty.all(
                            selectedIndex == 1 ? Colors.black : Colors.transparent,
                          ),
                          foregroundColor: WidgetStateProperty.all(
                            selectedIndex == 1 ? Colors.white : Colors.black,
                          ),
                          overlayColor: WidgetStateProperty.all(Colors.transparent),
                        ),
                        child: const Text('Marketplace'),
                      ),
                    ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}