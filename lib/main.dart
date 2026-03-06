import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

enum MainView { today, planning, projects }

enum PlanningScope { day, week, month }

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
    DateTime? endDate,
    this.allDay = false,
    this.startTime,
    this.endTime,
    this.duration = '',
    this.reminder = 'Aucun',
    this.recurrence = 'Aucune',
    this.status = 'À faire',
    this.contact = '',
    this.project = '',
    this.projectId,
    this.color = TaskColorOption.bleu,
  }) : endDate = endDate ?? date;

  String name;
  DateTime date;
  DateTime endDate;
  bool allDay;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String duration;
  String reminder;
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
      'endDate': endDate.toIso8601String(),
      'allDay': allDay,
      'startTime': _timeToMinutes(startTime),
      'endTime': _timeToMinutes(endTime),
      'duration': duration,
      'reminder': reminder,
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
      endDate:
          DateTime.tryParse((json['endDate'] as String?) ?? '') ??
          DateTime.tryParse((json['date'] as String?) ?? '') ??
          DateTime.now(),
      allDay: (json['allDay'] as bool?) ?? false,
      startTime: _minutesToTime(json['startTime'] as int?),
      endTime: _minutesToTime(json['endTime'] as int?),
      duration: (json['duration'] as String?) ?? '',
      reminder: (json['reminder'] as String?) ?? 'Aucun',
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

class _ReminderNotice {
  _ReminderNotice({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String title;
  final String subtitle;
}

class _PlanningTaskLayout {
  _PlanningTaskLayout({
    required this.task,
    required this.startMinutes,
    required this.endMinutes,
    required this.column,
    required this.totalColumns,
    this.columnSpan = 1,
  });

  final TaskItem task;
  final int startMinutes;
  final int endMinutes;
  final int column;
  int totalColumns;
  int columnSpan;
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
  Timer? _clockTimer;
  DateTime _liveNow = DateTime.now();
  final Map<String, _ReminderNotice> _activeReminders =
      <String, _ReminderNotice>{};
  final Set<String> _dismissedReminderIds = <String>{};

  MainView _currentView = MainView.today;
  PlanningScope _planningScope = PlanningScope.day;
  DateTime _planningAnchorDate = DateTime.now();
  String? _selectedProjectId;

  @override
  void initState() {
    super.initState();
    _refreshLiveNowAndReminders();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshLiveNowAndReminders(),
    );
    _loadData();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _quickAddTaskController.dispose();
    _quickAddProjectController.dispose();
    _quickAddProjectTaskController.dispose();
    super.dispose();
  }

  DateTime get _todayOnly {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  Duration? _reminderOffset(String reminder) {
    switch (reminder) {
      case '1 jour avant':
        return const Duration(days: 1);
      case '1h avant':
        return const Duration(hours: 1);
      case '10 min avant':
        return const Duration(minutes: 10);
      default:
        return null;
    }
  }

  DateTime _withTime(DateTime day, TimeOfDay time) {
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }

  String _reminderId(TaskItem task, DateTime occurrenceDate) {
    final start = task.startTime;
    final startLabel = start == null ? 'none' : '${start.hour}:${start.minute}';
    return '${task.name}|${task.date.toIso8601String()}|${task.endDate.toIso8601String()}|$startLabel|${occurrenceDate.toIso8601String()}|${task.reminder}';
  }

  void _refreshLiveNowAndReminders() {
    if (!mounted) {
      return;
    }

    final now = DateTime.now();
    final today = _dateOnly(now);
    final tomorrow = today.add(const Duration(days: 1));
    final newNotices = <_ReminderNotice>[];

    for (final task in _tasks) {
      if (task.reminder == 'Aucun' || task.startTime == null) {
        continue;
      }

      final offset = _reminderOffset(task.reminder);
      if (offset == null) {
        continue;
      }

      for (final occurrenceDate in [today, tomorrow]) {
        if (!_taskOccursOnDate(task, occurrenceDate)) {
          continue;
        }

        final startDateTime = _withTime(occurrenceDate, task.startTime!);
        final triggerDateTime = startDateTime.subtract(offset);
        final reminderId = _reminderId(task, occurrenceDate);
        if (_dismissedReminderIds.contains(reminderId) ||
            _activeReminders.containsKey(reminderId) ||
            newNotices.any((notice) => notice.id == reminderId)) {
          continue;
        }

        if (!now.isBefore(triggerDateTime) && !now.isAfter(startDateTime)) {
          newNotices.add(
            _ReminderNotice(
              id: reminderId,
              title: task.name,
              subtitle:
                  'Rappel ${task.reminder} • ${_twoDigits(occurrenceDate.day)}/${_twoDigits(occurrenceDate.month)} ${_twoDigits(task.startTime!.hour)}:${_twoDigits(task.startTime!.minute)}',
            ),
          );
        }
      }
    }

    setState(() {
      _liveNow = now;

      for (final notice in newNotices) {
        _activeReminders[notice.id] = notice;
      }
    });

    if (newNotices.isNotEmpty) {
      SystemSound.play(SystemSoundType.alert);
    }
  }

  void _dismissReminder(String reminderId) {
    setState(() {
      _activeReminders.remove(reminderId);
      _dismissedReminderIds.add(reminderId);
    });
  }

  int? _weekdayFromFrenchLabel(String label) {
    switch (label) {
      case 'Lundi':
        return DateTime.monday;
      case 'Mardi':
        return DateTime.tuesday;
      case 'Mercredi':
        return DateTime.wednesday;
      case 'Jeudi':
        return DateTime.thursday;
      case 'Vendredi':
        return DateTime.friday;
      case 'Samedi':
        return DateTime.saturday;
      case 'Dimanche':
        return DateTime.sunday;
      default:
        return null;
    }
  }

  bool _taskOccursOnDate(TaskItem task, DateTime date) {
    final day = _dateOnly(date);
    final taskDate = _dateOnly(task.date);
    final taskEndDate = _dateOnly(task.endDate);
    if (day.isBefore(taskDate)) {
      return false;
    }
    if (day.isAfter(taskEndDate)) {
      return false;
    }

    switch (task.recurrence) {
      case 'Aucune':
        return !day.isBefore(taskDate) && !day.isAfter(taskEndDate);
      case 'Quotidienne':
        return !day.isBefore(taskDate) && !day.isAfter(taskEndDate);
      case 'Mensuelle':
        return !day.isBefore(taskDate) &&
            !day.isAfter(taskEndDate) &&
            day.day == taskDate.day;
      case 'Hebdomadaire':
        return !day.isBefore(taskDate) &&
            !day.isAfter(taskEndDate) &&
            day.weekday == taskDate.weekday;
      default:
        if (task.recurrence.startsWith('Jours:')) {
          final rawDays = task.recurrence
              .substring('Jours:'.length)
              .split(',')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList();
          final weekdays = rawDays
              .map(_weekdayFromFrenchLabel)
              .whereType<int>()
              .toSet();
          return !day.isBefore(taskDate) &&
              !day.isAfter(taskEndDate) &&
              weekdays.contains(day.weekday);
        }
        return _isSameDay(taskDate, day);
    }
  }

  List<TaskItem> _tasksForDate(DateTime date, {bool timedOnly = false}) {
    final entries = _tasks.where((task) {
      if (!_taskOccursOnDate(task, date)) {
        return false;
      }
      if (!timedOnly) {
        return true;
      }
      return task.startTime != null && task.endTime != null;
    }).toList();

    entries.sort((a, b) {
      final aMinutes =
          (a.startTime?.hour ?? 23) * 60 + (a.startTime?.minute ?? 59);
      final bMinutes =
          (b.startTime?.hour ?? 23) * 60 + (b.startTime?.minute ?? 59);
      return aMinutes.compareTo(bMinutes);
    });
    return entries;
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = _dateOnly(date);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  List<DateTime> _weekDays(DateTime date) {
    final start = _startOfWeek(date);
    return List<DateTime>.generate(
      7,
      (index) => start.add(Duration(days: index)),
    );
  }

  List<DateTime> _monthGridDays(DateTime monthDate) {
    final firstDay = DateTime(monthDate.year, monthDate.month, 1);
    final start = _startOfWeek(firstDay);
    final lastDay = DateTime(monthDate.year, monthDate.month + 1, 0);
    final end = _startOfWeek(lastDay).add(const Duration(days: 6));
    final totalDays = end.difference(start).inDays + 1;
    return List<DateTime>.generate(
      totalDays,
      (index) => start.add(Duration(days: index)),
    );
  }

  String _dayLabel(DateTime date) {
    const labels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return labels[date.weekday - 1];
  }

  String _monthLabel(DateTime date) {
    const months = [
      'Janvier',
      'Fevrier',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Aout',
      'Septembre',
      'Octobre',
      'Novembre',
      'Decembre',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  String _timeRangeLabel(TaskItem task) {
    if (task.startTime == null || task.endTime == null) {
      return 'Sans horaire';
    }
    return '${_twoDigits(task.startTime!.hour)}:${_twoDigits(task.startTime!.minute)} - ${_twoDigits(task.endTime!.hour)}:${_twoDigits(task.endTime!.minute)}';
  }

  Future<void> _openNewTaskForDate(DateTime date) async {
    final newTask = TaskItem(name: 'Nouvelle tache', date: _dateOnly(date));
    await _openTaskEditor(newTask, isNew: true);
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

  ProjectItem? _projectForTask(TaskItem task) {
    if (task.projectId != null) {
      final byId = _projects.where((project) => project.id == task.projectId);
      if (byId.isNotEmpty) {
        return byId.first;
      }
    }
    if (task.project.isNotEmpty) {
      final byName = _projects.where((project) => project.name == task.project);
      if (byName.isNotEmpty) {
        return byName.first;
      }
    }
    return null;
  }

  Color _taskDisplayColor(TaskItem task) {
    final linkedProject = _projectForTask(task);
    return linkedProject?.color.color ?? task.color.color;
  }

  TaskColorOption _taskColorFromProjectColor(ProjectColorOption projectColor) {
    return TaskColorOption.values.firstWhere(
      (taskColor) => taskColor.color.value == projectColor.color.value,
      orElse: () => TaskColorOption.gris,
    );
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
      color: _taskColorFromProjectColor(selectedProject.color),
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

      final linkedProject = loadedProjects.where(
        (project) =>
            project.id == task.projectId ||
            (task.projectId == null && project.name == task.project),
      );
      if (linkedProject.isNotEmpty) {
        task.color = _taskColorFromProjectColor(linkedProject.first.color);
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
    _refreshLiveNowAndReminders();
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = _tasks.map((task) => task.toJson()).toList();
    await prefs.setString(_tasksStorageKey, jsonEncode(payload));
    _refreshLiveNowAndReminders();
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

    DateTime selectedDate = task.date;
    DateTime selectedEndDate = task.endDate;
    if (selectedEndDate.isBefore(selectedDate)) {
      selectedEndDate = selectedDate;
    }
    bool allDay = task.allDay;
    TimeOfDay? startTime = task.startTime;
    TimeOfDay? endTime = task.endTime;
    String reminder = task.reminder;
    String recurrence = task.recurrence;
    String status = task.status;
    const weekdays = <String>[
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];

    String recurrenceMode = 'Aucune';
    final selectedWeekdays = <String>{};

    if (recurrence == 'Quotidienne' ||
        recurrence == 'Mensuelle' ||
        recurrence == 'Aucune') {
      recurrenceMode = recurrence;
    } else if (recurrence == 'Hebdomadaire') {
      recurrenceMode = 'Jours de la semaine';
      selectedWeekdays.add(weekdays[selectedDate.weekday - 1]);
    } else if (recurrence.startsWith('Jours:')) {
      recurrenceMode = 'Jours de la semaine';
      final rawDays = recurrence
          .substring('Jours:'.length)
          .split(',')
          .map((day) => day.trim())
          .where((day) => day.isNotEmpty);
      selectedWeekdays.addAll(rawDays.where((day) => weekdays.contains(day)));
    }

    String selectedProjectId = task.projectId ?? '';
    if (selectedProjectId.isEmpty && task.project.isNotEmpty) {
      final linked = _projects.where((project) => project.name == task.project);
      if (linked.isNotEmpty) {
        selectedProjectId = linked.first.id;
      }
    }

    String timeLabel(TimeOfDay? value) {
      if (value == null) {
        return '--:--';
      }
      return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    }

    int toMinutes(TimeOfDay value) {
      return value.hour * 60 + value.minute;
    }

    TimeOfDay fromMinutes(int value) {
      var normalized = value % (24 * 60);
      if (normalized < 0) {
        normalized += 24 * 60;
      }
      return TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60);
    }

    String formatDuration(int minutes) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
    }

    int? parseDurationMinutes(String raw) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return null;
      }

      final hhmm = RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(trimmed);
      if (hhmm != null) {
        final h = int.tryParse(hhmm.group(1)!);
        final m = int.tryParse(hhmm.group(2)!);
        if (h != null && m != null && m >= 0 && m < 60) {
          return h * 60 + m;
        }
      }

      final hOnly = RegExp(r'^(\d+)\s*h$').firstMatch(trimmed);
      if (hOnly != null) {
        final h = int.tryParse(hOnly.group(1)!);
        if (h != null) {
          return h * 60;
        }
      }

      final hm = RegExp(r'^(\d+)\s*h\s*(\d{1,2})\s*m?$').firstMatch(trimmed);
      if (hm != null) {
        final h = int.tryParse(hm.group(1)!);
        final m = int.tryParse(hm.group(2)!);
        if (h != null && m != null && m >= 0 && m < 60) {
          return h * 60 + m;
        }
      }

      final minutesOnly = int.tryParse(trimmed);
      return minutesOnly;
    }

    if (durationController.text.trim().isEmpty &&
        startTime != null &&
        endTime != null) {
      final diff = toMinutes(endTime) - toMinutes(startTime);
      if (diff > 0) {
        durationController.text = formatDuration(diff);
      }
    }

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        Offset dialogOffset = Offset.zero;

        return StatefulBuilder(
          builder: (context, setModalState) {
            var isInternalDurationUpdate = false;

            void showValidationMessage(String message) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(message)));
            }

            void syncDurationFromTimes() {
              if (startTime == null || endTime == null) {
                return;
              }
              final diff = toMinutes(endTime!) - toMinutes(startTime!);
              if (diff <= 0) {
                return;
              }
              isInternalDurationUpdate = true;
              durationController.text = formatDuration(diff);
              isInternalDurationUpdate = false;
            }

            void syncMissingTimeFromDuration() {
              final durationMinutes = parseDurationMinutes(
                durationController.text,
              );
              if (durationMinutes == null || durationMinutes <= 0) {
                return;
              }

              if (startTime != null && endTime == null) {
                endTime = fromMinutes(toMinutes(startTime!) + durationMinutes);
              } else if (startTime == null && endTime != null) {
                startTime = fromMinutes(toMinutes(endTime!) - durationMinutes);
              }
            }

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
                  if (selectedEndDate.isBefore(selectedDate)) {
                    selectedEndDate = selectedDate;
                  }
                });
              }
            }

            Future<void> pickEndDate() async {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: selectedEndDate,
                firstDate: selectedDate,
                lastDate: DateTime(2100),
              );
              if (pickedDate != null) {
                setModalState(() {
                  selectedEndDate = pickedDate;
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
                  endTime = fromMinutes(toMinutes(picked) + 60);
                  syncDurationFromTimes();
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
                  syncMissingTimeFromDuration();
                  syncDurationFromTimes();
                });
              }
            }

            const recurrenceOptions = <String>{
              'Aucune',
              'Quotidienne',
              'Jours de la semaine',
              'Mensuelle',
            };
            const reminderOptions = <String>{
              'Aucun',
              '1 jour avant',
              '1h avant',
              '10 min avant',
            };
            const statusOptions = <String>{'À faire', 'En cours', 'Terminé'};
            final effectiveReminder = reminderOptions.contains(reminder)
                ? reminder
                : 'Aucun';
            final effectiveRecurrenceMode =
                recurrenceOptions.contains(recurrenceMode)
                ? recurrenceMode
                : 'Aucune';
            final effectiveStatus = statusOptions.contains(status)
                ? status
                : 'À faire';
            final effectiveSelectedProjectId =
                selectedProjectId.isEmpty ||
                    _projects.any((project) => project.id == selectedProjectId)
                ? selectedProjectId
                : '';

            return Material(
              type: MaterialType.transparency,
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final dialogWidth = constraints.maxWidth > 980
                        ? 920.0
                        : constraints.maxWidth - 24;
                    final dialogHeight = constraints.maxHeight <= 360
                        ? constraints.maxHeight - 16
                        : (constraints.maxHeight * 0.82).clamp(320.0, 720.0)
                              as double;

                    final centeredLeft =
                        (constraints.maxWidth - dialogWidth) / 2;
                    final centeredTop =
                        (constraints.maxHeight - dialogHeight) / 2;
                    final minLeft = 8.0;
                    final maxLeftRaw = constraints.maxWidth - dialogWidth - 8;
                    final maxLeft = maxLeftRaw < minLeft ? minLeft : maxLeftRaw;
                    final minTop = 8.0;
                    final maxTopRaw = constraints.maxHeight - dialogHeight - 8;
                    final maxTop = maxTopRaw < minTop ? minTop : maxTopRaw;

                    final left =
                        (centeredLeft + dialogOffset.dx).clamp(minLeft, maxLeft)
                            as double;
                    final top =
                        (centeredTop + dialogOffset.dy).clamp(minTop, maxTop)
                            as double;

                    return Stack(
                      children: [
                        Positioned(
                          left: left,
                          top: top,
                          width: dialogWidth,
                          height: dialogHeight,
                          child: Material(
                            color: Theme.of(context).colorScheme.surface,
                            elevation: 16,
                            borderRadius: BorderRadius.circular(16),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                MouseRegion(
                                  cursor: SystemMouseCursors.move,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onPanUpdate: (details) {
                                      setModalState(() {
                                        dialogOffset += details.delta;
                                      });
                                    },
                                    child: Container(
                                      height: 20,
                                      alignment: Alignment.center,
                                      child: Container(
                                        width: 42,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: Colors.black26,
                                          borderRadius: BorderRadius.circular(
                                            99,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          TextField(
                                            controller: nameController,
                                            decoration: const InputDecoration(
                                              labelText: 'Nom',
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ListTile(
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  title: const Text(
                                                    'Date debut',
                                                  ),
                                                  subtitle: Text(
                                                    '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                                                  ),
                                                  trailing: const Icon(
                                                    Icons.calendar_month,
                                                  ),
                                                  onTap: pickDate,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: ListTile(
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  title: const Text('Date fin'),
                                                  subtitle: Text(
                                                    '${selectedEndDate.day.toString().padLeft(2, '0')}/${selectedEndDate.month.toString().padLeft(2, '0')}/${selectedEndDate.year}',
                                                  ),
                                                  trailing: const Icon(
                                                    Icons.event_available,
                                                  ),
                                                  onTap: pickEndDate,
                                                ),
                                              ),
                                              SizedBox(
                                                width: 145,
                                                child: CheckboxListTile(
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  value: allDay,
                                                  onChanged: (value) {
                                                    setModalState(() {
                                                      allDay = value ?? false;
                                                    });
                                                  },
                                                  title: const Text('All day'),
                                                  controlAffinity:
                                                      ListTileControlAffinity
                                                          .leading,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton(
                                                  onPressed: allDay
                                                      ? null
                                                      : pickStartTime,
                                                  child: Text(
                                                    'Heure début: ${timeLabel(startTime)}',
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: OutlinedButton(
                                                  onPressed: allDay
                                                      ? null
                                                      : pickEndTime,
                                                  child: Text(
                                                    'Heure fin: ${timeLabel(endTime)}',
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: TextField(
                                                  controller:
                                                      durationController,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: 'Durée',
                                                      ),
                                                  onChanged: (value) {
                                                    if (isInternalDurationUpdate ||
                                                        allDay) {
                                                      return;
                                                    }
                                                    setModalState(() {
                                                      syncMissingTimeFromDuration();
                                                      syncDurationFromTimes();
                                                    });
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          DropdownButtonFormField<String>(
                                            initialValue: effectiveReminder,
                                            decoration: const InputDecoration(
                                              labelText: 'Rappel',
                                            ),
                                            items: const [
                                              DropdownMenuItem(
                                                value: 'Aucun',
                                                child: Text('Aucun'),
                                              ),
                                              DropdownMenuItem(
                                                value: '1 jour avant',
                                                child: Text('1 jour avant'),
                                              ),
                                              DropdownMenuItem(
                                                value: '1h avant',
                                                child: Text('1h avant'),
                                              ),
                                              DropdownMenuItem(
                                                value: '10 min avant',
                                                child: Text('10 min avant'),
                                              ),
                                            ],
                                            onChanged: (value) {
                                              if (value != null) {
                                                setModalState(() {
                                                  reminder = value;
                                                });
                                              }
                                            },
                                          ),
                                          const SizedBox(height: 12),
                                          DropdownButtonFormField<String>(
                                            initialValue:
                                                effectiveRecurrenceMode,
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
                                                value: 'Jours de la semaine',
                                                child: Text(
                                                  'Jours de la semaine',
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'Mensuelle',
                                                child: Text('Mensuelle'),
                                              ),
                                            ],
                                            onChanged: (value) {
                                              if (value != null) {
                                                setModalState(() {
                                                  recurrenceMode = value;
                                                  if (value !=
                                                      'Jours de la semaine') {
                                                    selectedWeekdays.clear();
                                                  }
                                                });
                                              }
                                            },
                                          ),
                                          if (effectiveRecurrenceMode ==
                                              'Jours de la semaine') ...[
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: weekdays.map((day) {
                                                final isSelected =
                                                    selectedWeekdays.contains(
                                                      day,
                                                    );
                                                return FilterChip(
                                                  label: Text(day),
                                                  selected: isSelected,
                                                  onSelected: (selected) {
                                                    setModalState(() {
                                                      if (selected) {
                                                        selectedWeekdays.add(
                                                          day,
                                                        );
                                                      } else {
                                                        selectedWeekdays.remove(
                                                          day,
                                                        );
                                                      }
                                                    });
                                                  },
                                                );
                                              }).toList(),
                                            ),
                                          ],
                                          const SizedBox(height: 12),
                                          DropdownButtonFormField<String>(
                                            initialValue: effectiveStatus,
                                            decoration: const InputDecoration(
                                              labelText: 'Statut',
                                            ),
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
                                            decoration: const InputDecoration(
                                              labelText: 'Contact',
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          DropdownButtonFormField<String>(
                                            initialValue:
                                                effectiveSelectedProjectId,
                                            decoration: const InputDecoration(
                                              labelText: 'Projet',
                                            ),
                                            items: [
                                              const DropdownMenuItem(
                                                value: '',
                                                child: Text('Aucun'),
                                              ),
                                              ..._projects.map(
                                                (project) => DropdownMenuItem(
                                                  value: project.id,
                                                  child: Text(project.name),
                                                ),
                                              ),
                                            ],
                                            onChanged: (value) {
                                              if (value != null) {
                                                setModalState(() {
                                                  selectedProjectId = value;
                                                });
                                              }
                                            },
                                          ),
                                          const SizedBox(height: 12),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    10,
                                    16,
                                    12,
                                  ),
                                  child: Row(
                                    children: [
                                      if (!isNew)
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () {
                                              setState(() {
                                                _tasks.remove(task);
                                              });
                                              _saveTasks();
                                              Navigator.of(context).pop();
                                            },
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                            label: const Text('Supprimer'),
                                          ),
                                        ),
                                      if (!isNew) const SizedBox(width: 10),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: const Text('Annuler'),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        flex: 2,
                                        child: FilledButton(
                                          onPressed: () {
                                            if (!allDay) {
                                              syncMissingTimeFromDuration();
                                              syncDurationFromTimes();

                                              final durationRaw =
                                                  durationController.text
                                                      .trim();
                                              final durationMinutes =
                                                  parseDurationMinutes(
                                                    durationRaw,
                                                  );
                                              if (durationRaw.isNotEmpty &&
                                                  (durationMinutes == null ||
                                                      durationMinutes <= 0)) {
                                                showValidationMessage(
                                                  'La durée doit être positive (ex: 01:30).',
                                                );
                                                return;
                                              }

                                              if (startTime != null &&
                                                  endTime != null) {
                                                final startMinutes = toMinutes(
                                                  startTime!,
                                                );
                                                final endMinutes = toMinutes(
                                                  endTime!,
                                                );
                                                if (endMinutes <=
                                                    startMinutes) {
                                                  showValidationMessage(
                                                    'Heure fin doit être après heure début.',
                                                  );
                                                  return;
                                                }
                                              }
                                            }

                                            setState(() {
                                              if (isNew) {
                                                _tasks.insert(0, task);
                                              }

                                              task.name =
                                                  nameController.text
                                                      .trim()
                                                      .isEmpty
                                                  ? task.name
                                                  : nameController.text.trim();
                                              task.date = selectedDate;
                                              task.endDate =
                                                  selectedEndDate.isBefore(
                                                    selectedDate,
                                                  )
                                                  ? selectedDate
                                                  : selectedEndDate;
                                              task.allDay = allDay;
                                              task.startTime = allDay
                                                  ? null
                                                  : startTime;
                                              task.endTime = allDay
                                                  ? null
                                                  : endTime;
                                              task.duration = durationController
                                                  .text
                                                  .trim();
                                              task.reminder = reminder;
                                              if (recurrenceMode ==
                                                  'Jours de la semaine') {
                                                final orderedDays = weekdays
                                                    .where(
                                                      (day) => selectedWeekdays
                                                          .contains(day),
                                                    );
                                                recurrence = orderedDays.isEmpty
                                                    ? 'Aucune'
                                                    : 'Jours:${orderedDays.join(',')}';
                                              } else {
                                                recurrence = recurrenceMode;
                                              }
                                              task.recurrence = recurrence;
                                              task.status = status;
                                              task.contact = contactController
                                                  .text
                                                  .trim();
                                              final linked = _projects.where(
                                                (project) =>
                                                    project.id ==
                                                    selectedProjectId,
                                              );
                                              if (linked.isEmpty) {
                                                task.project = '';
                                                task.projectId = null;
                                              } else {
                                                task.project =
                                                    linked.first.name;
                                                task.projectId =
                                                    linked.first.id;
                                                task.color =
                                                    _taskColorFromProjectColor(
                                                      linked.first.color,
                                                    );
                                              }
                                            });
                                            _saveTasks();
                                            Navigator.of(context).pop();
                                          },
                                          child: const Text('Enregistrer'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
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

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        Offset dialogOffset = Offset.zero;

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

            const statusOptions = <String>{'À faire', 'En cours', 'Terminé'};
            final effectiveStatus = statusOptions.contains(status)
                ? status
                : 'À faire';

            return Material(
              type: MaterialType.transparency,
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final dialogWidth = constraints.maxWidth > 980
                        ? 920.0
                        : constraints.maxWidth - 24;
                    final dialogHeight = constraints.maxHeight <= 360
                        ? constraints.maxHeight - 16
                        : (constraints.maxHeight * 0.82).clamp(320.0, 720.0)
                              as double;

                    final centeredLeft =
                        (constraints.maxWidth - dialogWidth) / 2;
                    final centeredTop =
                        (constraints.maxHeight - dialogHeight) / 2;
                    final minLeft = 8.0;
                    final maxLeftRaw = constraints.maxWidth - dialogWidth - 8;
                    final maxLeft = maxLeftRaw < minLeft ? minLeft : maxLeftRaw;
                    final minTop = 8.0;
                    final maxTopRaw = constraints.maxHeight - dialogHeight - 8;
                    final maxTop = maxTopRaw < minTop ? minTop : maxTopRaw;

                    final left =
                        (centeredLeft + dialogOffset.dx).clamp(minLeft, maxLeft)
                            as double;
                    final top =
                        (centeredTop + dialogOffset.dy).clamp(minTop, maxTop)
                            as double;

                    return Stack(
                      children: [
                        Positioned(
                          left: left,
                          top: top,
                          width: dialogWidth,
                          height: dialogHeight,
                          child: Material(
                            color: Theme.of(context).colorScheme.surface,
                            elevation: 16,
                            borderRadius: BorderRadius.circular(16),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                MouseRegion(
                                  cursor: SystemMouseCursors.move,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onPanUpdate: (details) {
                                      setModalState(() {
                                        dialogOffset += details.delta;
                                      });
                                    },
                                    child: Container(
                                      height: 20,
                                      alignment: Alignment.center,
                                      child: Container(
                                        width: 42,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: Colors.black26,
                                          borderRadius: BorderRadius.circular(
                                            99,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Édition du projet',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleLarge,
                                          ),
                                          const SizedBox(height: 16),
                                          TextField(
                                            controller: nameController,
                                            decoration: const InputDecoration(
                                              labelText: 'Nom',
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            title: const Text('Date de début'),
                                            subtitle: Text(
                                              formatDate(startDate),
                                            ),
                                            trailing: const Icon(
                                              Icons.calendar_month,
                                            ),
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
                                            trailing: const Icon(
                                              Icons.event_available,
                                            ),
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
                                            initialValue: effectiveStatus,
                                            decoration: const InputDecoration(
                                              labelText: 'Statut',
                                            ),
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
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: ProjectColorOption.values
                                                .map((colorOption) {
                                                  return ChoiceChip(
                                                    label: Text(
                                                      colorOption.label,
                                                    ),
                                                    selected:
                                                        selectedColor ==
                                                        colorOption,
                                                    selectedColor:
                                                        colorOption.color,
                                                    onSelected: (_) {
                                                      setModalState(() {
                                                        selectedColor =
                                                            colorOption;
                                                      });
                                                    },
                                                  );
                                                })
                                                .toList(),
                                          ),
                                          const SizedBox(height: 18),
                                          SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton.icon(
                                              onPressed: () async {
                                                final projectName =
                                                    nameController.text
                                                        .trim()
                                                        .isEmpty
                                                    ? project.name
                                                    : nameController.text
                                                          .trim();
                                                final newTask = TaskItem(
                                                  name: 'Nouvelle tâche',
                                                  date: _todayOnly,
                                                  project: projectName,
                                                  projectId: project.id,
                                                  color:
                                                      _taskColorFromProjectColor(
                                                        selectedColor,
                                                      ),
                                                );
                                                await _openTaskEditor(
                                                  newTask,
                                                  isNew: true,
                                                );
                                              },
                                              icon: const Icon(Icons.add_task),
                                              label: const Text(
                                                'Ajouter une tâche',
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    10,
                                    16,
                                    12,
                                  ),
                                  child: Row(
                                    children: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: const Text('Annuler'),
                                      ),
                                      const SizedBox(width: 6),
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _projects.removeWhere(
                                              (item) => item.id == project.id,
                                            );
                                            if (_selectedProjectId ==
                                                project.id) {
                                              _selectedProjectId =
                                                  _projects.isEmpty
                                                  ? null
                                                  : _projects.first.id;
                                            }
                                            for (final task in _tasks) {
                                              if (task.projectId ==
                                                  project.id) {
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
                                                nameController.text
                                                    .trim()
                                                    .isEmpty
                                                ? project.name
                                                : nameController.text.trim();

                                            setState(() {
                                              project.name = nextName;
                                              project.startDate = startDate;
                                              project.endDate = endDate;
                                              project.description =
                                                  descriptionController.text
                                                      .trim();
                                              project.status = status;
                                              project.color = selectedColor;

                                              for (final task in _tasks) {
                                                if (task.projectId ==
                                                    project.id) {
                                                  task.project = project.name;
                                                  task.color =
                                                      _taskColorFromProjectColor(
                                                        project.color,
                                                      );
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
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
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
        buildButton(label: 'Planning', view: MainView.planning),
        const SizedBox(width: 8),
        buildButton(label: 'Projets', view: MainView.projects),
      ],
    );
  }

  Widget _buildTaskTile(TaskItem task) {
    return Material(
      color: _taskDisplayColor(task),
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

  Widget _buildPlanningModeSelector() {
    Widget scopeButton({
      required String label,
      required PlanningScope scope,
      required VoidCallback onPressed,
    }) {
      final isSelected = _planningScope == scope;
      if (isSelected) {
        return FilledButton(onPressed: onPressed, child: Text(label));
      }
      return OutlinedButton(onPressed: onPressed, child: Text(label));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        scopeButton(
          label: 'Aujourd\'hui',
          scope: PlanningScope.day,
          onPressed: () {
            setState(() {
              _planningScope = PlanningScope.day;
              _planningAnchorDate = _todayOnly;
            });
          },
        ),
        scopeButton(
          label: 'Semaine',
          scope: PlanningScope.week,
          onPressed: () {
            setState(() {
              _planningScope = PlanningScope.week;
            });
          },
        ),
        scopeButton(
          label: 'Mois',
          scope: PlanningScope.month,
          onPressed: () {
            setState(() {
              _planningScope = PlanningScope.month;
            });
          },
        ),
      ],
    );
  }

  Widget _buildPlanningDayView(DateTime date) {
    final day = _dateOnly(date);
    final isTodayView = _isSameDay(day, _todayOnly);
    final timedTasks = _tasksForDate(day, timedOnly: true)
      ..removeWhere((task) {
        if (task.startTime == null || task.endTime == null) {
          return true;
        }
        final start = task.startTime!.hour * 60 + task.startTime!.minute;
        final end = task.endTime!.hour * 60 + task.endTime!.minute;
        return end <= start;
      });

    final timedLayouts = <_PlanningTaskLayout>[];
    if (timedTasks.isNotEmpty) {
      final sorted = List<TaskItem>.from(timedTasks)
        ..sort((a, b) {
          final aStart = a.startTime!.hour * 60 + a.startTime!.minute;
          final bStart = b.startTime!.hour * 60 + b.startTime!.minute;
          if (aStart != bStart) {
            return aStart.compareTo(bStart);
          }
          final aEnd = a.endTime!.hour * 60 + a.endTime!.minute;
          final bEnd = b.endTime!.hour * 60 + b.endTime!.minute;
          return aEnd.compareTo(bEnd);
        });

      final clusters = <List<TaskItem>>[];
      var currentCluster = <TaskItem>[];
      var clusterEnd = -1;

      for (final task in sorted) {
        final taskStart = task.startTime!.hour * 60 + task.startTime!.minute;
        final taskEnd = task.endTime!.hour * 60 + task.endTime!.minute;

        if (currentCluster.isEmpty || taskStart < clusterEnd) {
          currentCluster.add(task);
          if (taskEnd > clusterEnd) {
            clusterEnd = taskEnd;
          }
        } else {
          clusters.add(List<TaskItem>.from(currentCluster));
          currentCluster = [task];
          clusterEnd = taskEnd;
        }
      }
      if (currentCluster.isNotEmpty) {
        clusters.add(currentCluster);
      }

      for (final cluster in clusters) {
        final active = <_PlanningTaskLayout>[];
        final clusterLayouts = <_PlanningTaskLayout>[];
        var maxColumns = 1;

        for (final task in cluster) {
          final start = task.startTime!.hour * 60 + task.startTime!.minute;
          final end = task.endTime!.hour * 60 + task.endTime!.minute;
          active.removeWhere((entry) => entry.endMinutes <= start);

          final usedColumns = active.map((entry) => entry.column).toSet();
          var nextColumn = 0;
          while (usedColumns.contains(nextColumn)) {
            nextColumn += 1;
          }

          final layout = _PlanningTaskLayout(
            task: task,
            startMinutes: start,
            endMinutes: end,
            column: nextColumn,
            totalColumns: 1,
          );
          active.add(layout);
          clusterLayouts.add(layout);

          if (nextColumn + 1 > maxColumns) {
            maxColumns = nextColumn + 1;
          }
        }

        bool overlaps(_PlanningTaskLayout a, _PlanningTaskLayout b) {
          return a.startMinutes < b.endMinutes && a.endMinutes > b.startMinutes;
        }

        for (final layout in clusterLayouts) {
          layout.totalColumns = maxColumns;
          var span = 1;
          for (
            var nextColumn = layout.column + 1;
            nextColumn < maxColumns;
            nextColumn++
          ) {
            final blocked = clusterLayouts.any(
              (other) => other.column == nextColumn && overlaps(layout, other),
            );
            if (blocked) {
              break;
            }
            span += 1;
          }
          layout.columnSpan = span;
        }
        timedLayouts.addAll(clusterLayouts);
      }
    }

    final unscheduled = _tasksForDate(
      day,
    ).where((task) => task.startTime == null || task.endTime == null).toList();

    final firstStart = timedTasks.isEmpty
        ? 8 * 60
        : timedTasks
                  .map(
                    (task) =>
                        task.startTime!.hour * 60 + task.startTime!.minute,
                  )
                  .reduce((a, b) => a < b ? a : b) -
              30;
    final lastEnd = timedTasks.isEmpty
        ? 18 * 60
        : timedTasks
                  .map((task) => task.endTime!.hour * 60 + task.endTime!.minute)
                  .reduce((a, b) => a > b ? a : b) +
              30;

    final minMinutes = firstStart.clamp(0, 23 * 60);
    final maxMinutes = lastEnd.clamp(minMinutes + 60, 24 * 60);

    final startHour = minMinutes ~/ 60;
    final endHour = (maxMinutes / 60).ceil();
    const hourHeight = 72.0;
    final totalHeight = (endHour - startHour) * hourHeight;
    final nowMinutes = _liveNow.hour * 60 + _liveNow.minute;
    final showsNowIndicator =
        isTodayView && nowMinutes >= minMinutes && nowMinutes <= maxMinutes;
    final nowTop = ((nowMinutes / 60) - startHour) * hourHeight;

    return Expanded(
      child: timedTasks.isEmpty && unscheduled.isEmpty
          ? Center(
              child: Text(
                'Aucune tache planifiee pour cette journee.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (timedTasks.isNotEmpty)
                    Container(
                      height: totalHeight,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          const gutterLeft = 70.0;
                          const gutterRight = 10.0;
                          const taskGap = 4.0;
                          final laneWidth =
                              constraints.maxWidth - gutterLeft - gutterRight;

                          return Stack(
                            children: [
                              for (
                                var hour = startHour;
                                hour <= endHour;
                                hour++
                              )
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: (hour - startHour) * hourHeight,
                                  child: SizedBox(
                                    height: 1,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Colors.black12,
                                      ),
                                    ),
                                  ),
                                ),
                              for (var hour = startHour; hour < endHour; hour++)
                                Positioned(
                                  top: (hour - startHour) * hourHeight - 10,
                                  left: 8,
                                  child: Text(
                                    '${_twoDigits(hour)}:00',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                              for (final layout in timedLayouts)
                                Builder(
                                  builder: (context) {
                                    final top =
                                        ((layout.startMinutes / 60) -
                                            startHour) *
                                        hourHeight;
                                    final height =
                                        ((layout.endMinutes -
                                                layout.startMinutes) /
                                            60) *
                                        hourHeight;
                                    final columnWidth =
                                        laneWidth / layout.totalColumns;
                                    final left =
                                        gutterLeft +
                                        (layout.column * columnWidth) +
                                        (taskGap / 2);
                                    final spanWidth =
                                        (columnWidth * layout.columnSpan) -
                                        taskGap;
                                    final width = spanWidth > 36
                                        ? spanWidth
                                        : 36.0;

                                    return Positioned(
                                      left: left,
                                      width: width,
                                      top: top,
                                      height: height < 34 ? 34 : height,
                                      child: GestureDetector(
                                        onTap: () =>
                                            _openTaskEditor(layout.task),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: _taskDisplayColor(
                                              layout.task,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            '${layout.task.name}\n${_timeRangeLabel(layout.task)}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              if (showsNowIndicator)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: nowTop,
                                  child: IgnorePointer(
                                    child: Row(
                                      children: [
                                        const SizedBox(width: 58),
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFE53935),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        Expanded(
                                          child: Container(
                                            height: 2,
                                            color: const Color(0xFFE53935),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE53935),
                                            borderRadius: BorderRadius.circular(
                                              99,
                                            ),
                                          ),
                                          child: Text(
                                            '${_twoDigits(_liveNow.hour)}:${_twoDigits(_liveNow.minute)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(color: Colors.white),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  if (unscheduled.isNotEmpty) const SizedBox(height: 14),
                  if (unscheduled.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sans horaire',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          for (final task in unscheduled)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(task.name),
                              subtitle: Text(
                                task.project.isEmpty
                                    ? 'Sans projet'
                                    : task.project,
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _openTaskEditor(task),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildPlanningWeekView(DateTime anchorDate) {
    final days = _weekDays(anchorDate);

    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth > 1100
              ? 4
              : constraints.maxWidth > 780
              ? 2
              : 1;

          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: columns == 1 ? 2.4 : 1.25,
            ),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];
              final tasks = _tasksForDate(day, timedOnly: true);
              final isToday = _isSameDay(day, _todayOnly);

              return GestureDetector(
                onDoubleTap: () => _openNewTaskForDate(day),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isToday
                          ? Theme.of(context).colorScheme.primary
                          : Colors.black12,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_dayLabel(day)} ${_twoDigits(day.day)}/${_twoDigits(day.month)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (tasks.isEmpty)
                        Text(
                          'Aucune tache horaire',
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            itemCount: tasks.length,
                            itemBuilder: (context, taskIndex) {
                              final task = tasks[taskIndex];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: InkWell(
                                  onTap: () => _openTaskEditor(task),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _taskDisplayColor(task),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${_timeRangeLabel(task)}\n${task.name}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
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
            },
          );
        },
      ),
    );
  }

  Widget _buildPlanningMonthView(DateTime anchorDate) {
    final days = _monthGridDays(anchorDate);
    const labels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

    return Expanded(
      child: Column(
        children: [
          Row(
            children: labels
                .map(
                  (label) => Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          Expanded(
            child: GridView.builder(
              itemCount: days.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                childAspectRatio: 1.15,
              ),
              itemBuilder: (context, index) {
                final day = days[index];
                final tasks = _tasksForDate(day, timedOnly: true);
                final inCurrentMonth = day.month == anchorDate.month;
                final isToday = _isSameDay(day, _todayOnly);

                return GestureDetector(
                  onDoubleTap: () => _openNewTaskForDate(day),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: inCurrentMonth ? Colors.white : Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isToday
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${day.day}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        for (final task in tasks.take(3))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _taskDisplayColor(task),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${_twoDigits(task.startTime?.hour ?? 0)}:${_twoDigits(task.startTime?.minute ?? 0)} ${task.name}',
                                style: Theme.of(context).textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        if (tasks.length > 3)
                          Text(
                            '+${tasks.length - 3} autres',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
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

  Widget _buildPlanningView() {
    final anchor = _dateOnly(_planningAnchorDate);
    final headerTitle = _planningScope == PlanningScope.month
        ? _monthLabel(anchor)
        : _planningScope == PlanningScope.week
        ? 'Semaine du ${_twoDigits(_startOfWeek(anchor).day)}/${_twoDigits(_startOfWeek(anchor).month)}'
        : '${_dayLabel(anchor)} ${_twoDigits(anchor.day)}/${_twoDigits(anchor.month)}/${anchor.year}';

    DateTime previousAnchor() {
      switch (_planningScope) {
        case PlanningScope.day:
          return anchor.subtract(const Duration(days: 1));
        case PlanningScope.week:
          return anchor.subtract(const Duration(days: 7));
        case PlanningScope.month:
          return DateTime(anchor.year, anchor.month - 1, anchor.day);
      }
    }

    DateTime nextAnchor() {
      switch (_planningScope) {
        case PlanningScope.day:
          return anchor.add(const Duration(days: 1));
        case PlanningScope.week:
          return anchor.add(const Duration(days: 7));
        case PlanningScope.month:
          return DateTime(anchor.year, anchor.month + 1, anchor.day);
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPlanningModeSelector(),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _planningAnchorDate = previousAnchor();
                  });
                },
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Periode precedente',
              ),
              Expanded(
                child: Text(
                  headerTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _planningAnchorDate = nextAnchor();
                  });
                },
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Periode suivante',
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_planningScope == PlanningScope.day)
            _buildPlanningDayView(anchor)
          else if (_planningScope == PlanningScope.week)
            _buildPlanningWeekView(anchor)
          else
            _buildPlanningMonthView(anchor),
        ],
      ),
    );
  }

  Widget _buildReminderOverlay() {
    if (_activeReminders.isEmpty) {
      return const SizedBox.shrink();
    }

    final reminders = _activeReminders.values.toList();
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, right: 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: reminders.map((reminder) {
              return TweenAnimationBuilder<double>(
                key: ValueKey(reminder.id),
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset((1 - value) * 16, 0),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4D6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE9C46A)),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.notifications_active, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reminder.title,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              reminder.subtitle,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _dismissReminder(reminder.id),
                        icon: const Icon(Icons.close, size: 16),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Fermer',
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentView = _currentView == MainView.today
        ? _buildTodayView()
        : _currentView == MainView.planning
        ? _buildPlanningView()
        : _buildProjectsView();

    return Scaffold(
      appBar: AppBar(centerTitle: false, title: _buildViewSwitcher()),
      body: Stack(children: [currentView, _buildReminderOverlay()]),
    );
  }
}
