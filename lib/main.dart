
import 'package:flutter/material.dart';
import '../reach_quest_screen.dart';
import "../sudoku2.dart";


void main() {
  runApp(const RehabSudokuApp());
}

class RehabSudokuApp extends StatelessWidget {
  const RehabSudokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RehabSudoku',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF177E89),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F8FA),
      ),
      home: const PatientHomeScreen(),
    );
  }
}

class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key});

  void openScreen(
    BuildContext context,
    String title,
    String description,
    IconData icon,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FeatureScreen(
          title: title,
          description: description,
          icon: icon,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF177E89),
        foregroundColor: Colors.white,
        title: const Text(
          'RehabSudoku',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Welcome section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1F2F3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, Patient!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Welcome to your rehabilitation session.',
                        style: TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                const Text(
                  'What would you like to do today?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 18),

                // Sudoku training
                HomeFeatureCard(
                  title: 'Sudoku Training',
                  description:
                      'Exercise your arm while solving Sudoku puzzles.',
                  icon: Icons.grid_on_rounded,
                  color: const Color(0xFF177E89),
                  buttonText: 'Start Training',
                  onPressed: () {

                    Navigator.push(context, MaterialPageRoute<void>(builder: (context) => const SudokuPg(),),);

                    // openScreen(
                    //   context,
                    //   'Sudoku Training',
                    //   'Your Sudoku game will appear here.',
                    //   Icons.grid_on_rounded,
                    // );
                  },
                ),

                const SizedBox(height: 18),

                // Motor assessment
                HomeFeatureCard(
                  title: 'Reach Quest',
                  description:
                      'Complete tile-transfer tasks to assess '
                      'your arm performance.',
                  icon: Icons.track_changes_rounded,
                  color: const Color(0xFF5275B5),
                  buttonText: 'Start Assessment',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ReachQuestScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 18),

                // Progress tracking
                HomeFeatureCard(
                  title: 'My Progress',
                  description:
                      'View your training history and progress.',
                  icon: Icons.bar_chart_rounded,
                  color: const Color(0xFF489879),
                  buttonText: 'View Progress',
                  onPressed: () {
                    openScreen(
                      context,
                      'My Progress',
                      'Your progress charts will appear here.',
                      Icons.bar_chart_rounded,
                    );
                  },
                ),

                const SizedBox(height: 28),

                const Center(
                  child: Text(
                    'Move at your own pace and follow '
                    'your therapist\'s guidance.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black54,
                    ),
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

// Reusable feature card
class HomeFeatureCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String buttonText;
  final VoidCallback onPressed;

  const HomeFeatureCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 44, color: color),
            const SizedBox(height: 14),

            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              description,
              style: const TextStyle(
                fontSize: 17,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Placeholder screen for future features
class FeatureScreen extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const FeatureScreen({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 80,
                color: const Color(0xFF177E89),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
