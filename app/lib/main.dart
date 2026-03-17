import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const AGVApp());
}

class AGVApp extends StatelessWidget {
  const AGVApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AGV Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C63FF),
          secondary: Color(0xFF03DAC6),
        ),
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
      ),
      home: const ConnectScreen(),
    );
  }
}

// ==================== CONNECT SCREEN ====================
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});
  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _ipController = TextEditingController(text: '10.59.69.57');
  bool _connecting = false;
  String _error = '';

  void _connect() async {
    setState(() { _connecting = true; _error = ''; });
    final ip = _ipController.text.trim();
    try {
      final channel = WebSocketChannel.connect(
        Uri.parse('ws://$ip:8765'),
      );
      await channel.ready;
      if (!mounted) return;
      Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => AGVControlScreen(
          channel: channel, piIp: ip)));
    } catch (e) {
      setState(() {
        _error = 'Cannot connect to $ip:8765\nMake sure Pi server is running.';
        _connecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.smart_toy, size: 80, color: Color(0xFF6C63FF)),
              const SizedBox(height: 16),
              const Text('AGV Controller',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Connect to your Raspberry Pi AGV',
                style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              TextField(
                controller: _ipController,
                decoration: InputDecoration(
                  labelText: 'Pi IP Address',
                  prefixIcon: const Icon(Icons.wifi),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _connecting ? null : _connect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
                  child: _connecting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Connect', style: TextStyle(fontSize: 18)),
                ),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(_error,
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== MAIN CONTROL SCREEN ====================
class AGVControlScreen extends StatefulWidget {
  final WebSocketChannel channel;
  final String piIp;
  const AGVControlScreen({super.key, required this.channel, required this.piIp});
  @override
  State<AGVControlScreen> createState() => _AGVControlScreenState();
}

class _AGVControlScreenState extends State<AGVControlScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _mode = 'manual';
  String _status = 'Connected';
  List<dynamic> _lidarPoints = [];
  List<int> _irSensors = List.filled(8, 0);
  double _obstacleDistance = 9999;
  bool _connected = true;
  Timer? _pingTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _listenToServer();
    _pingTimer = Timer.periodic(const Duration(seconds: 2), (_) => _ping());
  }

  void _listenToServer() {
    widget.channel.stream.listen(
      (message) {
        final data = jsonDecode(message);
        setState(() {
          if (data['type'] == 'sensor_data') {
            _lidarPoints = data['lidar'] ?? [];
            _irSensors = List<int>.from(data['ir'] ?? List.filled(8, 0));
            _obstacleDistance = (data['obstacle_mm'] ?? 9999).toDouble();
            _mode = data['mode'] ?? _mode;
          } else if (data['type'] == 'mode_changed') {
            _mode = data['mode'];
          } else if (data['type'] == 'warning') {
            _status = data['message'];
          } else if (data['type'] == 'connected') {
            _status = 'AGV Ready';
          }
        });
      },
      onDone: () => setState(() {
        _connected = false; _status = 'Disconnected';
      }),
      onError: (_) => setState(() {
        _connected = false; _status = 'Connection error';
      }),
    );
  }

  void _sendCommand(Map<String, dynamic> cmd) {
    if (_connected) {
      widget.channel.sink.add(jsonEncode(cmd));
    }
  }

  void _ping() {
    _sendCommand({'action': 'ping'});
  }

  void _setMode(String mode) {
    setState(() => _mode = mode);
    _sendCommand({'action': 'set_mode', 'mode': mode});
  }

  void _sendMove(double left, double right) {
    _sendCommand({
      'action': 'move',
      'left': left.toInt(),
      'right': right.toInt(),
    });
  }

  void _stop() {
    _sendCommand({'action': 'stop'});
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _tabController.dispose();
    widget.channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Row(children: [
          Icon(
            _connected ? Icons.circle : Icons.circle_outlined,
            color: _connected ? Colors.greenAccent : Colors.redAccent,
            size: 12),
          const SizedBox(width: 8),
          Text(_status, style: const TextStyle(fontSize: 14)),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _ObstacleIndicator(distanceMm: _obstacleDistance),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6C63FF),
          tabs: const [
            Tab(icon: Icon(Icons.gamepad), text: 'Control'),
            Tab(icon: Icon(Icons.radar), text: 'LiDAR'),
            Tab(icon: Icon(Icons.linear_scale), text: 'IR'),
          ],
        ),
      ),
      body: Column(children: [
        // Mode selector
        _ModeBar(currentMode: _mode, onModeChanged: _setMode),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // === TAB 1: JOYSTICK CONTROL ===
              _JoystickTab(
                onMove: _sendMove,
                onStop: _stop,
                mode: _mode,
              ),
              // === TAB 2: LIDAR MAP ===
              _LidarTab(points: _lidarPoints, obstacleDistance: _obstacleDistance),
              // === TAB 3: IR SENSORS ===
              _IRTab(sensors: _irSensors),
            ],
          ),
        ),
      ]),
    );
  }
}

// ==================== MODE BAR ====================
class _ModeBar extends StatelessWidget {
  final String currentMode;
  final Function(String) onModeChanged;
  const _ModeBar({required this.currentMode, required this.onModeChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        const Text('Mode:', style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(width: 8),
        _modeChip('manual', 'Manual', Icons.gamepad),
        const SizedBox(width: 6),
        _modeChip('line_follow', 'Line', Icons.linear_scale),
        const SizedBox(width: 6),
        _modeChip('obstacle_avoid', 'Auto', Icons.radar),
      ]),
    );
  }

  Widget _modeChip(String mode, String label, IconData icon) {
    final active = currentMode == mode;
    return GestureDetector(
      onTap: () => onModeChanged(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF6C63FF) : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? const Color(0xFF6C63FF) : Colors.transparent),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: active ? Colors.white : Colors.grey),
          const SizedBox(width: 4),
          Text(label,
            style: TextStyle(
              fontSize: 12,
              color: active ? Colors.white : Colors.grey,
              fontWeight: active ? FontWeight.bold : FontWeight.normal)),
        ]),
      ),
    );
  }
}

// ==================== OBSTACLE INDICATOR ====================
class _ObstacleIndicator extends StatelessWidget {
  final double distanceMm;
  const _ObstacleIndicator({required this.distanceMm});

  @override
  Widget build(BuildContext context) {
    final dist = distanceMm / 10; // convert to cm
    Color color;
    if (dist > 60) color = Colors.greenAccent;
    else if (dist > 40) color = Colors.orangeAccent;
    else color = Colors.redAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.sensors, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          dist > 999 ? 'Clear' : '${dist.toStringAsFixed(0)}cm',
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

// ==================== JOYSTICK TAB ====================
class _JoystickTab extends StatefulWidget {
  final Function(double, double) onMove;
  final VoidCallback onStop;
  final String mode;
  const _JoystickTab({required this.onMove, required this.onStop, required this.mode});
  @override
  State<_JoystickTab> createState() => _JoystickTabState();
}

class _JoystickTabState extends State<_JoystickTab> {
  Offset _joystickPos = Offset.zero;
  bool _touching = false;
  Timer? _moveTimer;

  void _onJoystickMove(Offset offset) {
    setState(() { _joystickPos = offset; _touching = true; });
    // Convert joystick to motor speeds
    final forward = -offset.dy; // -1 to 1
    final turn = offset.dx;     // -1 to 1
    final left = ((forward + turn) * 80).clamp(-100.0, 100.0);
    final right = ((forward - turn) * 80).clamp(-100.0, 100.0);
    widget.onMove(left, right);
  }

  void _onJoystickRelease() {
    setState(() { _joystickPos = Offset.zero; _touching = false; });
    widget.onStop();
  }

  @override
  Widget build(BuildContext context) {
    final isManual = widget.mode == 'manual';
    return Stack(children: [
      if (!isManual)
        Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withOpacity(0.5)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.info_outline, color: Colors.orange, size: 36),
              const SizedBox(height: 12),
              Text('Currently in ${widget.mode.replaceAll('_', ' ')} mode',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Switch to Manual mode to use joystick',
                style: TextStyle(color: Colors.grey)),
            ]),
          ),
        ),
      if (isManual)
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // D-pad style buttons
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _CtrlBtn(Icons.arrow_upward, () => widget.onMove(75, 75), widget.onStop),
              ]),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _CtrlBtn(Icons.arrow_back, () => widget.onMove(-60, 60), widget.onStop),
                const SizedBox(width: 8),
                _CtrlBtn(Icons.stop_circle_outlined, () => widget.onStop(), null,
                  color: Colors.redAccent),
                const SizedBox(width: 8),
                _CtrlBtn(Icons.arrow_forward, () => widget.onMove(60, -60), widget.onStop),
              ]),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _CtrlBtn(Icons.arrow_downward, () => widget.onMove(-75, -75), widget.onStop),
              ]),
              const SizedBox(height: 40),
              // Joystick area
              const Text('— or use joystick —',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 20),
              _JoystickWidget(
                onMove: _onJoystickMove,
                onRelease: _onJoystickRelease,
                position: _joystickPos,
              ),
            ],
          ),
        ),
    ]);
  }
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPress;
  final VoidCallback? onRelease;
  final Color? color;
  const _CtrlBtn(this.icon, this.onPress, this.onRelease, {this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onPress(),
      onTapUp: (_) => onRelease?.call(),
      onTapCancel: () => onRelease?.call(),
      child: Container(
        width: 72, height: 72,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: (color ?? const Color(0xFF6C63FF)).withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: (color ?? const Color(0xFF6C63FF)).withOpacity(0.5)),
        ),
        child: Icon(icon, color: color ?? const Color(0xFF6C63FF), size: 32),
      ),
    );
  }
}

class _JoystickWidget extends StatelessWidget {
  final Function(Offset) onMove;
  final VoidCallback onRelease;
  final Offset position;
  const _JoystickWidget({required this.onMove, required this.onRelease, required this.position});

  @override
  Widget build(BuildContext context) {
    const radius = 70.0;
    return GestureDetector(
      onPanUpdate: (d) {
        final local = d.localPosition - const Offset(radius, radius);
        final dist = local.distance;
        final clamped = dist > radius
          ? local / dist * radius
          : local;
        onMove(clamped / radius);
      },
      onPanEnd: (_) => onRelease(),
      onPanCancel: () => onRelease(),
      child: Container(
        width: radius * 2, height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1A1A1A),
          border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.4), width: 2),
        ),
        child: Stack(alignment: Alignment.center, children: [
          // Crosshair
          Container(width: 1, height: radius * 2, color: Colors.white10),
          Container(width: radius * 2, height: 1, color: Colors.white10),
          // Thumb
          Transform.translate(
            offset: position * (radius - 20),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6C63FF),
                boxShadow: [BoxShadow(
                  color: const Color(0xFF6C63FF).withOpacity(0.5),
                  blurRadius: 12)],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ==================== LIDAR TAB ====================
class _LidarTab extends StatelessWidget {
  final List<dynamic> points;
  final double obstacleDistance;
  const _LidarTab({required this.points, required this.obstacleDistance});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: points.isEmpty
            ? const Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF6C63FF)),
                  SizedBox(height: 16),
                  Text('Waiting for LiDAR data...',
                    style: TextStyle(color: Colors.grey)),
                ]))
            : CustomPaint(
                painter: _LidarPainter(points: points),
                child: Container(),
              ),
        ),
      ),
      Container(
        color: const Color(0xFF1A1A1A),
        padding: const EdgeInsets.all(12),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _InfoTile('Points', '${points.length}', Icons.scatter_plot),
          _InfoTile('Obstacle',
            obstacleDistance > 9000 ? 'Clear'
              : '${(obstacleDistance/10).toStringAsFixed(0)}cm',
            Icons.warning_amber,
            color: obstacleDistance < 400 ? Colors.redAccent : Colors.greenAccent),
          _InfoTile('Range', '8m max', Icons.straighten),
        ]),
      ),
    ]);
  }
}

class _InfoTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color? color;
  const _InfoTile(this.label, this.value, this.icon, {this.color});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color ?? Colors.grey, size: 18),
      const SizedBox(height: 4),
      Text(value,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color ?? Colors.white,
          fontSize: 14)),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
    ]);
  }
}

class _LidarPainter extends CustomPainter {
  final List<dynamic> points;
  const _LidarPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxDist = 4000.0; // 4 meters display range
    final scale = min(cx, cy) / maxDist;

    // Background grid circles
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    for (double r = 1000; r <= maxDist; r += 1000) {
      canvas.drawCircle(Offset(cx, cy), r * scale, gridPaint);
    }

    // Grid lines
    for (int a = 0; a < 360; a += 45) {
      final rad = a * pi / 180;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + cos(rad) * min(cx, cy), cy + sin(rad) * min(cx, cy)),
        gridPaint,
      );
    }

    // Robot marker
    final robotPaint = Paint()..color = const Color(0xFF6C63FF);
    canvas.drawCircle(Offset(cx, cy), 6, robotPaint);

    // Forward indicator
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx, cy - 20),
      Paint()..color = const Color(0xFF6C63FF)..strokeWidth = 2,
    );

    // LiDAR points
    final pointPaint = Paint()..strokeWidth = 2.5..strokeCap = StrokeCap.round;
    for (final pt in points) {
      final angle = (pt[0] as num).toDouble();
      final dist = (pt[1] as num).toDouble();
      if (dist <= 0 || dist > maxDist) continue;

      final rad = angle * pi / 180;
      final px = cx + sin(rad) * dist * scale;
      final py = cy - cos(rad) * dist * scale;

      // Color by distance: close=red, far=green
      final t = (dist / maxDist).clamp(0.0, 1.0);
      pointPaint.color = Color.lerp(
        Colors.redAccent, Colors.greenAccent, t)!.withOpacity(0.8);
      canvas.drawPoints(
        PointMode.points, [Offset(px, py)], pointPaint);
    }

    // Distance labels
    final textStyle = TextStyle(
      color: Colors.white.withOpacity(0.3), fontSize: 9);
    for (double r = 1000; r <= maxDist; r += 1000) {
      final tp = TextPainter(
        text: TextSpan(text: '${(r/10).toInt()}cm', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx + r * scale + 2, cy));
    }
  }

  @override
  bool shouldRepaint(_LidarPainter old) => old.points != points;
}

// ==================== IR SENSORS TAB ====================
class _IRTab extends StatelessWidget {
  final List<int> sensors;
  const _IRTab({required this.sensors});

  @override
  Widget build(BuildContext context) {
    final onLine = sensors.where((s) => s == 1).length;
    return Column(children: [
      const SizedBox(height: 30),
      const Text('IR Line Sensors',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('$onLine of 8 sensors detecting line',
        style: const TextStyle(color: Colors.grey)),
      const SizedBox(height: 40),
      // Sensor visual
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(sensors.length, (i) {
          final active = sensors[i] == 1;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(children: [
              Text('D${i+1}',
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: 32, height: 48,
                decoration: BoxDecoration(
                  color: active
                    ? const Color(0xFF6C63FF)
                    : const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: active
                      ? const Color(0xFF6C63FF)
                      : Colors.grey.withOpacity(0.3),
                    width: 2),
                  boxShadow: active ? [BoxShadow(
                    color: const Color(0xFF6C63FF).withOpacity(0.5),
                    blurRadius: 8)] : null,
                ),
              ),
              const SizedBox(height: 6),
              Text(active ? 'LINE' : '   ',
                style: const TextStyle(
                  color: Color(0xFF6C63FF), fontSize: 9,
                  fontWeight: FontWeight.bold)),
            ]),
          );
        }),
      ),
      const SizedBox(height: 40),
      // Line position indicator
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          const Text('Line Position',
            style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          Stack(children: [
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            // Position indicator
            Builder(builder: (ctx) {
              final total = sensors.length;
              final active = sensors.where((s) => s == 1).toList();
              if (active.isEmpty) return const SizedBox.shrink();
              double pos = 0.5;
              int count = 0;
              for (int i = 0; i < total; i++) {
                if (sensors[i] == 1) { pos += i / (total - 1); count++; }
              }
              if (count > 0) pos /= count;
              return Align(
                alignment: Alignment(pos * 2 - 1, 0),
                child: Container(
                  width: 20, height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              );
            }),
          ]),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Left', style: TextStyle(color: Colors.grey, fontSize: 11)),
              Text('Center', style: TextStyle(color: Colors.grey, fontSize: 11)),
              Text('Right', style: TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
        ]),
      ),
    ]);
  }
}
