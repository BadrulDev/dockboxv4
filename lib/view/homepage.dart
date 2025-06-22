import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io';

import '../controller/cpu.dart';
import '../view/terminal.dart';
import '../controller/ram.dart';
import '../controller/runningContainer.dart';
import '../controller/statecontroller.dart';
import '../view/appbar.dart';
import '../view/containerList.dart';
import '../view/AIchat.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  List<String> _logMessages = [];
  String selectedOption = '';

  @override
  void initState() {
    super.initState();
    addLogEntry("Filter: Showing all containers");
    _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    final stateController = Provider.of<StateController>(context);
    final double containerHeight = MediaQuery.of(context).size.height * 0.65;

    if (stateController.devSet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const TerminalPage()));
      });
    }

    return Scaffold(
      backgroundColor: const Color.fromRGBO(233, 233, 233, 1),
      appBar: CustomAppBar(),
      body: Container(
        margin: const EdgeInsets.only(top: 16, left: 10, right: 10),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: MediaQuery.of(context).size.width * 0.7,
                      margin: const EdgeInsets.only(top: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black38),
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        hint: const Text('Options', style: TextStyle(fontSize: 16, color: Colors.black)),
                        value: selectedOption.isEmpty ? null : selectedOption,
                        items: ['Web', 'other'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            selectedOption = newValue!;
                            if(selectedOption == 'Web'){
                              addLogEntry("Filter: Showing containers with web ports");
                            }else if(selectedOption == 'other'){
                              addLogEntry("Filter: Showing containers without web ports");
                            }else{
                              addLogEntry("Filter: Unknown option '$selectedOption', showing all containers");
                            }
                          });
                        },
                        underline: const SizedBox(),
                        padding: const EdgeInsets.only(left: 10),
                        isExpanded: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      height: containerHeight - 70,
                      width: MediaQuery.of(context).size.width * 0.7,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.bookmark_added, color: Colors.black),
                              SizedBox(width: 10),
                              Text("Docker Container List", style: TextStyle(color: Colors.black)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: DockerContainerList(
                              addLog: addLogEntry,
                              optionSelected: selectedOption,
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: containerHeight,
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Logs", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Expanded(
                          child: SingleChildScrollView(
                            reverse: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _logMessages
                                  .map((msg) => Text(msg, style: const TextStyle(color: Colors.black, fontSize: 12)))
                                  .toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: LiveCpuChart(),
                ),
                Expanded(
                  child: LiveContainerChart(),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: LiveRamChart(),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.6,
                  height: 600,
                  child: const AiChat(),
                ),
              );
            },
          );
        },
        backgroundColor: Colors.white,
        child: const Icon(Icons.chat),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Future<void> _loadLogs() async {
    final filePath = await _getLogFilePath();
    final file = File(filePath);

    if (await file.exists()) {
      final jsonString = await file.readAsString();
      setState(() {
        _logMessages = List<String>.from(json.decode(jsonString));
      });
    } else {
      setState(() {
        _logMessages = ['Log file not found.'];
      });
    }
  }

  Future<String> _getLogFilePath() async {
    final directory = Directory('logs');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return '${directory.path}/log.json';
  }

  Future<void> addLogEntry(String activity) async {
    final filePath = await _getLogFilePath();
    final file = File(filePath);

    List<String> logs = [];

    if (await file.exists()) {
      final contents = await file.readAsString();
      try {
        logs = List<String>.from(json.decode(contents));
      } catch (e) {
        logs = [];
      }
    }

    final now = DateTime.now().toLocal().toIso8601String().substring(0, 19).replaceFirst('T', ' ');
    logs.add('$now - $activity');

    await file.writeAsString(json.encode(logs), flush: true);
    await _loadLogs();
  }
}