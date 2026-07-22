import 'package:fittrack/screens/workout_log_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Workout converts to and from a database map', () {
    final workout = Workout(
      name: 'Morning Run',
      date: '2026-07-22',
      durationMinutes: 30,
      imagePath: '/tmp/run.jpg',
    );

    final restored = Workout.fromMap(workout.toMap());

    expect(restored.name, 'Morning Run');
    expect(restored.date, '2026-07-22');
    expect(restored.durationMinutes, 30);
    expect(restored.imagePath, '/tmp/run.jpg');
  });
}
