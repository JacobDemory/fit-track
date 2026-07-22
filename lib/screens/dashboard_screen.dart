import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:permission_handler/permission_handler.dart';
import '../database_helper.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _steps = 0;
  String _status = 'stopped';
  int _lastPedometerReading = 0;
  String _currentDate = DateTime.now().toIso8601String().split('T')[0];

  Timer? _saveTimer;
  int _pendingSteps = 0;

  StreamSubscription<StepCount>? _stepCountSubscription;
  StreamSubscription<PedestrianStatus>? _pedestrianStatusSubscription;

  List<int> _weeklySteps = List.filled(7, 0);
  int _weeklyWorkoutCount = 0;
  int _weeklyWorkoutMinutes = 0;
  int _stepGoal = 5000;
  String _name = '';
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _checkPermissionsAndInit();
  }

  Future<void> _loadDashboardData() async {
    final weeklySteps = await DatabaseHelper.getLast7DaysSteps();
    final workoutCount = await DatabaseHelper.getWorkoutCountLast7Days();
    final workoutMinutes = await DatabaseHelper.getWorkoutMinutesLast7Days();
    final savedGoal = await DatabaseHelper.getSetting('stepGoal');
    final savedName = await DatabaseHelper.getSetting('name');

    if (!mounted) return;

    setState(() {
      _weeklySteps = weeklySteps;
      _weeklyWorkoutCount = workoutCount;
      _weeklyWorkoutMinutes = workoutMinutes;
      _stepGoal = int.tryParse(savedGoal ?? '') ?? 5000;
      _name = savedName ?? '';
      _loadingStats = false;
    });
  }

  Future<void> _checkPermissionsAndInit() async {
    final status = await Permission.activityRecognition.request();
    if (status.isGranted) {
      _initPedometer();
    } else {
      if (!mounted) return;
      setState(() {
        _status = 'Permission denied';
      });
    }
  }

  void _initPedometer() async {
    _steps = await DatabaseHelper.getStepsForDate(_currentDate);
    if (mounted) {
      setState(() {});
    }

    _stepCountSubscription = Pedometer.stepCountStream.listen((
      StepCount event,
    ) async {
      final today = DateTime.now().toIso8601String().split('T')[0];

      if (today != _currentDate) {
        _currentDate = today;
        _steps = await DatabaseHelper.getStepsForDate(_currentDate);
        await _loadDashboardData();
      }

      if (_lastPedometerReading == 0 || event.steps < _lastPedometerReading) {
        _lastPedometerReading = event.steps;
        return;
      }

      final delta = event.steps - _lastPedometerReading;
      _lastPedometerReading = event.steps;

      if (delta > 0) {
        if (mounted) {
          setState(() {
            _steps += delta;
            _weeklySteps[6] = _steps;
          });
        }

        _pendingSteps += delta;
        _saveTimer?.cancel();
        _saveTimer = Timer(const Duration(seconds: 2), () async {
          if (_pendingSteps > 0) {
            final toSave = _pendingSteps;
            _pendingSteps = 0;
            await DatabaseHelper.addDailySteps(_currentDate, toSave);
            await _loadDashboardData();
          }
        });
      }
    }, onError: (_) {});

    _pedestrianStatusSubscription = Pedometer.pedestrianStatusStream.listen(
      (PedestrianStatus event) {
        if (!mounted) return;
        setState(() {
          _status = event.status;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _status = 'unavailable';
        });
      },
    );
  }

  @override
  void dispose() {
    _stepCountSubscription?.cancel();
    _pedestrianStatusSubscription?.cancel();
    _saveTimer?.cancel();

    if (_pendingSteps > 0) {
      DatabaseHelper.addDailySteps(_currentDate, _pendingSteps);
    }

    super.dispose();
  }

  List<String> _recentDayLabels() {
    return List.generate(7, (index) {
      final date = DateTime.now().subtract(Duration(days: 6 - index));
      switch (date.weekday) {
        case DateTime.monday:
          return 'Mon';
        case DateTime.tuesday:
          return 'Tue';
        case DateTime.wednesday:
          return 'Wed';
        case DateTime.thursday:
          return 'Thu';
        case DateTime.friday:
          return 'Fri';
        case DateTime.saturday:
          return 'Sat';
        default:
          return 'Sun';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final percent = _stepGoal > 0 ? (_steps / _stepGoal).clamp(0.0, 1.0) : 0.0;
    final chartLabels = _recentDayLabels();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _loadingStats
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (_name.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Welcome back, $_name',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.directions_walk, size: 48),
                        const SizedBox(height: 8),
                        Text(
                          '$_steps',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const Text('steps today'),
                        const SizedBox(height: 8),
                        Text(
                          'Goal: $_stepGoal',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(value: percent),
                        const SizedBox(height: 8),
                        Text('${(percent * 100).round()}% of daily goal'),
                        const SizedBox(height: 8),
                        Text(
                          'Status: $_status',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: 'Workouts (7 days)',
                        value: '$_weeklyWorkoutCount',
                        icon: Icons.fitness_center,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Minutes (7 days)',
                        value: '$_weeklyWorkoutMinutes',
                        icon: Icons.timer,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                Text(
                  'Weekly Step Chart',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),

                SizedBox(
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      maxY:
                          (_weeklySteps
                                      .reduce((a, b) => a > b ? a : b)
                                      .toDouble() +
                                  1000)
                              .clamp(3000, 30000),
                      barGroups: List.generate(_weeklySteps.length, (i) {
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: _weeklySteps[i].toDouble(),
                              width: 18,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        );
                      }),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, _) {
                              final i = value.toInt();
                              if (i < 0 || i >= chartLabels.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(chartLabels[i]),
                              );
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
