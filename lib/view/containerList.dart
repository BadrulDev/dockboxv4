import 'package:flutter/material.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

import '../model/containerListModel.dart';

class DockerContainerList extends StatefulWidget {
  final void Function(String) addLog;
  final String? optionSelected;

  const DockerContainerList({
    super.key,
    required this.addLog,
    required this.optionSelected,
  });

  @override
  State<DockerContainerList> createState() => _DockerContainerListState();
}

class _DockerContainerListState extends State<DockerContainerList> {
  late Future<List<DockerContainer>> _futureContainers;

  @override
  void initState() {
    super.initState();
    print('initState: ${widget.optionSelected}');
    _futureContainers = getDockerContainers();
  }

  @override
  void didUpdateWidget(covariant DockerContainerList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.optionSelected != widget.optionSelected) {
      print('didUpdateWidget: ${widget.optionSelected}');
      setState(() {
        _futureContainers = getDockerContainers();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: FutureBuilder<List<DockerContainer>>(
        future: _futureContainers,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No containers found."));
          }

          final containers = snapshot.data!;

          return ListView.builder(
            itemCount: containers.length,
            itemBuilder: (context, index) {
              final container = containers[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                child: ListTile(
                  leading: Icon(
                    container.isRunning ? Icons.check_circle : Icons.stop_circle,
                    color: container.isRunning ? Colors.green : Colors.red,
                  ),
                  title: Text(container.name),
                  subtitle: Text(container.isRunning ? "Running" : "Stopped"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (container.webUrl != null && container.isRunning)
                        IconButton(
                          icon: const Icon(Icons.open_in_browser),
                          onPressed: () async {
                            final url = Uri.parse(container.webUrl!);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url,
                                  mode:
                                  LaunchMode.externalApplication);
                              widget.addLog(
                                  "Opened web URL for '${container.name}'");
                            } else {
                              widget.addLog(
                                  "Failed to open web URL for '${container.name}'");
                            }
                          },
                        ),
                      TextButton(
                        onPressed: () => toggleContainer(container),
                        child: Icon(
                          container.isRunning ? Icons.pause : Icons.play_arrow,
                          color: container.isRunning ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<DockerContainer>> getDockerContainers() async {
    final psResult = await Process.run('docker', [
      'ps',
      '-a',
      '--format',
      '{{.ID}},{{.Names}},{{.Image}},{{.Status}}'
    ]);

    final output = psResult.stdout.toString().trim();
    if (output.isEmpty) return [];

    final lines = output.split('\n');
    List<DockerContainer> containers = [];
    final option = widget.optionSelected;

    for (var line in lines) {
      final parts = line.split(',');
      final id = parts[0];
      final name = parts[1];
      final image = parts[2];
      final status = parts[3];

      final inspect = await Process.run('docker', [
        'inspect',
        id,
        '--format',
        '{{json .HostConfig.PortBindings}}'
      ]);
      final inspectOutput = inspect.stdout.toString().trim();

      String? webUrl;
      try {
        final Map<String, dynamic> portsMap = json.decode(inspectOutput);
        for (final entry in portsMap.entries) {
          final bindings = entry.value;
          if (bindings != null && bindings is List && bindings.isNotEmpty) {
            final hostPort = bindings[0]['HostPort'];
            webUrl ??= 'http://localhost:$hostPort';
          }
        }
      } catch (e) {
        webUrl = null;
      }

      containers.add(DockerContainer(
        id: id,
        name: name,
        image: image,
        status: status,
        webUrl: webUrl,
      ));
    }

    if (option == null || option.isEmpty) {
      return containers;
    } else if (option.toLowerCase() == "web") {
      return containers.where((c) => c.webUrl != null).toList();
    } else if (option.toLowerCase() == "other") {
      return containers.where((c) => c.webUrl == null).toList();
    } else {
      return containers;
    }
  }

  Future<void> toggleContainer(DockerContainer container) async {
    String command = container.isRunning ? 'stop' : 'start';
    widget.addLog("Container '${container.name}' $command");

    await Process.run('docker', [command, container.name]);

    if (!container.isRunning) {
      final inspectResult = await Process.run('docker', ['inspect', container.name]);
      if (inspectResult.exitCode == 0) {
        final inspectJson = jsonDecode(inspectResult.stdout);
        if (inspectJson is List && inspectJson.isNotEmpty) {
          final networkSettings = inspectJson[0]['NetworkSettings'];
          if (networkSettings != null && networkSettings['Ports'] != null) {
            final ports = networkSettings['Ports'] as Map<String, dynamic>;
            String portLog = '';
            ports.forEach((containerPort, mappings) {
              if (mappings != null && mappings is List && mappings.isNotEmpty) {
                for (var mapping in mappings) {
                  portLog +=
                  "Container '${container.name}' started at port: ${mapping['HostPort']}:$containerPort\n";
                }
              }
            });
            if (portLog.isNotEmpty) {
              widget.addLog(portLog.trim());
            }
          }
        }
      }
    }

    setState(() {
      _futureContainers = getDockerContainers();
    });
  }
}