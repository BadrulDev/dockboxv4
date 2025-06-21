import 'dart:convert';
import 'package:http/http.dart' as http;

class AISearch{
  Future<List<String>> fetchSuggestions(String query, String key) async {
    final url = Uri.https("api.openai.com", "/v1/chat/completions");
    final headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $key",
    };

    final body = jsonEncode({
      "model": "gpt-4o",
      "messages": [
        {
          "role": "system",
          "content":
          //"You are an autocomplete suggestion engine for GHCR (GitHub Container Registry) repository names. Respond with a JSON array of 4 suggestions that start with: '$query'."
          "You are a GHCR Docker image autocomplete engine for GHCR (GitHub Container Registry) repository names. Respond ONLY with a raw JSON array of exactly 4 strings that start with '$query'. Do not include explanations, markdown, or more than 4 items"

        }
      ],
      "max_tokens": 100,
      "temperature": 0.2
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final String content = data['choices'][0]['message']['content'];
      //print("Raw GPT response: $content");
      final cleanContent = sanitizeJsonArray(content);
      final List<dynamic> jsonList = jsonDecode(cleanContent);
      return jsonList.map((e) => e.toString()).toList();
    } else {
      throw Exception('Failed to fetch suggestions: ${response.body}');
    }
  }
  String sanitizeJsonArray(String raw) {
    final clean = raw
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    // If ends with a comma (or half-finished), try to close array
    if (!clean.endsWith(']')) {
      final lastBracket = clean.lastIndexOf(']');
      if (lastBracket != -1) return clean.substring(0, lastBracket + 1);
      // Try to force close it
      return clean + '"]';
    }

    return clean;
  }

}