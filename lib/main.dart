import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings();

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  try {
    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );
  } catch (e) {
    debugPrint('Notification init error: $e');
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(MedicineApp(prefs: prefs));
}

// ─────────────────────────────────────────────────────────────────────────────
// Constants & Theme
// ─────────────────────────────────────────────────────────────────────────────
const Color primaryColor = Color(0xFF147A53);
const Color bgColor = Color(0xFFEAF5EB);
const Color textColor = Color(0xFF1B3B2A);
const Color textLightColor = Color(0xFF6B8A7A);
const Color inputBgColor = Color(0xFFD1E8D8);

// ─────────────────────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────────────────────
class MedicineEntry {
  String id;
  String name;
  String description;
  String
  type; // Pill, Capsule, Injection, Syrup, Drop, Vitamins, Sachet, Others
  String
  frequency; // Everyday | Every Other Day | Specific days | Every X day | Every X weeks | Every X months
  List<String> specificDays; // ['MON','WED'] for specific days
  String dosageTiming; // Before Eating | After Eating | With Food
  String
  frequencyPerDay; // Once a day | Twice a day | 3 times a day | X times a day | Every X hours | Only when needed
  int quantity;
  TimeOfDay time;
  bool isDone;
  String? imagePath;

  MedicineEntry({
    String? id,
    required this.name,
    this.description = '',
    this.type = 'Capsule',
    this.frequency = 'Everyday',
    this.specificDays = const [],
    this.dosageTiming = 'Before Eating',
    this.frequencyPerDay = 'Once a day',
    this.quantity = 1,
    required this.time,
    this.isDone = false,
    this.imagePath,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'type': type,
    'frequency': frequency,
    'specificDays': specificDays,
    'dosageTiming': dosageTiming,
    'frequencyPerDay': frequencyPerDay,
    'quantity': quantity,
    'timeH': time.hour,
    'timeM': time.minute,
    'isDone': isDone,
    'imagePath': imagePath,
  };

  factory MedicineEntry.fromJson(Map<String, dynamic> json) => MedicineEntry(
    id: json['id'] as String?,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    type: json['type'] as String? ?? 'Capsule',
    frequency: json['frequency'] as String? ?? 'Everyday',
    specificDays:
        (json['specificDays'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [],
    dosageTiming: json['dosageTiming'] as String? ?? 'Before Eating',
    frequencyPerDay: json['frequencyPerDay'] as String? ?? 'Once a day',
    quantity: json['quantity'] as int? ?? 1,
    time: TimeOfDay(
      hour: json['timeH'] as int? ?? 8,
      minute: json['timeM'] as int? ?? 0,
    ),
    isDone: json['isDone'] as bool? ?? false,
    imagePath: json['imagePath'] as String?,
  );

  String get timeString {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final min = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$min $period';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App State (InheritedWidget for global medicine list & profile)
// ─────────────────────────────────────────────────────────────────────────────
class AppState extends ChangeNotifier {
  final SharedPreferences prefs;

  String userName = 'User';
  String userInitial = 'U';
  List<MedicineEntry> medicines = [];
  List<String> notifications = [];

  AppState(this.prefs) {
    _loadData();
  }

  void _loadData() {
    userName = prefs.getString('userName') ?? 'User';
    userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    final medsJsonStr = prefs.getString('medicines');
    if (medsJsonStr != null) {
      final List<dynamic> decoded = jsonDecode(medsJsonStr);
      medicines = decoded
          .map((e) => MedicineEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // 🔥 ALWAYS rebuild notifications from medicines (DON’T trust old saved ones)
    notifications = medicines
        .map((m) => 'New reminder set: ${m.name} at ${m.timeString}')
        .toList();

    _saveData(); // ensure sync

    notifyListeners();
  }

  void _saveData() {
    prefs.setString('userName', userName);
    prefs.setStringList('notifications', notifications);
    final medsJsonStr = jsonEncode(medicines.map((e) => e.toJson()).toList());
    prefs.setString('medicines', medsJsonStr);
  }

  void scheduleNotification(MedicineEntry m) async {
    final int id = m.id.hashCode & 0x7FFFFFFF;
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'medicine_channel',
          'Medicine Reminders',
          channelDescription: 'Reminds you to take your medicine',
          importance: Importance.max,
          priority: Priority.high,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    // Demonstrate showing a notification (in a full prod app you'd use zonedSchedule)
    // await flutterLocalNotificationsPlugin.show(id, 'Medicine Reminder', 'Time to take ${m.name}', platformChannelSpecifics);
  }

  void addMedicine(MedicineEntry m) {
    medicines.add(m);
    notifications.insert(0, 'New reminder set: ${m.name} at ${m.timeString}');
    scheduleNotification(m);
    _saveData();
    notifyListeners();
  }

  void toggleDone(int index) {
    medicines[index].isDone = !medicines[index].isDone;
    _saveData();
    notifyListeners();
  }

  void removeMedicine(int index) async {
    // 1. Remove medicine
    medicines.removeAt(index);

    // 2. Cancel all system notifications
    await flutterLocalNotificationsPlugin.cancelAll();

    // 3. 🔥 Rebuild notifications ONLY from remaining medicines
    notifications = medicines
        .map((m) => 'New reminder set: ${m.name} at ${m.timeString}')
        .toList();

    // 4. Save everything properly
    _saveData();

    // 5. Refresh UI
    notifyListeners();
  }

  void updateProfile(String name) {
    userName = name;
    userInitial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    _saveData();
    notifyListeners();
  }
}

class AppStateProvider extends InheritedNotifier<AppState> {
  const AppStateProvider({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppStateProvider>()!
        .notifier!;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Root App
// ─────────────────────────────────────────────────────────────────────────────
class MedicineApp extends StatelessWidget {
  final SharedPreferences prefs;
  const MedicineApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return AppStateProvider(
      state: AppState(prefs),
      child: MaterialApp(
        title: 'Medicine Reminder',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          scaffoldBackgroundColor: bgColor,
          fontFamily: 'Roboto',
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(color: Colors.black87),
            titleTextStyle: TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        home: const WelcomeScreen(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Welcome / Splash Screen
// ─────────────────────────────────────────────────────────────────────────────
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Column(
              children: [
                const SizedBox(height: 60),
                const Center(
                  child: Text(
                    'Medicine Reminder',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Never miss a dose again',
                    style: TextStyle(
                      fontSize: 14,
                      color: textLightColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 220,
                  height: 220,
                  decoration: const BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    'assets/medicine_reminder 1.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.medical_services,
                      size: 90,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 40,
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _navigateToHome,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 4,
                            shadowColor: primaryColor.withOpacity(0.4),
                          ),
                          child: const Text(
                            'Get Started',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _navigateToHome,
                        child: const Text(
                          'I already have an account',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Home Screen  (fully stateful — calendar, medicines, nav)
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedNavIndex = 0; // 0=Home,1=Profile
  late DateTime _today;
  late DateTime _selectedDate;
  late List<DateTime> _weekDays;

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _selectedDate = _today;
    _generateWeek(_today);
  }

  void _generateWeek(DateTime anchor) {
    final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
    _weekDays = List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  void _previousWeek() => setState(
    () => _generateWeek(_weekDays.first.subtract(const Duration(days: 7))),
  );
  void _nextWeek() => setState(
    () => _generateWeek(_weekDays.first.add(const Duration(days: 7))),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // 🔁 SWITCH BETWEEN HOME & PROFILE
            _selectedNavIndex == 0
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildHeader(context),
                      const SizedBox(height: 24),
                      _buildCalendarSection(),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            const Text(
                              "Today's medicines",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const Spacer(),
                            _buildProgressBadge(context),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildMedicineList(context),
                    ],
                  )
                : Positioned.fill(
                    child: ProfileScreen(
                      onBack: () => setState(() => _selectedNavIndex = 0),
                    ),
                  ),

            // 🔻 ALWAYS VISIBLE BOTTOM NAV
            Positioned(
              left: 24,
              right: 24,
              bottom: 20,
              child: _buildBottomNav(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBadge(BuildContext context) {
    final state = AppStateProvider.of(context);
    final done = state.medicines.where((m) => m.isDone).length;
    final total = state.medicines.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$done / $total done',
        style: const TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final state = AppStateProvider.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => _selectedNavIndex = 1),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFDCAE82),
              child: Text(
                state.userInitial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, ${state.userName}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                "Let's check your plan today",
                style: TextStyle(
                  fontSize: 12,
                  color: textLightColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => _showNotifications(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  const Icon(
                    Icons.notifications_none,
                    color: primaryColor,
                    size: 26,
                  ),
                  if (state.notifications.isNotEmpty)
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    final state = AppStateProvider.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              if (state.notifications.isEmpty)
                const Center(
                  child: Text(
                    'No notifications',
                    style: TextStyle(color: textLightColor),
                  ),
                )
              else
                ...state.notifications.map(
                  (n) => ListTile(
                    leading: const Icon(Icons.alarm, color: primaryColor),
                    title: Text(
                      n,
                      style: const TextStyle(fontSize: 13, color: textColor),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCalendarSection() {
    final monthStr = _monthName(_weekDays[0].month);
    final yearStr = _weekDays[0].year.toString();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: primaryColor),
                onPressed: _previousWeek,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const Spacer(),
              Text(
                '$monthStr, $yearStr',
                style: const TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: primaryColor),
                onPressed: _nextWeek,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final day = _weekDays[i];
              final isSelected = _isSameDay(day, _selectedDate);
              final isToday = _isSameDay(day, _today);
              return GestureDetector(
                onTap: () => setState(() => _selectedDate = day),
                child: Column(
                  children: [
                    Text(
                      _dayAbbr(day.weekday),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? primaryColor
                            : textLightColor.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isSelected ? primaryColor : Colors.transparent,
                        shape: BoxShape.circle,
                        border: isToday && !isSelected
                            ? Border.all(color: primaryColor, width: 1.5)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildMedicineList(BuildContext context) {
    final state = AppStateProvider.of(context);
    return Expanded(
      child: state.medicines.isEmpty
          ? const Center(
              child: Text(
                'No medicines added yet.\nTap + to add one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textLightColor, fontSize: 15),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
              itemCount: state.medicines.length,
              itemBuilder: (ctx, index) {
                final med = state.medicines[index];
                return Dismissible(
                  key: ValueKey('$index-${med.name}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Medicine'),
                            content: Text(
                              'Remove "${med.name}" from your list?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ) ??
                        false;
                  },
                  onDismissed: (_) => state.removeMedicine(index),
                  child: _buildMedicineCard(context, med, index),
                );
              },
            ),
    );
  }

  Widget _buildMedicineCard(
    BuildContext context,
    MedicineEntry med,
    int index,
  ) {
    final state = AppStateProvider.of(context);
    final iconData = _iconForType(med.type);
    final iconColors = _colorForType(med.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: iconColors[0],
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: med.imagePath != null
                ? Image.file(File(med.imagePath!), fit: BoxFit.cover)
                : Icon(iconData, color: iconColors[1], size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  med.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${med.timeString}  •  ${med.quantity > 1 ? "${med.quantity}x " : ""}${med.type}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: textLightColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (med.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      med.description,
                      style: const TextStyle(
                        fontSize: 11,
                        color: textLightColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => state.toggleDone(index),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                med.isDone ? Icons.check_circle : Icons.check_circle_outline,
                key: ValueKey(med.isDone),
                color: med.isDone ? primaryColor : Colors.grey.shade300,
                size: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFFD1E8DA),
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => setState(() => _selectedNavIndex = 0),
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.home_rounded,
                    color: _selectedNavIndex == 0
                        ? primaryColor
                        : textLightColor,
                    size: 26,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Home',
                    style: TextStyle(
                      color: _selectedNavIndex == 0
                          ? primaryColor
                          : textLightColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddMedicationScreen1()),
              );
              if (result != null && result is MedicineEntry) {
                AppStateProvider.of(context).addMedicine(result);
              }
            },
            child: Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 30),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _selectedNavIndex = 1),
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    color: _selectedNavIndex == 1
                        ? primaryColor
                        : textLightColor,
                    size: 26,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Profile',
                    style: TextStyle(
                      color: _selectedNavIndex == 1
                          ? primaryColor
                          : textLightColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── helpers ──
  bool _isSameDay(DateTime a, DateTime b) =>
      a.day == b.day && a.month == b.month && a.year == b.year;
  String _dayAbbr(int weekday) =>
      ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'][weekday - 1];
  String _monthName(int m) => [
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
  ][m - 1];

  IconData _iconForType(String type) {
    switch (type) {
      case 'Capsule':
        return Icons.medication;
      case 'Injection':
        return Icons.vaccines;
      case 'Syrup':
        return Icons.local_drink;
      case 'Drop':
        return Icons.water_drop;
      case 'Vitamins':
        return Icons.health_and_safety;
      case 'Sachet':
        return Icons.mail_outline;
      default:
        return Icons.radio_button_checked;
    }
  }

  List<Color> _colorForType(String type) {
    switch (type) {
      case 'Capsule':
        return [const Color(0xFFF1F6F5), Colors.redAccent];
      case 'Injection':
        return [const Color(0xFFE8F5E9), Colors.green];
      case 'Syrup':
        return [const Color(0xFFFFF3E0), Colors.orange];
      case 'Drop':
        return [const Color(0xFFE3F2FD), Colors.blue];
      case 'Vitamins':
        return [const Color(0xFFF3E5F5), Colors.purple];
      case 'Sachet':
        return [const Color(0xFFFCE4EC), Colors.pink];
      default:
        return [const Color(0xFFFAF3F0), Colors.brown];
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Add Medication Screen 1  (name, description, type, frequency choice)
// ─────────────────────────────────────────────────────────────────────────────
class AddMedicationScreen1 extends StatefulWidget {
  const AddMedicationScreen1({super.key});

  @override
  State<AddMedicationScreen1> createState() => _AddMedicationScreen1State();
}

class _AddMedicationScreen1State extends State<AddMedicationScreen1> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  int _selectedTypeIndex = 1; // Capsule default
  final String _selectedFrequency = ''; // will be set on screen 2
  String? _pickedImagePath;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _pickedImagePath = image.path;
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  final List<Map<String, dynamic>> _types = [
    {'icon': Icons.radio_button_checked, 'name': 'Pill'},
    {'icon': Icons.medication, 'name': 'Capsule'},
    {'icon': Icons.vaccines, 'name': 'Injection'},
    {'icon': Icons.local_drink, 'name': 'Syrup'},
    {'icon': Icons.water_drop, 'name': 'Drop'},
    {'icon': Icons.health_and_safety, 'name': 'Vitamins'},
    {'icon': Icons.mail_outline, 'name': 'Sachet'},
    {'icon': Icons.add_circle_outline, 'name': 'Others'},
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _goToScreen2(String frequency) async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a medicine name'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddMedicationScreen2(
          medicineName: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          medicineType: _types[_selectedTypeIndex]['name'],
          frequency: frequency,
          imagePath: _pickedImagePath,
        ),
      ),
    );
    if (result != null && result is MedicineEntry) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Add New Medication'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar / image placeholder
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: _pickedImagePath != null
                          ? Image.file(
                              File(_pickedImagePath!),
                              fit: BoxFit.cover,
                            )
                          : Image.asset(
                              'assets/medicine_reminder 1.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.medication,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap to add image',
                    style: TextStyle(
                      fontSize: 12,
                      color: textLightColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildTextField('Medicine Name *', _nameCtrl),
            const SizedBox(height: 12),
            _buildTextField('Description (optional)', _descCtrl),
            const SizedBox(height: 24),
            const Text(
              'Medication Type',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _types.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.85,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemBuilder: (ctx, idx) {
                final isSel = idx == _selectedTypeIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTypeIndex = idx),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSel ? primaryColor : inputBgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _types[idx]['icon'],
                          color: isSel ? Colors.white : primaryColor,
                          size: 26,
                        ),
                        const SizedBox(height: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _types[idx]['name'],
                              style: TextStyle(
                                fontSize: 10,
                                color: isSel ? Colors.white : primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Frequency',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            _buildOptionButton(
              'Specific time',
              () => _goToScreen2('Specific time'),
            ),
            _buildOptionButton(
              'Specific day',
              () => _goToScreen2('Specific day'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: primaryColor.withOpacity(0.5),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: inputBgColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildOptionButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: inputBgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: primaryColor),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Add Medication Screen 2  (frequency + dosage timing)
// ─────────────────────────────────────────────────────────────────────────────
class AddMedicationScreen2 extends StatefulWidget {
  final String medicineName;
  final String description;
  final String medicineType;
  final String frequency;
  final String? imagePath;

  const AddMedicationScreen2({
    super.key,
    required this.medicineName,
    required this.description,
    required this.medicineType,
    required this.frequency,
    this.imagePath,
  });

  @override
  State<AddMedicationScreen2> createState() => _AddMedicationScreen2State();
}

class _AddMedicationScreen2State extends State<AddMedicationScreen2> {
  String _selectedFrequency = 'Everyday';
  final Set<String> _selectedDays = {'MON', 'WED', 'FRI'};
  String _dosageTiming = 'Before Eating';
  final List<String> _allDays = [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  void _goToScreen3() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddMedicationScreen3(
          medicineName: widget.medicineName,
          description: widget.description,
          medicineType: widget.medicineType,
          frequency: _selectedFrequency,
          specificDays: _selectedDays.toList(),
          dosageTiming: _dosageTiming,
          imagePath: widget.imagePath,
        ),
      ),
    );
    if (result != null && result is MedicineEntry) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Add New Medication'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Frequency',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            ..._buildFrequencyOptions(),
            if (_selectedFrequency == 'Specific days') ...[
              const SizedBox(height: 12),
              _buildSpecificDaysRow(),
            ],
            const SizedBox(height: 24),
            const Text(
              'When to take',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            _buildDosageTimingOptions(),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _goToScreen3,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Next',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFrequencyOptions() {
    final options = [
      'Everyday',
      'Every Other Day',
      'Specific days',
      'Every X day',
      'Every X weeks',
      'Every X months',
    ];
    return options.map((opt) {
      final isSel = opt == _selectedFrequency;
      return GestureDetector(
        onTap: () => setState(() => _selectedFrequency = opt),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: isSel ? primaryColor : inputBgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  opt,
                  style: TextStyle(
                    color: isSel ? Colors.white : primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              if (isSel) const Icon(Icons.check, color: Colors.white, size: 18),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildSpecificDaysRow() {
    return Wrap(
      spacing: 8,
      children: _allDays.map((day) {
        final isSel = _selectedDays.contains(day);
        return GestureDetector(
          onTap: () => setState(
            () => isSel ? _selectedDays.remove(day) : _selectedDays.add(day),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSel ? primaryColor : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSel ? primaryColor : Colors.grey.shade300,
              ),
            ),
            child: Text(
              day,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSel ? Colors.white : textColor,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDosageTimingOptions() {
    final options = ['Before Eating', 'After Eating', 'With Food'];
    return Column(
      children: options.map((opt) {
        final isSel = opt == _dosageTiming;
        return GestureDetector(
          onTap: () => setState(() => _dosageTiming = opt),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isSel ? primaryColor : Colors.transparent,
                    border: Border.all(
                      color: isSel ? primaryColor : Colors.grey.shade400,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: isSel
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 10),
                Text(
                  opt,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isSel ? primaryColor : textColor,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Add Medication Screen 3  (time, quantity, frequency per day → Done)
// ─────────────────────────────────────────────────────────────────────────────
class AddMedicationScreen3 extends StatefulWidget {
  final String medicineName;
  final String description;
  final String medicineType;
  final String frequency;
  final List<String> specificDays;
  final String dosageTiming;
  final String? imagePath;

  const AddMedicationScreen3({
    super.key,
    required this.medicineName,
    required this.description,
    required this.medicineType,
    required this.frequency,
    required this.specificDays,
    required this.dosageTiming,
    this.imagePath,
  });

  @override
  State<AddMedicationScreen3> createState() => _AddMedicationScreen3State();
}

class _AddMedicationScreen3State extends State<AddMedicationScreen3> {
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  int _quantity = 1;
  String _frequencyPerDay = 'Once a day';

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _done() {
    final medicine = MedicineEntry(
      name: widget.medicineName,
      description: widget.description,
      type: widget.medicineType,
      frequency: widget.frequency,
      specificDays: widget.specificDays,
      dosageTiming: widget.dosageTiming,
      frequencyPerDay: _frequencyPerDay,
      quantity: _quantity,
      time: _time,
      imagePath: widget.imagePath,
    );
    Navigator.pop(context, medicine);
  }

  String _formattedTime() {
    final hour = _time.hourOfPeriod == 0 ? 12 : _time.hourOfPeriod;
    final min = _time.minute.toString().padLeft(2, '0');
    final period = _time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}  :  $min   $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Add New Medication'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryColor.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.medication, color: primaryColor, size: 26),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.medicineName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${widget.medicineType}  •  ${widget.frequency}',
                        style: const TextStyle(
                          color: textLightColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Time',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickTime,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: inputBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, color: primaryColor),
                    const SizedBox(width: 12),
                    Text(
                      _formattedTime(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: primaryColor,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.edit, color: primaryColor, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Quantity',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: inputBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, color: primaryColor),
                    onPressed: () => setState(() {
                      if (_quantity > 1) _quantity--;
                    }),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '$_quantity',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: primaryColor),
                    onPressed: () => setState(() => _quantity++),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Frequency per day',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            ..._buildFrequencyPerDayOptions(),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _done,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  shadowColor: primaryColor.withOpacity(0.4),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Save Medicine',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFrequencyPerDayOptions() {
    final options = [
      'Once a day',
      'Twice a day',
      '3 times a day',
      'X times a day',
      'Every X hours',
      'Only when needed',
    ];
    return options.map((opt) {
      final isSel = opt == _frequencyPerDay;
      return GestureDetector(
        onTap: () => setState(() => _frequencyPerDay = opt),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: isSel ? primaryColor : inputBgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  opt,
                  style: TextStyle(
                    color: isSel ? Colors.white : primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              if (isSel) const Icon(Icons.check, color: Colors.white, size: 18),
            ],
          ),
        ),
      );
    }).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. Profile Screen
// ─────────────────────────────────────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  final VoidCallback onBack;

  const ProfileScreen({super.key, required this.onBack});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppStateProvider.of(context);
    _nameCtrl.text = state.userName;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _saveProfile() {
    final state = AppStateProvider.of(context);
    state.updateProfile(_nameCtrl.text.trim());

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile saved!'),
        backgroundColor: primaryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Text('Profile'),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
        child: Column(
          children: [
            const SizedBox(height: 20),

            CircleAvatar(
              radius: 50,
              backgroundColor: primaryColor,
              child: Text(
                state.userInitial,
                style: const TextStyle(
                  fontSize: 36,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Your Name',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textColor,
                ),
              ),
            ),

            const SizedBox(height: 8),

            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                filled: true,
                fillColor: inputBgColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                hintText: 'Enter your name',
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Your Medicines',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textColor,
                ),
              ),
            ),

            const SizedBox(height: 12),

            ...state.medicines.map(
              (m) => ListTile(
                leading: m.imagePath != null
                    ? ClipOval(
                        child: Image.file(
                          File(m.imagePath!),
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(Icons.medication, color: primaryColor),
                title: Text(
                  m.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                subtitle: Text(
                  '${m.type} • ${m.timeString} • ${m.frequencyPerDay}',
                  style: const TextStyle(color: textLightColor, fontSize: 12),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: m.isDone
                        ? primaryColor.withOpacity(0.15)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    m.isDone ? 'Done' : 'Pending',
                    style: TextStyle(
                      color: m.isDone ? primaryColor : Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),

            const SizedBox(height: 40),

            OutlinedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                );
              },
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
