import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for HardwareKeyboard (Tab interception)

void main() {
  runApp(const CrosswordApp());
}

// --- DATA STRUCTURES ---
class VerbForm {
  final String form;
  final String label;
  VerbForm(this.form, this.label);
}

// 1. Defining the three explicit types of cells you requested.
enum CellType { colCell, rowCell, overlapCell }

// 2. Defining the three positive navigation modes.
enum TypeDirection { neutral, across, down }

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

class CrosswordHomepage extends StatefulWidget {
  const CrosswordHomepage({super.key});

  @override
  State<CrosswordHomepage> createState() => _CrosswordHomepageState();
}

class _CrosswordHomepageState extends State<CrosswordHomepage> {
  // Puzzle Definition (1-based logic as per spec)
  final int colLen = 3;
  final int rowLen = 5;
  final int ovrCol = 2; // Intersection occurs at the 2nd cell of the column
  final int ovrRow = 5; // Intersection occurs at the 5th cell of the row

  // Maps to hold our Controllers and FocusNodes.
  // Using Maps allows us to easily use integer coordinates (0-indexed).
  final Map<int, TextEditingController> colControllers = {};
  final Map<int, TextEditingController> rowControllers = {};
  
  final Map<int, FocusNode> colNodes = {};
  final Map<int, FocusNode> rowNodes = {};

  // State Variables
  bool isValidated = false;
  bool isFlashing = false;
  String colTenseLabel = "";
  String rowTenseLabel = "";
  
  // Start with no cell selected, and neutral direction.
  TypeDirection currentDirection = TypeDirection.neutral;

  late final List<VerbForm> fazerForms;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _initializeGrid();
  }

  /// Sets up the controllers and explicitly links the overlap cell.
  void _initializeGrid() {
    // 0-based indices for the overlap
    int overlapColIndex = ovrCol - 1;
    int overlapRowIndex = ovrRow - 1;

    // A. Create the SINGLE overlap cell objects first.
    // This is the secret to perfect overlap behavior. Both the column
    // and the row will share this exact same controller and focus node.
    TextEditingController overlapController = TextEditingController();
    FocusNode overlapNode = _createCustomFocusNode();
    
    // Add listener to trigger validation whenever text changes
    overlapController.addListener(_validatePuzzle);

    // B. Build Row Cells
    for (int i = 0; i < rowLen; i++) {
      if (i == overlapRowIndex) {
        // Plug in the shared overlap objects
        rowControllers[i] = overlapController;
        rowNodes[i] = overlapNode;
      } else {
        // Create standard row cell
        rowControllers[i] = TextEditingController()..addListener(_validatePuzzle);
        rowNodes[i] = _createCustomFocusNode();
      }
    }

    // C. Build Column Cells
    for (int i = 0; i < colLen; i++) {
      if (i == overlapColIndex) {
        // Plug in the shared overlap objects
        colControllers[i] = overlapController;
        colNodes[i] = overlapNode;
      } else {
        // Create standard column cell
        colControllers[i] = TextEditingController()..addListener(_validatePuzzle);
        colNodes[i] = _createCustomFocusNode();
      }
    }
  }

  /// Creates a FocusNode that strictly listens for Tab and Shift+Tab,
  /// overriding Flutter's default unpredictable screen-based Tab traversal.
  FocusNode _createCustomFocusNode() {
    return FocusNode(
      onKeyEvent: (node, event) {
        // We only care about the moment the key goes down (KeyDownEvent)
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.tab) {
          // Check if Shift is currently being held down
          bool isShift = HardwareKeyboard.instance.isShiftPressed;
          
          // Move forward if just Tab, move backwards if Shift+Tab
          _moveFocus(forward: !isShift);
          
          // Return 'handled' so Flutter doesn't try to move focus on its own
          return KeyEventResult.handled;
        }
        // Let all other keys (like typing letters) pass through normally
        return KeyEventResult.ignored;
      },
    );
  }

  /// Core Navigation Engine: 
  /// Figures out where the cursor should go based on current direction mode.
  void _moveFocus({required bool forward}) {
    // If neutral (meaning they clicked the overlap cell), Tab/Typing doesn't move.
    if (currentDirection == TypeDirection.neutral) return;

    if (currentDirection == TypeDirection.across) {
      // 1. Find which row cell is CURRENTLY focused.
      int currentIndex = -1;
      for (var entry in rowNodes.entries) {
        if (entry.value.hasFocus) {
          currentIndex = entry.key;
          break;
        }
      }
      
      // 2. Calculate the target index (next or previous)
      if (currentIndex != -1) {
        int nextIndex = forward ? currentIndex + 1 : currentIndex - 1;
        // 3. If that cell exists in our row map, jump to it!
        // Notice this doesn't care if the next cell is the overlap cell.
        // It will just focus it and maintain 'across' mode.
        if (rowNodes.containsKey(nextIndex)) {
          rowNodes[nextIndex]!.requestFocus();
        }
      }
    } 
    else if (currentDirection == TypeDirection.down) {
      // 1. Find which col cell is CURRENTLY focused.
      int currentIndex = -1;
      for (var entry in colNodes.entries) {
        if (entry.value.hasFocus) {
          currentIndex = entry.key;
          break;
        }
      }
      
      // 2. Calculate the target index (next or previous)
      if (currentIndex != -1) {
        int nextIndex = forward ? currentIndex + 1 : currentIndex - 1;
        // 3. If that cell exists in our col map, jump to it!
        if (colNodes.containsKey(nextIndex)) {
          colNodes[nextIndex]!.requestFocus();
        }
      }
    }
  }

  /// Triggered whenever a user taps their finger/mouse on a cell
  void _handleCellTap(CellType type) {
    setState(() {
      if (type == CellType.overlapCell) {
        currentDirection = TypeDirection.neutral;
      } else if (type == CellType.rowCell) {
        currentDirection = TypeDirection.across;
      } else if (type == CellType.colCell) {
        currentDirection = TypeDirection.down;
      }
      // NYT Crossword logic specifically avoided: 
      // If you click a row cell twice, it stays across.
    });
  }

  /// Triggered when a letter is actually typed into the box
  void _onCellTextChanged(String value) {
    // If they typed something (length > 0), auto-advance to next cell.
    if (value.isNotEmpty) {
      _moveFocus(forward: true);
    }
  }

  void _validatePuzzle() {
    // Because the overlap cell is shared, we simply read the maps directly!
    String currentColWord = "";
    for (int i = 0; i < colLen; i++) {
      currentColWord += colControllers[i]!.text.toLowerCase();
    }

    String currentRowWord = "";
    for (int i = 0; i < rowLen; i++) {
      currentRowWord += rowControllers[i]!.text.toLowerCase();
    }

    if (currentColWord.length != colLen || currentRowWord.length != rowLen) {
      _setInvalid();
      return;
    }

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
        Future.delayed(const Duration(milliseconds: 400), () {
          setState(() { isFlashing = false; });
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
    Color letterColor = isValidated ? (isFlashing ? Colors.redAccent : Colors.red) : Colors.blue;
    FontWeight letterWeight = isValidated ? FontWeight.bold : FontWeight.normal;

    // Dynamic prompt text based on current mode
    String promptText = "Click a cell to start";
    if (currentDirection == TypeDirection.across) promptText = "Mode: Across (Row)";
    if (currentDirection == TypeDirection.down) promptText = "Mode: Down (Column)";
    if (currentDirection == TypeDirection.neutral) promptText = "Mode: Neutral (Overlap Clicked)";

    return Scaffold(
      appBar: AppBar(title: const String.fromEnvironment("title") == "" ? const Text("Verb Crossword Mockup") : null),
      body: Row(
        children: [
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
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 40),
                    _buildCrosswordGrid(letterColor, letterWeight),
                  ],
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
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
                  Expanded(
                    child: ListView.builder(
                      itemCount: fazerForms.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Text(
                            "${fazerForms[index].label}: ${fazerForms[index].form}",
                            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                          ),
                        );
                      },
                    ),
                  ),
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
          // Column Tense Label
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
              // Row Tense Label
              Container(
                width: 100,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 8),
                child: Text(rowTenseLabel, textAlign: TextAlign.end, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
              ),
              // Bounding Grid Box
              SizedBox(
                width: cellSize * rowLen,
                height: cellSize * colLen,
                child: Stack(
                  children: [
                    // Render the Row (This naturally renders the shared Overlap cell too)
                    for (int i = 0; i < rowLen; i++)
                      Positioned(
                        left: i * cellSize,
                        top: overlapColIndex * cellSize,
                        child: _buildCell(
                          controller: rowControllers[i]!,
                          node: rowNodes[i]!,
                          color: letterColor,
                          weight: letterWeight,
                          size: cellSize,
                          // Determine the specific CellType so onTap behaves correctly
                          type: i == overlapRowIndex ? CellType.overlapCell : CellType.rowCell,
                        ),
                      ),
                    
                    // Render the Column (We SKIP the overlap index here so we don't render it twice)
                    for (int i = 0; i < colLen; i++)
                      if (i != overlapColIndex)
                        Positioned(
                          left: overlapRowIndex * cellSize,
                          top: i * cellSize,
                          child: _buildCell(
                            controller: colControllers[i]!,
                            node: colNodes[i]!,
                            color: letterColor,
                            weight: letterWeight,
                            size: cellSize,
                            type: CellType.colCell,
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

  Widget _buildCell({
    required TextEditingController controller,
    required FocusNode node,
    required Color color,
    required FontWeight weight,
    required double size,
    required CellType type,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(border: Border.all(color: Colors.black87), color: Colors.white),
      child: TextField(
        controller: controller,
        focusNode: node, // Attach the custom FocusNode we created
        maxLength: 1,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.characters,
        style: TextStyle(color: color, fontWeight: weight, fontSize: 20),
        
        // 1. Navigation Rule: Click triggers onTap to set direction mode
        onTap: () => _handleCellTap(type),
        
        // 2. Navigation Rule: Auto-type triggers move focus forward
        onChanged: _onCellTextChanged,
        
        decoration: const InputDecoration(counterText: "", border: InputBorder.none, contentPadding: EdgeInsets.only(bottom: 4)),
      ),
    );
  }

  // Remember to dispose of Nodes and Controllers to prevent memory leaks!
  @override
  void dispose() {
    // Because the overlap cell is shared in both maps, we put them in a Set 
    // to ensure we only dispose of the overlap objects once.
    final allNodes = {...colNodes.values, ...rowNodes.values};
    for (var node in allNodes) { node.dispose(); }

    final allControllers = {...colControllers.values, ...rowControllers.values};
    for (var controller in allControllers) { controller.dispose(); }
    
    super.dispose();
  }

  void _initializeData() {
    // (Truncated list for brevity, same 70 items as your previous code goes here)
    fazerForms = [
      VerbForm("faço", "1st pres. indic."), VerbForm("fazes", "2nd pres. indic."), VerbForm("faz", "3rd pres. indic."),
      VerbForm("fiz", "1st pret. perf. indic."), VerbForm("fez", "3rd pret. perf. indic."), VerbForm("fizer", "1st fut. subj."),
      VerbForm("fazia", "1st pret. imperf. indic."),
    ];
  }
}