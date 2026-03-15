import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (FlutterErrorDetails details) {
        debugPrint('[Tamago][FlutterError] ${details.exceptionAsString()}');
        debugPrint(details.stack?.toString() ?? 'No stack trace');
      };
      ui.PlatformDispatcher.instance.onError =
          (Object error, StackTrace stack) {
            debugPrint('[Tamago][PlatformError] $error');
            debugPrint(stack.toString());
            return true;
          };
      runApp(const MaterialApp(home: TodayPage()));
    },
    (error, stack) {
      debugPrint('[Tamago][ZoneError] $error');
      debugPrint(stack.toString());
    },
  );
}

enum MainView { today, planning, projects }

enum _TodayPane { tasks, timeline }

enum TaskColorOption {
  jaune('Jaune', Color(0xFFFFE79A)),
  rouge('Rose corail', Color(0xFFFFB3C7)),
  vert('Vert menthe', Color(0xFFBDECC8)),
  bleu('Lilas', Color(0xFFC9C4FF)),
  gris('Gris lavande', Color(0xFFE2DDEA)),
  violet('Violet', Color(0xFFE3B7FF));

  const TaskColorOption(this.label, this.color);
  final String label;
  final Color color;
}

enum ProjectColorOption {
  jaune('Jaune', Color(0xFFFFE79A)),
  vert('Vert menthe', Color(0xFFBDECC8)),
  rouge('Rose corail', Color(0xFFFFB3C7)),
  bleu('Lilas', Color(0xFFC9C4FF)),
  gris('Gris lavande', Color(0xFFE2DDEA)),
  marron('Pêche', Color(0xFFF1C9A6));

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
  });

  final TaskItem task;
  final int startMinutes;
  final int endMinutes;
  final int column;
  int totalColumns;
  int columnSpan = 1;
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

class _TodayPageState extends State<TodayPage> with WidgetsBindingObserver {
  Widget buildMobileTodayTasksList() {
    final todayTasks = _tasksForDate(_todayOnly);
    return Container(
      height: 320,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: todayTasks.isEmpty
          ? Center(
              child: Text(
                'Aucune tâche pour aujourd’hui.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            )
          : Scrollbar(
              child: ListView.builder(
                itemCount: todayTasks.length,
                itemBuilder: (context, index) {
                  final task = todayTasks[index];
                  return ListTile(
                    key: ObjectKey(task),
                    title: _buildTaskNameWithRecurrenceIcon(
                      task,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    subtitle: task.startTime != null && task.endTime != null
                        ? Text(
                            _timeRangeLabel(task),
                            style: Theme.of(context).textTheme.bodySmall,
                          )
                        : null,
                    onTap: () => _openTaskEditor(task),
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    contentPadding: EdgeInsets.zero,
                  );
                },
              ),
            ),
    );
  }

  final Set<String> _expandedProjectIds = <String>{};
  DateTime _withTime(DateTime day, TimeOfDay time) {
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }

  void _resetRecurringTasksStatus() {
    final today = _dateOnly(DateTime.now());
    for (final task in _tasks) {
      if (_isRecurringTask(task) &&
          task.status == 'Terminé' &&
          !_isSameDay(task.date, today)) {
        task.status = 'À faire';
      }
    }
  }

  Duration? _reminderOffset(String option) {
    switch (option) {
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

  String _encodeReminderSelections(Set<String> selections) {
    if (selections.isEmpty) return 'Aucun';
    return selections.join(' | ');
  }

  void _centerTimelineOnNow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_planningDayScrollController.hasClients) return;
      final nowMinutes = _liveNow.hour * 60 + _liveNow.minute;
      final forcedMin = nowMinutes - 180;
      final minMinutes = forcedMin;
      final startHour = minMinutes ~/ 60;
      const hourHeight = 72.0;
      final nowTop = ((nowMinutes / 60) - startHour) * hourHeight;
      final viewportHeight =
          _planningDayScrollController.position.viewportDimension;
      final targetOffset = nowTop.clamp(
        0.0,
        _planningDayScrollController.position.maxScrollExtent,
      );
      _planningDayScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  static const _tasksStorageKey = 'tamago_tasks_v1';
  static const _projectsStorageKey = 'tamago_projects_v1';
  static const _weekNotesStorageKey = 'tamago_week_notes_v1';
  static const List<String> _reminderOptions = <String>[
    '1 jour avant',
    '1h avant',
    '10 min avant',
  ];

  final TextEditingController _quickAddTaskController = TextEditingController();
  final TextEditingController _quickAddProjectController =
      TextEditingController();
  final TextEditingController _quickAddProjectTaskController =
      TextEditingController();
  final TextEditingController _headerPostItController = TextEditingController();
  final TextEditingController _weekNotesController = TextEditingController();
  final ScrollController _planningDayScrollController = ScrollController();

  final List<TaskItem> _tasks = [];
  final List<ProjectItem> _projects = [];
  Timer? _clockTimer;
  DateTime _liveNow = DateTime.now();
  final Map<String, _ReminderNotice> _activeReminders =
      <String, _ReminderNotice>{};
  final Set<String> _dismissedReminderIds = <String>{};
  final Map<String, String> _weekNotesByWeekKey = <String, String>{};

  MainView _currentView = MainView.today;
  DateTime _planningAnchorDate = DateTime.now();
  DateTime? _lastAutoScrolledPlanningDay;
  String? _selectedProjectId;
  bool _todayTasksPaneCollapsed = false;
  bool _todayTimelinePaneCollapsed = false;
  _TodayPane? _todayExpandedPane;
  String _activeWeekNotesKey = '';
  bool _isSyncingWeekNotesController = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    debugPrint('[Tamago][Lifecycle] initState');
    _refreshLiveNowAndReminders();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshLiveNowAndReminders(),
    );
    _loadData();
    _loadHeaderPostIt();
    _loadWeekNotes();
  }

  @override
  void dispose() {
    debugPrint('[Tamago][Lifecycle] dispose');
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _quickAddTaskController.dispose();
    _quickAddProjectController.dispose();
    _quickAddProjectTaskController.dispose();
    _headerPostItController.dispose();
    _weekNotesController.dispose();
    _planningDayScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[Tamago][Lifecycle] state=$state');
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

  List<String> _parseReminderSelections(String rawReminder) {
    final trimmed = rawReminder.trim();
    if (trimmed.isEmpty || trimmed == 'Aucun') {
      return const <String>[];
    }
    final tokens = trimmed
        .split(RegExp(r'\||,'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty && value != 'Aucun');
    return tokens.toList();
  }

  String _reminderId(
    TaskItem task,
    DateTime occurrenceDate,
    String reminderOption,
  ) {
    final start = task.startTime;
    final startLabel = start == null ? 'none' : '${start.hour}:${start.minute}';
    return '${task.name}|${task.date.toIso8601String()}|${task.endDate.toIso8601String()}|$startLabel|${occurrenceDate.toIso8601String()}|$reminderOption';
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
      if (task.startTime == null) {
        continue;
      }

      final reminderSelections = _parseReminderSelections(task.reminder);
      if (reminderSelections.isEmpty) {
        continue;
      }

      for (final occurrenceDate in [today, tomorrow]) {
        if (!_taskOccursOnDate(task, occurrenceDate)) {
          continue;
        }

        final startDateTime = _withTime(occurrenceDate, task.startTime!);
        for (final reminderOption in reminderSelections) {
          final offset = _reminderOffset(reminderOption);
          if (offset == null) {
            continue;
          }

          final triggerDateTime = startDateTime.subtract(offset);
          final reminderId = _reminderId(task, occurrenceDate, reminderOption);
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
                    'Rappel $reminderOption • ${_twoDigits(occurrenceDate.day)}/${_twoDigits(occurrenceDate.month)} ${_twoDigits(task.startTime!.hour)}:${_twoDigits(task.startTime!.minute)}',
              ),
            );
          }
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

  String _dayLabel(DateTime date) {
    const labels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return labels[date.weekday - 1];
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

  bool _isRecurringTask(TaskItem task) {
    return task.recurrence != 'Aucune';
  }

  Widget _buildTaskNameWithRecurrenceIcon(
    TaskItem task, {
    TextStyle? style,
    int maxLines = 1,
  }) {
    final titleText = task.name;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isRecurringTask(task)) ...[
          Icon(Icons.repeat_rounded, size: 16, color: Colors.black87),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(
            titleText,
            style: style,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
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

  List<TaskItem> get _todayTasks {
    return _tasksForDate(
      _todayOnly,
    ).where((task) => task.status != 'Terminé').toList();
  }

  List<TaskItem> _completedTasksForDate(DateTime date) {
    return _tasksForDate(
      date,
    ).where((task) => task.status == 'Terminé').toList();
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

  Color _taskMarkerColor(TaskItem task) {
    final linkedProject = _projectForTask(task);
    return linkedProject?.color.color ?? task.color.color;
  }

  TaskColorOption _taskColorFromProjectColor(ProjectColorOption projectColor) {
    return TaskColorOption.values.firstWhere(
      (taskColor) => taskColor.color.value == projectColor.color.value,
      orElse: () => TaskColorOption.gris,
    );
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

  void _deleteTask(TaskItem task) {
    setState(() {
      _tasks.remove(task);
    });
    _saveTasks();
  }

  void _deleteProject(ProjectItem project) {
    setState(() {
      _projects.removeWhere((item) => item.id == project.id);
      if (_selectedProjectId == project.id) {
        _selectedProjectId = _projects.isEmpty ? null : _projects.first.id;
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

  void _toggleTodayPaneCollapse(_TodayPane pane) {
    setState(() {
      if (pane == _TodayPane.tasks) {
        final next = !_todayTasksPaneCollapsed;
        _todayTasksPaneCollapsed = next;
        if (next && _todayExpandedPane == _TodayPane.tasks) {
          _todayExpandedPane = null;
        }
      } else {
        final next = !_todayTimelinePaneCollapsed;
        _todayTimelinePaneCollapsed = next;
        if (next && _todayExpandedPane == _TodayPane.timeline) {
          _todayExpandedPane = null;
        }
      }

      // Keep at least one panel open in Today view.
      if (_todayTasksPaneCollapsed && _todayTimelinePaneCollapsed) {
        if (pane == _TodayPane.tasks) {
          _todayTimelinePaneCollapsed = false;
        } else {
          _todayTasksPaneCollapsed = false;
        }
      }
    });
  }

  void _toggleTodayPaneExpand(_TodayPane pane) {
    setState(() {
      if (_todayExpandedPane == pane) {
        _todayExpandedPane = null;
        return;
      }
      _todayExpandedPane = pane;
      if (pane == _TodayPane.tasks) {
        _todayTasksPaneCollapsed = false;
      } else {
        _todayTimelinePaneCollapsed = false;
        _centerTimelineOnNow();
      }
    });
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

  void _selectProjectTasksPanel(ProjectItem project) {
    setState(() {
      _selectedProjectId = project.id;
    });
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
      _resetRecurringTasksStatus();
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

  Future<void> _loadWeekNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final rawNotes = prefs.getString(_weekNotesStorageKey) ?? '';
    final loaded = <String, String>{};

    if (rawNotes.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawNotes) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          final value = entry.value;
          if (value is String) {
            loaded[entry.key] = value;
          }
        }
      } catch (_) {
        // Legacy format fallback: map existing note to the current anchor week.
        loaded[_weekNotesKeyForDate(_planningAnchorDate)] = rawNotes;
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _weekNotesByWeekKey
        ..clear()
        ..addAll(loaded);
    });
    _syncWeekNotesControllerForDate(_planningAnchorDate);
  }

  Future<void> _saveWeekNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _weekNotesStorageKey,
      jsonEncode(_weekNotesByWeekKey),
    );
  }

  String _weekNotesKeyForDate(DateTime date) {
    final weekStart = _startOfWeek(_dateOnly(date));
    return '${weekStart.year}-${_twoDigits(weekStart.month)}-${_twoDigits(weekStart.day)}';
  }

  void _syncWeekNotesControllerForDate(DateTime date) {
    final nextKey = _weekNotesKeyForDate(date);
    _activeWeekNotesKey = nextKey;
    final nextText = _weekNotesByWeekKey[nextKey] ?? '';
    if (_weekNotesController.text == nextText) {
      return;
    }

    _isSyncingWeekNotesController = true;
    _weekNotesController.text = nextText;
    _weekNotesController.selection = TextSelection.collapsed(
      offset: _weekNotesController.text.length,
    );
    _isSyncingWeekNotesController = false;
  }

  void _onWeekNotesChanged(String value) {
    if (_isSyncingWeekNotesController) {
      return;
    }
    if (_activeWeekNotesKey.isEmpty) {
      _activeWeekNotesKey = _weekNotesKeyForDate(_planningAnchorDate);
    }

    if (value.trim().isEmpty) {
      _weekNotesByWeekKey.remove(_activeWeekNotesKey);
    } else {
      _weekNotesByWeekKey[_activeWeekNotesKey] = value;
    }
    _saveWeekNotes();
  }

  Future<File> _headerPostItFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}${Platform.pathSeparator}tamago_post_it.txt');
  }

  Future<void> _loadHeaderPostIt() async {
    if (kIsWeb) {
      return;
    }

    try {
      final file = await _headerPostItFile();
      if (!await file.exists()) {
        return;
      }
      final content = await file.readAsString();
      if (!mounted) {
        return;
      }
      setState(() {
        _headerPostItController.text = content;
      });
    } catch (_) {}
  }

  void _clearHeaderPostIt() {
    setState(() {
      _headerPostItController.clear();
    });
  }

  Future<void> _saveHeaderPostIt() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sauvegarde fichier indisponible sur le web.'),
        ),
      );
      return;
    }

    try {
      final file = await _headerPostItFile();
      await file.writeAsString(_headerPostItController.text.trimRight());
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Post-it enregistre dans ${file.path}')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Echec de la sauvegarde du post-it.')),
      );
    }
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
    final selectedReminders = _parseReminderSelections(task.reminder).toSet();
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
            const statusOptions = <String>{'À faire', 'En cours', 'Terminé'};
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
                        : (constraints.maxHeight * 0.82).clamp(320.0, 720.0);

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

                    final left = (centeredLeft + dialogOffset.dx).clamp(
                      minLeft,
                      maxLeft,
                    );
                    final top = (centeredTop + dialogOffset.dy).clamp(
                      minTop,
                      maxTop,
                    );

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
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Rappel',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.titleSmall,
                                              ),
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: _reminderOptions.map((
                                                  option,
                                                ) {
                                                  final isSelected =
                                                      selectedReminders
                                                          .contains(option);
                                                  return FilterChip(
                                                    label: Text(option),
                                                    selected: isSelected,
                                                    onSelected: (selected) {
                                                      setModalState(() {
                                                        if (selected) {
                                                          selectedReminders.add(
                                                            option,
                                                          );
                                                        } else {
                                                          selectedReminders
                                                              .remove(option);
                                                        }
                                                      });
                                                    },
                                                  );
                                                }).toList(),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                selectedReminders.isEmpty
                                                    ? 'Aucun rappel selectionne'
                                                    : '${selectedReminders.length} rappel(s) selectionne(s)',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                              ),
                                            ],
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
                                            icon: const Icon(Icons.close),
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
                                              task.reminder =
                                                  _encodeReminderSelections(
                                                    selectedReminders,
                                                  );
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
                        : (constraints.maxHeight * 0.82).clamp(320.0, 720.0);

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

                    final left = (centeredLeft + dialogOffset.dx).clamp(
                      minLeft,
                      maxLeft,
                    );
                    final top = (centeredTop + dialogOffset.dy).clamp(
                      minTop,
                      maxTop,
                    );

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
    Widget buildButton({required IconData icon, required MainView view}) {
      final isSelected = _currentView == view;
      if (isSelected) {
        return FilledButton(
          onPressed: () {
            setState(() {
              _currentView = view;
            });
          },
          style: FilledButton.styleFrom(
            minimumSize: const Size(40, 40),
            padding: const EdgeInsets.all(8),
          ),
          child: Icon(icon, size: 18),
        );
      }
      return OutlinedButton(
        onPressed: () {
          setState(() {
            _currentView = view;
          });
        },
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(40, 40),
          padding: const EdgeInsets.all(8),
        ),
        child: Icon(icon, size: 18),
      );
    }

    return Row(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: 'Today',
              child: buildButton(
                icon: Icons.bolt_rounded,
                view: MainView.today,
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: 'Semaine',
              child: buildButton(
                icon: Icons.calendar_view_week_rounded,
                view: MainView.planning,
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: 'Projets',
              child: buildButton(
                icon: Icons.rocket_launch_rounded,
                view: MainView.projects,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(child: _buildHeaderPostIt()),
      ],
    );
  }

  Widget _buildHeaderPostIt() {
    return Container(
      height: 40,
      padding: const EdgeInsets.only(left: 10, right: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3BF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE6D08A)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.sticky_note_2_outlined,
            size: 16,
            color: Colors.black54,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _headerPostItController,
              maxLines: 1,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Post-it rapide... ',
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          IconButton(
            onPressed: _clearHeaderPostIt,
            tooltip: 'Effacer',
            icon: const Icon(Icons.close, size: 17, color: Colors.black54),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: _saveHeaderPostIt,
            tooltip: 'Enregistrer dans un fichier',
            icon: const Icon(
              Icons.save_outlined,
              size: 17,
              color: Colors.black54,
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTile(TaskItem task) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(color: _taskMarkerColor(task), width: 2),
          top: BorderSide(color: _taskMarkerColor(task), width: 1),
          right: BorderSide(color: _taskMarkerColor(task), width: 1),
          bottom: BorderSide(color: _taskMarkerColor(task), width: 1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          onTap: () => _openTaskEditor(task),
          leading: IconButton(
            onPressed: () => _cycleTaskStatus(task),
            icon: Icon(_statusIcon(task.status), color: _taskMarkerColor(task)),
            tooltip: 'Changer le statut',
          ),
          title: _buildTaskNameWithRecurrenceIcon(
            task,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
    );
  }

  Widget _buildTodayView() {
    final tasksForToday = _todayTasks;
    final isTimelineExpanded = _todayExpandedPane == _TodayPane.timeline;
    final showTasksPane = _todayExpandedPane != _TodayPane.timeline;
    final showTimelinePane = _todayExpandedPane == null || isTimelineExpanded;

    Widget buildPaneHeader({
      String? title,
      required bool collapsed,
      required bool expanded,
      required VoidCallback onCollapsePressed,
      required VoidCallback onExpandPressed,
    }) {
      return Row(
        children: [
          if (title != null)
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          IconButton(
            onPressed: onCollapsePressed,
            tooltip: collapsed ? 'Afficher' : 'Réduire',
            icon: Icon(collapsed ? Icons.unfold_more : Icons.unfold_less),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: onExpandPressed,
            tooltip: expanded ? 'Quitter plein écran' : 'Plein écran',
            icon: Icon(expanded ? Icons.fullscreen_exit : Icons.open_in_full),
            visualDensity: VisualDensity.compact,
          ),
        ],
      );
    }

    Widget buildTasksPane() {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: tasksForToday.isEmpty
                  ? Center(
                      child: Text(
                        'Aucune tâche pour aujourd’hui.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    )
                  : ListView.builder(
                      itemCount: tasksForToday.length,
                      itemBuilder: (context, index) {
                        final task = tasksForToday[index];
                        return Padding(
                          key: ObjectKey(task),
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildTaskTile(task),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    }

    Widget buildTimelinePane() {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildPaneHeader(
              title: 'Timeline',
              collapsed: _todayTimelinePaneCollapsed,
              expanded: isTimelineExpanded,
              onCollapsePressed: () =>
                  _toggleTodayPaneCollapse(_TodayPane.timeline),
              onExpandPressed: () =>
                  _toggleTodayPaneExpand(_TodayPane.timeline),
            ),
            if (!_todayTimelinePaneCollapsed) const SizedBox(height: 8),
            if (!_todayTimelinePaneCollapsed) _buildPlanningDayView(_todayOnly),
          ],
        ),
      );
    }

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
            child: Column(
              children: [
                if (showTasksPane) Expanded(flex: 8, child: buildTasksPane()),
                if (showTasksPane && showTimelinePane)
                  const SizedBox(height: 10),
                if (showTimelinePane)
                  Expanded(
                    flex: _todayTimelinePaneCollapsed ? 1 : 8,
                    child: buildTimelinePane(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsView() {
    final selectedProject = _selectedProject;
    final selectedProjectTasks = selectedProject == null
        ? <TaskItem>[]
        : _tasksForProject(selectedProject);

    Widget buildProjectRow(ProjectItem project) {
      final isExpanded = _expandedProjectIds.contains(project.id);
      final projectTasks = _tasksForProject(project);
      return Padding(
        key: ValueKey('project-${project.id}'),
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => _cycleProjectStatus(project),
                    icon: Icon(
                      _statusIcon(project.status),
                      color: project.color.color,
                    ),
                    tooltip: 'Changer le statut',
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _openProjectEditor(project),
                      child: Text(
                        project.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  Text(
                    '${projectTasks.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedProjectId = project.id;
                        if (isExpanded) {
                          _expandedProjectIds.remove(project.id);
                        } else {
                          _expandedProjectIds.add(project.id);
                        }
                      });
                    },
                    tooltip: isExpanded
                        ? 'Masquer les tâches'
                        : 'Afficher les tâches',
                    icon: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                    ),
                  ),
                ],
              ),
              if (isExpanded)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: projectTasks.isEmpty
                      ? Text(
                          'Aucune tâche pour ce projet.',
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      : Column(
                          children: projectTasks.map((task) {
                            return Padding(
                              key: ValueKey(
                                'project-task-${project.id}-${task.name}-${task.date.toIso8601String()}',
                              ),
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildTaskTile(task),
                            );
                          }).toList(),
                        ),
                ),
            ],
          ),
        ),
      );
    }

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
                tooltip: 'Ajouter le projet',
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (selectedProject != null)
            TextField(
              controller: _quickAddProjectTaskController,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addTaskToSelectedProjectFromPrompt(),
              decoration: InputDecoration(
                hintText:
                    'Ajouter une tâche au projet "${selectedProject.name}"…',
                suffixIcon: IconButton(
                  onPressed: _addTaskToSelectedProjectFromPrompt,
                  icon: const Icon(Icons.add_task_outlined),
                  tooltip: 'Ajouter la tâche au projet',
                ),
              ),
            ),
          if (selectedProject != null) const SizedBox(height: 14),
          Expanded(
            child: _projects.isEmpty
                ? Center(
                    child: Text(
                      'Aucun projet disponible.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                : ListView(children: _projects.map(buildProjectRow).toList()),
          ),
          if (selectedProject != null && selectedProjectTasks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Projet sélectionné: ${selectedProject.name} (${selectedProjectTasks.length} tâche(s))',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlanningDayView(DateTime date) {
    final day = _dateOnly(date);
    final isTodayView = _isSameDay(day, _todayOnly);
    final dayTasks = isTodayView ? _todayTasks : _tasksForDate(day);
    final timedTasks =
        dayTasks
            .where((task) => task.startTime != null && task.endTime != null)
            .toList()
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

    final nowMinutes = _liveNow.hour * 60 + _liveNow.minute;

    var firstStart = timedTasks.isEmpty
        ? 8 * 60
        : timedTasks
                  .map(
                    (task) =>
                        task.startTime!.hour * 60 + task.startTime!.minute,
                  )
                  .reduce((a, b) => a < b ? a : b) -
              30;
    var lastEnd = timedTasks.isEmpty
        ? 18 * 60
        : timedTasks
                  .map((task) => task.endTime!.hour * 60 + task.endTime!.minute)
                  .reduce((a, b) => a > b ? a : b) +
              30;

    if (isTodayView) {
      final nowWindowStart = nowMinutes - 90;
      final nowWindowEnd = nowMinutes + 90;
      if (nowWindowStart < firstStart) {
        firstStart = nowWindowStart;
      }
      if (nowWindowEnd > lastEnd) {
        lastEnd = nowWindowEnd;
      }
    }

    // Force la plage horaire à inclure l'heure actuelle
    // Toujours élargir la plage pour inclure l'heure actuelle
    final forcedMin = nowMinutes - 180;
    final forcedMax = nowMinutes + 180;
    final minMinutes = firstStart < forcedMin ? firstStart : forcedMin;
    final maxMinutes = lastEnd > forcedMax ? lastEnd : forcedMax;

    // Toujours afficher la ligne rouge
    final showsNowIndicator = isTodayView;

    final startHour = minMinutes ~/ 60;
    final endHour = (maxMinutes / 60).ceil();
    const hourHeight = 72.0;
    final totalHeight = (endHour - startHour) * hourHeight;
    final nowTop = ((nowMinutes / 60) - startHour) * hourHeight;

    if (isTodayView && _lastAutoScrolledPlanningDay == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_planningDayScrollController.hasClients) {
          return;
        }
        final viewportHeight =
            _planningDayScrollController.position.viewportDimension;
        final targetOffset = (nowTop - viewportHeight / 2).clamp(
          0.0,
          _planningDayScrollController.position.maxScrollExtent,
        );
        _planningDayScrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      });
      _lastAutoScrolledPlanningDay = day;
    }

    return Expanded(
      child: SingleChildScrollView(
        controller: _planningDayScrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      for (var hour = startHour; hour <= endHour; hour++)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: (hour - startHour) * hourHeight,
                          child: SizedBox(
                            height: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(color: Colors.black12),
                            ),
                          ),
                        ),
                      for (var hour = startHour; hour < endHour; hour++)
                        Positioned(
                          top: (hour - startHour) * hourHeight - 10,
                          left: 8,
                          child: Text(
                            '${_twoDigits(hour)}:00',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      for (final layout in timedLayouts)
                        Builder(
                          builder: (context) {
                            final top =
                                ((layout.startMinutes / 60) - startHour) *
                                hourHeight;
                            final height =
                                ((layout.endMinutes - layout.startMinutes) /
                                    60) *
                                hourHeight;
                            final columnWidth = laneWidth / layout.totalColumns;
                            final left =
                                gutterLeft +
                                (layout.column * columnWidth) +
                                (taskGap / 2);
                            final spanWidth =
                                (columnWidth * layout.columnSpan) - taskGap;
                            final width = spanWidth > 36 ? spanWidth : 36.0;

                            return Positioned(
                              left: left,
                              width: width,
                              top: top,
                              height: height < 34 ? 34 : height,
                              child: GestureDetector(
                                onTap: () => _openTaskEditor(layout.task),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border(
                                      left: BorderSide(
                                        color: _taskMarkerColor(layout.task),
                                        width: 1,
                                      ),
                                      top: BorderSide(
                                        color: _taskMarkerColor(layout.task),
                                        width: 1,
                                      ),
                                      right: BorderSide(
                                        color: _taskMarkerColor(layout.task),
                                        width: 1,
                                      ),
                                      bottom: BorderSide(
                                        color: _taskMarkerColor(layout.task),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildTaskNameWithRecurrenceIcon(
                                        layout.task,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _timeRangeLabel(layout.task),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
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
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    '${_twoDigits(_liveNow.hour)}:${_twoDigits(_liveNow.minute)}',
                                    style: Theme.of(context).textTheme.bodySmall
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
            if (timedTasks.isEmpty) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Aucune tache planifiee pour cette journee.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
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
            itemCount: days.length + 1,
            itemBuilder: (context, index) {
              if (index == days.length) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notes',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TextField(
                          controller: _weekNotesController,
                          onChanged: _onWeekNotesChanged,
                          expands: true,
                          maxLines: null,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            hintText: 'Ecris tes notes de semaine...',
                            border: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final day = days[index];
              final tasks = _tasksForDate(day);
              final timedTasks = tasks
                  .where(
                    (task) => task.startTime != null && task.endTime != null,
                  )
                  .toList();
              final unscheduledTasks = tasks
                  .where(
                    (task) => task.startTime == null || task.endTime == null,
                  )
                  .toList();
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
                          'Aucune tache',
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      else
                        Expanded(
                          child: ListView(
                            children: [
                              ...timedTasks.map((task) {
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
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border(
                                          left: BorderSide(
                                            color: _taskMarkerColor(task),
                                            width: 1,
                                          ),
                                          top: BorderSide(
                                            color: _taskMarkerColor(task),
                                            width: 1,
                                          ),
                                          right: BorderSide(
                                            color: _taskMarkerColor(task),
                                            width: 1,
                                          ),
                                          bottom: BorderSide(
                                            color: _taskMarkerColor(task),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            _timeRangeLabel(task),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(width: 4),
                                          if (_isRecurringTask(task)) ...[
                                            const Icon(
                                              Icons.repeat_rounded,
                                              size: 12,
                                              color: Colors.black87,
                                            ),
                                            const SizedBox(width: 2),
                                          ],
                                          Expanded(
                                            child: Text(
                                              task.name,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              ...unscheduledTasks.map((task) {
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
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border(
                                          left: BorderSide(
                                            color: _taskMarkerColor(task),
                                            width: 1,
                                          ),
                                          top: BorderSide(
                                            color: _taskMarkerColor(task),
                                            width: 1,
                                          ),
                                          right: BorderSide(
                                            color: _taskMarkerColor(task),
                                            width: 1,
                                          ),
                                          bottom: BorderSide(
                                            color: _taskMarkerColor(task),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildTaskNameWithRecurrenceIcon(
                                            task,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
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

  Widget _buildPlanningView() {
    final anchor = _dateOnly(_planningAnchorDate);
    final headerTitle =
        'Semaine du ${_twoDigits(_startOfWeek(anchor).day)}/${_twoDigits(_startOfWeek(anchor).month)}';

    DateTime previousAnchor() {
      return anchor.subtract(const Duration(days: 7));
    }

    DateTime nextAnchor() {
      return anchor.add(const Duration(days: 7));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _planningAnchorDate = previousAnchor();
                  });
                  _syncWeekNotesControllerForDate(_planningAnchorDate);
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
                  _syncWeekNotesControllerForDate(_planningAnchorDate);
                },
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Periode suivante',
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildPlanningWeekView(anchor),
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
