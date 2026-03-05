import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const TamagoApp());
}

class TamagoApp extends StatelessWidget {
  const TamagoApp({super.key});

  @override
  Widget build(BuildContext context) {
    const pastelBackground = Color(0xFFFDF8F5);
    const pastelPrimary = Color(0xFF9EB7FF);
    const pastelSecondary = Color(0xFFFFE6B8);

    return MaterialApp(
      title: 'Tamago Tasks',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: pastelPrimary,
          brightness: Brightness.light,
          primary: pastelPrimary,
          secondary: pastelSecondary,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: pastelBackground,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
      home: const TodayPage(),
    );
  }
}

enum TaskColorOption {
  jaune('Jaune', Color(0xFFFFE082)),
  rouge('Rouge', Color(0xFFFFABAB)),
  vert('Vert', Color(0xFFA8E6A2)),
  bleu('Bleu', Color(0xFFA9D6FF)),
  gris('Gris', Color(0xFFD6D8DC)),
  violet('Violet', Color(0xFFD8B4FE));

  const TaskColorOption(this.label, this.color);
  final String label;
  final Color color;
}

class TaskItem {
  TaskItem({
    required this.name,
    required this.date,
    this.allDay = false,
    this.startTime,
    this.endTime,
    this.duration = '',
    this.recurrence = 'Aucune',
    this.status = 'À faire',
    this.contact = '',
    this.project = '',
    this.color = TaskColorOption.bleu,
  });

  String name;
  DateTime date;
  bool allDay;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String duration;
  String recurrence;
  String status;
  String contact;
  String project;
  TaskColorOption color;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'date': date.toIso8601String(),
      'allDay': allDay,
      'startTime': _timeToMinutes(startTime),
      'endTime': _timeToMinutes(endTime),
      'duration': duration,
      'recurrence': recurrence,
      'status': status,
      'contact': contact,
      'project': project,
      'color': color.name,
    };
  }

  static TaskItem fromJson(Map<String, dynamic> json) {
    final colorName = (json['color'] as String?) ?? TaskColorOption.bleu.name;
    final resolvedColor = TaskColorOption.values.firstWhere(
      (item) => item.name == colorName,
      orElse: () => TaskColorOption.bleu,
    );

    return TaskItem(
      name: (json['name'] as String?) ?? '',
      date:
          DateTime.tryParse((json['date'] as String?) ?? '') ?? DateTime.now(),
      allDay: (json['allDay'] as bool?) ?? false,
      startTime: _minutesToTime(json['startTime'] as int?),
      endTime: _minutesToTime(json['endTime'] as int?),
      duration: (json['duration'] as String?) ?? '',
      recurrence: (json['recurrence'] as String?) ?? 'Aucune',
      status: (json['status'] as String?) ?? 'À faire',
      contact: (json['contact'] as String?) ?? '',
      project: (json['project'] as String?) ?? '',
      color: resolvedColor,
    );
  }

  static int? _timeToMinutes(TimeOfDay? value) {
    if (value == null) {
      return null;
    }
    return value.hour * 60 + value.minute;
  }

  static TimeOfDay? _minutesToTime(int? value) {
    if (value == null) {
      return null;
    }
    final hour = value ~/ 60;
    final minute = value % 60;
    return TimeOfDay(hour: hour, minute: minute);
  }
}

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  static const _tasksStorageKey = 'tamago_tasks_v1';

  final TextEditingController _quickAddController = TextEditingController();
  final List<TaskItem> _tasks = [];
  TaskItem? _hoveredTask;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _quickAddController.dispose();
    super.dispose();
  }

  DateTime get _todayOnly {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  List<TaskItem> get _todayTasks {
    final today = _todayOnly;
    return _tasks.where((task) {
      return _isSameDay(task.date, today);
    }).toList();
  }

  void _reorderTodayTasks(int oldIndex, int newIndex) {
    final reorderedTodayTasks = List<TaskItem>.from(_todayTasks);
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final movedTask = reorderedTodayTasks.removeAt(oldIndex);
    reorderedTodayTasks.insert(newIndex, movedTask);

    setState(() {
      var todayIndex = 0;
      for (var i = 0; i < _tasks.length; i++) {
        if (_isSameDay(_tasks[i].date, _todayOnly)) {
          _tasks[i] = reorderedTodayTasks[todayIndex];
          todayIndex += 1;
        }
      }
    });
    _saveTasks();
  }

  Widget _buildPlatformDragListener({
    required int index,
    required Widget child,
  }) {
    final isMobile =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    if (isMobile) {
      return ReorderableDelayedDragStartListener(index: index, child: child);
    }

    return ReorderableDragStartListener(index: index, child: child);
  }

  void _addTaskFromPrompt() {
    final taskName = _quickAddController.text.trim();
    if (taskName.isEmpty) {
      return;
    }

    setState(() {
      _tasks.insert(0, TaskItem(name: taskName, date: _todayOnly));
      _quickAddController.clear();
    });
    _saveTasks();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final rawData = prefs.getString(_tasksStorageKey);
    if (rawData == null || rawData.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(rawData) as List<dynamic>;
      final loadedTasks = decoded
          .whereType<Map<String, dynamic>>()
          .map(TaskItem.fromJson)
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _tasks
          ..clear()
          ..addAll(loadedTasks);
      });
    } catch (_) {}
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = _tasks.map((task) => task.toJson()).toList();
    await prefs.setString(_tasksStorageKey, jsonEncode(payload));
  }

  Future<void> _openTaskEditor(TaskItem task) async {
    final nameController = TextEditingController(text: task.name);
    final durationController = TextEditingController(text: task.duration);
    final contactController = TextEditingController(text: task.contact);
    final projectController = TextEditingController(text: task.project);

    DateTime selectedDate = task.date;
    bool allDay = task.allDay;
    TimeOfDay? startTime = task.startTime;
    TimeOfDay? endTime = task.endTime;
    String recurrence = task.recurrence;
    String status = task.status;
    TaskColorOption selectedColor = task.color;

    String timeLabel(TimeOfDay? value) {
      if (value == null) {
        return '--:--';
      }
      final hour = value.hour.toString().padLeft(2, '0');
      final minute = value.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickDate() async {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (pickedDate != null) {
                setModalState(() {
                  selectedDate = pickedDate;
                });
              }
            }

            Future<void> pickStartTime() async {
              final picked = await showTimePicker(
                context: context,
                initialTime: startTime ?? const TimeOfDay(hour: 9, minute: 0),
              );
              if (picked != null) {
                setModalState(() {
                  startTime = picked;
                });
              }
            }

            Future<void> pickEndTime() async {
              final picked = await showTimePicker(
                context: context,
                initialTime: endTime ?? const TimeOfDay(hour: 10, minute: 0),
              );
              if (picked != null) {
                setModalState(() {
                  endTime = picked;
                });
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Édition de la tâche',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Nom'),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Date'),
                        subtitle: Text(
                          '${selectedDate.day.toString().padLeft(2, '0')}/'
                          '${selectedDate.month.toString().padLeft(2, '0')}/'
                          '${selectedDate.year}',
                        ),
                        trailing: const Icon(Icons.calendar_month),
                        onTap: pickDate,
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: allDay,
                        onChanged: (value) {
                          setModalState(() {
                            allDay = value ?? false;
                          });
                        },
                        title: const Text('All day'),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: allDay ? null : pickStartTime,
                              child: Text(
                                'Heure début: ${timeLabel(startTime)}',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: allDay ? null : pickEndTime,
                              child: Text('Heure fin: ${timeLabel(endTime)}'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: durationController,
                        decoration: const InputDecoration(labelText: 'Durée'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: recurrence,
                        decoration: const InputDecoration(
                          labelText: 'Récurrence',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Aucune',
                            child: Text('Aucune'),
                          ),
                          DropdownMenuItem(
                            value: 'Quotidienne',
                            child: Text('Quotidienne'),
                          ),
                          DropdownMenuItem(
                            value: 'Hebdomadaire',
                            child: Text('Hebdomadaire'),
                          ),
                          DropdownMenuItem(
                            value: 'Mensuelle',
                            child: Text('Mensuelle'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setModalState(() {
                              recurrence = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(labelText: 'Statut'),
                        items: const [
                          DropdownMenuItem(
                            value: 'À faire',
                            child: Text('À faire'),
                          ),
                          DropdownMenuItem(
                            value: 'En cours',
                            child: Text('En cours'),
                          ),
                          DropdownMenuItem(
                            value: 'Terminé',
                            child: Text('Terminé'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setModalState(() {
                              status = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: contactController,
                        decoration: const InputDecoration(labelText: 'Contact'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: projectController,
                        decoration: const InputDecoration(labelText: 'Projet'),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Couleur',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: TaskColorOption.values.map((colorOption) {
                          return ChoiceChip(
                            label: Text(colorOption.label),
                            selected: selectedColor == colorOption,
                            selectedColor: colorOption.color,
                            onSelected: (_) {
                              setModalState(() {
                                selectedColor = colorOption;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _tasks.remove(task);
                            });
                            _saveTasks();
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Supprimer la tâche'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('Annuler'),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              onPressed: () {
                                setState(() {
                                  task.name = nameController.text.trim().isEmpty
                                      ? task.name
                                      : nameController.text.trim();
                                  task.date = selectedDate;
                                  task.allDay = allDay;
                                  task.startTime = allDay ? null : startTime;
                                  task.endTime = allDay ? null : endTime;
                                  task.duration = durationController.text
                                      .trim();
                                  task.recurrence = recurrence;
                                  task.status = status;
                                  task.contact = contactController.text.trim();
                                  task.project = projectController.text.trim();
                                  task.color = selectedColor;
                                });
                                _saveTasks();
                                Navigator.of(context).pop();
                              },
                              child: const Text('Enregistrer'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    durationController.dispose();
    contactController.dispose();
    projectController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasksForToday = _todayTasks;

    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('Today')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _quickAddController,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addTaskFromPrompt(),
              decoration: InputDecoration(
                hintText: 'Entrer le nom de la nouvelle tâche…',
                suffixIcon: IconButton(
                  onPressed: _addTaskFromPrompt,
                  icon: const Icon(Icons.add),
                  tooltip: 'Ajouter',
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: tasksForToday.isEmpty
                  ? Center(
                      child: Text(
                        'Aucune tâche pour aujourd’hui.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    )
                  : ReorderableListView.builder(
                      itemCount: tasksForToday.length,
                      onReorder: _reorderTodayTasks,
                      buildDefaultDragHandles: false,
                      itemBuilder: (context, index) {
                        final task = tasksForToday[index];
                        return Padding(
                          key: ObjectKey(task),
                          padding: const EdgeInsets.only(bottom: 10),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.grab,
                            onEnter: (_) {
                              setState(() {
                                _hoveredTask = task;
                              });
                            },
                            onExit: (_) {
                              setState(() {
                                if (_hoveredTask == task) {
                                  _hoveredTask = null;
                                }
                              });
                            },
                            child: _buildPlatformDragListener(
                              index: index,
                              child: Material(
                                color: task.color.color,
                                borderRadius: BorderRadius.circular(14),
                                child: ListTile(
                                  leading: AnimatedOpacity(
                                    opacity: _hoveredTask == task ? 1 : 0,
                                    duration: const Duration(milliseconds: 120),
                                    child: const Icon(Icons.drag_indicator),
                                  ),
                                  title: Text(task.name),
                                  subtitle: Text(
                                    '${task.status} • ${task.project.isEmpty ? 'Sans projet' : task.project}',
                                  ),
                                  trailing: IconButton(
                                    onPressed: () => _openTaskEditor(task),
                                    icon: const Icon(Icons.chevron_right),
                                    tooltip: 'Éditer',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
