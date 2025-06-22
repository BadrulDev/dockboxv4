import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

import 'message.dart';

class AiChat extends StatefulWidget {
  const AiChat({super.key});

  @override
  State<AiChat> createState() => _AiChatState();
}

class _AiChatState extends State<AiChat> {
  final TextEditingController _userInput = TextEditingController();
  final List<Message> _messages = [];
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Chat'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Messages(
                  isUser: message.isUser,
                  message: message.message,
                  date: message.date,
                  isLoading: message.isLoading,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: 8.0,
              right: 8.0,
              bottom: 16,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 15,
                  child: TextFormField(
                    style: const TextStyle(color: Colors.black),
                    controller: _userInput,
                    textInputAction: TextInputAction.send,
                    onFieldSubmitted: (_) {
                      if (!isLoading) sendMessage();
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      label: const Text('Enter Your Message'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  padding: const EdgeInsets.all(12),
                  iconSize: 30,
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all(Colors.blueAccent),
                    foregroundColor: MaterialStateProperty.all(Colors.white),
                    shape: MaterialStateProperty.all(const CircleBorder()),
                  ),
                  onPressed: isLoading ? null : sendMessage,
                  icon: isLoading
                      ? Container(width: 24, height: 24, child: const CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],

      ),
    );
  }



  Future<void> sendMessage() async {
    await dotenv.load(fileName: ".env");
    final message = _userInput.text;
    _userInput.clear();

    // Add user's message to the chat
    setState(() {
      _messages.add(Message(isUser: true, message: message, date: DateTime.now()));
    });

    if (message.isEmpty) return;

    // Add loading indicator
    setState(() {
      isLoading = true;
      _messages.add(Message(isUser: false, message: "...", date: DateTime.now(), isLoading: true));
    });

    try {
      var openAIKey = dotenv.env['API_KEY']!;
      final url = Uri.parse('https://api.openai.com/v1/chat/completions');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $openAIKey',
        },
        body: jsonEncode({
          "model": "gpt-4o",
          "messages": [
            {"role": "user", "content": message}
          ]
        }),
      );

      setState(() {
        isLoading = false;
        _messages.removeWhere((msg) => msg.isLoading);
      });

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final reply = responseData['choices'][0]['message']['content'].trim();
        setState(() {
          _messages.add(Message(isUser: false, message: reply, date: DateTime.now()));
        });
      } else {
        setState(() {
          _messages.add(Message(
            isUser: false,
            message: "Failed to get a response from OpenAI.",
            date: DateTime.now(),
          ));
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        _messages.removeWhere((msg) => msg.isLoading);
        _messages.add(Message(
          isUser: false,
          message: "An error occurred: $e",
          date: DateTime.now(),
        ));
      });
    }
  }
}
