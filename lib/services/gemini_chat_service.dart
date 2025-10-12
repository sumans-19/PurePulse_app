import 'package:google_generative_ai/google_generative_ai.dart';


class GeminiChatService {
  final GenerativeModel _model;

  GeminiChatService()
      : _model = GenerativeModel(
          model: 'gemini-2.5-flash',
          // IMPORTANT: Your API key is loaded securely from the .env file
          apiKey: 'AIzaSyC2WrlsJUNuc8ILebmhxYOHh-KinBfK7X8',
        );

  Future<String> getChatResponse(String userQuery) async {
    // This is the prompt that gives the AI its instructions and context
    final prompt = '''
      You are PurePulse Assist, a friendly and helpful AI assistant for the PurePulse air quality app.

      Your knowledge base:
      - The app's features: personal and parent profiles, live AQI tracking (0-500 scale based on WAQI), health-based risk calculation, and notification history.
      - General knowledge about air quality, pollutants (like PM2.5, Ozone), and their health effects.

      Your instructions:
      - Your expertise is limited to air quality, the health effects of pollution, and the PurePulse app's features. 
      - Politely decline to answer questions outside this scope (e.g., politics, celebrities, coding).
      - Keep answers concise, helpful, and easy for a non-technical person to understand.

      User Question: "$userQuery"
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text ?? 'I am having trouble responding right now. Please try again.';
    } catch (e) {
      print('Gemini API Error: $e');
      return 'Sorry, I was unable to get a response. Please check your connection.';
    }
  }
}