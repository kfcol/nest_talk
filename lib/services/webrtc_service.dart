import 'dart:async';
import 'dart:convert';
import 'package:webrtc_interface/webrtc_interface.dart';
import 'package:dart_webrtc/dart_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebRTCService {
  static final WebRTCService _instance = WebRTCService._internal();
  factory WebRTCService() => _instance;
  WebRTCService._internal();

  RTCPeerConnection? _peerConnection;
  WebSocketChannel? _signaling;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final Map<String, RTCPeerConnection> _peers = {};
  String? _localId;
  MediaStream? _localStream;
  final Map<String, RTCDataChannel> _dataChannels = {};

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  Future<void> initialize(String username) async {
    _localId = username;
    await _connectSignaling();
    await _createPeerConnection();
  }

  Future<void> _connectSignaling() async {
    _messageController.add({
      'type': 'connected',
      'username': _localId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    final config = <String, dynamic>{
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    };

    final pc = await createPeerConnection(config);

    pc.onIceCandidate = (candidate) {
      if (candidate == null) return;
      // Handle ICE candidate
    };

    pc.onDataChannel = (channel) {
      channel.onMessage = (data) {
        if (data.isBinary) return;
        try {
          final message = json.decode(data.text);
          _messageController.add(message);
        } catch (e) {
          print('Error parsing message: $e');
        }
      };
    };

    return pc;
  }

  void sendMessage(String message) {
    final messageData = json.encode({
      'type': 'message',
      'username': _localId,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    });

    _messageController.add(json.decode(messageData));
  }

  void dispose() {
    for (final peer in _peers.values) {
      peer.close();
    }
    _peers.clear();
    _signaling?.sink.close();
    _messageController.close();
    _localStream?.dispose();
  }
}
