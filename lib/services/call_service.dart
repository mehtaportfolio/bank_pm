import 'package:url_launcher/url_launcher.dart';
import 'dart:developer' as developer;

class CallService {
  /// Opens the Android dialer with the specified [phoneNumber].
  /// Uses the 'tel:' scheme to ensure the dialer is opened.
  Future<bool> openDialer(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );

    try {
      if (await canLaunchUrl(launchUri)) {
        return await launchUrl(launchUri);
      } else {
        developer.log('Could not launch dialer for $phoneNumber', name: 'CallService');
        return false;
      }
    } catch (e) {
      developer.log('Error launching dialer: $e', name: 'CallService', error: e);
      return false;
    }
  }
}
