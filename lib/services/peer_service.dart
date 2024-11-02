import 'dart:async';
import 'network_service.dart';

class User {
  final String username;
  final String networkId;
  final DateTime lastSeen;

  User({
    required this.username,
    required this.networkId,
    required this.lastSeen,
  });
}

class PeerService {
  static final PeerService _instance = PeerService._internal();
  factory PeerService() => _instance;
  PeerService._internal();

  final _activeUsers = <String, User>{};
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _userCountController = StreamController<int>.broadcast();
  final _networkService = NetworkService();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  List<User> get activeUsers => _activeUsers.values.toList();
  int get activeUserCount => _activeUsers.length;
  Stream<int> get userCountStream => _userCountController.stream;

  bool isUsernameTaken(String username) {
    return _activeUsers.values.any((user) =>
        user.username.toLowerCase() == username.toLowerCase() &&
        DateTime.now().difference(user.lastSeen).inMinutes < 1);
  }

  Future<bool> joinChat(String username, String networkId) async {
    if (isUsernameTaken(username)) {
      return false;
    }

    try {
      await _networkService.initialize(username, networkId);

      _networkService.messageStream.listen((message) {
        if (message['type'] == 'message') {
          _messageController.add(message);
        } else if (message['type'] == 'discovery' || message['type'] == 'ack') {
          _updateUserPresence(message['username'], message['networkId']);
        }
      });

      _activeUsers[username] = User(
        username: username,
        networkId: networkId,
        lastSeen: DateTime.now(),
      );

      _messageController.add({
        'type': 'user_joined',
        'username': username,
        'timestamp': DateTime.now().toIso8601String(),
      });

      _userCountController.add(_activeUsers.length);
      return true;
    } catch (e) {
      print('Failed to join chat: $e');
      return false;
    }
  }

  void _updateUserPresence(String username, String networkId) {
    _activeUsers[username] = User(
      username: username,
      networkId: networkId,
      lastSeen: DateTime.now(),
    );
    _userCountController.add(_activeUsers.length);
  }

  void sendMessage(String username, String message) {
    if (_activeUsers.containsKey(username)) {
      _activeUsers[username] = User(
        username: username,
        networkId: _activeUsers[username]!.networkId,
        lastSeen: DateTime.now(),
      );

      _networkService.sendMessage(message);
    }
  }

  void leaveChat(String username) {
    _activeUsers.remove(username);
    _messageController.add({
      'type': 'user_left',
      'username': username,
      'timestamp': DateTime.now().toIso8601String(),
    });
    _userCountController.add(_activeUsers.length);
    _networkService.dispose();
  }

  void dispose() {
    _messageController.close();
    _userCountController.close();
    _networkService.dispose();
  }
}
