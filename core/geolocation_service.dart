// To be used for location
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';
import 'constants.dart';

class GeolocationService {
  static Future<String> getCurrentAddress() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return 'Location services disabled';
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return 'Location permission denied forever';
      }

      Position position = await Geolocator.getCurrentPosition();
      final response = await ApiService.get('${AppConstants.geocodePath}/reverse', query: {
        'lat': position.latitude.toString(),
        'lng': position.longitude.toString(),
      });
      return response.data['address'] ?? '${position.latitude}, ${position.longitude}';
    } catch (e) {
      return 'Unable to get location';
    }
  }
}

