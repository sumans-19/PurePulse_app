// In lib/services/aqi_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AqiService {
  final String _token = dotenv.env['WAQI_TOKEN'] ?? '';

  get latestData => null;

  Future<Map<String, dynamic>> getAqiData(double lat, double lon) async {
    if (_token.isEmpty) {
      throw Exception('WAQI_TOKEN is not configured');
    }
    
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
