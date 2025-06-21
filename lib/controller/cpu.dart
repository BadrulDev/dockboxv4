import 'dart:async';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class LiveCpuChart extends StatefulWidget {
  const LiveCpuChart({super.key});

  @override
  State<LiveCpuChart> createState() => _LiveCpuChartState();
}

class _LiveCpuChartState extends State<LiveCpuChart> {
  final List<double> _cpuHistory = List.generate(30, (_) => 0.0, growable: true);
  Timer? _timer;
  String _cpuType = '';


  @override
  void initState() {
    super.initState();
    _fetchCpuType();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      getCpuUsage().then((cpuLoad) {
        if (!mounted) return;
        setState(() {
          _cpuHistory.add(cpuLoad);
          if (_cpuHistory.length > 30) {
            _cpuHistory.removeAt(0);
          }
        });
      });
    });
  }



  Future<void> _fetchCpuType() async {
    try {
      final result = await Process.run(
        'wmic',
        ['cpu', 'get', 'name'],
        runInShell: true,
      );
      final output = result.stdout.toString();
      final lines = output.split('\n').where((line) => line.trim().isNotEmpty).toList();
      if (lines.length >= 2 && mounted) {
        setState(() {
          _cpuType = lines[1].trim();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cpuType = 'Unknown';
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
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "CPU Usage (%)",
            style: TextStyle(fontWeight: FontWeight.bold),
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
                    spots: _cpuHistory.asMap().entries.map(
                          (e) => FlSpot(e.key.toDouble(), e.value),
                    ).toList(),
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _cpuType,
                  style: const TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${_cpuHistory.last.toStringAsFixed(1)} %',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<double> getCpuUsage() async {
  try {
    final result = await Process.run(
      'wmic',
      ['cpu', 'get', 'loadpercentage'],
      runInShell: true,
    );

    final output = result.stdout.toString();
    final lines = output.split('\n').where((line) => line.trim().isNotEmpty).toList();

    if (lines.length >= 2) {
      final percentage = double.tryParse(lines[1].trim());
      return percentage ?? 0.0;
    }
  } catch (e) {
    print("Error fetching CPU usage: $e");
  }
  return 0.0;
}