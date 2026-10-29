import 'package:flutter/material.dart';

void main() {
  runApp(const MyWeekApp());
}

// ─────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────

class Course {
  Course({
    required this.name,
    required this.day,
    required this.startMin,
    required this.endMin,
  });

  String name;
  String day;
  int startMin;
  int endMin;
}

// ─────────────────────────────────────────────────────────────
// TIME HELPERS (Lab 1 logic)
// ─────────────────────────────────────────────────────────────

/// Returns minutes from midnight (e.g., "08:30" -> 510).
/// Returns null if the format is invalid.
int? parseTime(String text) {
  final parts = text.trim().split(':');
  if (parts.length != 2) return null;

  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);

  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23) return null;
  if (minute < 0 || minute > 59) return null;

  return hour * 60 + minute;
}

/// Returns formatted text (e.g., 510 -> "08:30").
String formatTime(int minutes) {
  final h = (minutes ~/ 60).toString().padLeft(2, '0');
  final m = (minutes % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

/// Returns duration like "1h 30m" or "2h 00m".
String formatDuration(int startMin, int endMin) {
  final diff = endMin - startMin;
  final h = diff ~/ 60;
  final m = diff % 60;
  if (h == 0) return '${m}m';
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}

// ─────────────────────────────────────────────────────────────
// APP SHELL
// ─────────────────────────────────────────────────────────────

class MyWeekApp extends StatelessWidget {
  const MyWeekApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Week',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const WeekScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WEEK SCREEN
// ─────────────────────────────────────────────────────────────

class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  final courses = [
    // Monday (contains a clash)
    Course(name: 'Math', day: 'Mon', startMin: 480, endMin: 600),
    Course(name: 'Physics', day: 'Mon', startMin: 570, endMin: 660),
    Course(name: 'Chemistry', day: 'Mon', startMin: 840, endMin: 930),
    // Wednesday
    Course(name: 'English', day: 'Wed', startMin: 480, endMin: 540),
    Course(name: 'Biology', day: 'Wed', startMin: 600, endMin: 690),
    // Friday
    Course(name: 'ICT', day: 'Fri', startMin: 540, endMin: 660),
  ];

  String selectedDay = 'Mon';

  // ── Clash detection (Lab 7) ──────────────────────────────────
  // Returns a list of course names that clash with the given course.
  List<String> clashesFor(Course target) {
    final clashNames = <String>[];
    for (final other in courses) {
      if (other == target) continue;
      if (other.day != target.day) continue;

      // Each starts before the other ends
      final overlaps =
          target.startMin < other.endMin && other.startMin < target.endMin;
      if (overlaps) {
        clashNames.add(other.name);
      }
    }
    return clashNames;
  }

  // ── Open Add/Edit screen ─────────────────────────────────────
  Future<void> openEditor({Course? existing}) async {
    final result = await Navigator.push<Course>(
      context,
      MaterialPageRoute(
        builder: (context) => EditorScreen(existing: existing, day: selectedDay),
      ),
    );

    if (result == null) return; // user went back without saving

    setState(() {
      if (existing != null) {
        // Edit: update the existing object in place
        existing.name = result.name;
        existing.day = result.day;
        existing.startMin = result.startMin;
        existing.endMin = result.endMin;
      } else {
        // Add: append to the list
        courses.add(result);
      }
      selectedDay = result.day;
    });
  }

  // ── Delete ───────────────────────────────────────────────────
  Future<void> deleteCourse(Course course) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this course?'),
        content: Text('${course.name} will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        courses.remove(course);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter courses for the selected day, and sort them by start time
    final dayCourses =
    courses.where((c) => c.day == selectedDay).toList()
      ..sort((a, b) => a.startMin.compareTo(b.startMin));

    // Calculate day total minutes
    int dayTotalMin = 0;
    for (final c in dayCourses) {
      dayTotalMin += (c.endMin - c.startMin);
    }

    // Calculate week total minutes
    int weekTotalMin = 0;
    for (final c in courses) {
      weekTotalMin += (c.endMin - c.startMin);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('My Week (Total: ${formatDuration(0, weekTotalMin)})'),
      ),
      body: Column(
        children: [
          // ── Day Filter Chips ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'].map((day) {
                return ChoiceChip(
                  label: Text(day),
                  selected: selectedDay == day,
                  onSelected: (_) {
                    setState(() {
                      selectedDay = day;
                    });
                  },
                );
              }).toList(),
            ),
          ),

          // ── Course List ──────────────────────────────────────
          Expanded(
            child: dayCourses.isEmpty
                ? Center(child: Text('No classes on $selectedDay'))
                : ListView.builder(
              itemCount: dayCourses.length,
              itemBuilder: (context, index) {
                final course = dayCourses[index];
                final clashNames = clashesFor(course);
                final hasClash = clashNames.isNotEmpty;

                return ListTile(
                  leading: Icon(
                    Icons.book,
                    color: hasClash ? Colors.red : Colors.indigo,
                  ),
                  title: Text(
                    course.name,
                    style: TextStyle(
                      color: hasClash ? Colors.red : null,
                      fontWeight: hasClash ? FontWeight.bold : null,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${formatTime(course.startMin)} – ${formatTime(course.endMin)}',
                      ),
                      if (hasClash)
                        Text(
                          'Clashes with ${clashNames.join(', ')}',
                          style: const TextStyle(color: Colors.red),
                        ),
                    ],
                  ),
                  onTap: () => openEditor(existing: course),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => deleteCourse(course),
                  ),
                );
              },
            ),
          ),

          // ── Day Total ────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.indigo.shade50,
            child: Text(
              'Total: ${formatDuration(0, dayTotalMin)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => openEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// EDITOR SCREEN (Add / Edit)
// ─────────────────────────────────────────────────────────────

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, this.existing, required this.day});

  final Course? existing;
  final String day;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late TextEditingController nameController;
  late TextEditingController startController;
  late TextEditingController endController;
  late String selectedDay;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    nameController = TextEditingController(text: c?.name ?? '');
    startController = TextEditingController(
      text: c != null ? formatTime(c.startMin) : '',
    );
    endController = TextEditingController(
      text: c != null ? formatTime(c.endMin) : '',
    );
    selectedDay = c?.day ?? widget.day;
  }

  @override
  void dispose() {
    nameController.dispose();
    startController.dispose();
    endController.dispose();
    super.dispose();
  }

  void save() {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      _error('Course name cannot be empty.');
      return;
    }

    final startMin = parseTime(startController.text);
    if (startMin == null) {
      _error('Start time must be HH:MM (e.g., 08:00).');
      return;
    }

    final endMin = parseTime(endController.text);
    if (endMin == null) {
      _error('End time must be HH:MM (e.g., 10:00).');
      return;
    }

    if (endMin <= startMin) {
      _error('End time must be after start time.');
      return;
    }

    // Valid — pop back with the new/updated course
    Navigator.pop(
      context,
      Course(name: name, day: selectedDay, startMin: startMin, endMin: endMin),
    );
  }

  void _error(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add Course' : 'Edit Course'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Course name'),
            ),
            const SizedBox(height: 16),
            const Text('Day:'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'].map((day) {
                return ChoiceChip(
                  label: Text(day),
                  selected: selectedDay == day,
                  onSelected: (_) {
                    setState(() {
                      selectedDay = day;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: startController,
              decoration: const InputDecoration(
                labelText: 'Start time (HH:MM)',
                hintText: '08:00',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: endController,
              decoration: const InputDecoration(
                labelText: 'End time (HH:MM)',
                hintText: '10:00',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}