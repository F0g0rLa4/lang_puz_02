import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';

import 'package:lang_puz_02/utils/aa_logger_meta.dart';
import 'package:lang_puz_02/utils/dbhelper_models.dart';

// --- PAGE 2: CROSSWORD ---
class Crossword extends StatefulWidget {
  final String metadataCombined;
  const Crossword({
    super.key,
    required this.metadataCombined
  });

  @override
  State<Crossword> createState() => _CrosswordState();
}

class _CrosswordState extends State<Crossword> {
  final int colLen = 3;
  final int rowLen = 5;
  final int ovrCol = 2; 
  final int ovrRow = 5; 

  // Calculated overlap indices
  late final int overlapColIndex = ovrCol - 1;
  late final int overlapRowIndex = ovrRow - 1;

  // 1. NEW DATA STATE: Simple lists instead of Heavy TextFields
  List<String> colLetters = [];
  List<String> rowLetters = [];

  // Track which cell the user has selected
  TypeDirection currentDirection = TypeDirection.neutral;
  int? activeRowIdx;
  int? activeColIdx;

  // 2. THE HIDDEN INPUT: One connection to the OS keyboard
  final FocusNode hiddenNode = FocusNode();
  final TextEditingController hiddenController = TextEditingController();

  bool isValidated = false;
  bool showRedLetters = false;
  String colTenseLabel = "";
  String rowTenseLabel = "";
  String verbDisplayMode = "Guess!"; 
  
  Timer? flashTimer;
  List<VerbForm> fazerForms = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeGrid();
    _loadDataFromDatabase(); 

    // Intercept hardware keys on the hidden text field
    hiddenNode.onKeyEvent = (node, event) {
      // 1. Handle Backspace (Move backward)
      if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
        if (_isCurrentCellEmpty()) {
            _moveFocus(forward: false);
            _clearCurrentCell();
          } else {
            _clearCurrentCell();
          }
        return KeyEventResult.handled;
      }
      // 2. Handle Delete (Just erase current cell)
        else if (event.logicalKey == LogicalKeyboardKey.delete) {
          _clearCurrentCell();
          return KeyEventResult.handled;
        }
      // 3. Handle Tab (Move forward, or backward if Shift is held)
      // TAB LOGIC REMOVED - Handled by Shortcuts widget now
      // else if (event.logicalKey == LogicalKeyboardKey.tab) {
      //     bool isShift = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
      //                    HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftRight);
      //     _moveFocus(forward: !isShift);
      //     return KeyEventResult.handled;
      //   }
      return KeyEventResult.ignored;
    }; // hiddenNode.onKeyEvent
  } // initState

  void _initializeGrid() {
    colLetters = List.filled(colLen, "");
    rowLetters = List.filled(rowLen, "");
  }

  Future<void> _loadDataFromDatabase() async {
    try {
      final forms = await DatabaseHelper.instance.getAllFazerForms();
      if (!mounted) return; 
      setState(() {
        fazerForms = forms;
      });
    } on FileSystemException catch (e) {
      AppLogger.error("Database file not found: ${e.message}");
      if (!mounted) return;
      setState(() { isLoading = false; });
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Database Error"),
          content: Text("Failed to load database: ${e.message}"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      AppLogger.error("An unexpected error occurred: $e");
    } finally {
      if (mounted) {
        setState(() { isLoading = false; });
      }
    } 
  } 

  @override
  void dispose() {
    flashTimer?.cancel();
    hiddenNode.dispose();
    hiddenController.dispose();
    super.dispose();
  }

  // Handle keystrokes from the hidden input
  void _onHiddenTextChanged(String value) {
    if (value.isEmpty) return;
    
    // Grab the actual letter typed
    String newLetter = value[value.length - 1];
    // Ignore anything that isn't an actual letter (like the \t tab dropped into the cell) to avoid double jumps
    if (!RegExp(r'[a-zA-Z]').hasMatch(newLetter)) {
      hiddenController.clear();
      return;
    }
    
    setState(() {
      if (currentDirection == TypeDirection.across && activeRowIdx != null) {
        rowLetters[activeRowIdx!] = newLetter;
        // Sync the intersection
        if (activeRowIdx == overlapRowIndex) colLetters[overlapColIndex] = newLetter;
      } else if (currentDirection == TypeDirection.down && activeColIdx != null) {
        colLetters[activeColIdx!] = newLetter;
        // Sync the intersection
        if (activeColIdx == overlapColIndex) rowLetters[overlapRowIndex] = newLetter;
      }
    });

    _moveFocus(forward: true);
    // Clear the hidden text field so it's ready for the next letter
    hiddenController.clear();
    _validatePuzzle();
  }

  void _moveFocus({required bool forward}) {
    setState(() {
      if (currentDirection == TypeDirection.across && activeRowIdx != null) {
        if (forward && activeRowIdx! < rowLen - 1) {
          activeRowIdx = activeRowIdx! + 1;
        } else if (!forward && activeRowIdx! > 0) {
          activeRowIdx = activeRowIdx! - 1;
        }
      } else if (currentDirection == TypeDirection.down && activeColIdx != null) {
        if (forward && activeColIdx! < colLen - 1) {
          activeColIdx = activeColIdx! + 1;
        } else if (!forward && activeColIdx! > 0) {
          activeColIdx = activeColIdx! - 1;
        }
      }
    });
  }

  bool _isCurrentCellEmpty() {
    if (currentDirection == TypeDirection.across && activeRowIdx != null) {
      return rowLetters[activeRowIdx!].isEmpty;
    } else if (currentDirection == TypeDirection.down && activeColIdx != null) {
      return colLetters[activeColIdx!].isEmpty;
    }
    return true;
  }

  void _clearCurrentCell() {
    setState(() {
      if (currentDirection == TypeDirection.across && activeRowIdx != null) {
        rowLetters[activeRowIdx!] = "";
        if (activeRowIdx == overlapRowIndex) colLetters[overlapColIndex] = "";
      } else if (currentDirection == TypeDirection.down && activeColIdx != null) {
        colLetters[activeColIdx!] = "";
        if (activeColIdx == overlapColIndex) rowLetters[overlapRowIndex] = "";
      }
    });
    _validatePuzzle(); // Re-validate to clear the success state if we delete a letter
  }

  void _handleCellTap(CellType type, int index) {
    setState(() {
      if (type == CellType.overlapCell) {
        currentDirection = (currentDirection == TypeDirection.across) 
            ? TypeDirection.down 
            : TypeDirection.across;
        activeRowIdx = overlapRowIndex;
        activeColIdx = overlapColIndex;
      } else if (type == CellType.rowCell) {
        currentDirection = TypeDirection.across;
        activeRowIdx = index;
        activeColIdx = null;
      } else if (type == CellType.colCell) {
        currentDirection = TypeDirection.down;
        activeColIdx = index;
        activeRowIdx = null;
      }
    });
    // Pop open the keyboard by focusing the hidden text field
    hiddenNode.requestFocus();
  }

  void _validatePuzzle() {
    String currentColWord = colLetters.join("").toLowerCase();
    String currentRowWord = rowLetters.join("").toLowerCase();

    // If any cell is empty, the join string will be too short
    if (currentColWord.length != colLen || currentRowWord.length != rowLen) {
      _setInvalid();
      return;
    }

    VerbForm? matchedCol = fazerForms.firstWhere(
      (element) => element.form.toLowerCase() == currentColWord,
      orElse: () => const VerbForm("", ""),
    );

    VerbForm? matchedRow = fazerForms.firstWhere(
      (element) => element.form.toLowerCase() == currentRowWord,
      orElse: () => const VerbForm("", ""),
    );

    if (matchedCol.form.isNotEmpty && matchedRow.form.isNotEmpty) {
      if (!isValidated) {
        setState(() {
          isValidated = true;
          showRedLetters = true;
          colTenseLabel = matchedCol.label;
          rowTenseLabel = matchedRow.label;
        });

        flashTimer?.cancel();
        int flashCount = 0;
        flashTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
          flashCount++;
          if (flashCount < 10) {
            setState(() { showRedLetters = !showRedLetters; });
          } else {
            timer.cancel();
            setState(() { showRedLetters = true; });
          }
        });
      }
    } else {
      _setInvalid();
    }
  }

  void _setInvalid() {
    if (isValidated) {
      flashTimer?.cancel(); // <-- CRITICAL: Kills the background flashing
      setState(() {
        isValidated = false;
        showRedLetters = false;
        colTenseLabel = "";
        rowTenseLabel = "";
      });
    }
  }

  void _confirmReturn() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Return to Choices?"),
          content: const Text("Do you want to return to Choices and lose your work?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), 
              child: const Text("No"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacementNamed(context, '/');
              },
              child: const Text("Yes"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Loading Dictionary...", style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    Color letterColor = Colors.blue;
    FontWeight letterWeight = FontWeight.normal;

    if (isValidated) {
      letterColor = showRedLetters ? Colors.redAccent : Colors.blue;
      letterWeight = FontWeight.bold;
    }

    String promptText = "Click a cell to start";
    if (currentDirection == TypeDirection.across) promptText = "Mode: Across (Row)";
    if (currentDirection == TypeDirection.down) promptText = "Mode: Down (Column)";
    if (currentDirection == TypeDirection.neutral) promptText = "Mode: Neutral (Overlap Clicked)";

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // --- FIXED: HEADER ROW ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    "CrossWord",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12), // Prevents infinite expansion errors
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 250),
                        child: Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300)
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("Pick simple forms from: \"Fazer\"", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue[900])),
                              DropdownButton<String>(
                                value: verbDisplayMode,
                                isExpanded: true,
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    setState(() { verbDisplayMode = newValue; });
                                  }
                                },
                                items: <String>[
                                  "Guess!",
                                  "Only forms which fit",
                                  "All simple forms"
                                ].map<DropdownMenuItem<String>>((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value, style: const TextStyle(fontSize: 14)),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                height: 90, 
                                child: _buildVerbList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(),

            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        promptText,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                      ),
                      const SizedBox(height: 40),
                      _buildCrosswordGrid(letterColor, letterWeight),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _confirmReturn,
        label: const Text("Return"),
        icon: const Icon(Icons.arrow_back),
      ),
    );
  }

  Widget _buildCrosswordGrid(Color letterColor, FontWeight letterWeight) {
    double cellSize = 50.0;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: cellSize * 4), 
              Container(
                width: cellSize,
                alignment: Alignment.center,
                child: Text(colTenseLabel, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
              )
            ],
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 8),
                child: Text(rowTenseLabel, textAlign: TextAlign.end, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
              ),
              SizedBox(
                width: cellSize * rowLen,
                height: cellSize * colLen,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // --- THE HIDDEN TEXT FIELD ---
                    Positioned(
                      top: -100, left: -100, // Shoved off-screen just to be safe
                      child: SizedBox(
                        width: 10, height: 10,
                        // 1. Intercept Tab and Shift+Tab at the engine level
                        child: Shortcuts(
                          shortcuts: <ShortcutActivator, Intent>{
                            const SingleActivator(LogicalKeyboardKey.tab): const NextFocusIntent(),
                            const SingleActivator(LogicalKeyboardKey.tab, shift: true): const PreviousFocusIntent(),
                          }, // End of Shortcuts
                          // 2. Route those engine intents to our custom movement logic
                          child: Actions(
                            actions: <Type, Action<Intent>>{
                              NextFocusIntent: CallbackAction<NextFocusIntent>(
                                onInvoke: (NextFocusIntent intent) {
                                  _moveFocus(forward: true);
                                  return null; 
                                },
                              ),
                              PreviousFocusIntent: CallbackAction<PreviousFocusIntent>(
                                onInvoke: (PreviousFocusIntent intent) {
                                  _moveFocus(forward: false);
                                  return null;
                                },
                              ),
                            }, // End of actions: etc.
                            child: Opacity( //================
                              opacity: 0,
                              child: TextField(
                                controller: hiddenController,
                                focusNode: hiddenNode,
                                onChanged: _onHiddenTextChanged,
                                autocorrect: false,
                                enableSuggestions: false,
                                cursorColor: Colors.transparent, // Hides phantom cursors that appear when modification keys are pressed
                                decoration: const InputDecoration(
                                  // Strips all OS focus rings
                                  border: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                ),
                              ),  
                            ), //================ 
                          ), //child:Actions
                        ),
                      ),
                    ),
                    // --- ROW CELLS ---
                    for (int i = 0; i < rowLen; i++)
                      Positioned(
                        left: i * cellSize,
                        top: overlapColIndex * cellSize, 
                        child: _buildCell(
                          index: i,
                          type: i == overlapRowIndex ? CellType.overlapCell : CellType.rowCell,
                          color: letterColor, 
                          weight: letterWeight, 
                          size: cellSize, 
                        ),
                      ),
                      
                    // --- COLUMN CELLS ---
                    for (int i = 0; i < colLen; i++)
                      if (i != overlapColIndex)
                        Positioned(
                          left: overlapRowIndex * cellSize, 
                          top: i * cellSize,
                          child: _buildCell(
                            index: i,
                            type: CellType.colCell,
                            color: letterColor, 
                            weight: letterWeight, 
                            size: cellSize, 
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<VerbForm> _getFilteredForms() {
    switch (verbDisplayMode) {
      case "Guess!":
        return [];
      case "Only forms which fit":
        return fazerForms.where((form) {
          int len = form.form.length;
          return len == colLen || len == rowLen;
        }).toList();
      case "All simple forms":
        return fazerForms;
      default:
        return [];
    }
  }

  // --- FIXED: VERB LIST SCROLLING ---
  Widget _buildVerbList() {
    List<VerbForm> formsToShow = _getFilteredForms();

    if (formsToShow.isEmpty) {
      return Container(
        alignment: Alignment.topRight,
        child: Text(
          verbDisplayMode == "Guess!" ? "Make your guess!" : "No forms match.",
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: formsToShow.length,
      shrinkWrap: false, // Allows scrolling inside the 90px height
      physics: const AlwaysScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Text(
            "${formsToShow[index].label}: ${formsToShow[index].form}",
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
          ),
        );
      },
    );
  }

  // --- NEW VISUAL CELL (No TextField) ---
  Widget _buildCell({
    required int index,
    required CellType type,
    required Color color, 
    required FontWeight weight, 
    required double size, 
  }) {
    String letter = "";
    bool isActive = false;

    // Read the correct letter and determine if this cell is currently selected
    if (type == CellType.rowCell) {
      letter = rowLetters[index];
      isActive = (currentDirection == TypeDirection.across && activeRowIdx == index);
    } else if (type == CellType.colCell) {
      letter = colLetters[index];
      isActive = (currentDirection == TypeDirection.down && activeColIdx == index);
    } else if (type == CellType.overlapCell) {
      letter = rowLetters[index]; // Syncs perfectly with colLetters

      isActive = (currentDirection == TypeDirection.across && activeRowIdx == overlapRowIndex) || 
                 (currentDirection == TypeDirection.down && activeColIdx == overlapColIndex);
    }

    return GestureDetector(
      onTap: () => _handleCellTap(type, index),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black87),
          // Gives the user visual feedback on which cell they are typing in
          color: isActive ? Colors.blue.withAlpha(25) : Colors.white,
        ),
        child: Text(
          letter.toUpperCase(),
          style: TextStyle(color: color, fontWeight: weight, fontSize: 20),
        ),
      ),
    );
  }
}