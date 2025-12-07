import 'package:checkout_flutter_bridge/checkout_flutter_bridge.dart';

/// Session result model
class SessionResult {
  final CardTokenResult token;
  final String sessionData;

  SessionResult({
    required this.token,
    required this.sessionData,
  });
}
