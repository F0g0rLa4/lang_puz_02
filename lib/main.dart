import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
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

// --- WIDGET DEFINITIONS ---
class CrosswordHomepage extends StatefulWidget {
  const CrosswordHomepage({super.key});

  @override
  State<CrosswordHomepage> createState() => _CrosswordHomepageState();
}

class _CrosswordHomepageState extends State<CrosswordHomepage> {
  // Puzzle Definition: (colLen, rowLen, ovr=(colIdx1Based, rowIdx1Based))
  // Per spec: thisPuz = (3, 5, (2, 5))
  final int colLen = 3;
  final int rowLen = 5;
  final int ovrCol = 2; // 1-based index where intersection happens in column
  final int ovrRow = 5; // 1-based index where intersection happens in row

  // Controller maps to hold user inputs
  // Column inputs (0-indexed internally)
  final Map<int, TextEditingController> colControllers = {};
  // Row inputs (0-indexed internally)
  final Map<int, TextEditingController> rowControllers = {};

  // Focus nodes for navigation
  final Map<String, FocusNode> focusNodes = {}; // key format: "col_0", "row_0", "overlap"
  
  // Track which word ("row" or "col") the overlap cell was last entered from
  String overlapEnteredFrom = "row"; // default to row
  
  // Track the current navigation mode based on last cell entry
  String navigationMode = ""; // "row" or "col", empty until first entry

  // Validation States
  bool isValidated = false;
  bool isFlashing = false;
  String colTenseLabel = "";
  String rowTenseLabel = "";

  // Dropdown filter for verb display
  String verbDisplayMode = "Guess!"; // "Guess!", "Only those simple forms which fit", "All simple forms"

  // The 70+ Simple Tense Forms of "Fazer"
  late final List<VerbForm> fazerForms;
  
  // Timer for flashing effect
  Timer? flashTimer;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _initializeControllers();
  }

  @override
  void dispose() {
    flashTimer?.cancel();
    for (var c in colControllers.values) {
      c.dispose();
    }
    for (var c in rowControllers.values) {
      c.dispose();
    }
    for (var fn in focusNodes.values) {
      fn.dispose();
    }
    super.dispose();
  }

  void _initializeControllers() {
    for (int i = 0; i < colLen; i++) {
      colControllers[i] = TextEditingController();
      focusNodes["col_$i"] = FocusNode();
    }
    for (int i = 0; i < rowLen; i++) {
      rowControllers[i] = TextEditingController();
      focusNodes["row_$i"] = FocusNode();
    }
    focusNodes["overlap"] = FocusNode();

    // Link the overlapping cell controllers so typing in one updates the other
    colControllers[ovrCol - 1]!.addListener(() {
      final text = colControllers[ovrCol - 1]!.text;
      if (rowControllers[ovrRow - 1]!.text != text) {
        rowControllers[ovrRow - 1]!.text = text;
        _validatePuzzle();
      }
    });

    rowControllers[ovrRow - 1]!.addListener(() {
      final text = rowControllers[ovrRow - 1]!.text;
      if (colControllers[ovrCol - 1]!.text != text) {
        colControllers[ovrCol - 1]!.text = text;
        _validatePuzzle();
      }
    });

    // Add general listeners to all to trigger validation
    for (var c in colControllers.values) {
      c.addListener(_validatePuzzle);
    }
    for (var c in rowControllers.values) {
      c.addListener(_validatePuzzle);
    }
  }

  void _validatePuzzle() {
    // Reconstruct words from input
    String currentColWord = colControllers.values.map((e) => e.text.toLowerCase()).join();
    String currentRowWord = rowControllers.values.map((e) => e.text.toLowerCase()).join();

    // Check if lengths match completely (no empty cells)
    if (currentColWord.length != colLen || currentRowWord.length != rowLen) {
      _setInvalid();
      return;
    }

    // Verify intersection rule inherently handled by listener, but let's double check values
    if (colControllers[ovrCol - 1]!.text.isEmpty || 
        colControllers[ovrCol - 1]!.text != rowControllers[ovrRow - 1]!.text) {
      _setInvalid();
      return;
    }

    // Search for matches in dictionary
    VerbForm? matchedCol = fazerForms.firstWhere(
      (element) => element.form.toLowerCase() == currentColWord,
      orElse: () => VerbForm("", ""),
    );

    VerbForm? matchedRow = fazerForms.firstWhere(
      (element) => element.form.toLowerCase() == currentRowWord,
      orElse: () => VerbForm("", ""),
    );

    if (matchedCol.form.isNotEmpty && matchedRow.form.isNotEmpty) {
      if (!isValidated) {
        setState(() {
          isValidated = true;
          isFlashing = true;
          colTenseLabel = matchedCol.label;
          rowTenseLabel = matchedRow.label;
        });

        // Cancel any existing timer
        flashTimer?.cancel();
        
        // Flash Red simulation: toggle between redAccent and red for 2 seconds, then hold bold red
        int flashCount = 0;
        flashTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
          flashCount++;
          if (flashCount <= 10) { // Flash 10 times (2 seconds total at 200ms intervals)
            setState(() {
              isFlashing = !isFlashing;
            });
          } else {
            timer.cancel();
            setState(() {
              isFlashing = false;
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
        isFlashing = false;
        colTenseLabel = "";
        rowTenseLabel = "";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Color logic based on state spec
    Color letterColor = Colors.blue;
    FontWeight letterWeight = FontWeight.normal;

    if (isValidated) {
      letterColor = isFlashing ? Colors.redAccent : Colors.red;
      letterWeight = FontWeight.bold;
    }

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
                    const Text(
                      "Fill the Crossword with valid forms of FAZER",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 40),
                    _buildCrosswordGrid(letterColor, letterWeight),
                  ],
                ),
              ),
            ),
          ),
          
          // Vertical Divider
          const VerticalDivider(width: 1),

          // Right Side: Verb Bank Info Panel ("pickFrom")
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
                        setState(() {
                          verbDisplayMode = newValue;
                        });
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
                  Expanded(
                    child: _buildVerbList(),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  // Layout engine transforming matrix coordinates relative to intersection point
  Widget _buildCrosswordGrid(Color letterColor, FontWeight letterWeight) {
    // We establish a structural layout grid. 
    // The Row's cross vertical alignment anchor will align relative to the intersection point.
    
    int totalGridRows = (ovrCol - 1) > (0) ? (ovrCol) : 1; 
    // To keep it simple, let's use Stack positioning or absolute coordinate shifts.
    // Given fixed sizes (Col:3, Row:5, intersecting at Col 2, Row 5):
    // Row is horizontal. It spans 5 units wide.
    // Col is vertical. It spans 3 units high.
    // They meet at Row index 4 (0-based) and Col index 1 (0-based).
    
    // Total bounding width = 5 grid units
    // Total bounding height = 3 grid units
    // Column x position is at index 4 (the last block of the row).
    // Row y position is at index 1 (the middle block of the column).

    double cellSize = 50.0;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Label Row for Column Title
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: cellSize * 4), // offset to column placement
              Container(
                width: cellSize,
                alignment: Alignment.center,
                child: Text(
                  colTenseLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red),
                ),
              )
            ],
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row label column
              Container(
                width: 100,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  rowTenseLabel,
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ),
              // Bounding Grid Box
              SizedBox(
                width: cellSize * 5,
                height: cellSize * 3,
                child: Stack(
                  children: [
                    // Render Row Units
                    for (int i = 0; i < rowLen; i++)
                      Positioned(
                        left: i * cellSize,
                        top: (ovrCol - 1) * cellSize, // Row sits at the vertical intersection line
                        child: _buildCell(rowControllers[i]!, letterColor, letterWeight, cellSize, focusNodes["row_$i"]!, "row_$i", true, i),
                      ),
                    // Render Column Units
                    for (int i = 0; i < colLen; i++)
                      // Skip the overlap index to avoid double rendering UI layers stacked awkwardly
                      if (i != (ovrCol - 1))
                        Positioned(
                          left: (ovrRow - 1) * cellSize, // Column sits at horizontal intersection line
                          top: i * cellSize,
                          child: _buildCell(colControllers[i]!, letterColor, letterWeight, cellSize, focusNodes["col_$i"]!, "col_$i", false, i),
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

  Widget _buildCell(TextEditingController controller, Color color, FontWeight weight, double size, FocusNode focusNode, String cellKey, bool isRowCell, int cellIndex) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black87),
        color: Colors.white,
      ),
      child: Focus(
        onKey: (node, event) {
          if (event.isKeyPressed(LogicalKeyboardKey.tab)) {
            if (event.isShiftPressed) {
              _tabBackward(cellKey, isRowCell, cellIndex);
              return KeyEventResult.handled;
            } else {
              _tabForward(cellKey, isRowCell, cellIndex);
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          maxLength: 1,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          style: TextStyle(color: color, fontWeight: weight, fontSize: 20),
          decoration: const InputDecoration(
            counterText: "",
            border: InputBorder.none,
            contentPadding: EdgeInsets.only(bottom: 4)
          ),
          onChanged: (value) {
            if (value.isNotEmpty) {
              _handleCellInput(cellKey, isRowCell, cellIndex);
            }
          },
        ),
      ),
    );
  }

  void _tabForward(String cellKey, bool isRowCell, int cellIndex) {
    // Determine which mode to use for navigation
    String mode = navigationMode;
    if (mode.isEmpty) {
      mode = isRowCell ? "row" : "col";
    }
    
    String nextKey = "";
    
    if (mode == "row") {
      // Navigate within row (horizontally)
      final maxIndex = rowLen - 1;
      if (cellIndex < maxIndex) {
        nextKey = "row_${cellIndex + 1}";
      }
    } else {
      // Navigate within column (vertically), skipping the overlap cell
      final maxIndex = colLen - 1;
      if (cellIndex < maxIndex) {
        int nextIndex = cellIndex + 1;
        // Skip the overlap cell (ovrCol - 1)
        if (nextIndex == ovrCol - 1) {
          nextIndex++;
        }
        if (nextIndex <= maxIndex) {
          nextKey = "col_$nextIndex";
        }
      }
    }
    
    if (nextKey.isNotEmpty && focusNodes.containsKey(nextKey)) {
      focusNodes[nextKey]?.requestFocus();
    }
  }

  void _tabBackward(String cellKey, bool isRowCell, int cellIndex) {
    // Determine which mode to use for navigation
    String mode = navigationMode;
    if (mode.isEmpty) {
      mode = isRowCell ? "row" : "col";
    }
    
    String prevKey = "";
    
    if (mode == "row") {
      // Navigate within row (horizontally)
      if (cellIndex > 0) {
        prevKey = "row_${cellIndex - 1}";
      }
    } else {
      // Navigate within column (vertically), skipping the overlap cell
      if (cellIndex > 0) {
        int prevIndex = cellIndex - 1;
        // Skip the overlap cell (ovrCol - 1)
        if (prevIndex == ovrCol - 1) {
          prevIndex--;
        }
        if (prevIndex >= 0) {
          prevKey = "col_$prevIndex";
        }
      }
    }
    
    if (prevKey.isNotEmpty && focusNodes.containsKey(prevKey)) {
      focusNodes[prevKey]?.requestFocus();
    }
  }

  void _handleCellInput(String cellKey, bool isRowCell, int cellIndex) {
    // Determine if this is the overlap cell
    bool isOverlapCell = isRowCell ? (cellIndex == ovrRow - 1) : (cellIndex == ovrCol - 1);
    
    // Set navigation mode based on entry
    if (!isOverlapCell) {
      // Entering a non-overlap cell, set mode
      navigationMode = isRowCell ? "row" : "col";
    } else if (navigationMode.isEmpty) {
      // Entering overlap as first cell, don't set mode yet - wait for next entry
      return;
    }
    
    // Determine which mode to use
    String mode = navigationMode.isEmpty ? (isRowCell ? "row" : "col") : navigationMode;
    
    // Determine next cell based on mode
    String nextKey = "";
    
    if (mode == "row") {
      // Navigate horizontally within row
      final maxIndex = rowLen - 1;
      if (cellIndex < maxIndex) {
        nextKey = "row_${cellIndex + 1}";
      }
    } else {
      // Navigate vertically within column, skipping the overlap cell
      final maxIndex = colLen - 1;
      if (cellIndex < maxIndex) {
        int nextIndex = cellIndex + 1;
        // Skip the overlap cell (ovrCol - 1)
        if (nextIndex == ovrCol - 1) {
          nextIndex++;
        }
        if (nextIndex <= maxIndex) {
          nextKey = "col_$nextIndex";
        }
      }
    }
    
    if (nextKey.isNotEmpty && focusNodes.containsKey(nextKey)) {
      Future.delayed(const Duration(milliseconds: 50), () {
        focusNodes[nextKey]?.requestFocus();
      });
    }
  }

  void _initializeData() {
    fazerForms = fazerFormsList;
  }
}