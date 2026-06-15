import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for Keyboard Events
import 'dart:async';  // for Timer
import 'fazer_forms.dart';

void main() {
  runApp(const CrosswordApp());
}

class CrosswordApp extends StatelessWidget {
  const CrosswordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Verb Crossword Mockup',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const CrosswordHomepage(),
    );
  }
}

// --- DATA STRUCTURES ---
class VerbForm {
  final String form;
  final String label; // e.g., "1st pres. indic."
  const VerbForm(this.form, this.label);
}

// 1. Explicit cell types for navigation rules
enum CellType { colCell, rowCell, overlapCell }

// 2. Navigation modes
enum TypeDirection { neutral, across, down }

// --- WIDGET DEFINITIONS ---
class CrosswordHomepage extends StatefulWidget {
  const CrosswordHomepage({super.key});

  @override
  State<CrosswordHomepage> createState() => _CrosswordHomepageState();
}

class _CrosswordHomepageState extends State<CrosswordHomepage> {
  // Puzzle Definition: (colLen, rowLen, ovr=(colIdx1Based, rowIdx1Based))
  final int colLen = 3;
  final int rowLen = 5;
  final int ovrCol = 2; 
  final int ovrRow = 5; 

  // Maps to hold our Controllers and FocusNodes (0-indexed internally).
  final Map<int, TextEditingController> colControllers = {};
  final Map<int, TextEditingController> rowControllers = {};
  final Map<int, FocusNode> colNodes = {};
  final Map<int, FocusNode> rowNodes = {};

  // Track the current navigation mode
  TypeDirection currentDirection = TypeDirection.neutral;

  // Validation States
  bool isValidated = false;
  bool showRedLetters = false;
  String colTenseLabel = "";
  String rowTenseLabel = "";

  // Dropdown filter for verb display
  String verbDisplayMode = "Guess!"; 

  late final List<VerbForm> fazerForms;
  
  // Timer for flashing effect
  Timer? flashTimer;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _initializeGrid(); // Replacing your old _initializeControllers
  }

  @override
  void dispose() {
    flashTimer?.cancel();
    
    // Dispose all unique nodes and controllers to prevent memory leaks
    final allNodes = {...colNodes.values, ...rowNodes.values};
    for (var node in allNodes) { node.dispose(); }

    final allControllers = {...colControllers.values, ...rowControllers.values};
    for (var controller in allControllers) { controller.dispose(); }
    
    super.dispose();
  }

  // --- NEW CURSOR LOGIC BLOCK ---

  void _initializeGrid() {
    int overlapColIndex = ovrCol - 1;
    int overlapRowIndex = ovrRow - 1;

    // Create the unified overlap objects (Both Row and Col maps will point to this exact object)
    TextEditingController overlapController = TextEditingController();
    FocusNode overlapNode = _createCustomFocusNode();
    overlapController.addListener(_validatePuzzle);

    // Build Row Cells
    for (int i = 0; i < rowLen; i++) {
      if (i == overlapRowIndex) {
        rowControllers[i] = overlapController;
        rowNodes[i] = overlapNode;
      } else {
        rowControllers[i] = TextEditingController()..addListener(_validatePuzzle);
        rowNodes[i] = _createCustomFocusNode();
      }
    }

    // Build Column Cells
    for (int i = 0; i < colLen; i++) {
      if (i == overlapColIndex) {
        colControllers[i] = overlapController;
        colNodes[i] = overlapNode;
      } else {
        colControllers[i] = TextEditingController()..addListener(_validatePuzzle);
        colNodes[i] = _createCustomFocusNode();
      }
    }
  }

  FocusNode _createCustomFocusNode() {
    return FocusNode(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.tab) {
          bool isShift = HardwareKeyboard.instance.isShiftPressed;
          _moveFocus(forward: !isShift);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
    );
  }

  void _moveFocus({required bool forward}) {
    if (currentDirection == TypeDirection.neutral) return;

    if (currentDirection == TypeDirection.across) {
      int currentIndex = -1;
      for (var entry in rowNodes.entries) {
        if (entry.value.hasFocus) {
          currentIndex = entry.key;
          break;
        }
      }
      if (currentIndex != -1) {
        int nextIndex = forward ? currentIndex + 1 : currentIndex - 1;
        if (rowNodes.containsKey(nextIndex)) {
          rowNodes[nextIndex]!.requestFocus();
        }
      }
    } else if (currentDirection == TypeDirection.down) {
      int currentIndex = -1;
      for (var entry in colNodes.entries) {
        if (entry.value.hasFocus) {
          currentIndex = entry.key;
          break;
        }
      }
      if (currentIndex != -1) {
        int nextIndex = forward ? currentIndex + 1 : currentIndex - 1;
        if (colNodes.containsKey(nextIndex)) {
          colNodes[nextIndex]!.requestFocus();
        }
      }
    }
  }

  void _handleCellTap(CellType type) {
    setState(() {
      if (type == CellType.overlapCell) {
        currentDirection = TypeDirection.neutral;
      } else if (type == CellType.rowCell) {
        currentDirection = TypeDirection.across;
      } else if (type == CellType.colCell) {
        currentDirection = TypeDirection.down;
      }
    });
  }

  void _onCellTextChanged(String value) {
    if (value.isNotEmpty) {
      _moveFocus(forward: true);
    }
  }

  // --- END CURSOR LOGIC BLOCK ---

  void _validatePuzzle() {
    // Because the overlap cell is unified, we simply read the maps sequentially
    String currentColWord = "";
    for (int i = 0; i < colLen; i++) {
      currentColWord += colControllers[i]!.text.toLowerCase();
    }

    String currentRowWord = "";
    for (int i = 0; i < rowLen; i++) {
      currentRowWord += rowControllers[i]!.text.toLowerCase();
    }

    // Check if lengths match completely
    if (currentColWord.length != colLen || currentRowWord.length != rowLen) {
      _setInvalid();
      return;
    }

    // Search for matches in dictionary
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

        // Use your preserved Timer effect
flashTimer?.cancel();

        int flashCount = 0;
        flashTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
          flashCount++;

          if (flashCount < 10) {
            setState(() {
              showRedLetters = !showRedLetters;
            });
          } else {
            timer.cancel();
            setState(() {
              showRedLetters = true; // hold red after flashing
            });
          }
        });
      }
    } else {
      _setInvalid();
    }
  }

  void _setInvalid() {
    if (isValidated) {
      setState(() {
        isValidated = false;
        showRedLetters = false;
        colTenseLabel = "";
        rowTenseLabel = "";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Color letterColor = Colors.blue;
    FontWeight letterWeight = FontWeight.normal;

    if (isValidated) {
      letterColor = showRedLetters ? Colors.redAccent : Colors.blue;
      letterWeight = FontWeight.bold;
    }

    // Added the dynamic prompt so the user knows the navigation state
    String promptText = "Click a cell to start";
    if (currentDirection == TypeDirection.across) promptText = "Mode: Across (Row)";
    if (currentDirection == TypeDirection.down) promptText = "Mode: Down (Column)";
    if (currentDirection == TypeDirection.neutral) promptText = "Mode: Neutral (Overlap Clicked)";

    return Scaffold(
      appBar: AppBar(title: const String.fromEnvironment("title") == "" ? const Text("Verb Crossword Mockup") : null),
      body: Row(
        children: [
          // Left Side: Crossword Graphic Board
          Expanded(
            flex: 3,
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
          
          const VerticalDivider(width: 1),

          // Right Side: Preserved Dropdown UI
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.grey[50],
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("pickFrom: \"Fazer\"", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[900])),
                  const Divider(),
                  DropdownButton<String>(
                    value: verbDisplayMode,
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() { verbDisplayMode = newValue; });
                      }
                    },
                    items: <String>[
                      "Guess!",
                      "Only those simple forms which fit",
                      "All simple forms"
                    ].map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value, style: const TextStyle(fontSize: 12)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: _buildVerbList()),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCrosswordGrid(Color letterColor, FontWeight letterWeight) {
    double cellSize = 50.0;
    int overlapColIndex = ovrCol - 1;
    int overlapRowIndex = ovrRow - 1;

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
                  children: [
                    // Render Row Units
                    for (int i = 0; i < rowLen; i++)
                      Positioned(
                        left: i * cellSize,
                        top: overlapColIndex * cellSize, 
                        child: _buildCell(
                          controller: rowControllers[i]!, 
                          color: letterColor, 
                          weight: letterWeight, 
                          size: cellSize, 
                          node: rowNodes[i]!, 
                          type: i == overlapRowIndex ? CellType.overlapCell : CellType.rowCell
                        ),
                      ),
                    // Render Column Units (Skipping overlap to prevent doubling UI)
                    for (int i = 0; i < colLen; i++)
                      if (i != overlapColIndex)
                        Positioned(
                          left: overlapRowIndex * cellSize, 
                          top: i * cellSize,
                          child: _buildCell(
                            controller: colControllers[i]!, 
                            color: letterColor, 
                            weight: letterWeight, 
                            size: cellSize, 
                            node: colNodes[i]!, 
                            type: CellType.colCell
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

  // Your preserved _getFilteredForms / _buildVerbList
  List<VerbForm> _getFilteredForms() {
    switch (verbDisplayMode) {
      case "Guess!":
        return [];
      case "Only those simple forms which fit":
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

  Widget _buildVerbList() {
    List<VerbForm> formsToShow = _getFilteredForms();

    if (formsToShow.isEmpty) {
      return Center(
        child: Text(
          verbDisplayMode == "Guess!" ? "Make your guess!" : "No forms match.",
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: formsToShow.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Text(
            "${formsToShow[index].label}: ${formsToShow[index].form}",
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
          ),
        );
      },
    );
  }

  // Notice: The custom Focus wrapper is gone, logic handled seamlessly via custom FocusNode!
  Widget _buildCell({
    required TextEditingController controller, 
    required Color color, 
    required FontWeight weight, 
    required double size, 
    required FocusNode node, 
    required CellType type
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black87), // Preserved your black87 request
        color: Colors.white,
      ),
      child: TextField(
        controller: controller,
        focusNode: node,
        maxLength: 1,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.characters,
        style: TextStyle(color: color, fontWeight: weight, fontSize: 20),
        decoration: const InputDecoration(
          counterText: "",
          border: InputBorder.none,
          contentPadding: EdgeInsets.only(bottom: 4)
        ),
        onTap: () => _handleCellTap(type),
        onChanged: _onCellTextChanged,
      ),
    );
  }

  void _initializeData() {
    // Linked to your separate fazer_forms.dart import
    fazerForms = fazerFormsList;
  }
}