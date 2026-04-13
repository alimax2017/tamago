import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (FlutterErrorDetails details) {
        final exceptionText = details.exceptionAsString();
        final stackText = details.stack?.toString() ?? '';
        debugPrint('[Tamago][FlutterError] $exceptionText');
        debugPrint(stackText.isEmpty ? 'No stack trace' : stackText);
      };
      ui.PlatformDispatcher.instance.onError =
          (Object error, StackTrace stack) {
            debugPrint('[Tamago][PlatformError] $error');
            debugPrint(stack.toString());
            return true;
          };
      runApp(const TamagoApp());
    },
    (error, stack) {
      debugPrint('[Tamago][ZoneError] $error');
      debugPrint(stack.toString());
    },
  );
}

class TamagoApp extends StatelessWidget {
  const TamagoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      locale: Locale('en', 'US'),
      supportedLocales: [Locale('en', 'US')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: TodayPage(),
    );
  }
}

enum MainView { today, planning, projects }

enum _TodayPane { tasks, timeline }

enum TaskColorOption {
  jaune('Yellow', Color(0xFFFFE79A)),
  rouge('Coral pink', Color(0xFFFFB3C7)),
  vert('Mint green', Color(0xFFBDECC8)),
  bleu('Lilac', Color(0xFFC9C4FF)),
  gris('Lavender gray', Color(0xFFE2DDEA)),
  violet('Violet', Color(0xFFE3B7FF));

  const TaskColorOption(this.label, this.color);
  final String label;
  final Color color;
}

enum ProjectColorOption {
  jaune('Yellow', Color(0xFFFFE79A)),
  vert('Mint green', Color(0xFFBDECC8)),
  marron('Peach', Color(0xFFF1C9A6)),
  rouge('Coral pink', Color(0xFFFFB3C7)),
  bleu('Lilac', Color(0xFFC9C4FF)),
  gris('Lavender gray', Color(0xFFE2DDEA));

  const ProjectColorOption(this.label, this.color);
  final String label;
  final Color color;
}

String _normalizeStatus(String? rawStatus) {
  final value = (rawStatus ?? '').trim();
  switch (value) {
    case 'To do':
    case 'A faire':
    case 'À faire':
    case '� faire':
      return 'To do';
    case 'In progress':
    case 'En cours':
      return 'In progress';
    case 'Done':
    case 'Termine':
    case 'Terminé':
    case 'Termin�':
      return 'Done';
    default:
      return value.isEmpty ? 'To do' : value;
  }
}

String _normalizeWeekdayLabel(String rawWeekday) {
  final value = rawWeekday.trim();
  switch (value) {
    case 'Monday':
    case 'Lundi':
      return 'Monday';
    case 'Tuesday':
    case 'Mardi':
      return 'Tuesday';
    case 'Wednesday':
    case 'Mercredi':
      return 'Wednesday';
    case 'Thursday':
    case 'Jeudi':
      return 'Thursday';
    case 'Friday':
    case 'Vendredi':
      return 'Friday';
    case 'Saturday':
    case 'Samedi':
      return 'Saturday';
    case 'Sunday':
    case 'Dimanche':
      return 'Sunday';
    default:
      return value;
  }
}

String _normalizeRecurrence(String? rawRecurrence) {
  final value = (rawRecurrence ?? '').trim();
  if (value.isEmpty || value == 'Aucune' || value == 'Nonee') {
    return 'None';
  }
  if (value == 'Daily' || value == 'Quotidienne') {
    return 'Daily';
  }
  if (value == 'Weekly' || value == 'Hebdomadaire') {
    return 'Weekly';
  }
  if (value == 'Monthly' || value == 'Mensuelle') {
    return 'Monthly';
  }
  if (value.startsWith('Days:') || value.startsWith('Jours:')) {
    final prefixLength = value.startsWith('Days:')
        ? 'Days:'.length
        : 'Jours:'.length;
    final days = value
        .substring(prefixLength)
        .split(',')
        .map((day) => _normalizeWeekdayLabel(day))
        .where((day) => day.isNotEmpty)
        .toList();
    return days.isEmpty ? 'None' : 'Days:${days.join(',')}';
  }
  return value;
}

String _normalizeReminderOption(String rawOption) {
  final value = rawOption.trim();
  switch (value) {
    case '1 day before':
    case '1 jour avant':
      return '1 day before';
    case '1h before':
    case '1h avant':
      return '1h before';
    case '10 min before':
    case '10 min avant':
      return '10 min before';
    default:
      return value;
  }
}

String _fullWeekdayLabel(DateTime date) {
  const labels = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return labels[date.weekday - 1];
}

String _fullMonthLabel(DateTime date) {
  const labels = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return labels[date.month - 1];
}

String _formatLongDateUs(DateTime date) {
  return '${_fullWeekdayLabel(date)}, ${_fullMonthLabel(date)} ${date.day}';
}

class TaskItem {
  TaskItem({
    required this.name,
    this.date,
    this.endDate,
    this.allDay = false,
    this.startTime,
    this.endTime,
    this.duration = '',
    this.reminder = 'None',
    this.recurrence = 'None',
    this.status = 'To do',
    this.contact = '',
    this.project = '',
    this.projectId,
    this.color = TaskColorOption.bleu,
  });

  String name;
  DateTime? date;
  DateTime? endDate;
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
      'date': date?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
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
      date: DateTime.tryParse((json['date'] as String?) ?? ''),
      endDate: DateTime.tryParse((json['endDate'] as String?) ?? ''),
      allDay: (json['allDay'] as bool?) ?? false,
      startTime: _minutesToTime(json['startTime'] as int?),
      endTime: _minutesToTime(json['endTime'] as int?),
      duration: (json['duration'] as String?) ?? '',
      reminder: (json['reminder'] as String?) ?? 'None',
      recurrence: _normalizeRecurrence(json['recurrence'] as String?),
      status: _normalizeStatus(json['status'] as String?),
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

class _GlobalSearchResult {
  _GlobalSearchResult({
    required this.category,
    required this.title,
    required this.subtitle,
    required this.matchedFields,
    this.meta = '',
    this.onTap,
    this.noteContent,
    this.onNoteChanged,
  });

  final String category;
  final String title;
  final String subtitle;
  final List<_SearchMatchedField> matchedFields;
  final String meta;
  final VoidCallback? onTap;
  final String? noteContent;
  final void Function(String)? onNoteChanged;
}

class _SearchMatchedField {
  const _SearchMatchedField({required this.label, required this.value});

  final String label;
  final String value;
}

class ProjectItem {
  ProjectItem({
    required this.id,
    required this.name,
    required this.createdAt,
    DateTime? startDate,
    this.endDate,
    this.description = '',
    this.status = 'To do',
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
      name: (json['name'] as String?) ?? 'Project',
      createdAt: createdAt,
      startDate: startDate,
      endDate: endDate,
      description: (json['description'] as String?) ?? '',
      status: _normalizeStatus(json['status'] as String?),
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
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static const AndroidNotificationChannel _taskReminderChannel =
      AndroidNotificationChannel(
        'tamago_task_reminders',
        'Task reminders',
        description: 'Reminders for scheduled Tamago tasks',
        importance: Importance.max,
        playSound: true,
      );

  Widget buildMobileTodayTasksList() {
    final todayTasks = _tasksForDate(_todayOnly);
    return Container(
      height: 320,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: todayTasks.isEmpty
          ? Center(
              child: Text(
                'No tasks for today.',
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
      final taskDate = task.date;
      if (_isRecurringTask(task) &&
          task.status == 'Done' &&
          taskDate != null &&
          !_isSameDay(taskDate, today)) {
        task.status = 'To do';
      }
    }
  }

  DateTime _lastPendingTaskRollDate = DateTime.now();

  bool _rollForwardPendingTasks(List<TaskItem> tasks, DateTime today) {
    var changed = false;
    for (final task in tasks) {
      final taskDate = task.date;
      if (task.status == 'Done' || _isRecurringTask(task) || taskDate == null) {
        continue;
      }
      final taskStart = _dateOnly(taskDate);
      final taskEnd = _dateOnly(task.endDate ?? taskDate);
      if (!taskEnd.isBefore(today)) {
        continue;
      }
      final spanDays = taskEnd.difference(taskStart).inDays;
      task.date = today;
      task.endDate = spanDays <= 0
          ? today
          : today.add(Duration(days: spanDays));
      changed = true;
    }
    return changed;
  }

  void _rollForwardPendingTasksIfNeeded(DateTime today) {
    if (_isSameDay(_lastPendingTaskRollDate, today)) {
      return;
    }
    _lastPendingTaskRollDate = today;
    if (_rollForwardPendingTasks(_tasks, today)) {
      unawaited(_saveTasks());
    }
  }

  Duration? _reminderOffset(String option) {
    switch (_normalizeReminderOption(option)) {
      case '1 day before':
        return const Duration(days: 1);
      case '1h before':
        return const Duration(hours: 1);
      case '10 min before':
        return const Duration(minutes: 10);
      default:
        return null;
    }
  }

  String _encodeReminderSelections(Set<String> selections) {
    if (selections.isEmpty) return 'None';
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
  static const MethodChannel _androidWidgetChannel = MethodChannel(
    'tamago/widget',
  );
  static const MethodChannel _androidNotifChannel = MethodChannel(
    'tamago/notifications',
  );
  static const List<String> _reminderOptions = <String>[
    '1 day before',
    '1h before',
    '10 min before',
  ];

  final TextEditingController _quickAddTaskController = TextEditingController();
  final TextEditingController _quickAddProjectController =
      TextEditingController();
  final TextEditingController _quickAddProjectTaskController =
      TextEditingController();
  final TextEditingController _headerSearchController = TextEditingController();
  final TextEditingController _weekNotesController = TextEditingController();
  final ScrollController _planningDayScrollController = ScrollController();
  final GlobalKey _goToCurrentWeekButtonKey = GlobalKey();

  final List<TaskItem> _tasks = [];
  final List<ProjectItem> _projects = [];
  Timer? _clockTimer;
  DateTime _liveNow = DateTime.now();
  final Map<String, _ReminderNotice> _activeReminders =
      <String, _ReminderNotice>{};
  final Set<String> _dismissedReminderIds = <String>{};
  final Map<String, String> _weekNotesByWeekKey = <String, String>{};
  bool _mobileNotificationsReady = false;

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
    _loadWeekNotes();
    unawaited(_initializeMobileNotifications());
    unawaited(_requestBatteryOptimizationExemption());
  }

  @override
  void dispose() {
    debugPrint('[Tamago][Lifecycle] dispose');
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _quickAddTaskController.dispose();
    _quickAddProjectController.dispose();
    _quickAddProjectTaskController.dispose();
    _headerSearchController.dispose();
    _weekNotesController.dispose();
    _planningDayScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
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

  bool get _supportsScheduledTaskNotifications {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _initializeMobileNotifications() async {
    if (!_supportsScheduledTaskNotifications || _mobileNotificationsReady) {
      return;
    }

    tz.initializeTimeZones();
    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
      debugPrint('[Tamago][Notif] timezone=$timezoneName');
    } catch (e) {
      debugPrint('[Tamago][Notif] timezone error: $e');
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _localNotificationsPlugin.initialize(initializationSettings);

    final androidImpl = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.createNotificationChannel(_taskReminderChannel);

    final notifGranted = await androidImpl?.requestNotificationsPermission();
    debugPrint('[Tamago][Notif] notifPermission=$notifGranted');

    // Android 12+ requires user to grant exact alarm permission via Settings
    final canExact = await androidImpl?.canScheduleExactNotifications();
    debugPrint('[Tamago][Notif] canScheduleExact=$canExact');
    if (canExact == false) {
      await androidImpl?.requestExactAlarmsPermission();
    }

    final iosImplementation = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosImplementation?.requestPermissions(
      alert: true,
      badge: false,
      sound: true,
    );

    _mobileNotificationsReady = true;
    debugPrint('[Tamago][Notif] initialized, tasks=${_tasks.length}');
    // Reschedule now that init is done (tasks may already be loaded)
    await _scheduleMobileTaskNotifications();
  }

  Iterable<DateTime> _notificationOccurrenceDatesForTask(
    TaskItem task,
    DateTime startDay,
    DateTime endDay,
  ) sync* {
    if (task.date == null) {
      return;
    }

    var currentDay = startDay;
    while (!currentDay.isAfter(endDay)) {
      if (_taskOccursOnDate(task, currentDay)) {
        yield currentDay;
      }
      currentDay = currentDay.add(const Duration(days: 1));
    }
  }

  int _notificationIntId(String rawValue) {
    var hash = 0;
    for (final codeUnit in rawValue.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return hash;
  }

  Future<void> _scheduleMobileTaskNotifications() async {
    if (!_supportsScheduledTaskNotifications || !_mobileNotificationsReady) {
      debugPrint(
        '[Tamago][Notif] skip: supported=$_supportsScheduledTaskNotifications ready=$_mobileNotificationsReady',
      );
      return;
    }

    await _localNotificationsPlugin.cancelAll();

    // Determine whether exact alarms are permitted
    final androidImpl = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final canExact =
        await androidImpl?.canScheduleExactNotifications() ?? false;
    final scheduleMode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    debugPrint(
      '[Tamago][Notif] scheduling with mode=${canExact ? "exact" : "inexact"}, tasks=${_tasks.length}',
    );

    final now = DateTime.now();
    final startDay = _dateOnly(now);
    final endDay = startDay.add(const Duration(days: 30));
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'tamago_task_reminders',
        'Task reminders',
        channelDescription: 'Reminders for scheduled Tamago tasks',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );

    var scheduledCount = 0;
    for (final task in _tasks) {
      if (task.startTime == null) {
        continue;
      }

      final reminderSelections = _parseReminderSelections(task.reminder);
      if (reminderSelections.isEmpty) {
        continue;
      }

      for (final occurrenceDate in _notificationOccurrenceDatesForTask(
        task,
        startDay,
        endDay,
      )) {
        final startDateTime = _withTime(occurrenceDate, task.startTime!);
        for (final reminderOption in reminderSelections) {
          final offset = _reminderOffset(reminderOption);
          if (offset == null) {
            continue;
          }

          final scheduledAt = startDateTime.subtract(offset);
          if (!scheduledAt.isAfter(now)) {
            continue;
          }

          final reminderId = _reminderId(task, occurrenceDate, reminderOption);
          await _localNotificationsPlugin.zonedSchedule(
            _notificationIntId(reminderId),
            task.name,
            'Reminder ${_normalizeReminderOption(reminderOption)} - ${_formatMonthDayUs(occurrenceDate)} ${_formatTimeUs(task.startTime!)}',
            tz.TZDateTime.fromMillisecondsSinceEpoch(
              tz.local,
              scheduledAt.millisecondsSinceEpoch,
            ),
            notificationDetails,
            androidScheduleMode: scheduleMode,
          );
          scheduledCount++;
          debugPrint(
            '[Tamago][Notif] scheduled "${task.name}" at $scheduledAt',
          );
        }
      }
    }
    debugPrint('[Tamago][Notif] total scheduled: $scheduledCount');
    try {
      final pending = await _localNotificationsPlugin
          .pendingNotificationRequests();
      debugPrint('[Tamago][Notif] plugin pending count=${pending.length}');
      for (final request in pending.take(5)) {
        debugPrint(
          '[Tamago][Notif] pending id=${request.id} title=${request.title}',
        );
      }
    } catch (e) {
      debugPrint('[Tamago][Notif] pending read error: $e');
    }
  }

  Future<void> _requestBatteryOptimizationExemption() async {
    if (!_supportsScheduledTaskNotifications) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final ignoring =
          await _androidNotifChannel.invokeMethod<bool>(
            'isIgnoringBatteryOptimizations',
          ) ??
          true;
      debugPrint('[Tamago][Notif] isIgnoringBatteryOptimizations=$ignoring');
      if (!ignoring) {
        await _androidNotifChannel.invokeMethod<void>(
          'requestIgnoreBatteryOptimizations',
        );
      }
    } catch (e) {
      debugPrint('[Tamago][Notif] battery opt error: $e');
    }
  }

  List<String> _parseReminderSelections(String rawReminder) {
    final trimmed = rawReminder.trim();
    if (trimmed.isEmpty || trimmed == 'None') {
      return const <String>[];
    }
    final tokens = trimmed
        .split(RegExp(r'\||,'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty && value != 'None')
        .map(_normalizeReminderOption)
        .where((value) => value != 'None')
        .toList();
    return tokens;
  }

  String _reminderId(
    TaskItem task,
    DateTime occurrenceDate,
    String reminderOption,
  ) {
    final start = task.startTime;
    final startLabel = start == null ? 'none' : '${start.hour}:${start.minute}';
    final dateLabel = task.date?.toIso8601String() ?? 'none';
    final endDateLabel = task.endDate?.toIso8601String() ?? 'none';
    return '${task.name}|$dateLabel|$endDateLabel|$startLabel|${occurrenceDate.toIso8601String()}|$reminderOption';
  }

  void _refreshLiveNowAndReminders() {
    if (!mounted) {
      return;
    }

    final now = DateTime.now();
    final today = _dateOnly(now);
    _rollForwardPendingTasksIfNeeded(today);
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
                    'Reminder ${_normalizeReminderOption(reminderOption)} - ${_formatMonthDayUs(occurrenceDate)} ${_formatTimeUs(task.startTime!)}',
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

  int? _weekdayFromLabel(String label) {
    switch (label) {
      case 'Monday':
        return DateTime.monday;
      case 'Tuesday':
        return DateTime.tuesday;
      case 'Wednesday':
        return DateTime.wednesday;
      case 'Thursday':
        return DateTime.thursday;
      case 'Friday':
        return DateTime.friday;
      case 'Saturday':
        return DateTime.saturday;
      case 'Sunday':
        return DateTime.sunday;
      default:
        return null;
    }
  }

  bool _taskOccursOnDate(TaskItem task, DateTime date) {
    if (task.date == null) {
      return false;
    }

    final day = _dateOnly(date);
    final taskDate = _dateOnly(task.date!);
    final taskEndDate = _dateOnly(task.endDate ?? task.date!);
    if (day.isBefore(taskDate)) {
      return false;
    }
    if (day.isAfter(taskEndDate)) {
      return false;
    }

    switch (task.recurrence) {
      case 'None':
        return !day.isBefore(taskDate) && !day.isAfter(taskEndDate);
      case 'Daily':
        return !day.isBefore(taskDate) && !day.isAfter(taskEndDate);
      case 'Monthly':
        return !day.isBefore(taskDate) &&
            !day.isAfter(taskEndDate) &&
            day.day == taskDate.day;
      case 'Weekly':
        return !day.isBefore(taskDate) &&
            !day.isAfter(taskEndDate) &&
            day.weekday == taskDate.weekday;
      default:
        if (task.recurrence.startsWith('Days:')) {
          final rawDays = task.recurrence
              .substring('Days:'.length)
              .split(',')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList();
          final weekdays = rawDays
              .map(_weekdayFromLabel)
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
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[date.weekday - 1];
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  String _formatMonthDayUs(DateTime value) {
    return '${_twoDigits(value.month)}/${_twoDigits(value.day)}';
  }

  String _formatDateUs(DateTime value) {
    return '${_formatMonthDayUs(value)}/${value.year}';
  }

  String _formatOptionalDateUs(DateTime? value, {String fallback = 'Not set'}) {
    if (value == null) {
      return fallback;
    }
    return _formatDateUs(value);
  }

  String _formatTimeUs(TimeOfDay value) {
    final hour = value.hourOfPeriod == 0 ? 12 : value.hourOfPeriod;
    final suffix = value.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:${_twoDigits(value.minute)} $suffix';
  }

  Future<void> _showPlanningMonthPickerPopup() async {
    final buttonContext = _goToCurrentWeekButtonKey.currentContext;
    if (buttonContext == null) {
      return;
    }

    final buttonBox = buttonContext.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (buttonBox == null || overlayBox == null) {
      return;
    }

    final topLeft = buttonBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final bottomRight = buttonBox.localToGlobal(
      buttonBox.size.bottomRight(Offset.zero),
      ancestor: overlayBox,
    );
    final overlaySize = overlayBox.size;

    final pickedDate = await showDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black12,
      builder: (dialogContext) {
        DateTime visibleMonth = DateTime(_todayOnly.year, _todayOnly.month, 1);
        final selectedDate = _dateOnly(_planningAnchorDate);

        return StatefulBuilder(
          builder: (context, setPopupState) {
            final firstOfMonth = DateTime(
              visibleMonth.year,
              visibleMonth.month,
              1,
            );
            final leadingEmptyDays = firstOfMonth.weekday - 1;
            final daysInMonth = DateTime(
              visibleMonth.year,
              visibleMonth.month + 1,
              0,
            ).day;
            final totalCells = ((leadingEmptyDays + daysInMonth + 6) ~/ 7) * 7;

            const popupWidth = 290.0;
            const popupHeight = 324.0;
            final left = topLeft.dx.clamp(
              8.0,
              (overlaySize.width - popupWidth - 8).clamp(8.0, double.infinity),
            );
            final top = (bottomRight.dy + 6).clamp(
              8.0,
              (overlaySize.height - popupHeight - 8).clamp(
                8.0,
                double.infinity,
              ),
            );

            return Stack(
              children: [
                Positioned(
                  left: left,
                  top: top,
                  child: Material(
                    elevation: 10,
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white,
                    child: SizedBox(
                      width: popupWidth,
                      height: popupHeight,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    setPopupState(() {
                                      visibleMonth = DateTime(
                                        visibleMonth.year,
                                        visibleMonth.month - 1,
                                        1,
                                      );
                                    });
                                  },
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.chevron_left),
                                  tooltip: 'Previous month',
                                ),
                                Expanded(
                                  child: Text(
                                    '${_fullMonthLabel(visibleMonth)} ${visibleMonth.year}',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    setPopupState(() {
                                      visibleMonth = DateTime(
                                        visibleMonth.year,
                                        visibleMonth.month + 1,
                                        1,
                                      );
                                    });
                                  },
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.chevron_right),
                                  tooltip: 'Next month',
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children:
                                  const [
                                    'Mon',
                                    'Tue',
                                    'Wed',
                                    'Thu',
                                    'Fri',
                                    'Sat',
                                    'Sun',
                                  ].map((label) {
                                    return Expanded(
                                      child: Center(
                                        child: Text(
                                          label,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: GridView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: totalCells,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 7,
                                      crossAxisSpacing: 4,
                                      mainAxisSpacing: 4,
                                    ),
                                itemBuilder: (context, index) {
                                  final dayNumber =
                                      index - leadingEmptyDays + 1;
                                  if (dayNumber < 1 ||
                                      dayNumber > daysInMonth) {
                                    return const SizedBox.shrink();
                                  }

                                  final day = DateTime(
                                    visibleMonth.year,
                                    visibleMonth.month,
                                    dayNumber,
                                  );
                                  final isToday = _isSameDay(day, _todayOnly);
                                  final isSelected = _isSameDay(
                                    day,
                                    selectedDate,
                                  );

                                  Color? backgroundColor;
                                  Color? borderColor;
                                  Color textColor = Colors.black87;

                                  if (isSelected) {
                                    backgroundColor = const Color(0xFFEAF2FF);
                                    borderColor = const Color(0xFF6F9BFF);
                                  }
                                  if (isToday) {
                                    backgroundColor = const Color(0xFFFFF1C7);
                                    borderColor = const Color(0xFFFFC24A);
                                    textColor = Colors.black;
                                  }

                                  return InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () {
                                      Navigator.of(dialogContext).pop(day);
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: backgroundColor,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color:
                                              borderColor ?? Colors.transparent,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$dayNumber',
                                          style: TextStyle(
                                            color: textColor,
                                            fontWeight: isToday
                                                ? FontWeight.w700
                                                : FontWeight.w500,
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
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    setState(() {
      _planningAnchorDate = _dateOnly(pickedDate);
    });
    _syncWeekNotesControllerForDate(_planningAnchorDate);
  }

  String _timeRangeLabel(TaskItem task) {
    if (task.startTime == null || task.endTime == null) {
      return 'No time set';
    }
    return '${_twoDigits(task.startTime!.hour)}:${_twoDigits(task.startTime!.minute)} - ${_twoDigits(task.endTime!.hour)}:${_twoDigits(task.endTime!.minute)}';
  }

  bool _isRecurringTask(TaskItem task) {
    return task.recurrence != 'None';
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
    final normalizedDate = _dateOnly(date);
    final newTask = TaskItem(
      name: 'New task',
      date: normalizedDate,
      endDate: normalizedDate,
    );
    await _openTaskEditor(newTask, isNew: true);
  }

  String _nextStatus(String currentStatus) {
    switch (currentStatus) {
      case 'To do':
        return 'In progress';
      case 'In progress':
        return 'Done';
      case 'Done':
        return 'To do';
      default:
        return 'To do';
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'In progress':
        return Icons.timelapse_rounded;
      case 'Done':
        return Icons.check_circle_rounded;
      default:
        return Icons.radio_button_unchecked_rounded;
    }
  }

  List<TaskItem> get _todayTasks {
    return _tasksForDate(
      _todayOnly,
    ).where((task) => task.status != 'Done').toList();
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
    final tasks = _tasks
        .where((task) => _taskBelongsToProject(task, project))
        .toList();

    tasks.sort((a, b) {
      final aDate = a.date;
      final bDate = b.date;
      if (aDate == null && bDate != null) {
        return -1;
      }
      if (aDate != null && bDate == null) {
        return 1;
      }
      if (aDate != null && bDate != null) {
        final byStartDate = aDate.compareTo(bDate);
        if (byStartDate != 0) {
          return byStartDate;
        }

        final aEndDate = a.endDate ?? aDate;
        final bEndDate = b.endDate ?? bDate;
        final byEndDate = aEndDate.compareTo(bEndDate);
        if (byEndDate != 0) {
          return byEndDate;
        }
      }

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return tasks;
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
      // ignore: deprecated_member_use
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

  void _addTaskFromPrompt() {
    final taskName = _quickAddTaskController.text.trim();
    if (taskName.isEmpty) {
      return;
    }

    setState(() {
      _tasks.insert(
        0,
        TaskItem(name: taskName, date: _todayOnly, endDate: _todayOnly),
      );
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

    final today = _todayOnly;
    final didRollPendingTasks = _rollForwardPendingTasks(loadedTasks, today);
    _lastPendingTaskRollDate = today;

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
    if (didRollPendingTasks) {
      unawaited(_saveTasks());
    } else {
      _refreshLiveNowAndReminders();
      _updateAndroidTodayWidget();
      // Always reschedule after load — init may have finished first with empty tasks
      unawaited(_scheduleMobileTaskNotifications());
    }
    // If init finished before load, reschedule now that tasks are populated
    if (_mobileNotificationsReady) {
      unawaited(_scheduleMobileTaskNotifications());
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = _tasks.map((task) => task.toJson()).toList();
    await prefs.setString(_tasksStorageKey, jsonEncode(payload));
    _refreshLiveNowAndReminders();
    _updateAndroidTodayWidget();
    await _scheduleMobileTaskNotifications();
  }

  Future<void> _updateAndroidTodayWidget() async {
    try {
      await _androidWidgetChannel.invokeMethod<void>('updateTodayTasksWidget');
    } catch (_) {}
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

  List<String> _searchTokens(String query) {
    return query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  bool _matchesTokens(List<String> tokens, String haystack) {
    if (tokens.isEmpty) {
      return false;
    }
    final normalized = haystack.toLowerCase();
    return tokens.every(normalized.contains);
  }

  bool _containsAtLeastOneToken(List<String> tokens, String value) {
    if (tokens.isEmpty) {
      return false;
    }
    final normalized = value.toLowerCase();
    return tokens.any(normalized.contains);
  }

  List<_SearchMatchedField> _collectMatchedFields(
    List<String> tokens,
    List<MapEntry<String, String>> fields,
  ) {
    return fields
        .where(
          (field) =>
              field.value.trim().isNotEmpty &&
              _containsAtLeastOneToken(tokens, field.value),
        )
        .map(
          (field) =>
              _SearchMatchedField(label: field.key, value: field.value.trim()),
        )
        .toList();
  }

  String _collapseSearchText(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<String> _extractSentences(String value) {
    final normalized = value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final sentences = <String>[];
    final buffer = StringBuffer();

    void flush() {
      final sentence = _collapseSearchText(buffer.toString());
      if (sentence.isNotEmpty) {
        sentences.add(sentence);
      }
      buffer.clear();
    }

    for (var index = 0; index < normalized.length; index++) {
      final character = normalized[index];
      buffer.write(character);
      final isSentenceBreak =
          character == '.' ||
          character == '!' ||
          character == '?' ||
          character == '\n';
      if (isSentenceBreak) {
        flush();
      }
    }

    flush();
    return sentences;
  }

  String _matchingNoteExcerpt(List<String> tokens, String noteText) {
    final sentences = _extractSentences(noteText);
    final matches = sentences
        .where((sentence) => _containsAtLeastOneToken(tokens, sentence))
        .toList();
    if (matches.isNotEmpty) {
      return matches.join(' ');
    }

    final compact = _collapseSearchText(noteText);
    if (compact.isEmpty) {
      return 'Empty note';
    }
    return compact.length > 160 ? '${compact.substring(0, 160)}...' : compact;
  }

  List<_GlobalSearchResult> _buildGlobalSearchResults(String query) {
    final tokens = _searchTokens(query);
    if (tokens.isEmpty) {
      return const <_GlobalSearchResult>[];
    }

    final results = <_GlobalSearchResult>[];

    for (final task in _tasks) {
      final dateLabel = _formatOptionalDateUs(task.date, fallback: 'No date');
      final linkedProject = _projectForTask(task);
      final projectName = linkedProject?.name ?? task.project;
      final taskText = [
        task.name,
        projectName,
        task.contact,
        task.status,
        task.recurrence,
        dateLabel,
      ].join(' ');
      if (_matchesTokens(tokens, taskText)) {
        final matchedFields = _collectMatchedFields(tokens, [
          MapEntry('Name', task.name),
          MapEntry('Project', task.project),
          MapEntry('Contact', task.contact),
          MapEntry('Status', task.status),
          MapEntry('Recurrence', task.recurrence),
          MapEntry('Date', dateLabel),
        ]);
        results.add(
          _GlobalSearchResult(
            category: 'Task',
            title: task.name,
            subtitle: projectName.isEmpty ? '' : 'Project: $projectName',
            matchedFields: matchedFields,
            meta: dateLabel,
            onTap: () {
              _openTaskEditor(task);
            },
          ),
        );
      }
    }

    for (final project in _projects) {
      final projectText = [
        project.name,
        project.description,
        project.status,
      ].join(' ');
      if (_matchesTokens(tokens, projectText)) {
        final matchedFields = _collectMatchedFields(tokens, [
          MapEntry('Name', project.name),
          MapEntry('Description', project.description),
          MapEntry('Status', project.status),
        ]);
        results.add(
          _GlobalSearchResult(
            category: 'Project',
            title: 'Project: ${project.name}',
            subtitle: '',
            matchedFields: matchedFields,
            meta: _formatDateUs(project.startDate),
            onTap: () {
              _openProjectEditor(project);
            },
          ),
        );
      }
    }

    for (final entry in _weekNotesByWeekKey.entries) {
      final noteText = '${entry.key} ${entry.value}';
      if (_matchesTokens(tokens, noteText)) {
        final parsedWeek = DateTime.tryParse(entry.key);
        final weekKey = entry.key;
        final excerpt = _matchingNoteExcerpt(tokens, entry.value);
        final matchedFields = _collectMatchedFields(tokens, [
          MapEntry('Week', entry.key),
          MapEntry('Note', entry.value),
        ]);
        results.add(
          _GlobalSearchResult(
            category: 'Note',
            title: 'Note',
            subtitle: excerpt,
            matchedFields: matchedFields,
            onTap: parsedWeek == null
                ? null
                : () {
                    setState(() {
                      _currentView = MainView.planning;
                      _planningAnchorDate = parsedWeek;
                    });
                    _syncWeekNotesControllerForDate(_planningAnchorDate);
                  },
            noteContent: entry.value,
            onNoteChanged: (newValue) {
              setState(() {
                if (newValue.trim().isEmpty) {
                  _weekNotesByWeekKey.remove(weekKey);
                } else {
                  _weekNotesByWeekKey[weekKey] = newValue;
                }
              });
              _saveWeekNotes();
              _syncWeekNotesControllerForDate(_planningAnchorDate);
            },
          ),
        );
      }
    }

    return results;
  }

  void _openSearchResultsPage() {
    final query = _headerSearchController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter keywords to start searching.')),
      );
      return;
    }

    final results = _buildGlobalSearchResults(query);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            _SearchResultsPage(query: query, results: results),
      ),
    );
  }

  Future<void> _openTaskEditor(TaskItem task, {bool isNew = false}) async {
    final nameController = TextEditingController(text: task.name);
    final durationController = TextEditingController(text: task.duration);
    final contactController = TextEditingController(text: task.contact);

    final defaultNewTaskDate = isNew && _currentView != MainView.projects
        ? _todayOnly
        : null;
    DateTime? selectedDate = task.date == null
        ? defaultNewTaskDate
        : _dateOnly(task.date!);
    DateTime? selectedEndDate = task.endDate == null
        ? selectedDate
        : _dateOnly(task.endDate!);
    if (selectedDate == null) {
      selectedEndDate = null;
    } else if (selectedEndDate != null &&
        selectedEndDate.isBefore(selectedDate)) {
      selectedEndDate = selectedDate;
    }
    bool allDay = task.allDay;
    TimeOfDay? startTime = task.startTime;
    TimeOfDay? endTime = task.endTime;
    final selectedReminders = _parseReminderSelections(task.reminder).toSet();
    String recurrence = task.recurrence;
    String status = task.status;
    const weekdays = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    String recurrenceMode = 'None';
    final selectedWeekdays = <String>{};

    if (recurrence == 'Daily' ||
        recurrence == 'Monthly' ||
        recurrence == 'None') {
      recurrenceMode = recurrence;
    } else if (recurrence == 'Weekly' && selectedDate != null) {
      recurrenceMode = 'Weekdays';
      selectedWeekdays.add(weekdays[selectedDate.weekday - 1]);
    } else if (recurrence.startsWith('Days:')) {
      recurrenceMode = 'Weekdays';
      final rawDays = recurrence
          .substring('Days:'.length)
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

    String timeLabel(BuildContext context, TimeOfDay? value) {
      if (value == null) {
        return '--:--';
      }
      return MaterialLocalizations.of(
        context,
      ).formatTimeOfDay(value, alwaysUse24HourFormat: false);
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

    var controllersDisposed = false;
    void disposeTaskControllers() {
      if (controllersDisposed) {
        return;
      }
      controllersDisposed = true;
      nameController.dispose();
      durationController.dispose();
      contactController.dispose();
    }

    Future<void> closeDialogSafely(BuildContext dialogContext) async {
      final navigator = Navigator.of(dialogContext);
      FocusManager.instance.primaryFocus?.unfocus();
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (!mounted) {
        return;
      }
      if (navigator.canPop()) {
        navigator.pop();
      }
    }

    if (!mounted) {
      disposeTaskControllers();
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
                initialDate: selectedDate ?? _todayOnly,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (pickedDate != null) {
                setModalState(() {
                  selectedDate = pickedDate;
                  if (selectedEndDate != null &&
                      selectedEndDate!.isBefore(selectedDate!)) {
                    selectedEndDate = selectedDate;
                  }
                });
              }
            }

            Future<void> pickEndDate() async {
              if (selectedDate == null) {
                return;
              }
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: selectedEndDate ?? selectedDate!,
                firstDate: selectedDate!,
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
                builder: (context, child) {
                  final mediaQuery = MediaQuery.of(context);
                  return MediaQuery(
                    data: mediaQuery.copyWith(alwaysUse24HourFormat: false),
                    child: child ?? const SizedBox.shrink(),
                  );
                },
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
                builder: (context, child) {
                  final mediaQuery = MediaQuery.of(context);
                  return MediaQuery(
                    data: mediaQuery.copyWith(alwaysUse24HourFormat: false),
                    child: child ?? const SizedBox.shrink(),
                  );
                },
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
              'None',
              'Daily',
              'Weekdays',
              'Monthly',
            };
            const statusOptions = <String>{'To do', 'In progress', 'Done'};
            final effectiveRecurrenceMode =
                recurrenceOptions.contains(recurrenceMode)
                ? recurrenceMode
                : 'None';
            final effectiveStatus = statusOptions.contains(status)
                ? status
                : 'To do';
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
                                              prefixIcon: Icon(Icons.title),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          TextField(
                                            controller: contactController,
                                            decoration: const InputDecoration(
                                              prefixIcon: Icon(Icons.person),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ListTile(
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  leading: const Icon(
                                                    Icons.calendar_month,
                                                  ),
                                                  title: Text(
                                                    _formatOptionalDateUs(
                                                      selectedDate,
                                                      fallback: 'No start date',
                                                    ),
                                                  ),
                                                  onTap: pickDate,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  onPressed:
                                                      allDay ||
                                                          selectedDate == null
                                                      ? null
                                                      : pickStartTime,
                                                  icon: const Icon(
                                                    Icons.schedule,
                                                  ),
                                                  label: Text(
                                                    timeLabel(
                                                      context,
                                                      startTime,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ListTile(
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  leading: const Icon(
                                                    Icons.event_available,
                                                  ),
                                                  title: Text(
                                                    _formatOptionalDateUs(
                                                      selectedEndDate,
                                                      fallback: 'No end date',
                                                    ),
                                                  ),
                                                  onTap: selectedDate == null
                                                      ? null
                                                      : pickEndDate,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  onPressed:
                                                      allDay ||
                                                          selectedDate == null
                                                      ? null
                                                      : pickEndTime,
                                                  icon: const Icon(
                                                    Icons.schedule_send,
                                                  ),
                                                  label: Text(
                                                    timeLabel(context, endTime),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Expanded(
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
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: TextField(
                                                  controller:
                                                      durationController,
                                                  enabled: !allDay,
                                                  decoration:
                                                      const InputDecoration(
                                                        prefixIcon: Icon(
                                                          Icons.timer,
                                                        ),
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
                                              const Icon(
                                                Icons.notifications_none,
                                                size: 20,
                                                color: Colors.black54,
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
                                              if (selectedReminders.isNotEmpty)
                                                const SizedBox(height: 6),
                                              if (selectedReminders.isNotEmpty)
                                                Text(
                                                  '${selectedReminders.length} reminder(s) selected',
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall,
                                                ),
                                              if (selectedDate == null)
                                                Text(
                                                  'Set a start date to enable reminders.',
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
                                              prefixIcon: Icon(Icons.repeat),
                                            ),
                                            items: const [
                                              DropdownMenuItem(
                                                value: 'None',
                                                child: Text('None'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'Daily',
                                                child: Text('Daily'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'Weekdays',
                                                child: Text('Weekdays'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'Monthly',
                                                child: Text('Monthly'),
                                              ),
                                            ],
                                            onChanged: selectedDate == null
                                                ? null
                                                : (value) {
                                                    if (value != null) {
                                                      setModalState(() {
                                                        recurrenceMode = value;
                                                        if (value !=
                                                            'Weekdays') {
                                                          selectedWeekdays
                                                              .clear();
                                                        }
                                                      });
                                                    }
                                                  },
                                          ),
                                          if (effectiveRecurrenceMode ==
                                              'Weekdays') ...[
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
                                                  onSelected:
                                                      selectedDate == null
                                                      ? null
                                                      : (selected) {
                                                          setModalState(() {
                                                            if (selected) {
                                                              selectedWeekdays
                                                                  .add(day);
                                                            } else {
                                                              selectedWeekdays
                                                                  .remove(day);
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
                                              prefixIcon: Icon(Icons.flag),
                                            ),
                                            items: const [
                                              DropdownMenuItem(
                                                value: 'To do',
                                                child: Text('To do'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'In progress',
                                                child: Text('In progress'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'Done',
                                                child: Text('Done'),
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
                                          DropdownButtonFormField<String>(
                                            initialValue:
                                                effectiveSelectedProjectId,
                                            decoration: const InputDecoration(
                                              prefixIcon: Icon(Icons.folder),
                                            ),
                                            items: [
                                              const DropdownMenuItem(
                                                value: '',
                                                child: Text('None'),
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
                                      TextButton(
                                        onPressed: () async {
                                          await closeDialogSafely(context);
                                        },
                                        child: const Text('Cancel'),
                                      ),
                                      if (!isNew) const SizedBox(width: 6),
                                      if (!isNew)
                                        TextButton(
                                          onPressed: () async {
                                            setState(() {
                                              _tasks.remove(task);
                                            });
                                            _saveTasks();
                                            await closeDialogSafely(context);
                                          },
                                          child: const Text('Delete'),
                                        ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: FilledButton(
                                          onPressed: () async {
                                            if (!allDay &&
                                                selectedDate != null) {
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
                                                  'Duration must be positive (e.g., 01:30).',
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
                                                    'End time must be after start time.',
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
                                                  selectedDate == null
                                                  ? null
                                                  : selectedEndDate == null
                                                  ? null
                                                  : selectedEndDate!.isBefore(
                                                      selectedDate!,
                                                    )
                                                  ? selectedDate
                                                  : selectedEndDate;
                                              task.allDay = selectedDate == null
                                                  ? false
                                                  : allDay;
                                              task.startTime =
                                                  selectedDate == null || allDay
                                                  ? null
                                                  : startTime;
                                              task.endTime =
                                                  selectedDate == null || allDay
                                                  ? null
                                                  : endTime;
                                              task.duration =
                                                  selectedDate == null
                                                  ? ''
                                                  : durationController.text
                                                        .trim();
                                              task.reminder =
                                                  selectedDate == null
                                                  ? 'None'
                                                  : _encodeReminderSelections(
                                                      selectedReminders,
                                                    );
                                              if (selectedDate == null) {
                                                recurrence = 'None';
                                              } else if (recurrenceMode ==
                                                  'Weekdays') {
                                                final orderedDays = weekdays
                                                    .where(
                                                      (day) => selectedWeekdays
                                                          .contains(day),
                                                    );
                                                recurrence = orderedDays.isEmpty
                                                    ? 'None'
                                                    : 'Days:${orderedDays.join(',')}';
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
                                            await closeDialogSafely(context);
                                          },
                                          child: const Text('Save'),
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
    disposeTaskControllers();
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
      return _formatDateUs(value);
    }

    var controllersDisposed = false;
    void disposeProjectControllers() {
      if (controllersDisposed) {
        return;
      }
      controllersDisposed = true;
      nameController.dispose();
      descriptionController.dispose();
    }

    Future<void> closeDialogSafely(BuildContext dialogContext) async {
      final navigator = Navigator.of(dialogContext);
      FocusManager.instance.primaryFocus?.unfocus();
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (!mounted) {
        return;
      }
      if (navigator.canPop()) {
        navigator.pop();
      }
    }

    if (!mounted) {
      disposeProjectControllers();
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

            const statusOptions = <String>{'To do', 'In progress', 'Done'};
            final effectiveStatus = statusOptions.contains(status)
                ? status
                : 'To do';

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
                                          TextField(
                                            controller: nameController,
                                            decoration: const InputDecoration(
                                              prefixIcon: Icon(Icons.title),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: const Icon(
                                              Icons.calendar_month,
                                            ),
                                            title: Text(formatDate(startDate)),
                                            onTap: pickStartDate,
                                          ),
                                          ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: const Icon(
                                              Icons.event_available,
                                            ),
                                            title: Text(
                                              endDate == null
                                                  ? 'Not set'
                                                  : formatDate(endDate!),
                                            ),
                                            onTap: pickEndDate,
                                          ),
                                          const SizedBox(height: 12),
                                          TextField(
                                            controller: descriptionController,
                                            minLines: 2,
                                            maxLines: 5,
                                            decoration: const InputDecoration(
                                              prefixIcon: Icon(Icons.notes),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          DropdownButtonFormField<String>(
                                            initialValue: effectiveStatus,
                                            decoration: const InputDecoration(
                                              prefixIcon: Icon(Icons.flag),
                                            ),
                                            items: const [
                                              DropdownMenuItem(
                                                value: 'To do',
                                                child: Text('To do'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'In progress',
                                                child: Text('In progress'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'Done',
                                                child: Text('Done'),
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
                                          const Icon(
                                            Icons.palette,
                                            size: 20,
                                            color: Colors.black54,
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: ProjectColorOption.values.map((
                                              colorOption,
                                            ) {
                                              final isSelected =
                                                  selectedColor == colorOption;
                                              return Tooltip(
                                                message: colorOption.label,
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    onTap: () {
                                                      setModalState(() {
                                                        selectedColor =
                                                            colorOption;
                                                      });
                                                    },
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          999,
                                                        ),
                                                    child: AnimatedContainer(
                                                      duration: const Duration(
                                                        milliseconds: 120,
                                                      ),
                                                      width: 34,
                                                      height: 34,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            colorOption.color,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: isSelected
                                                              ? Colors.black87
                                                              : Colors.black12,
                                                          width: isSelected
                                                              ? 3
                                                              : 1,
                                                        ),
                                                      ),
                                                      child: isSelected
                                                          ? const Icon(
                                                              Icons.check,
                                                              size: 18,
                                                              color:
                                                                  Colors.white,
                                                            )
                                                          : null,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
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
                                                  name: 'New task',
                                                  project: projectName,
                                                  projectId: project.id,
                                                  color:
                                                      _taskColorFromProjectColor(
                                                        selectedColor,
                                                      ),
                                                );
                                                await closeDialogSafely(
                                                  context,
                                                );
                                                await _openTaskEditor(
                                                  newTask,
                                                  isNew: true,
                                                );
                                              },
                                              icon: const Icon(Icons.add_task),
                                              label: const Text('Add a task'),
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
                                        onPressed: () async {
                                          await closeDialogSafely(context);
                                        },
                                        child: const Text('Cancel'),
                                      ),
                                      const SizedBox(width: 6),
                                      TextButton(
                                        onPressed: () async {
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
                                          await closeDialogSafely(context);
                                        },
                                        child: const Text('Delete'),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: FilledButton(
                                          onPressed: () async {
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
                                            await closeDialogSafely(context);
                                          },
                                          child: const Text('Save'),
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
    disposeProjectControllers();
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
              message: 'Week',
              child: buildButton(
                icon: Icons.calendar_view_week_rounded,
                view: MainView.planning,
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: 'Projects',
              child: buildButton(
                icon: Icons.rocket_launch_rounded,
                view: MainView.projects,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(child: _buildHeaderSearch()),
      ],
    );
  }

  Widget _buildHeaderSearch() {
    return Container(
      height: 40,
      padding: const EdgeInsets.only(left: 10, right: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _headerSearchController,
              maxLines: 1,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _openSearchResultsPage(),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Search tasks, projects, and notes...',
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _headerSearchController.clear();
              });
            },
            tooltip: 'Clear search',
            icon: const Icon(
              Icons.close_rounded,
              size: 17,
              color: Colors.black54,
            ),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: _openSearchResultsPage,
            tooltip: 'Run search',
            icon: const Icon(
              Icons.search_rounded,
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
            tooltip: 'Change status',
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
            tooltip: collapsed ? 'Show' : 'Collapse',
            icon: Icon(collapsed ? Icons.unfold_more : Icons.unfold_less),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: onExpandPressed,
            tooltip: expanded ? 'Exit full screen' : 'Full screen',
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
                        'No tasks for today.',
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
              title: _formatLongDateUs(_todayOnly),
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
              hintText: 'Enter the new task name...',
              suffixIcon: IconButton(
                onPressed: _addTaskFromPrompt,
                icon: const Icon(Icons.add),
                tooltip: 'Add',
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
                    tooltip: 'Change status',
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
                    tooltip: isExpanded ? 'Hide tasks' : 'Show tasks',
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
                          'No tasks for this project.',
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      : Column(
                          children: projectTasks.map((task) {
                            return Padding(
                              key: ValueKey(
                                'project-task-${project.id}-${task.name}-${task.date?.toIso8601String() ?? 'no-date'}',
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
              hintText: 'Enter the new project name...',
              suffixIcon: IconButton(
                onPressed: _addProjectFromPrompt,
                icon: const Icon(Icons.add),
                tooltip: 'Add project',
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
                hintText: 'Add a task to project "${selectedProject.name}"...',
                suffixIcon: IconButton(
                  onPressed: _addTaskToSelectedProjectFromPrompt,
                  icon: const Icon(Icons.add_task_outlined),
                  tooltip: 'Add task to project',
                ),
              ),
            ),
          if (selectedProject != null) const SizedBox(height: 14),
          Expanded(
            child: _projects.isEmpty
                ? Center(
                    child: Text(
                      'No project available.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                : ListView(children: _projects.map(buildProjectRow).toList()),
          ),
          if (selectedProject != null && selectedProjectTasks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Selected project: ${selectedProject.name} (${selectedProjectTasks.length} task(s))',
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
    final dayTasks = _tasksForDate(day);
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

    // Force la plage horaire � inclure l'heure actuelle
    // Toujours �largir la plage pour inclure l'heure actuelle
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
                                child: LayoutBuilder(
                                  builder: (context, cardConstraints) {
                                    final compact =
                                        cardConstraints.maxHeight < 58;

                                    return Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: compact ? 4 : 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border(
                                          left: BorderSide(
                                            color: _taskMarkerColor(
                                              layout.task,
                                            ),
                                            width: 1,
                                          ),
                                          top: BorderSide(
                                            color: _taskMarkerColor(
                                              layout.task,
                                            ),
                                            width: 1,
                                          ),
                                          right: BorderSide(
                                            color: _taskMarkerColor(
                                              layout.task,
                                            ),
                                            width: 1,
                                          ),
                                          bottom: BorderSide(
                                            color: _taskMarkerColor(
                                              layout.task,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: compact
                                          ? Align(
                                              alignment: Alignment.centerLeft,
                                              child:
                                                  _buildTaskNameWithRecurrenceIcon(
                                                    layout.task,
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                  ),
                                            )
                                          : Column(
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
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ],
                                            ),
                                    );
                                  },
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
                  'No tasks scheduled for this day.',
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
                            hintText: 'Write your weekly notes...',
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
                        '${_dayLabel(day)} ${_formatMonthDayUs(day)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (tasks.isEmpty)
                        Text(
                          'No tasks',
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
    final headerTitle = 'Week of ${_formatMonthDayUs(_startOfWeek(anchor))}';

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
                tooltip: 'Previous period',
              ),
              Expanded(
                child: Text(
                  headerTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                key: _goToCurrentWeekButtonKey,
                onPressed: () {
                  _showPlanningMonthPickerPopup();
                },
                icon: const Icon(Icons.today_rounded),
                tooltip: 'Pick a date and jump to its week',
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _planningAnchorDate = nextAnchor();
                  });
                  _syncWeekNotesControllerForDate(_planningAnchorDate);
                },
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next period',
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
                        tooltip: 'Close',
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

class _SearchResultsPage extends StatefulWidget {
  const _SearchResultsPage({required this.query, required this.results});

  final String query;
  final List<_GlobalSearchResult> results;

  @override
  State<_SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<_SearchResultsPage> {
  List<String> get _tokens => widget.query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();

  List<TextSpan> _highlightedSpans(String text, TextStyle baseStyle) {
    if (text.isEmpty || _tokens.isEmpty) {
      return <TextSpan>[TextSpan(text: text, style: baseStyle)];
    }

    final lowerText = text.toLowerCase();
    final ranges = <MapEntry<int, int>>[];
    for (final token in _tokens) {
      if (token.isEmpty) {
        continue;
      }
      var start = 0;
      while (true) {
        final index = lowerText.indexOf(token, start);
        if (index == -1) {
          break;
        }
        ranges.add(MapEntry(index, index + token.length));
        start = index + token.length;
      }
    }

    if (ranges.isEmpty) {
      return <TextSpan>[TextSpan(text: text, style: baseStyle)];
    }

    ranges.sort((a, b) => a.key.compareTo(b.key));
    final merged = <MapEntry<int, int>>[];
    for (final range in ranges) {
      if (merged.isEmpty || range.key > merged.last.value) {
        merged.add(range);
        continue;
      }
      final last = merged.removeLast();
      merged.add(
        MapEntry(last.key, range.value > last.value ? range.value : last.value),
      );
    }

    final spans = <TextSpan>[];
    var cursor = 0;
    for (final range in merged) {
      if (range.key > cursor) {
        spans.add(
          TextSpan(text: text.substring(cursor, range.key), style: baseStyle),
        );
      }
      spans.add(
        TextSpan(
          text: text.substring(range.key, range.value),
          style: baseStyle.copyWith(fontWeight: FontWeight.w700),
        ),
      );
      cursor = range.value;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Search results: "${widget.query}"')),
      body: widget.results.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No results for "${widget.query}".',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: widget.results.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = widget.results[index];
                final bodyStyle =
                    Theme.of(context).textTheme.bodyMedium ??
                    const TextStyle(fontSize: 14);
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      final noteContent = item.noteContent;
                      if (noteContent != null) {
                        final noteController = TextEditingController(
                          text: noteContent,
                        );
                        noteController.addListener(() {
                          item.onNoteChanged?.call(noteController.text);
                        });
                        showDialog<void>(
                          context: context,
                          builder: (dialogContext) {
                            return AlertDialog(
                              title: Text(item.title),
                              content: SizedBox(
                                width: 480,
                                child: TextField(
                                  controller: noteController,
                                  maxLines: null,
                                  minLines: 6,
                                  autofocus: true,
                                  keyboardType: TextInputType.multiline,
                                  decoration: const InputDecoration(
                                    hintText: 'Write your note here...',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.all(10),
                                  ),
                                ),
                              ),
                            );
                          },
                        ).then((_) => noteController.dispose());
                        return;
                      }

                      item.onTap?.call();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.category == 'Note')
                            Text.rich(
                              TextSpan(
                                style: bodyStyle,
                                children: [
                                  TextSpan(
                                    text: 'Note: ',
                                    style: bodyStyle.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  ..._highlightedSpans(
                                    item.subtitle,
                                    bodyStyle,
                                  ),
                                ],
                              ),
                            )
                          else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      style: bodyStyle.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                      children: _highlightedSpans(
                                        item.title,
                                        bodyStyle.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (item.meta.isNotEmpty) ...[
                                  const SizedBox(width: 12),
                                  Text(
                                    item.meta,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            ),
                          if (item.category != 'Note' &&
                              item.subtitle.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text.rich(
                                TextSpan(
                                  style: Theme.of(context).textTheme.bodySmall,
                                  children: _highlightedSpans(
                                    item.subtitle,
                                    Theme.of(context).textTheme.bodySmall ??
                                        const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
