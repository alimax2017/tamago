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

enum MainView { today, projects }

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

enum ProjectColorOption {
  jaune('Jaune', Color(0xFFFFE082)),
  vert('Vert', Color(0xFFA8E6A2)),
  rouge('Rouge', Color(0xFFFFABAB)),
  bleu('Bleu', Color(0xFFA9D6FF)),
  gris('Gris', Color(0xFFD6D8DC)),
  marron('Marron', Color(0xFFD7B899));

  const ProjectColorOption(this.label, this.color);
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
    this.projectId,
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
  String? projectId;
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
      'projectId': projectId,
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
      projectId: json['projectId'] as String?,
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
    return TimeOfDay(hour: value ~/ 60, minute: value % 60);
  }
}

class ProjectItem {
  ProjectItem({
    required this.id,
    required this.name,
    required this.createdAt,
    DateTime? startDate,
    this.endDate,
    this.description = '',
    this.status = 'À faire',
    this.color = ProjectColorOption.bleu,
  }) : startDate = startDate ?? createdAt;

  String id;
  String name;
  DateTime createdAt;
  DateTime startDate;
  DateTime? endDate;
  String description;
  String status;
  ProjectColorOption color;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'description': description,
      'status': status,
      'color': color.name,
    };
  }

  static ProjectItem fromJson(Map<String, dynamic> json) {
    final colorName =
        (json['color'] as String?) ?? ProjectColorOption.bleu.name;
    final resolvedColor = ProjectColorOption.values.firstWhere(
      (item) => item.name == colorName,
      orElse: () => ProjectColorOption.bleu,
    );

    final createdAt =
        DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
        DateTime.now();
    final startDate =
        DateTime.tryParse((json['startDate'] as String?) ?? '') ?? createdAt;
    final endDate = DateTime.tryParse((json['endDate'] as String?) ?? '');

    return ProjectItem(
      id:
          (json['id'] as String?) ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: (json['name'] as String?) ?? 'Projet',
      createdAt: createdAt,
      startDate: startDate,
      endDate: endDate,
      description: (json['description'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'À faire',
      color: resolvedColor,
    );
  }
}

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  static const _tasksStorageKey = 'tamago_tasks_v1';
  static const _projectsStorageKey = 'tamago_projects_v1';

  final TextEditingController _quickAddTaskController = TextEditingController();
  final TextEditingController _quickAddProjectController =
      TextEditingController();
  final TextEditingController _quickAddProjectTaskController =
      TextEditingController();

  final List<TaskItem> _tasks = [];
  final List<ProjectItem> _projects = [];

  MainView _currentView = MainView.today;
  String? _selectedProjectId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _quickAddTaskController.dispose();
    _quickAddProjectController.dispose();
    _quickAddProjectTaskController.dispose();
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

  String _nextStatus(String currentStatus) {
    switch (currentStatus) {
      case 'À faire':
        return 'En cours';
      case 'En cours':
        return 'Terminé';
      case 'Terminé':
        return 'À faire';
      default:
        return 'À faire';
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'En cours':
        return Icons.timelapse_rounded;
      case 'Terminé':
        return Icons.check_circle_rounded;
      default:
        return Icons.radio_button_unchecked_rounded;
    }
  }

  Color _statusColor(BuildContext context, String status) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (status) {
      case 'En cours':
        return colorScheme.primary;
      case 'Terminé':
        return colorScheme.secondary;
      default:
        return colorScheme.outline;
    }
  }

  List<TaskItem> get _todayTasks {
    return _tasks.where((task) => _isSameDay(task.date, _todayOnly)).toList();
  }

  ProjectItem? get _selectedProject {
    if (_selectedProjectId == null) {
      return null;
    }
    try {
      return _projects.firstWhere(
        (project) => project.id == _selectedProjectId,
      );
    } catch (_) {
      return null;
    }
  }

  List<TaskItem> _tasksForProject(ProjectItem project) {
    return _tasks
        .where((task) => _taskBelongsToProject(task, project))
        .toList();
  }

  bool _taskBelongsToProject(TaskItem task, ProjectItem project) {
    if (task.projectId != null) {
      return task.projectId == project.id;
    }
    return task.project == project.name;
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

  void _cycleTaskStatus(TaskItem task) {
    setState(() {
      task.status = _nextStatus(task.status);
    });
    _saveTasks();
  }

  void _cycleProjectStatus(ProjectItem project) {
    setState(() {
      project.status = _nextStatus(project.status);
    });
    _saveProjects();
  }

  void _reorderTodayTasks(int oldIndex, int newIndex) {
    final reordered = List<TaskItem>.from(_todayTasks);
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final movedTask = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, movedTask);

    setState(() {
      var todayIndex = 0;
      for (var i = 0; i < _tasks.length; i++) {
        if (_isSameDay(_tasks[i].date, _todayOnly)) {
          _tasks[i] = reordered[todayIndex];
          todayIndex += 1;
        }
      }
    });
    _saveTasks();
  }

  void _reorderProjects(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    setState(() {
      final movedProject = _projects.removeAt(oldIndex);
      _projects.insert(newIndex, movedProject);
    });
    _saveProjects();
  }

  void _reorderProjectTasks(ProjectItem project, int oldIndex, int newIndex) {
    final reordered = List<TaskItem>.from(_tasksForProject(project));
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final movedTask = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, movedTask);

    setState(() {
      var projectIndex = 0;
      for (var i = 0; i < _tasks.length; i++) {
        if (_taskBelongsToProject(_tasks[i], project)) {
          _tasks[i] = reordered[projectIndex];
          projectIndex += 1;
        }
      }
    });
    _saveTasks();
  }

  void _addTaskFromPrompt() {
    final taskName = _quickAddTaskController.text.trim();
    if (taskName.isEmpty) {
      return;
    }

    setState(() {
      _tasks.insert(0, TaskItem(name: taskName, date: _todayOnly));
      _quickAddTaskController.clear();
    });
    _saveTasks();
  }

  void _addProjectFromPrompt() {
    final projectName = _quickAddProjectController.text.trim();
    if (projectName.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final project = ProjectItem(
      id: now.microsecondsSinceEpoch.toString(),
      name: projectName,
      createdAt: now,
    );

    setState(() {
      _projects.insert(0, project);
      _selectedProjectId = project.id;
      _quickAddProjectController.clear();
    });
    _saveProjects();
  }

  void _addTaskToSelectedProjectFromPrompt() {
    final selectedProject = _selectedProject;
    if (selectedProject == null) {
      return;
    }

    final taskName = _quickAddProjectTaskController.text.trim();
    if (taskName.isEmpty) {
      return;
    }

    final task = TaskItem(
      name: taskName,
      date: _todayOnly,
      project: selectedProject.name,
      projectId: selectedProject.id,
    );

    setState(() {
      _tasks.insert(0, task);
      _quickAddProjectTaskController.clear();
    });
    _saveTasks();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final rawProjects = prefs.getString(_projectsStorageKey);
    final rawTasks = prefs.getString(_tasksStorageKey);

    final loadedProjects = <ProjectItem>[];
    final loadedTasks = <TaskItem>[];

    if (rawProjects != null && rawProjects.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawProjects) as List<dynamic>;
        loadedProjects.addAll(
          decoded.whereType<Map<String, dynamic>>().map(ProjectItem.fromJson),
        );
      } catch (_) {}
    }

    if (rawTasks != null && rawTasks.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTasks) as List<dynamic>;
        loadedTasks.addAll(
          decoded.whereType<Map<String, dynamic>>().map(TaskItem.fromJson),
        );
      } catch (_) {}
    }

    for (final task in loadedTasks) {
      if (task.projectId == null && task.project.isNotEmpty) {
        final byName = loadedProjects.where(
          (project) => project.name == task.project,
        );
        if (byName.isNotEmpty) {
          task.projectId = byName.first.id;
        }
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _projects
        ..clear()
        ..addAll(loadedProjects);
      _tasks
        ..clear()
        ..addAll(loadedTasks);
      if (_projects.isNotEmpty && _selectedProjectId == null) {
        _selectedProjectId = _projects.first.id;
      }
    });
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = _tasks.map((task) => task.toJson()).toList();
    await prefs.setString(_tasksStorageKey, jsonEncode(payload));
  }

  Future<void> _saveProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = _projects.map((project) => project.toJson()).toList();
    await prefs.setString(_projectsStorageKey, jsonEncode(payload));
  }

  Future<void> _openTaskEditor(TaskItem task, {bool isNew = false}) async {
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
      return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
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
                          '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
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
                      if (!isNew)
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
                      if (!isNew) const SizedBox(height: 10),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Annuler'),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              onPressed: () {
                                setState(() {
                                  if (isNew) {
                                    _tasks.insert(0, task);
                                  }

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
                                  final linked = _projects.where(
                                    (project) => project.name == task.project,
                                  );
                                  task.projectId = linked.isEmpty
                                      ? null
                                      : linked.first.id;
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

  Future<void> _openProjectEditor(ProjectItem project) async {
    final nameController = TextEditingController(text: project.name);
    final descriptionController = TextEditingController(
      text: project.description,
    );

    DateTime startDate = project.startDate;
    DateTime? endDate = project.endDate;
    String status = project.status;
    ProjectColorOption selectedColor = project.color;

    String formatDate(DateTime value) {
      return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
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
            Future<void> pickStartDate() async {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: startDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (pickedDate != null) {
                setModalState(() {
                  startDate = pickedDate;
                });
              }
            }

            Future<void> pickEndDate() async {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: endDate ?? startDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (pickedDate != null) {
                setModalState(() {
                  endDate = pickedDate;
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
                        'Édition du projet',
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
                        title: const Text('Date de début'),
                        subtitle: Text(formatDate(startDate)),
                        trailing: const Icon(Icons.calendar_month),
                        onTap: pickStartDate,
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Date de fin'),
                        subtitle: Text(
                          endDate == null
                              ? 'Non définie'
                              : formatDate(endDate!),
                        ),
                        trailing: const Icon(Icons.event_available),
                        onTap: pickEndDate,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        minLines: 2,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
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
                      const SizedBox(height: 14),
                      Text(
                        'Couleur',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ProjectColorOption.values.map((colorOption) {
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
                          onPressed: () async {
                            final projectName =
                                nameController.text.trim().isEmpty
                                ? project.name
                                : nameController.text.trim();
                            final newTask = TaskItem(
                              name: 'Nouvelle tâche',
                              date: _todayOnly,
                              project: projectName,
                              projectId: project.id,
                            );
                            await _openTaskEditor(newTask, isNew: true);
                          },
                          icon: const Icon(Icons.add_task),
                          label: const Text('Ajouter une tâche'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Annuler'),
                          ),
                          const SizedBox(width: 6),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _projects.removeWhere(
                                  (item) => item.id == project.id,
                                );
                                if (_selectedProjectId == project.id) {
                                  _selectedProjectId = _projects.isEmpty
                                      ? null
                                      : _projects.first.id;
                                }
                                for (final task in _tasks) {
                                  if (task.projectId == project.id) {
                                    task.projectId = null;
                                    task.project = '';
                                  }
                                }
                              });
                              _saveProjects();
                              _saveTasks();
                              Navigator.of(context).pop();
                            },
                            child: const Text('Supprimer'),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                final nextName =
                                    nameController.text.trim().isEmpty
                                    ? project.name
                                    : nameController.text.trim();

                                setState(() {
                                  project.name = nextName;
                                  project.startDate = startDate;
                                  project.endDate = endDate;
                                  project.description = descriptionController
                                      .text
                                      .trim();
                                  project.status = status;
                                  project.color = selectedColor;

                                  for (final task in _tasks) {
                                    if (task.projectId == project.id) {
                                      task.project = project.name;
                                    }
                                  }
                                });
                                _saveProjects();
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
    descriptionController.dispose();
  }

  Widget _buildViewSwitcher() {
    Widget buildButton({required String label, required MainView view}) {
      final isSelected = _currentView == view;
      if (isSelected) {
        return FilledButton(
          onPressed: () {
            setState(() {
              _currentView = view;
            });
          },
          child: Text(label),
        );
      }
      return OutlinedButton(
        onPressed: () {
          setState(() {
            _currentView = view;
          });
        },
        child: Text(label),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildButton(label: 'Today', view: MainView.today),
        const SizedBox(width: 8),
        buildButton(label: 'Projets', view: MainView.projects),
      ],
    );
  }

  Widget _buildTaskTile(TaskItem task) {
    return Material(
      color: task.color.color,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        leading: IconButton(
          onPressed: () => _cycleTaskStatus(task),
          icon: Icon(
            _statusIcon(task.status),
            color: _statusColor(context, task.status),
          ),
          tooltip: 'Changer le statut',
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
    );
  }

  Widget _buildTodayView() {
    final tasksForToday = _todayTasks;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _quickAddTaskController,
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
                          child: _buildPlatformDragListener(
                            index: index,
                            child: _buildTaskTile(task),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsView() {
    final selectedProject = _selectedProject;
    final tasks = selectedProject == null
        ? <TaskItem>[]
        : _tasksForProject(selectedProject);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 900;

        if (isCompact) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _quickAddProjectController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addProjectFromPrompt(),
                  decoration: InputDecoration(
                    hintText: 'Entrer le nom du nouveau projet…',
                    suffixIcon: IconButton(
                      onPressed: _addProjectFromPrompt,
                      icon: const Icon(Icons.add),
                      tooltip: 'Ajouter',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: _projects.isEmpty
                      ? Center(
                          child: Text(
                            'Aucun projet.',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        )
                      : ReorderableListView.builder(
                          itemCount: _projects.length,
                          onReorder: _reorderProjects,
                          buildDefaultDragHandles: false,
                          itemBuilder: (context, index) {
                            final project = _projects[index];
                            final isSelected = _selectedProjectId == project.id;
                            final projectTasks = _tasksForProject(project);

                            return Padding(
                              key: ValueKey('project-${project.id}'),
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MouseRegion(
                                    cursor: SystemMouseCursors.grab,
                                    child: _buildPlatformDragListener(
                                      index: index,
                                      child: Material(
                                        color: project.color.color,
                                        borderRadius: BorderRadius.circular(14),
                                        child: ListTile(
                                          selected: isSelected,
                                          leading: IconButton(
                                            onPressed: () =>
                                                _cycleProjectStatus(project),
                                            icon: Icon(
                                              _statusIcon(project.status),
                                              color: _statusColor(
                                                context,
                                                project.status,
                                              ),
                                            ),
                                            tooltip: 'Changer le statut',
                                          ),
                                          title: Text(project.name),
                                          subtitle: Text(project.status),
                                          onTap: () {
                                            setState(() {
                                              _selectedProjectId = project.id;
                                            });
                                          },
                                          trailing: IconButton(
                                            onPressed: () =>
                                                _openProjectEditor(project),
                                            icon: const Icon(
                                              Icons.chevron_right,
                                            ),
                                            tooltip: 'Éditer le projet',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (isSelected) const SizedBox(height: 8),
                                  if (isSelected)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextField(
                                            controller:
                                                _quickAddProjectTaskController,
                                            textInputAction:
                                                TextInputAction.done,
                                            onSubmitted: (_) =>
                                                _addTaskToSelectedProjectFromPrompt(),
                                            decoration: InputDecoration(
                                              hintText:
                                                  'Entrer le nom de la nouvelle tâche du projet…',
                                              suffixIcon: IconButton(
                                                onPressed:
                                                    _addTaskToSelectedProjectFromPrompt,
                                                icon: const Icon(Icons.add),
                                                tooltip: 'Ajouter',
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          if (projectTasks.isEmpty)
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                'Aucune tâche dans ce projet.',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodyLarge,
                                              ),
                                            )
                                          else
                                            ReorderableListView.builder(
                                              shrinkWrap: true,
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              buildDefaultDragHandles: false,
                                              itemCount: projectTasks.length,
                                              onReorder: (oldIndex, newIndex) {
                                                _reorderProjectTasks(
                                                  project,
                                                  oldIndex,
                                                  newIndex,
                                                );
                                              },
                                              itemBuilder: (context, taskIndex) {
                                                final task =
                                                    projectTasks[taskIndex];
                                                return Padding(
                                                  key: ObjectKey(task),
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 10,
                                                      ),
                                                  child: MouseRegion(
                                                    cursor:
                                                        SystemMouseCursors.grab,
                                                    child:
                                                        _buildPlatformDragListener(
                                                          index: taskIndex,
                                                          child: _buildTaskTile(
                                                            task,
                                                          ),
                                                        ),
                                                  ),
                                                );
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    TextField(
                      controller: _quickAddProjectController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addProjectFromPrompt(),
                      decoration: InputDecoration(
                        hintText: 'Entrer le nom du nouveau projet…',
                        suffixIcon: IconButton(
                          onPressed: _addProjectFromPrompt,
                          icon: const Icon(Icons.add),
                          tooltip: 'Ajouter',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: _projects.isEmpty
                          ? Center(
                              child: Text(
                                'Aucun projet.',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            )
                          : ReorderableListView.builder(
                              itemCount: _projects.length,
                              onReorder: _reorderProjects,
                              buildDefaultDragHandles: false,
                              itemBuilder: (context, index) {
                                final project = _projects[index];
                                return Padding(
                                  key: ValueKey(
                                    'desktop-project-${project.id}',
                                  ),
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.grab,
                                    child: _buildPlatformDragListener(
                                      index: index,
                                      child: Material(
                                        color: project.color.color,
                                        borderRadius: BorderRadius.circular(14),
                                        child: ListTile(
                                          selected:
                                              _selectedProjectId == project.id,
                                          leading: IconButton(
                                            onPressed: () =>
                                                _cycleProjectStatus(project),
                                            icon: Icon(
                                              _statusIcon(project.status),
                                              color: _statusColor(
                                                context,
                                                project.status,
                                              ),
                                            ),
                                            tooltip: 'Changer le statut',
                                          ),
                                          title: Text(project.name),
                                          subtitle: Text(project.status),
                                          onTap: () {
                                            setState(() {
                                              _selectedProjectId = project.id;
                                            });
                                          },
                                          trailing: IconButton(
                                            onPressed: () =>
                                                _openProjectEditor(project),
                                            icon: const Icon(
                                              Icons.chevron_right,
                                            ),
                                            tooltip: 'Éditer le projet',
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
              const SizedBox(width: 16),
              Expanded(
                flex: 6,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: selectedProject == null
                      ? Center(
                          child: Text(
                            'Sélectionne un projet pour voir ses tâches.',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedProject.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _quickAddProjectTaskController,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) =>
                                  _addTaskToSelectedProjectFromPrompt(),
                              decoration: InputDecoration(
                                hintText:
                                    'Entrer le nom de la nouvelle tâche du projet…',
                                suffixIcon: IconButton(
                                  onPressed:
                                      _addTaskToSelectedProjectFromPrompt,
                                  icon: const Icon(Icons.add),
                                  tooltip: 'Ajouter',
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: tasks.isEmpty
                                  ? Center(
                                      child: Text(
                                        'Aucune tâche dans ce projet.',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyLarge,
                                      ),
                                    )
                                  : ReorderableListView.builder(
                                      itemCount: tasks.length,
                                      onReorder: (oldIndex, newIndex) {
                                        _reorderProjectTasks(
                                          selectedProject,
                                          oldIndex,
                                          newIndex,
                                        );
                                      },
                                      buildDefaultDragHandles: false,
                                      itemBuilder: (context, index) {
                                        final task = tasks[index];
                                        return Padding(
                                          key: ObjectKey(task),
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: MouseRegion(
                                            cursor: SystemMouseCursors.grab,
                                            child: _buildPlatformDragListener(
                                              index: index,
                                              child: _buildTaskTile(task),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: false, title: _buildViewSwitcher()),
      body: _currentView == MainView.today
          ? _buildTodayView()
          : _buildProjectsView(),
    );
  }
}
