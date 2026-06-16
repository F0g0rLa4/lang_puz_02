import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Ensure this import matches your actual project name!
import 'package:lang_puz_02/main.dart'; 

void main() {
// Initialize the integration test binding to browser test the app with real keyboard events and time delays.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
// Helper functions for keyboard navigation
  Future<void> simulateTab(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
  }

  Future<void> simulateShiftTab(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
  }

  Future<void> realTimePause(int seconds) async {
    await Future.delayed(Duration(seconds: seconds));
  }

  testWidgets('Crossword navigation and input sequence test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CrosswordApp());
    await tester.pumpAndSettle();
    // ----------------------------------------------------------------------
    // PART 1: Dropdown Sequence
    // Click on the dropdown and select each of the 3 options.
    // Do this sequence 2 times, pausing between each selection for 4 seconds.
    // ----------------------------------------------------------------------
    final dropdownOptions = [
      "Guess!",
      "Only those simple forms which fit",
      "All simple forms"
    ];

    for (int sequence = 0; sequence < 2; sequence++) {
      for (String option in dropdownOptions) {
        // Find and tap the dropdown menu
        await tester.tap(find.byType(DropdownButton<String>));
        await tester.pumpAndSettle();

        // Tap the specific option (using .last because it exists both in the button and the menu list)
        await tester.tap(find.text(option).last);
        await tester.pumpAndSettle();

        // Pause for 4 seconds to observe
        await realTimePause(4);
      }
    }

    // ----------------------------------------------------------------------
    // PART 2: Grid Navigation Sequence
    // Based on how the grid is built in main.dart:
    // TextField indices:
    // 0 = Row[0], 1 = Row[1], 2 = Row[2], 3 = Row[3], 4 = Row[4] (Overlap Cell)
    // 5 = Col[0], 6 = Col[2]
    // ----------------------------------------------------------------------

    // Define the sub-sequence 2a as a reusable function so we can call it again in 2d
    Future<void> sequence2a() async {
      // Click in cell 1 of the row (Index 1)
      await tester.tap(find.byType(TextField).at(1));
      await tester.pumpAndSettle();
      await realTimePause(2);

      // Shift-tab 1 time
      await simulateShiftTab(tester);
      await realTimePause(2);

      // Tab equal to column length-1 (colLen is 3, so 3-1 = 2 times)
      for (int i = 0; i < 2; i++) {
        await simulateTab(tester);
        await realTimePause(2);
      }

      // Shift-tab 4 times
      for (int i = 0; i < 4; i++) {
        await simulateShiftTab(tester);
        await realTimePause(2);
      }
    }

    // 2a) Run sequence 2a
    await sequence2a();

    // 2b) Click in the overlap cell (Index 4), shift-tab 1 time, tab 3 times
    await tester.tap(find.byType(TextField).at(4));
    await tester.pumpAndSettle();
    await realTimePause(2);

    await simulateShiftTab(tester);
    await realTimePause(2);

    for (int i = 0; i < 3; i++) {
      await simulateTab(tester);
      await realTimePause(2);
    }

    // 2c) Click in last (bottom) cell of the column (Index 6), tab 2 times, shift-tab 3 times
    await tester.tap(find.byType(TextField).at(6));
    await tester.pumpAndSettle();
    await realTimePause(2);

    for (int i = 0; i < 2; i++) {
      await simulateTab(tester);
      await realTimePause(2);
    }

    for (int i = 0; i < 3; i++) {
      await simulateShiftTab(tester);
      await realTimePause(2);
    }

    // 2d) Repeat 2a
    await sequence2a();

    // ----------------------------------------------------------------------
    // PART 2e: Fill the words, wait, and change a letter
    // Fill row with "fazia" and column with "faz"
    // ----------------------------------------------------------------------
    
    // Fill Row (Indices 0 through 4) with f-a-z-i-a
    final rowLetters = ['f', 'a', 'z', 'i', 'a'];
    for (int i = 0; i < 5; i++) {
      await tester.enterText(find.byType(TextField).at(i), rowLetters[i]);
      await tester.pumpAndSettle();
      await realTimePause(1);
    }

    // Fill Column: 
    // Col[0] is at Index 5 ('f')
    // Col[1] is the overlap at Index 4 (already 'a' from 'fazia', so it matches 'faz'!)
    // Col[2] is at Index 6 ('z')
    await tester.enterText(find.byType(TextField).at(5), 'f');
    await tester.pumpAndSettle();
    await realTimePause(1);

    await tester.enterText(find.byType(TextField).at(6), 'z');
    await tester.pumpAndSettle();
    
    // The words are now complete, which should trigger the validation and flashing effect in the app!
    await realTimePause(4); // Wait 4 seconds as requested

    // Change the first cell in the row from 'f' to 'x'
    await tester.enterText(find.byType(TextField).at(0), 'x');
    await tester.pumpAndSettle();
    await realTimePause(2); // Final pause to see the invalidation state
    
  });
}