import '../view/login.dart';
import 'package:flutter/material.dart';

class AppStartup extends StatefulWidget {
  const AppStartup({super.key});

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  bool _engineFailed = false;
  bool _isChecking = true;

  Future<bool> engineCheck() async {
    //----------------------------------------make this check for docker engine existent, if no go to download, if yes go to login----------------------------------------
    await Future.delayed(const Duration(seconds: 2));
    // return false;
    return true;
  }

  void _checkAndNavigate() async {
    setState(() {
      _isChecking = true;
      _engineFailed = false;
    });
    bool isReady = await engineCheck();
    if (isReady && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    } else if (mounted) {
      setState(() {
        _engineFailed = true;
        _isChecking = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndNavigate());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/img/logo.png', width: 200),
                const SizedBox(width: 10),
                const Text(
                  'DockBox',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                )
              ],
            ),
            const SizedBox(height: 20),
            _isChecking
                ? Column(
              children: const [
                Text(
                  'Checking Environment and Docker Engine Startup',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                CircularProgressIndicator(),
              ],
            )
                : _engineFailed
                ? Column(
              children: [
                const Text(
                  'Fail to load Docker Engine',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _checkAndNavigate,
                  child: const Text('Retry'),
                ),
              ],
            )
                : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}