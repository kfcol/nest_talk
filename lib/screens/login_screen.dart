import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'chat_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import '../services/peer_service.dart';
import '../providers/theme_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  bool _isLoading = false;
  bool _isDarkMode = false;
  String? _wifiName;
  bool _isConnectedToWifi = false;
  final PeerService _peerService = PeerService();
  int _activeUsers = 0;

  @override
  void initState() {
    super.initState();
    _checkWifiConnection();
    _setupWifiListener();
    _setupUserCountListener();
    ThemeProvider().addListener(_handleThemeChange);
  }

  void _handleThemeChange() {
    setState(() {
      // This will rebuild the widget when theme changes
    });
  }

  Future<void> _checkWifiConnection() async {
    if (kIsWeb) {
      try {
        final connectivity = await Connectivity().checkConnectivity();
        setState(() {
          _isConnectedToWifi = connectivity != ConnectivityResult.none;
          _wifiName = connectivity != ConnectivityResult.none
              ? _getConnectionType(connectivity)
              : null;
        });
      } catch (e) {
        setState(() {
          _isConnectedToWifi = false;
          _wifiName = null;
        });
      }
      return;
    }

    // Request location permission for Android
    if (!kIsWeb) {
      final status = await Permission.location.request();
      if (status.isDenied) {
        setState(() {
          _wifiName = null;
          _isConnectedToWifi = false;
        });
        return;
      }
    }

    final connectivity = await Connectivity().checkConnectivity();
    final isWifi = connectivity == ConnectivityResult.wifi;

    if (isWifi) {
      try {
        final info = NetworkInfo();
        final wifiName = await info.getWifiName();
        setState(() {
          _wifiName = wifiName?.replaceAll('"', '');
          _isConnectedToWifi = true;
        });
      } catch (e) {
        setState(() {
          _wifiName = null;
          _isConnectedToWifi = false;
        });
      }
    } else {
      setState(() {
        _wifiName = null;
        _isConnectedToWifi = false;
      });
    }
  }

  void _setupWifiListener() {
    if (kIsWeb) {
      Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
        setState(() {
          _isConnectedToWifi = result != ConnectivityResult.none;
          _wifiName = result != ConnectivityResult.none
              ? _getConnectionType(result)
              : null;
        });
      });
      return;
    }

    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result == ConnectivityResult.wifi) {
        _checkWifiConnection();
      } else {
        setState(() {
          _wifiName = null;
          _isConnectedToWifi = false;
        });
      }
    });
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();

    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a username')),
      );
      return;
    }

    if (!_isConnectedToWifi) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please connect to a network to continue'),
        ),
      );
      return;
    }

    final peerService = PeerService();
    if (peerService.isUsernameTaken(username)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Username is already taken. Please choose another one.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    final joined = await peerService.joinChat(username, _wifiName ?? 'unknown');
    if (!joined) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to join chat. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            username: username,
            networkId: _wifiName ?? 'unknown',
          ),
        ),
      );
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Nest Talk'),
        content: const Text(
          'Nest Talk is a simple chat app that lets you talk with others on '
          'the same WiFi network.\n\n'
          '• No account needed\n'
          '• Messages disappear after 24 hours\n'
          '• Only visible to people on your WiFi\n'
          '• Choose any username you like',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _toggleDarkMode() {
    setState(() {
      ThemeProvider().toggleTheme();
    });
  }

  void _setupUserCountListener() {
    _peerService.userCountStream.listen((count) {
      setState(() {
        _activeUsers = count;
      });
    });
    // Initialize with current count
    _activeUsers = _peerService.activeUserCount;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    ThemeProvider().removeListener(_handleThemeChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.blue),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Text(
              '?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            onPressed: _showHelpDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return RotationTransition(
                    turns:
                        Tween<double>(begin: 0.5, end: 1.0).animate(animation),
                    child: ScaleTransition(
                      scale: animation,
                      child: child,
                    ),
                  );
                },
                child: Icon(
                  ThemeProvider().isDarkMode
                      ? Icons.light_mode
                      : Icons.dark_mode,
                  key: ValueKey<bool>(ThemeProvider().isDarkMode),
                  color: ThemeProvider().isDarkMode
                      ? Colors.white
                      : Colors.grey[800],
                ),
              ),
              title: Text(
                ThemeProvider().isDarkMode
                    ? 'Switch to Light Mode'
                    : 'Switch to Dark Mode',
                style: TextStyle(
                  color: ThemeProvider().isDarkMode
                      ? Colors.white
                      : Colors.grey[800],
                ),
              ),
              trailing: Switch(
                value: ThemeProvider().isDarkMode,
                onChanged: (_) => _toggleDarkMode(),
                activeColor: Colors.blue,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nest Talk',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_activeUsers ${_activeUsers == 1 ? 'user' : 'users'} online',
                    style: TextStyle(
                      fontSize: 16,
                      color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 48),
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      hintText: 'Enter username',
                      filled: true,
                      fillColor: ThemeProvider().isDarkMode
                          ? const Color(0xFF1E1E1E)
                          : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(
                        Icons.person_outline,
                        color: ThemeProvider().isDarkMode
                            ? Colors.white
                            : Colors.grey[600],
                      ),
                      hintStyle: TextStyle(
                        color: ThemeProvider().isDarkMode
                            ? Colors.grey[400]
                            : Colors.grey[600],
                      ),
                    ),
                    style: TextStyle(
                      color: ThemeProvider().isDarkMode
                          ? Colors.white
                          : Colors.black,
                    ),
                    onSubmitted: (_) => _handleLogin(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Join Chat',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 20,
            child: Center(
              child: !_isConnectedToWifi
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Please connect to a network to use the app',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    )
                  : _wifiName != null
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Connected to: $_wifiName',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  String _getConnectionType(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.mobile:
        return 'Mobile Data';
      default:
        return 'Unknown Network';
    }
  }
}
