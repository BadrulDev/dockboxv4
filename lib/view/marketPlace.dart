import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  //image show in ghcr
  String? _selectedImageName;
  String? _selectedTag;
  List<String> _availableTags = [];
  bool _isRunning = false;
  bool _isLoading = false;
  bool _imageExists = true;

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
                      for (final img in _recentImages.take(10))
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
                                    'https://github.githubassets.com/images/modules/logos_page/GitHub-Mark.png',
                                    width: 48,
                                    height: 48,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
                                  ),
                                  const SizedBox(height: 16),
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
    });

    await addRecentEntry(name);
    setState(() {
      _isLoading = false;
    });
  }
}