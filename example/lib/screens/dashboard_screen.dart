import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../providers/benchmark_provider.dart';
import '../models/benchmark_models.dart';
import '../widgets/custom_app_bar.dart';
import '../config/app_theme.dart';
import '../config/benchmark_scenarios.dart';
import 'rust_rust_tab.dart';
import 'rust_dart_tab.dart';
import 'dio_http2_tab.dart';
import 'analysis_tab.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _setupAnimations();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            CustomAppBar(
              pulseAnimation: _pulseAnimation,
              tabController: _tabController,
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            RustRustTab(),
            RustDartTab(),
            DioHttp2Tab(),
            AnalysisTab(tabController: _tabController)
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(isSmallScreen),
      floatingActionButtonLocation: isSmallScreen
          ? FloatingActionButtonLocation.centerFloat
          : FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildFloatingActionButton(bool isSmallScreen) {
    return Consumer<BenchmarkProvider>(
      builder: (context, provider, child) {
        final isRunning = provider.isRunning;

        return AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: isRunning ? _pulseAnimation.value : 1.0,
              child: Container(
                margin: isSmallScreen ? EdgeInsets.symmetric(horizontal: 16) : EdgeInsets.zero,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(isSmallScreen ? 28 : 32),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.4),
                      blurRadius: 15,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: isSmallScreen
                    ? _buildMobileFAB(isRunning, provider)
                    : _buildDesktopFAB(isRunning, provider),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMobileFAB(bool isRunning, BenchmarkProvider provider) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: isRunning
            ? () => provider.stopAllBenchmarks()
            : () => _showClientSelectionBottomSheet(),
        child: Container(
          height: 56,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              isRunning
                  ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
                  : Icon(Icons.rocket_launch, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text(
                isRunning
                    ? 'Stop Tests (${provider.currentScenarioIndex + 1}/${BenchmarkScenarios.scenarios.length})'
                    : 'Run All Benchmarks',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopFAB(bool isRunning, BenchmarkProvider provider) {
    return FloatingActionButton.extended(
      onPressed: isRunning
          ? () => provider.stopAllBenchmarks()
          : () => _showClientSelectionDialog(),
      backgroundColor: Colors.transparent,
      elevation: 0,
      icon: isRunning
          ? SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(Colors.white),
        ),
      )
          : Icon(Icons.rocket_launch, color: Colors.white),
      label: Text(
        isRunning
            ? 'Stop Tests (${provider.currentScenarioIndex + 1}/${BenchmarkScenarios.scenarios.length})'
            : 'Run All Benchmarks',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showClientSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => ClientSelectionDialog(
        onClientSelected: (clientType) {
          Navigator.of(context).pop();
          _startAllBenchmarks(clientType);
        },
      ),
    );
  }

  void _showClientSelectionBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ClientSelectionBottomSheet(
        onClientSelected: (clientType) {
          Navigator.of(context).pop();
          _startAllBenchmarks(clientType);
        },
      ),
    );
  }

  void _startAllBenchmarks(HttpClientType clientType) async {
    final provider = context.read<BenchmarkProvider>();

    // Switch to the appropriate tab
    switch (clientType) {
      case HttpClientType.rustParsedRust:
        _tabController.animateTo(0);
        break;
      case HttpClientType.dartParsedRust:
      case HttpClientType.rustDartInterop:
        _tabController.animateTo(1);
        break;
      case HttpClientType.dioHttp2:
        _tabController.animateTo(2);
        break;
    }

    // Start running all scenarios sequentially
    await provider.runAllScenarios(clientType);

    // Save results to shared preferences
    await _saveResultsToPreferences(provider.getAllResults());
  }

  Future<void> _saveResultsToPreferences(Map<String, dynamic> results) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().toIso8601String();

      // Get existing results
      final existingResultsJson = prefs.getString('benchmark_results') ?? '[]';
      final existingResults = json.decode(existingResultsJson) as List;

      // Add new results with timestamp
      existingResults.add({
        'timestamp': timestamp,
        'results': results,
      });

      // Keep only last 50 benchmark runs to prevent excessive storage
      if (existingResults.length > 50) {
        existingResults.removeRange(0, existingResults.length - 50);
      }

      // Save back to preferences
      await prefs.setString('benchmark_results', json.encode(existingResults));

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Benchmark results saved successfully!'),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error saving results to preferences: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving results: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// Simplified client selection dialog
class ClientSelectionDialog extends StatefulWidget {
  final Function(HttpClientType) onClientSelected;

  const ClientSelectionDialog({
    Key? key,
    required this.onClientSelected,
  }) : super(key: key);

  @override
  _ClientSelectionDialogState createState() => _ClientSelectionDialogState();
}

class _ClientSelectionDialogState extends State<ClientSelectionDialog> {
  HttpClientType selectedClient = HttpClientType.rustParsedRust;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: 24),
            _buildClientSelection(),
            SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.speed,
            color: Colors.white,
            size: 24,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Run All Benchmarks',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'Select HTTP client and run all ${BenchmarkScenarios.scenarios.length} scenarios',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClientSelection() {
    return Expanded(
      child: Container(
        decoration: AppTheme.cardDecoration(borderColor: AppTheme.primaryColor),
        child: ListView.builder(
          itemCount: HttpClientType.values.length,
          itemBuilder: (context, index) {
            final client = HttpClientType.values[index];
            final isSelected = selectedClient == client;

            return Container(
              margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected ? client.color.withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isSelected ? Border.all(color: client.color, width: 2) : null,
              ),
              child: ListTile(
                onTap: () => setState(() => selectedClient = client),
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: client.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(client.icon, color: client.color, size: 20),
                ),
                title: Text(
                  client.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                subtitle: Text(
                  client.description,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle, color: client.color)
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ),
        SizedBox(width: 16),
        ElevatedButton(
          onPressed: () => widget.onClientSelected(selectedClient),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_arrow, size: 20),
              SizedBox(width: 8),
              Text('Run All ${BenchmarkScenarios.scenarios.length} Scenarios'),
            ],
          ),
        ),
      ],
    );
  }
}

// Simplified mobile bottom sheet
class ClientSelectionBottomSheet extends StatefulWidget {
  final Function(HttpClientType) onClientSelected;

  const ClientSelectionBottomSheet({
    Key? key,
    required this.onClientSelected,
  }) : super(key: key);

  @override
  _ClientSelectionBottomSheetState createState() => _ClientSelectionBottomSheetState();
}

class _ClientSelectionBottomSheetState extends State<ClientSelectionBottomSheet> {
  HttpClientType selectedClient = HttpClientType.rustParsedRust;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildHeader(),
          Expanded(child: _buildClientSelection()),
          _buildBottomAction(),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: EdgeInsets.only(top: 12, bottom: 8),
      height: 4,
      width: 40,
      decoration: BoxDecoration(
        color: Colors.grey[600],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.speed,
              color: Colors.white,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Run All Benchmarks',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Choose client type for all ${BenchmarkScenarios.scenarios.length} scenarios',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildClientSelection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: ListView.separated(
        itemCount: HttpClientType.values.length,
        separatorBuilder: (context, index) => SizedBox(height: 12),
        itemBuilder: (context, index) {
          final client = HttpClientType.values[index];
          final isSelected = selectedClient == client;

          return Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? client.color.withOpacity(0.1)
                  : AppTheme.cardColor,
              border: Border.all(
                color: isSelected
                    ? client.color
                    : Colors.grey[700]!,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.all(16),
              onTap: () => setState(() => selectedClient = client),
              leading: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: client.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(client.icon, color: client.color, size: 24),
              ),
              title: Text(
                client.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              subtitle: Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  client.description,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ),
              trailing: isSelected
                  ? Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: client.color,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              )
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => widget.onClientSelected(selectedClient),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow, size: 24),
                SizedBox(width: 12),
                Text(
                  'Run All ${BenchmarkScenarios.scenarios.length} Scenarios',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}