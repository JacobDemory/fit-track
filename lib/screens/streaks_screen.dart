import 'package:flutter/material.dart';
import '../database_helper.dart';

class StreaksScreen extends StatefulWidget {
  const StreaksScreen({super.key});

  @override
  State<StreaksScreen> createState() => _StreaksScreenState();
}

class _StreaksScreenState extends State<StreaksScreen> {
  int _stepGoal = 5000;
  Map<String, int> _dailySteps = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final goalStr = await DatabaseHelper.getSetting('stepGoal');
      if (goalStr != null) {
        _stepGoal = int.tryParse(goalStr) ?? 5000;
      }

      final stepsData = await DatabaseHelper.getDailySteps();
      final map = <String, int>{};
      for (var row in stepsData) {
        map[row['date'] as String] = row['steps'] as int;
      }

      if (mounted) {
        setState(() {
          _dailySteps = map;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  int _calculateCurrentStreak() {
    int streak = 0;
    DateTime date = DateTime.now();
    String today = date.toIso8601String().split('T')[0];
    String yesterday = date
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .split('T')[0];

    if ((_dailySteps[today] ?? 0) < _stepGoal &&
        (_dailySteps[yesterday] ?? 0) < _stepGoal) {
      return 0; // Streak broken
    }

    while (true) {
      String dStr = date.toIso8601String().split('T')[0];
      int steps = _dailySteps[dStr] ?? 0;
      if (steps >= _stepGoal) {
        streak++;
      } else {
        if (dStr != today) break;
      }
      date = date.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int _calculateMaxStreak() {
    int maxStreak = 0;
    int current = 0;

    if (_dailySteps.isEmpty) return 0;
    List<String> dates = _dailySteps.keys.toList()..sort();

    DateTime start = DateTime.parse(dates.first);
    DateTime end = DateTime.now();

    for (
      DateTime d = start;
      d.isBefore(end) ||
          d.isAtSameMomentAs(end) ||
          d.toIso8601String().split('T')[0] ==
              end.toIso8601String().split('T')[0];
      d = d.add(const Duration(days: 1))
    ) {
      String dStr = d.toIso8601String().split('T')[0];
      int steps = _dailySteps[dStr] ?? 0;
      if (steps >= _stepGoal) {
        current++;
        if (current > maxStreak) maxStreak = current;
      } else {
        current = 0;
      }
    }
    return maxStreak;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    List<DateTime> past30Days = List.generate(30, (i) {
      return DateTime.now().subtract(Duration(days: 29 - i));
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Streaks'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: _InfoCard(
                      title: 'Current Streak',
                      value: '${_calculateCurrentStreak()}',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _InfoCard(
                      title: 'Max Streak',
                      value: '${_calculateMaxStreak()}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Past 30 Days (Goal: $_stepGoal)',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  itemCount: past30Days.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemBuilder: (context, index) {
                    DateTime date = past30Days[index];
                    String dStr = date.toIso8601String().split('T')[0];
                    int steps = _dailySteps[dStr] ?? 0;
                    bool reached = steps >= _stepGoal;
                    bool isToday =
                        dStr == DateTime.now().toIso8601String().split('T')[0];

                    return Container(
                      decoration: BoxDecoration(
                        color: reached
                            ? Colors.green.shade100
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: isToday
                            ? Border.all(color: Colors.blue, width: 2)
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${date.month}/${date.day}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Icon(
                            reached
                                ? Icons.check_circle
                                : (isToday
                                      ? Icons.hourglass_top
                                      : Icons.cancel),
                            color: reached
                                ? Colors.green
                                : (isToday ? Colors.grey : Colors.red),
                            size: 20,
                          ),
                          const SizedBox(height: 4),
                          Text('$steps', style: const TextStyle(fontSize: 10)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  const _InfoCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Column(
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
