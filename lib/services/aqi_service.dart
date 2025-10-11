// In lib/services/aqi_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class AqiService {
  final String _token = '324250aa1f0fd6b2e17e150d8f521f44a688b70b'; // <-- Paste your new WAQI token

  Future<Map<String, dynamic>> getAqiData(double lat, double lon) async {
    final url = Uri.parse('https://api.waqi.info/feed/geo:$lat;$lon/?token=$_token');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200 && json.decode(response.body)['status'] == 'ok') {
        return json.decode(response.body)['data']; // Return the 'data' object
      } else {
        throw Exception('Failed to load AQI data');
      }
    } catch (e) {
      print('Error fetching AQI data: $e');
      throw Exception('Could not connect to the AQI service.');
    }
  }
}