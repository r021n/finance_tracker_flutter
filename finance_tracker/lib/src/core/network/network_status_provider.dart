import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'network_status_provider.g.dart';

enum NetworkStatus { none, wifi, mobile, ethernet, vpn, bluetooth, other }

@Riverpod(keepAlive: true)
class NetworkStatusNotifier extends _$NetworkStatusNotifier {
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  NetworkStatus build() {
    _startListening();
    return NetworkStatus.none;
  }

  void _startListening() {
    _subscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      if (results.isNotEmpty) {
        state = _mapConnectivityResult(results.first);
      }
    });
  }

  NetworkStatus _mapConnectivityResult(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return NetworkStatus.wifi;
      case ConnectivityResult.mobile:
        return NetworkStatus.mobile;
      case ConnectivityResult.ethernet:
        return NetworkStatus.ethernet;
      case ConnectivityResult.vpn:
        return NetworkStatus.vpn;
      case ConnectivityResult.bluetooth:
        return NetworkStatus.bluetooth;
      case ConnectivityResult.other:
        return NetworkStatus.other;
      case ConnectivityResult.none:
        return NetworkStatus.none;
      case ConnectivityResult.satellite:
        return NetworkStatus.other;
    }
  }

  Future<void> checkCurrentStatus() async {
    final results = await Connectivity().checkConnectivity();
    if (results.isNotEmpty) {
      state = _mapConnectivityResult(results.first);
    }
  }

  bool get isConnected => state != NetworkStatus.none;

  void cancelSubscription() {
    _subscription?.cancel();
  }
}
