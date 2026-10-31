import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 👇 Your Web configuration
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCxUTDj5ca1FEvNuCVf_FC1htZq7pm9Oiw",
      authDomain: "myweek-98342.firebaseapp.com",
      projectId: "myweek-98342",
      storageBucket: "myweek-98342.firebasestorage.app",
      messagingSenderId: "829011260810",
      appId: "1:829011260810:web:2cad1abfbba38514cb4473",
    ),
  );

  runApp(const MyWeekApp());
}

class MyWeekApp extends StatelessWidget {
  const MyWeekApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Week',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const AuthGate(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────

class Course {
  Course({
    this.id = '',
    required this.name,
    required this.day,
    required this.startMin,
    required this.endMin,
  });

  final String id;
  String name;
  String day;
  int startMin;
  int endMin;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'day': day,
      'startMin': startMin,
      'endMin': endMin,
    };
  }

  factory Course.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Course(
      id: doc.id,
      name: data['name'] ?? '',
      day: data['day'] ?? 'Mon',
      startMin: data['startMin'] ?? 0,
      endMin: data['endMin'] ?? 0,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TIME HELPERS
// ─────────────────────────────────────────────────────────────

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

String formatTime(int minutes) {
  final h = (minutes ~/ 60).toString().padLeft(2, '0');
  final m = (minutes % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

String formatDuration(int startMin, int endMin) {
  final diff = endMin - startMin;
  final h = diff ~/ 60;
  final m = diff % 60;
  if (h == 0) return '${m}m';
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}

// ─────────────────────────────────────────────────────────────
// WEEK SCREEN (Now reads from Firestore)
// ─────────────────────────────────────────────────────────────

class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key});
  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  String selectedDay = 'Mon';

  CollectionReference<Map<String, dynamic>> get myCourses {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('courses');
  }

  List<String> clashesFor(Course target, List<Course> allCourses) {
    final clashNames = <String>[];
    for (final other in allCourses) {
      if (other.id == target.id) continue;
      if (other.day != target.day) continue;
      final overlaps = target.startMin < other.endMin && other.startMin < target.endMin;
      if (overlaps) clashNames.add(other.name);
    }
    return clashNames;
  }

  Future<void> openEditor({Course? existing}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditorScreen(existing: existing, day: selectedDay),
      ),
    );
  }

  Future<void> deleteCourse(Course course) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this course?'),
        content: Text('${course.name} will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await myCourses.doc(course.id).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Week'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: myCourses.snapshots(),
        builder: (context, snapshot) {
          // 1. Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // 2. Error state (THIS will show us if Firestore blocks it!)
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
              ),
            );
          }

          final allCourses = snapshot.data!.docs.map(Course.fromDoc).toList();
          final dayCourses = allCourses.where((c) => c.day == selectedDay).toList()
            ..sort((a, b) => a.startMin.compareTo(b.startMin));

          int dayTotalMin = 0;
          for (final c in dayCourses) dayTotalMin += (c.endMin - c.startMin);
          int weekTotalMin = 0;
          for (final c in allCourses) weekTotalMin += (c.endMin - c.startMin);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Week Total: ${formatDuration(0, weekTotalMin)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'].map((day) {
                    return ChoiceChip(
                      label: Text(day),
                      selected: selectedDay == day,
                      onSelected: (_) => setState(() => selectedDay = day),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: dayCourses.isEmpty
                    ? Center(child: Text('No classes on $selectedDay'))
                    : ListView.builder(
                  itemCount: dayCourses.length,
                  itemBuilder: (context, index) {
                    final course = dayCourses[index];
                    final clashNames = clashesFor(course, allCourses);
                    final hasClash = clashNames.isNotEmpty;
                    return ListTile(
                      leading: Icon(Icons.book, color: hasClash ? Colors.red : Colors.indigo),
                      title: Text(course.name, style: TextStyle(color: hasClash ? Colors.red : null)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${formatTime(course.startMin)} – ${formatTime(course.endMin)}'),
                          if (hasClash) Text('Clashes with ${clashNames.join(', ')}', style: const TextStyle(color: Colors.red)),
                        ],
                      ),
                      onTap: () => openEditor(existing: course),
                      trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => deleteCourse(course)),
                    );
                  },
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.indigo.shade50,
                child: Text('Total: ${formatDuration(0, dayTotalMin)}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => openEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// EDITOR SCREEN (Now saves to Firestore)
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
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    nameController = TextEditingController(text: c?.name ?? '');
    startController = TextEditingController(text: c != null ? formatTime(c.startMin) : '');
    endController = TextEditingController(text: c != null ? formatTime(c.endMin) : '');
    selectedDay = c?.day ?? widget.day;
  }

  @override
  void dispose() {
    nameController.dispose();
    startController.dispose();
    endController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final name = nameController.text.trim();
    if (name.isEmpty) { _error('Course name cannot be empty.'); return; }
    final startMin = parseTime(startController.text);
    if (startMin == null) { _error('Start time must be HH:MM'); return; }
    final endMin = parseTime(endController.text);
    if (endMin == null) { _error('End time must be HH:MM'); return; }
    if (endMin <= startMin) { _error('End time must be after start time.'); return; }

    setState(() => _busy = true);

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final collection = FirebaseFirestore.instance.collection('users').doc(uid).collection('courses');
    final newCourse = Course(name: name, day: selectedDay, startMin: startMin, endMin: endMin);

    try {
      if (widget.existing == null) {
        await collection.add(newCourse.toMap());
      } else {
        await collection.doc(widget.existing!.id).update(newCourse.toMap());
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // 👇 Shows a red popup if Firebase rejects the save
      _error('Save failed: $e');
      setState(() => _busy = false);
    }
  }

  void _error(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Add Course' : 'Edit Course')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Course name')),
            const SizedBox(height: 16),
            const Text('Day:'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'].map((day) {
                return ChoiceChip(
                  label: Text(day),
                  selected: selectedDay == day,
                  onSelected: (_) => setState(() => selectedDay = day),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(controller: startController, decoration: const InputDecoration(labelText: 'Start time (HH:MM)', hintText: '08:00')),
            const SizedBox(height: 16),
            TextField(controller: endController, decoration: const InputDecoration(labelText: 'End time (HH:MM)', hintText: '10:00')),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : save,
              child: _busy ? const CircularProgressIndicator() : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}