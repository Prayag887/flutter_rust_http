import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/benchmark_provider.dart';
import '../widgets/network_pattern_painter.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Animation<double> pulseAnimation;
  final TabController tabController;

  const CustomAppBar({
    super.key,
    required this.pulseAnimation,
    required this.tabController,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      floating: false,
      snap: false,
      backgroundColor: Colors.black,
      elevation: 2,
      title: Row(
        children: [
          Expanded(
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
              ).createShader(bounds),
              child: const Text(
                'HTTP Benchmark Suite',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          _buildStatusIndicators(),
        ],
      ),
      bottom: TabBar(
        controller: tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[400],
        indicatorColor: AppTheme.primaryColor,
        tabs: const [
          Tab(icon: Icon(Icons.rocket_launch), text: 'Rust→Rust'),
          Tab(icon: Icon(Icons.speed), text: 'Rust→Dart'),
          Tab(icon: Icon(Icons.network_check), text: 'Dio HTTP/2'),
          Tab(icon: Icon(Icons.analytics), text: 'Analysis'),
        ],
      ),
    );
  }

  Widget _buildStatusIndicators() {
    return Consumer<BenchmarkProvider>(
      builder: (context, provider, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statusChip(provider.isRunning ? 'RUNNING' : 'READY',
                provider.isRunning ? Colors.green : Colors.grey),
            if (provider.activeClient != null) ...[
              const SizedBox(width: 8),
              _statusChip(_getShortClientName(provider.activeClient!.name), Colors.blue),
            ],
            const SizedBox(width: 8),
            _perfIndicator(Icons.speed, 'RPS', _getCurrentThroughput(provider),
                AppTheme.primaryColor),
            const SizedBox(width: 8),
            _perfIndicator(Icons.timer, 'LAT', _getCurrentLatency(provider),
                AppTheme.secondaryColor),
          ],
        );
      },
    );
  }

  Widget _statusChip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.9),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
    ),
  );

  Widget _perfIndicator(IconData icon, String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.2),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.5)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey[300], fontSize: 8)),
      ],
    ),
  );

  String _getShortClientName(String name) {
    return name.length > 8 ? '${name.substring(0, 8)}…' : name;
  }

  String _getCurrentThroughput(BenchmarkProvider provider) {
    final liveData = provider.liveData[provider.activeClient];
    return liveData?.currentMetrics.throughput?.toStringAsFixed(0) ?? '0';
  }

  String _getCurrentLatency(BenchmarkProvider provider) {
    final liveData = provider.liveData[provider.activeClient];
    return liveData?.currentMetrics.averageLatency != null
        ? '${liveData!.currentMetrics.averageLatency.toStringAsFixed(0)}ms'
        : '0ms';
  }

  @override
  Size get preferredSize => const Size.fromHeight(110);
}
