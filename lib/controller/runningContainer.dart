import 'dart:async';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class LiveContainerChart extends StatefulWidget {
  const LiveContainerChart({super.key});

  @override
  State<LiveContainerChart> createState() => _LiveContainerChartState();
}

class _LiveContainerChartState extends State<LiveContainerChart> {
  final List<int> _containerHistory = List.generate(30, (_) => 0, growable: true);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      getRunningContainerCount().then((containerCount) {
        setState(() {
          _containerHistory.add(containerCount);
          if (_containerHistory.length > 30) {
            _containerHistory.removeAt(0);
          }
        });
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.18,
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Active Containers", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: (_containerHistory.reduce((a, b) => a > b ? a : b) + 2).toDouble(), // add 2 for better visualization
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 36),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _containerHistory.asMap().entries.map(
                          (e) => FlSpot(e.key.toDouble(), e.value.toDouble()),
                    ).toList(),
                    isCurved: true,
                    color: Colors.purple,
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_containerHistory.last} running',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

Future<int> getRunningContainerCount() async {
  try {
    final result = await Process.run(
      'docker',
      ['ps', '-q'],
      runInShell: true,
    );
    if (result.exitCode == 0) {
      final outputLines = result.stdout.toString().split('\n').where((line) => line.trim().isNotEmpty);
      return outputLines.length;
    }
  } catch (e) {
    print("Error fetching running container count: $e");
  }
  return 0;
}