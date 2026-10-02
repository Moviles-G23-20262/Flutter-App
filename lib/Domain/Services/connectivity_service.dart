import 'dart:async';
import 'dart:io';

import 'package:flutter_front_end/Domain/repositories/connectivity_checker.dart';

class ConnectivityService implements ConnectivityChecker {
  @override
  Future<bool> get isOnline async {
    try {
      final result = await InternetAddress.lookup('example.com')
          .timeout(const Duration(seconds: 2));
      return result.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    }
  }
}