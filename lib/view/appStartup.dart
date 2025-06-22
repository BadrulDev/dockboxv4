import 'dart:io';

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
    try {
      await launchDockerDesktop();
      await Future.delayed(const Duration(seconds: 5));
      final result = await Process.run('docker', ['version']);

      if (result.exitCode == 0) {
        return true;
      } else {
        print('Docker error: ${result.stderr}');
        return false;
      }
    } catch (e) {
      print('Failed to check Docker engine: $e');
      return false;
    }
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

  Future<void> launchDockerDesktop() async {
    try {
      await Process.start(
        'cmd',
        ['/C', 'start', '""', r'C:\Program Files\Docker\Docker\Docker Desktop.exe'],
        runInShell: true,
      );
    } catch (e) {
      print('Failed to launch Docker Desktop: $e');
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