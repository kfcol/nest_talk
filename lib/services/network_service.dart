import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'webrtc_service.dart';
import '../utils/encryption_util.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  static const int DISCOVERY_PORT = 8888;
  static const int MESSAGE_PORT = 8889;

  RawDatagramSocket? _discoverySocket;
  ServerSocket? _messageServer;
  List<Socket> _peerConnections = [];
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  String? _username;
  String? _networkId;

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  Future<void> initialize(String username, String networkId) async {
    _username = username;
    _networkId = networkId;

    if (kIsWeb) {
      final webrtcService = WebRTCService();
      await webrtcService.initialize(username);
      webrtcService.messageStream.listen((message) {
        _messageController.add(message);
      });
      return;
    }

    try {
      // Start discovery service
      await _startDiscoveryService();
      // Start message server
      await _startMessageServer();
      // Broadcast presence
      _broadcastPresence();
    } catch (e) {
      print('Error initializing network service: $e');
      rethrow;
    }
  }

  Future<void> _startDiscoveryService() async {
    _discoverySocket =
        await RawDatagramSocket.bind(InternetAddress.anyIPv4, DISCOVERY_PORT);

    _discoverySocket!.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        final datagram = _discoverySocket!.receive();
        if (datagram != null) {
          _handleDiscoveryMessage(datagram);
        }
      }
    });
  }

  Future<void> _startMessageServer() async {
    _messageServer =
        await ServerSocket.bind(InternetAddress.anyIPv4, MESSAGE_PORT);

    _messageServer!.listen((Socket client) {
      _peerConnections.add(client);

      client.listen(
        (List<int> data) {
          final message = utf8.decode(data);
          final messageData = json.decode(message);
          _messageController.add(messageData);
        },
        onDone: () {
          _peerConnections.remove(client);
          client.destroy();
        },
        onError: (error) {
          _peerConnections.remove(client);
          client.destroy();
        },
      );
    });
  }

  void _broadcastPresence() async {
    final message = json.encode({
      'type': 'discovery',
      'username': _username,
      'networkId': _networkId,
      'timestamp': DateTime.now().toIso8601String(),
    });

    final broadcastAddr = InternetAddress('255.255.255.255');
    _discoverySocket?.send(
      utf8.encode(message),
      broadcastAddr,
      DISCOVERY_PORT,
    );
  }

  void _handleDiscoveryMessage(Datagram datagram) async {
    final message = utf8.decode(datagram.data);
    final data = json.decode(message);

    if (data['type'] == 'discovery' &&
        data['networkId'] == _networkId &&
        data['username'] != _username) {
      // Connect to the peer
      try {
        final socket = await Socket.connect(datagram.address, MESSAGE_PORT);
        _peerConnections.add(socket);

        // Send acknowledgment
        final ack = json.encode({
          'type': 'ack',
          'username': _username,
          'networkId': _networkId,
          'timestamp': DateTime.now().toIso8601String(),
        });
        socket.write(ack);
      } catch (e) {
        print('Failed to connect to peer: $e');
      }
    }
  }

  void sendMessage(String message) {
    if (_username == null || _networkId == null) return;

    final encryptedMessage = EncryptionUtil.encrypt(message);

    if (kIsWeb) {
      WebRTCService().sendMessage(encryptedMessage);
      return;
    }

    final messageData = json.encode({
      'type': 'message',
      'username': _username,
      'message': encryptedMessage,
      'timestamp': DateTime.now().toIso8601String(),
    });

    for (final peer in _peerConnections) {
      try {
        peer.write(messageData);
      } catch (e) {
        print('Failed to send message to peer: $e');
      }
    }
  }

  void dispose() {
    if (!kIsWeb) {
      for (final peer in _peerConnections) {
        peer.destroy();
      }
      _discoverySocket?.close();
      _messageServer?.close();
    }
    _messageController.close();
  }
}
