import 'package:flutter/material.dart';
import '../database_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _name;
  int? _stepGoal;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final name = await DatabaseHelper.getSetting('name');
      final stepGoal = await DatabaseHelper.getSetting('stepGoal');
      if (mounted) {
        setState(() {
          _name = name;
          _stepGoal = stepGoal == null ? null : int.tryParse(stepGoal);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: _name,
                      decoration: const InputDecoration(
                        hintText: 'Type name here',
                        labelText: 'Name',
                      ),
                      autocorrect: false,
                      validator: (value) {
                        if (null == value || value.isEmpty) {
                          return 'No name provided';
                        }
                        return null;
                      },
                      onSaved: (newValue) {
                        _name = newValue;
                      },
                    ),
                    TextFormField(
                      initialValue: _stepGoal?.toString(),
                      decoration: const InputDecoration(
                        hintText: 'Type step goal here',
                        labelText: 'Daily step goal',
                      ),
                      keyboardType: TextInputType.number,
                      autocorrect: false,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'No step goal provided';
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
                        _stepGoal = int.parse(newValue!);
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        final state = _formKey.currentState;
                        if (state!.validate()) {
                          state.save();
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await DatabaseHelper.setSetting('name', _name!);
                            await DatabaseHelper.setSetting(
                              'stepGoal',
                              _stepGoal!.toString(),
                            );
                            if (!mounted) return;
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    ),
                                    SizedBox(width: 8),
                                    Text('Settings saved successfully!'),
                                  ],
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          } catch (e) {
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error: ${e.toString()}',
                                    maxLines: 4,
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
