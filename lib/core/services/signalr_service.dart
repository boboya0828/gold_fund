import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart' as dio;
import '../network/api_endpoints.dart';

/// SignalR 连接状态
enum SignalRState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// SignalR WebSocket 服务 - 轻量实现，匹配 uni-app utils/signalr.js 的行为
class SignalRService {
  static final SignalRService _instance = SignalRService._internal();
  factory SignalRService() => _instance;
  SignalRService._internal();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  SignalRState _state = SignalRState.disconnected;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _reconnectCount = 0;
  int _messageId = 0;
  String _connectionId = '';

  static const _maxReconnect = 3;
  static const _pingInterval = Duration(seconds: 15);
  static const _reconnectDelays = [Duration(seconds: 1), Duration(seconds: 2), Duration(seconds: 4)];

  final Map<String, List<void Function(List<dynamic>)>> _handlers = {};

  // ===== 公共 API =====

  SignalRState get state => _state;
  String get connectionId => _connectionId;
  bool get isConnected => _state == SignalRState.connected;

  /// 初始化并连接 SignalR
  Future<void> connect() async {
    if (_state == SignalRState.connected || _state == SignalRState.connecting) {
      print('[SignalR] Already connected or connecting, skip');
      return;
    }
    await _startConnection();
  }

  /// 监听消息
  void on(String methodName, void Function(List<dynamic> args) callback) {
    _handlers.putIfAbsent(methodName, () => []);
    _handlers[methodName]!.add(callback);
  }

  /// 取消监听
  void off(String methodName, [void Function(List<dynamic>)? callback]) {
    if (callback == null) {
      _handlers.remove(methodName);
    } else {
      _handlers[methodName]?.remove(callback);
    }
  }

  /// 发送消息
  Future<void> invoke(String methodName, [List<dynamic>? args]) async {
    if (!isConnected) {
      throw Exception('SignalR not connected');
    }
    final message = {
      'type': 1, // Invocation
      'invocationId': '${_messageId++}',
      'target': methodName,
      'arguments': args ?? [],
    };
    _send(jsonEncode(message));
  }

  /// 断开连接
  Future<void> disconnect() async {
    _cancelTimers();
    _reconnectCount = 0;

    if (_channel != null) {
      try {
        final message = {'type': 7}; // Close
        _send(jsonEncode(message));
      } catch (_) {}
      await _subscription?.cancel();
      await _channel?.sink.close();
      _channel = null;
    }

    _state = SignalRState.disconnected;
    _connectionId = '';
    print('[SignalR] Disconnected');
  }

  // ===== 内部实现 =====

  Future<void> _startConnection() async {
    _state = SignalRState.connecting;
    _cancelTimers();

    try {
      // Step 1: Negotiate (使用 Dio 兼容 Web 和 Native)
      final token = await _getToken();
      final negotiateUrl = '${ApiEndpoints.signalrUrl}/negotiate?negotiateVersion=1';

      final dioClient = dio.Dio(dio.BaseOptions(
        headers: token.isNotEmpty ? {'Authorization': 'Bearer $token'} : {},
      ));
      final resp = await dioClient.get(negotiateUrl);
      final negotiate = resp.data as Map<String, dynamic>;

      final connectionToken = negotiate['connectionToken'] as String? ?? '';

      // Step 2: Connect via WebSocket
      final wsUrl = Uri.parse(
        '${ApiEndpoints.signalrUrl.replaceFirst('https://', 'wss://')}'
        '?id=$connectionToken',
      );

      _channel = WebSocketChannel.connect(wsUrl);
      await _channel!.ready;
      _state = SignalRState.connected;
      _reconnectCount = 0;

      // Step 3: Handshake
      final handshake = '{"protocol":"json","version":1}${''}';
      _channel!.sink.add(handshake);

      // Step 4: Listen
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: (error) {
          print('[SignalR] WebSocket error: $error');
          _handleDisconnect();
        },
        onDone: () {
          print('[SignalR] WebSocket closed');
          _handleDisconnect();
        },
      );

      // Start ping timer
      _pingTimer = Timer.periodic(_pingInterval, (_) => _sendPing());

      print('[SignalR] Connected successfully');
    } catch (e) {
      print('[SignalR] Connection failed: $e');
      _state = SignalRState.disconnected;
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    final data = raw as String;

    // SignalR messages are separated by \x1e (record separator)
    for (final message in data.split('')) {
      if (message.trim().isEmpty) continue;

      try {
        final json = jsonDecode(message) as Map<String, dynamic>;
        final type = json['type'] as int?;

        switch (type) {
          case 1: // Invocation
            _handleInvocation(json);
            break;
          case 6: // Ping
            // Ignore pings from server
            break;
          case 7: // Close
            print('[SignalR] Server closed connection');
            _handleDisconnect();
            break;
          default:
            // Handshake response or other
            if (json['connectionId'] != null) {
              _connectionId = json['connectionId'] as String;
            }
        }
      } catch (e) {
        // Ignore parse errors for non-JSON messages
      }
    }
  }

  void _handleInvocation(Map<String, dynamic> message) {
    final target = message['target'] as String?;
    final args = (message['arguments'] as List?)?.cast<dynamic>() ?? [];

    if (target != null && _handlers.containsKey(target)) {
      for (final handler in _handlers[target]!) {
        try {
          handler(args);
        } catch (e) {
          print('[SignalR] Handler error for $target: $e');
        }
      }
    }
  }

  void _sendPing() {
    if (isConnected) {
      final ping = '{"type":6}${''}';
      try {
        _channel?.sink.add(ping);
      } catch (_) {}
    }
  }

  void _send(String message) {
    _channel?.sink.add('$message');
  }

  void _handleDisconnect() {
    if (_state == SignalRState.disconnected) return;
    _state = SignalRState.disconnected;
    _subscription?.cancel();
    _channel = null;
    _connectionId = '';
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectCount >= _maxReconnect) {
      print('[SignalR] Max reconnect attempts reached');
      return;
    }

    final delay = _reconnectDelays[_reconnectCount];
    _reconnectCount++;
    _state = SignalRState.reconnecting;

    print('[SignalR] Reconnecting in ${delay.inMilliseconds}ms (attempt $_reconnectCount/$_maxReconnect)');

    _reconnectTimer = Timer(delay, () {
      if (_state == SignalRState.reconnecting) {
        _startConnection();
      }
    });
  }

  void _cancelTimers() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }
}
