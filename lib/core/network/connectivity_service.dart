import 'package:connectivity_plus/connectivity_plus.dart';

abstract class ConnectivityService {
  /// Emits on every change, without repeating the same value.
  Stream<bool> get isOnline;

  Future<bool> check();
}

/// Online when any reported result is not [ConnectivityResult.none].
class ConnectivityServiceImpl implements ConnectivityService {
  ConnectivityServiceImpl(this._connectivity);

  final Connectivity _connectivity;

  @override
  Stream<bool> get isOnline =>
      _connectivity.onConnectivityChanged.map(_hasConnection).distinct();

  @override
  Future<bool> check() async =>
      _hasConnection(await _connectivity.checkConnectivity());

  static bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}
