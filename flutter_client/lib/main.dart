import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:signalr_netcore/signalr_client.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:5000',
);

void main() {
  runApp(const OrderDemoApp());
}

class OrderDemoApp extends StatelessWidget {
  const OrderDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live Order Status',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B87)),
        useMaterial3: true,
      ),
      home: const OrderStatusPage(),
    );
  }
}

class OrderStatusPage extends StatefulWidget {
  const OrderStatusPage({super.key});

  @override
  State<OrderStatusPage> createState() => _OrderStatusPageState();
}

class _OrderStatusPageState extends State<OrderStatusPage> {
  static const _orderId = 'ORD-1042';
  static const _statuses = [
    'Order received',
    'Preparing',
    'Ready for pickup',
    'Picked up',
  ];

  final _updates = StreamController<OrderStatusUpdate>.broadcast();
  late final HubConnection _connection;
  String _status = 'Waiting for first update';
  String _connectionStatus = 'Connecting…';
  String? _errorMessage;
  bool _sending = false;
  int _nextStatusIndex = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_connect());
  }

  Future<void> _connect() async {
    _connection = HubConnectionBuilder()
        .withUrl('$apiBaseUrl/hubs/notifications')
        .withAutomaticReconnect()
        .build();

    _connection.on('ReceiveOrderUpdate', _handleOrderUpdate);
    _connection.onreconnecting(({error}) {
      if (!mounted) return;
      setState(() {
        _connectionStatus = 'Reconnecting…';
        if (error != null) {
          _errorMessage = 'Live connection interrupted: $error';
        }
      });
    });
    _connection.onreconnected(({connectionId}) {
      if (!mounted) return;
      setState(() {
        _connectionStatus = 'Connected';
        _errorMessage = null;
      });
    });
    _connection.onclose(({error}) {
      if (!mounted) return;
      setState(() {
        _connectionStatus = 'Disconnected';
        _errorMessage =
            error == null ? null : 'Live connection closed: $error';
      });
    });

    try {
      await _connection.start();
      if (!mounted) return;
      setState(() {
        _connectionStatus = 'Connected';
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _connectionStatus = 'Connection failed';
        _errorMessage = 'Could not connect to the live updates service: $error';
      });
    }
  }

  void _handleOrderUpdate(List<Object?>? arguments) {
    if (arguments == null || arguments.isEmpty) {
      _updates.addError(const FormatException('The update payload was empty.'));
      return;
    }

    final payload = arguments.first;
    if (payload is! Map<Object?, Object?>) {
      _updates.addError(const FormatException('The update payload was invalid.'));
      return;
    }

    final orderId = payload['orderId'];
    final status = payload['status'];
    if (orderId is! String || status is! String) {
      _updates.addError(
        const FormatException('The update must include orderId and status.'),
      );
      return;
    }

    final update = OrderStatusUpdate(orderId: orderId, status: status);
    _updates.add(update);

    if (!mounted || update.orderId != _orderId) return;
    setState(() {
      _status = update.status;
      _errorMessage = null;
    });
  }

  Future<void> _sendNextUpdate() async {
    setState(() {
      _sending = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/orders/$_orderId/status'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'status': _statuses[_nextStatusIndex]}),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        var message = 'Request failed (${response.statusCode}).';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['message'] is String) {
            message = body['message'] as String;
          }
        } on FormatException {
          // Keep the status-code message when the response is not JSON.
        }
        throw Exception(message);
      }

      if (mounted) {
        setState(() {
          _nextStatusIndex = (_nextStatusIndex + 1) % _statuses.length;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not update the order. $error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    unawaited(_updates.close());
    unawaited(_connection.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Order Status'),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ORDER', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 4),
                      Text(_orderId, style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 24),
                      Text('CURRENT STATUS', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 8),
                      StreamBuilder<OrderStatusUpdate>(
                        stream: _updates.stream,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Text(
                              'Invalid live update: ${snapshot.error}',
                              style: TextStyle(color: theme.colorScheme.error),
                            );
                          }
                          final update = snapshot.data;
                          final liveStatus =
                              update != null && update.orderId == _orderId
                              ? update.status
                              : _status;
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Text(
                              liveStatus,
                              key: ValueKey(liveStatus),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Icon(
                            _connectionStatus == 'Connected'
                                ? Icons.wifi
                                : Icons.wifi_off,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text('Live updates: $_connectionStatus'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _sending ? null : _sendNextUpdate,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.campaign_outlined),
                label: Text(_sending ? 'Sending update…' : 'Send next status'),
              ),
              const SizedBox(height: 8),
              Text(
                'This button calls the REST API. SignalR pushes the resulting '
                'status to connected clients.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Material(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class OrderStatusUpdate {
  const OrderStatusUpdate({required this.orderId, required this.status});

  final String orderId;
  final String status;
}
