import 'package:flutter/material.dart';

// --- PAGE 1: PUZZLE CHOICES ---
class PuzzleChoicesPage extends StatefulWidget {
  final String metadataCombined;
  const PuzzleChoicesPage({super.key, required this.metadataCombined});

  @override
  State<PuzzleChoicesPage> createState() => _PuzzleChoicesPageState();
}

class _PuzzleChoicesPageState extends State<PuzzleChoicesPage> {
  String? selectedPuzzle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Language Puzzles"),
            Text(
              widget.metadataCombined,
              style: const TextStyle(
                color: Colors.grey,
                fontStyle: FontStyle.italic,
                fontSize: 14.0,
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Choose Your Puzzle",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            DropdownButton<String>(
              value: selectedPuzzle,
              hint: const Text("Select a puzzle..."),
              items: <String>["Crossword"].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue == "Crossword") {
                  // Navigate to Crossword, push will allow us to easily pop back and destroy Crossword state
                  Navigator.pushReplacementNamed(context, '/crossword');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

