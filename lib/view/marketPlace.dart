import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../controller/aiSearch.dart';
import '../view/appbar.dart';

class Marketplace extends StatefulWidget {
  const Marketplace({super.key});

  @override
  State<Marketplace> createState() => _MarketplaceState();
}

class _MarketplaceState extends State<Marketplace> {
  //searching algo with openAI
  final TextEditingController _imageController = TextEditingController();
  late TextEditingController _autoCompleteController;
  List<String> _suggestions = [];
  late AISearch suggestionsService;
  Timer? _debounce;
  //recent data
  List<String> _recentImages = [];
  //image show in ghcr or docker
  String? _selectedImageName;
  String? _selectedTag;
  List<String> _availableTags = [];
  bool _isPulling = false;
  bool _isLoading = false;
  bool _imageExists = true;
  bool _isGhcr = true;
  //pulling and saving image
  bool _pulled = false;
  bool _isRunning = false;
  bool _isweb = false;
  final TextEditingController _hostPortController = TextEditingController();
  final TextEditingController _containerPortController = TextEditingController();
  //log
  List<String> _logMessages = [];

  @override
  void initState() {
    super.initState();
    suggestionsService = AISearch();
    _imageController.addListener(() {
      print('listener triggered: ${_imageController.text}');
      _onTextChanged(_imageController.text);
    });
    _loadRecent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        appBar: CustomAppBar(),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              SizedBox(
                width: 350,
                child: Column(
                  children: [
                    const Text("Search Docker Image", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SizedBox(
                      child: Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                          return _suggestions.where(
                                (option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()),
                          );
                        },
                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                          _autoCompleteController = textEditingController;
                          return TextField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: "Image name (ghcr.io/...)",
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              _imageController.text = value;
                              _onTextChanged(value);
                            },
                            onSubmitted: (_) => _showImage(),
                          );
                        },
                        onSelected: (String selection) {
                          _imageController.text = selection;
                          _showImage();
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.visibility),
                      label: const Text("Show"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                      onPressed: _showImage,
                    ),
                    const SizedBox(height: 32),
                    const Text("🔁 Recent Search", style: TextStyle(fontSize: 16)),
                    if (_recentImages.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      for (final img in _recentImages.take(5))
                        ListTile(
                          title: Text(img, overflow: TextOverflow.ellipsis),
                          onTap: () {
                            _autoCompleteController.text = img;
                            _imageController.text = img;
                            _autoCompleteController.selection = TextSelection.fromPosition(
                              TextPosition(offset: img.length),
                            );
                            _showImage();
                          },
                          trailing: const Icon(Icons.history),
                        )
                    ]
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)],
                    ),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : (_selectedImageName == null)
                        ? const Center(child: Text("Enter a Docker image name to preview"))
                        : Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Image.network(
                                _isGhcr
                                    ? 'https://github.githubassets.com/images/modules/logos_page/GitHub-Mark.png'
                                    : 'https://www.docker.com/wp-content/uploads/2022/03/Moby-logo.png',
                                width: 48,
                                height: 48,
                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _selectedImageName!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (!_imageExists)
                                const Text(
                                  '⚠️ The image could not be found on GitHub Container Registry Or Docker Hub.',
                                  style: TextStyle(color: Colors.red, fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                              if (_imageExists && _availableTags.isNotEmpty)
                                DropdownButton<String>(
                                  value: _selectedTag,
                                  items: _availableTags
                                      .map((tag) => DropdownMenuItem(value: tag, child: Text(tag)))
                                      .toList(),
                                  onChanged: (val) {
                                    setState(() => _selectedTag = val);
                                  },
                                ),
                              const SizedBox(height: 10),
                              Text(
                                '$_selectedImageName:$_selectedTag',
                                style: TextStyle(color: Colors.black, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              if (_imageExists && _availableTags.isNotEmpty)
                                ElevatedButton(
                                  onPressed: (_isPulling || _pulled)
                                      ? null
                                      : () {
                                    _pullImage('$_selectedImageName:$_selectedTag');
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                  ),
                                  child: _isPulling
                                      ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                      : const Text('Pull'),
                                ),

                              const SizedBox(height: 20),
                              if(_isweb)
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _hostPortController,
                                        decoration: InputDecoration(
                                          labelText: "Host Port",
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: _containerPortController,
                                        decoration: InputDecoration(
                                          labelText: "Container Port",
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                              if(_pulled)
                                ElevatedButton(
                                    onPressed: _isRunning
                                    ? null
                                    : () {
                                      final hostPort = _hostPortController.text.trim();
                                      final containerPort = _containerPortController.text.trim();
                                      if (hostPort.isNotEmpty && containerPort.isNotEmpty) {
                                        _runImage(hostPort: hostPort, containerPort: containerPort);
                                      } else {
                                        _runImage();
                                      }
                                    },
                                  style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                  ),
                                  child: _isRunning
                                      ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                      : const Text('Run Image'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
              )
            ],
          ),
        )
    );
  }

  //===================================search with openAI=========================================
  Future<String> _getApi() async {
    await dotenv.load(fileName: ".env");
    return dotenv.env['API_KEY']!;
  }

  void _onTextChanged(String input) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (input.isNotEmpty) {
        _fetchSuggestions(input);
      } else {
        setState(() => _suggestions = []);
      }
    });
  }

  Future<void> _fetchSuggestions(String input) async {
    print('Fetching suggestions for: $input');
    String key = await _getApi();
    try {
      final suggestions = await suggestionsService.fetchSuggestions(input, key);
      print("Suggestions: $suggestions");

      setState(() {
        _suggestions = suggestions;
      });
    } catch (e) {
      print('Error during fetch: $e');
      setState(() {
        _suggestions = ['No valid suggestions found'];
      });
    }

  }

  //===================================recent data=========================================
  Future<void> _loadRecent() async {
    final filePath = await _getRecentFilePath();
    final file = File(filePath);

    if (await file.exists()) {
      final jsonString = await file.readAsString();
      try {
        setState(() {
          _recentImages = List<String>.from(json.decode(jsonString));
        });
      } catch (e) {
        print("Failed to parse recent images: $e");
        setState(() {
          _recentImages = [];
        });
      }
    } else {
      setState(() {
        _recentImages = [];
      });
    }
  }

  Future<String> _getRecentFilePath() async {
    final directory = Directory('logs');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return '${directory.path}/recent.json';
  }

  Future<void> addRecentEntry(String imageName) async {
    final filePath = await _getRecentFilePath();
    final file = File(filePath);

    List<String> recent = [];

    if (await file.exists()) {
      final contents = await file.readAsString();
      try {
        recent = List<String>.from(json.decode(contents));
      } catch (e) {
        recent = [];
      }
    }

    recent.remove(imageName);
    recent.insert(0, imageName);
    if (recent.length > 10) recent = recent.sublist(0, 10);

    await file.writeAsString(json.encode(recent));
    setState(() {
      _recentImages = recent;
    });
  }

  //==================================image ========================================
  //--------------------------------image searching---------------------------------
  void _showImage() async {
    final name = _imageController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _selectedImageName = name;
      _isLoading = true;
      _availableTags = [];
      _selectedTag = null;
      _imageExists = true;
      if (!_recentImages.contains(name)) {
        _recentImages.insert(0, name);
        if (_recentImages.length > 10) {
          _recentImages = _recentImages.sublist(0, 10);
        }
      }
      _isGhcr = true;
      _pulled = false;
      _isRunning = false;
      _isweb = false;
    });

    //add data to recent log
    await addRecentEntry(name);

    // Determine if it's GHCR or Docker Hub
    final isGhcr = name.startsWith('ghcr.io/');
    //check if the search image exist in both registry
    bool exists = isGhcr
        ? await checkPublicGHCRImageExists(name)
        : await checkDockerHubImageExists(name);

    if (!exists) {
      setState(() {
        _imageExists = false;
        _isLoading = false;
      });
      return;
    }

    //check if the exist image has tags
    List<String> tags = [];
    try {
      tags = isGhcr ? await fetchGHTags(name) : await fetchDockerTags(name);
    } catch (e) {
      print("Tag fetch error: $e");
    }

    //implement all the data search to UI
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _isGhcr = isGhcr;
      _availableTags = tags.isNotEmpty ? tags : ['latest'];
      if (_availableTags.contains('main')) {
        _selectedTag = 'main';
      } else if (_availableTags.contains('latest')) {
        _selectedTag = 'latest';
      } else {
        _selectedTag = _availableTags.last;
      }
      _isLoading = false;
    });
  }

  Future<bool> checkPublicGHCRImageExists(String imageName) async {
    final token = dotenv.env['GIT_TOKEN'];
    print(token);
    if (token == null) throw Exception("GitHub token missing");

    // Parse image name like "ghcr.io/owner/image"
    final path = imageName.replaceFirst('ghcr.io/', '');
    final parts = path.split('/');
    if (parts.length < 2) throw Exception("Invalid GHCR image name");

    final owner = parts[0];
    final repo = parts[1];

    // Use GitHub API to fetch container packages for the user
    final url = Uri.parse("https://api.github.com/users/$owner/packages?package_type=container");

    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/vnd.github+json',
    });

    if (response.statusCode == 200) {
      final List<dynamic> packages = jsonDecode(response.body);
      final imageExists = packages.any((pkg) => pkg['name'] == repo);
      return imageExists;
    } else if (response.statusCode == 404) {
      return false;
    } else {
      print("Failed to fetch GHCR images: ${response.statusCode} - ${response.body}");
      return false;
    }
  }

  Future<List<String>> fetchGHTags(String imageName) async {
    final token = dotenv.env['GIT_TOKEN'];
    if (token == null) throw Exception("GitHub token missing");

    final parts = imageName.replaceFirst('ghcr.io/', '').split('/');
    if (parts.length < 2) throw Exception("Invalid GHCR image name");

    final owner = parts[0];
    final repo = parts[1];

    final url = 'https://api.github.com/users/$owner/packages/container/$repo/versions';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github+json',
      },
    );

    final Set<String> allTags = {};

    if (response.statusCode == 200) {
      final List<dynamic> versions = jsonDecode(response.body);

      for (final version in versions) {
        final tags = version['metadata']?['container']?['tags'];
        if (tags != null && tags is List) {
          allTags.addAll(tags.cast<String>());
        }
      }
    } else {
      print("GitHub API Error: ${response.statusCode} - ${response.body}");
    }

    if (!allTags.contains('main')) {
      //final exists = await _checkTagExistsDirectly(imageName, 'main');
      //if (exists) {
        allTags.add('main');
      //}
    }

    return allTags.toList();
  }

  Future<bool> _checkTagExistsDirectly(String imageName, String tag) async {
    final token = dotenv.env['GIT_TOKEN'];
    if (token == null) {
      print("GitHub token missing");
      return false;
    }

    final path = imageName.replaceFirst('ghcr.io/', '');
    final parts = path.split('/');
    if (parts.length < 2) return false;

    final owner = parts[0];
    final repo = parts[1];

    final url = Uri.parse("https://ghcr.io/v2/$owner/$repo/manifests/$tag");

    final response = await http.head(url, headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/vnd.docker.distribution.manifest.v2+json',
    });

    print("HEAD check for '$tag': ${response.statusCode}");

    return response.statusCode == 200;
  }

  Future<bool> checkDockerHubImageExists(String imageName, {String tag = "latest"}) async {
    final parts = imageName.split('/');
    String namespace = 'library';
    String repo;

    if (parts.length == 2) {
      namespace = parts[0];
      repo = parts[1];
    } else {
      repo = parts[0];
    }

    final url = Uri.parse("https://hub.docker.com/v2/repositories/$namespace/$repo/tags/$tag");
    final response = await http.get(url);

    return response.statusCode == 200;
  }

  Future<List<String>> fetchDockerTags(String imageName) async {
    final parts = imageName.split('/');
    String namespace = 'library';
    String repo;

    if (parts.length == 2) {
      namespace = parts[0];
      repo = parts[1];
    } else {
      repo = parts[0];
    }

    final url = Uri.parse("https://hub.docker.com/v2/repositories/$namespace/$repo/tags?page_size=100");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final results = json['results'] as List;
      return results.map((e) => e['name'].toString()).toList();
    }
    return [];
  }

  //-----------------------------------------image pulling-----------------------------------------

  void _pullImage(String imageName) async {
    setState(() {
      _isPulling = true;
    });

    try {
      final pullResult = await Process.run('docker', ['pull', imageName]);
      print(pullResult.stdout);
      if (pullResult.exitCode != 0) {
        print('Failed to pull image: ${pullResult.stderr}');
        addLogEntry('Failed to pull image: ${pullResult.stderr}');
        setState(() {
          _isPulling = false;
        });
        return;
      }

      final dir = Directory('pulledImages');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final sanitizedImageName = imageName.replaceAll('/', '_').replaceAll(':', '_');
      final outputPath = '${dir.path}/$sanitizedImageName.tar';

      // Check if image is already saved
      final file = File(outputPath);
      if (await file.exists()) {
        print('Image already saved at $outputPath');
        addLogEntry('Image: $sanitizedImageName already saved at $outputPath');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Image already saved at $outputPath"),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _isPulling = false;
          _pulled = true;
        });
        await _inspectExposedPorts(imageName);
        return;
      }

      final saveResult = await Process.run('docker', ['save', '-o', outputPath, imageName]);
      print(saveResult.stdout);
      if (saveResult.exitCode != 0) {
        print('Failed to save image: ${saveResult.stderr}');
        addLogEntry('Failed to save image: ${saveResult.stderr}');
      } else {
        print('Image saved to $outputPath');
        addLogEntry('Image saved to $outputPath');
      }
    } catch (e) {
      print('Error during image pull/save: $e');
      addLogEntry('Error during image pull/save: $e');
    }

    await _inspectExposedPorts(imageName);

    setState(() {
      _isPulling = false;
      _pulled = true;
    });
  }

  Future<void> _inspectExposedPorts(String imageName) async {
    final inspectResult = await Process.run('docker', ['inspect', imageName]);
    if (inspectResult.exitCode == 0) {
      final inspectJson = jsonDecode(inspectResult.stdout);
      if (inspectJson is List && inspectJson.isNotEmpty) {
        final config = inspectJson[0]['Config'];
        if (config != null && config['ExposedPorts'] != null) {
          final exposedPorts = config['ExposedPorts'].keys.toList();
          print('🔌 Exposed ports: $exposedPorts');
          setState(() {
            _isweb = true;
          });
        } else {
          print('No exposed ports found in image.');
        }
      }
    } else {
      print('Failed to inspect image: ${inspectResult.stderr}');
    }
  }

  //-------------------------------------image run ----------------------------------------

  Future<void> _runImage({String? hostPort, String? containerPort}) async {
    if (_selectedImageName == null || _selectedImageName!.isEmpty) return;
    final imageName = '$_selectedImageName:${_selectedTag ?? 'latest'}';
    final sanitizedImageName = imageName.replaceAll('/', '_').replaceAll(':', '_');
    final tarPath = 'pulledImages/$sanitizedImageName.tar';

    setState(() => _isRunning = true);
    print('Attempt to run image: $sanitizedImageName');
    addLogEntry('Attempt to run image: $sanitizedImageName');

    try {
      final tarFile = File(tarPath);
      if (await tarFile.exists()) {
        final loadResult = await Process.run('docker', ['load', '-i', tarPath]);
        if (loadResult.exitCode != 0) {
          addLogEntry('Failed to load image from tar: ${loadResult.stderr}');
          throw Exception('Failed to load image from tar: ${loadResult.stderr}');
        } else {
          print('Loaded image from $tarPath');
        }
      }

      final args = [
        'run',
        '-d',
        '--name',
        'container_${imageName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase()}',
      ];

      if (hostPort != null && containerPort != null) {
        args.addAll(['-p', '$hostPort:$containerPort']);
      }

      args.add(imageName);

      final runResult = await Process.run('docker', args);

      if (runResult.exitCode != 0) {
        throw Exception("Run failed:\n${runResult.stderr}");
      }

      print('Successfully to run image: $sanitizedImageName');
      addLogEntry('Successfully to run image: $sanitizedImageName');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ Image running as container."),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      print('Attempt to run image: $sanitizedImageName failed');
      addLogEntry('Attempt to run image: $sanitizedImageName failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Failed: ${e.toString()}"),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isRunning = false);
    }
  }

  //==============================================log function=========================
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