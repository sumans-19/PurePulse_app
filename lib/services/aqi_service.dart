import 'dart:convert';
import 'package:http/http.dart' as http;

class AqiService {
  final String _apiKey = 'fe50874374ed6c4abfacb98b377d55b1'; // <-- IMPORTANT: PASTE YOUR KEY HERE
  final String _baseUrl = 'https://api.openweathermap.org/data/2.5/air_pollution';

  Future<Map<String, dynamic>> getAqiData(double lat, double lon) async {
    final url = Uri.parse('$_baseUrl?lat=$lat&lon=$lon&appid=$_apiKey');
    
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        // The API returns a list, we are interested in the first item.
        return json.decode(response.body)['list'][0];
      } else {
        throw Exception('Failed to load AQI data');
      }
    } catch (e) {
      print('Error fetching AQI data: $e');
      throw Exception('Could not connect to the AQI service.');
    }
  }
}