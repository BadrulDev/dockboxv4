import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller/statecontroller.dart';
import '../view/appbar.dart';

class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key});

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _output = [];
  bool _isRunningCommand = false;

  @override
  Widget build(BuildContext context) {
    final stateController = Provider.of<StateController>(context);
    if (!stateController.devSet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: CustomAppBar(),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _output.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2),
                child: Text(
                  _output[index],
                  style: const TextStyle(
                    fontFamily: 'Courier New',
                    color: Colors.greenAccent,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
            child: Row(
              children: [
                const Text("C:\\>", style: TextStyle(color: Colors.greenAccent)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white, fontFamily: 'Courier New'),
                    cursorColor: Colors.greenAccent,
                    decoration: const InputDecoration.collapsed(hintText: 'Enter command', hintStyle: TextStyle(color: Colors.grey)),
                    onSubmitted: (val) => _runCommand(val),
                    enabled: !_isRunningCommand,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }


  void _runCommand(String command) async {
    if (command.trim().isEmpty) return;
    setState(() {
      _output.add("C:\\> $command");
      _isRunningCommand = true;
    });

    try {
      final process = await Process.start(
        Platform.isWindows ? 'cmd' : 'bash',
        Platform.isWindows ? ['/c', command] : ['-c', command],
        runInShell: true,
      );

      process.stdout.transform(utf8.decoder).listen((line) {
        setState(() => _output.add(line.trimRight()));
        _scrollToBottom();
      });
      process.stderr.transform(utf8.decoder).listen((line) {
        setState(() => _output.add(line.trimRight()));
        _scrollToBottom();
      });

      await process.exitCode;
    } catch (e) {
      setState(() => _output.add("Error: $e"));
    }

    setState(() {
      _isRunningCommand = false;
    });
    _controller.clear();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }
}
