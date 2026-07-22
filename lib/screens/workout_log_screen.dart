import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../database_helper.dart';

class Workout {
  final String name;
  final String date;
  final int durationMinutes;
  final String? imagePath;

  Workout({
    required this.name,
    required this.date,
    required this.durationMinutes,
    this.imagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'date': date,
      'durationMinutes': durationMinutes,
      'imagePath': imagePath,
    };
  }

  factory Workout.fromMap(Map<String, dynamic> map) {
    return Workout(
      name: map['name'],
      date: map['date'],
      durationMinutes: map['durationMinutes'],
      imagePath: map['imagePath'],
    );
  }
}

class WorkoutLogScreen extends StatefulWidget {
  const WorkoutLogScreen({super.key});

  @override
  State<WorkoutLogScreen> createState() => _WorkoutLogScreenState();
}

class _WorkoutLogScreenState extends State<WorkoutLogScreen> {
  List<Workout> _workouts = [];

  final GlobalKey<FormState> _formKey = GlobalKey();
  String? _workoutName;
  int? _workoutDuration;

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  void _loadWorkouts() {
    DatabaseHelper.getWorkouts().then((rows) {
      setState(() {
        _workouts = rows.map((row) => Workout.fromMap(row)).toList();
      });
    });
  }

  void _showAddWorkoutForm() {
    String? pickedImagePath;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('New Workout'),
              scrollable: true,
              content: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      decoration: const InputDecoration(
                        hintText: 'Type workout name here',
                      ),
                      autocorrect: false,
                      obscureText: false,
                      autofocus: true,
                      validator: (value) {
                        if (null == value || value.isEmpty) {
                          return 'No name provided';
                        }
                        return null;
                      },
                      onSaved: (newValue) {
                        _workoutName = newValue;
                      },
                    ),
                    TextFormField(
                      decoration: const InputDecoration(
                        hintText: 'Type duration in minutes here',
                      ),
                      keyboardType: TextInputType.number,
                      autocorrect: false,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'No duration provided';
                        }
                        final ival = int.tryParse(value);
                        if (ival == null) {
                          return 'Not a number';
                        }
                        if (ival <= 0) {
                          return 'Must be positive';
                        }
                        return null;
                      },
                      onSaved: (newValue) {
                        _workoutDuration = int.parse(newValue!);
                      },
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        FilePicker.platform
                            .pickFiles(type: FileType.image)
                            .then((value) {
                              final path = value?.files.single.path;
                              setDialogState(() {
                                pickedImagePath = path;
                              });
                            });
                      },
                      child: const Text('Attach Photo'),
                    ),
                    if (pickedImagePath != null) ...[
                      const SizedBox(height: 8),
                      Image.file(
                        File(pickedImagePath!),
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final state = _formKey.currentState;
                    if (state!.validate()) {
                      state.save();
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      final workout = Workout(
                        name: _workoutName!,
                        date: DateTime.now().toIso8601String().split('T')[0],
                        durationMinutes: _workoutDuration!,
                        imagePath: pickedImagePath,
                      );
                      try {
                        await DatabaseHelper.insertWorkout(workout.toMap());
                        _loadWorkouts();
                        if (mounted && navigator.canPop()) {
                          navigator.pop();
                        }
                      } catch (e) {
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.error, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Failed to save workout to database'),
                                ],
                              ),
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Log'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddWorkoutForm,
        child: const Icon(Icons.add),
      ),
      body: ListView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            'Recent Workouts',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ..._workouts.map(
            (workout) => Card(
              child: ListTile(
                leading: workout.imagePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.file(
                          File(workout.imagePath!),
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(Icons.fitness_center),
                title: Text(workout.name),
                subtitle: Text(workout.date),
                trailing: Text('${workout.durationMinutes} min'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
