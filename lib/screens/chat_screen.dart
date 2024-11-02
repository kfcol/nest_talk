import 'package:flutter/material.dart';
import '../services/peer_service.dart';
import './login_screen.dart';
import '../utils/encryption_util.dart';

class ChatScreen extends StatefulWidget {
  final String username;
  final String networkId;

  const ChatScreen({
    super.key,
    required this.username,
    required this.networkId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final PeerService _peerService = PeerService();
  final List<Map<String, dynamic>> _messages = [];
  String _networkName = '';
  int _networkUserCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    _peerService.messageStream.listen((message) {
      setState(() {
        if (message['type'] == 'message') {
          _messages.add(message);
        } else if (message['type'] == 'user_joined' ||
            message['type'] == 'user_left') {
          // Add system message
          _messages.add({
            'type': 'system',
            'message': message['type'] == 'user_joined'
                ? '${message['username']} joined the chat'
                : '${message['username']} left the chat',
            'timestamp': message['timestamp'],
          });
        }
      });
    });
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    _peerService.sendMessage(widget.username, _messageController.text.trim());
    _messageController.clear();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _peerService.leaveChat(widget.username);
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Leave Chat?'),
            content:
                const Text('Are you sure you want to leave the chat room?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  _peerService.leaveChat(widget.username);
                  Navigator.of(context).pop(true);
                },
                child: const Text('Leave'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Chat Room'),
              Text(
                'Network: ${widget.networkId}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.blue,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await _onWillPop()) {
                if (context.mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                }
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.people),
              onPressed: () => _showActiveUsers(),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                reverse: true,
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[_messages.length - 1 - index];

                  if (message['type'] == 'system') {
                    return _buildSystemMessage(message);
                  }

                  return _buildChatMessage(message);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) {
                        _sendMessage();
                      },
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatMessage(Map<String, dynamic> message) {
    final isCurrentUser = message['username'] == widget.username;
    final decryptedMessage = EncryptionUtil.decrypt(message['message']);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Align(
        alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            color: isCurrentUser ? Colors.blue : Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isCurrentUser)
                Text(
                  message['username'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              Text(
                decryptedMessage,
                style: TextStyle(
                  color: isCurrentUser ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemMessage(Map<String, dynamic> message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Center(
        child: Text(
          message['message'],
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  void _showActiveUsers() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Active Users'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _peerService.activeUsers.length,
            itemBuilder: (context, index) {
              final user = _peerService.activeUsers[index];
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(user.username),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
