import 'dart:async';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class LiveRamChart extends StatefulWidget {
  const LiveRamChart({super.key});

  @override
  State<LiveRamChart> createState() => _LiveRamChartState();
}

class _LiveRamChartState extends State<LiveRamChart> {
  final List<double> _ramHistory = List.generate(30, (_) => 0.0, growable: true);
  Timer? _timer;
  double _maxRamGB = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchMaxRam();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      getRamUsage().then((ramLoad) {
        setState(() {
          _ramHistory.add(ramLoad);
          if (_ramHistory.length > 30) {
            _ramHistory.removeAt(0);
          }
        });
      });
    });
  }

  Future<void> _fetchMaxRam() async {
    try {
      final result = await Process.run(
        'wmic',
        ['computersystem', 'get', 'TotalPhysicalMemory'],
        runInShell: true,
      );
      final output = result.stdout.toString();
      final lines = output.split('\n').where((line) => line.trim().isNotEmpty).toList();

      if (lines.length >= 2) {
        final totalPhysicalMemory = double.tryParse(lines[1].trim());
        if (totalPhysicalMemory != null && totalPhysicalMemory > 0) {
          // Convert bytes to GB
          setState(() {
            _maxRamGB = totalPhysicalMemory / (1024 * 1024 * 1024);
          });
        }
      }
    } catch (e) {
      setState(() {
        _maxRamGB = 0.0;
      });
    }
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
          Row(
            children: [
              const Text("RAM Usage (%)", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Text(
                _maxRamGB > 0
                    ? 'Max: ${_maxRamGB.toStringAsFixed(2)} GB'
                    : 'Max: -',
                style: const TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 13,
                    color: Colors.black54
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
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
                    spots: _ramHistory.asMap().entries.map(
                          (e) => FlSpot(e.key.toDouble(), e.value),
                    ).toList(),
                    isCurved: true,
                    color: Colors.green,
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
              '${_ramHistory.last.toStringAsFixed(1)} %',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

Future<double> getRamUsage() async {
  try {
    final result = await Process.run(
      'wmic',
      ['OS', 'get', 'FreePhysicalMemory,TotalVisibleMemorySize', '/Value'],
      runInShell: true,
    );
    final output = result.stdout.toString();
    int? freeKb, totalKb;
    for (var line in output.split('\n')) {
      if (line.startsWith('FreePhysicalMemory=')) {
        freeKb = int.tryParse(line.split('=')[1].trim());
      } else if (line.startsWith('TotalVisibleMemorySize=')) {
        totalKb = int.tryParse(line.split('=')[1].trim());
      }
    }
    if (freeKb != null && totalKb != null && totalKb != 0) {
      final used = totalKb - freeKb;
      final usedPercent = used / totalKb * 100.0;
      return usedPercent;
    }
  } catch (e) {
    print("Error fetching RAM usage: $e");
  }
  return 0.0;
}