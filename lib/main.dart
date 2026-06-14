import 'package:flutter/material.dart';
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

  // Validation States
  bool isValidated = false;
  bool isFlashing = false;
  String colTenseLabel = "";
  String rowTenseLabel = "";

  // The 70+ Simple Tense Forms of "Fazer"
  late final List<VerbForm> fazerForms;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _initializeControllers();
  }

  void _initializeControllers() {
    for (int i = 0; i < colLen; i++) {
      colControllers[i] = TextEditingController();
    }
    for (int i = 0; i < rowLen; i++) {
      rowControllers[i] = TextEditingController();
    }

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

        // Flash Red simulation: 1) flash red, 2) then hold bold red
        Future.delayed(const Duration(milliseconds: 400), () {
          setState(() {
            isFlashing = false;
          });
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
                        child: _buildCell(rowControllers[i]!, letterColor, letterWeight, cellSize),
                      ),
                    // Render Column Units
                    for (int i = 0; i < colLen; i++)
                      // Skip the overlap index to avoid double rendering UI layers stacked awkwardly
                      if (i != (ovrCol - 1))
                        Positioned(
                          left: (ovrRow - 1) * cellSize, // Column sits at horizontal intersection line
                          top: i * cellSize,
                          child: _buildCell(colControllers[i]!, letterColor, letterWeight, cellSize),
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

  Widget _buildCell(TextEditingController controller, Color color, FontWeight weight, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black87),
        color: Colors.white,
      ),
      child: TextField(
        controller: controller,
        maxLength: 1,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.characters,
        style: TextStyle(color: color, fontWeight: weight, fontSize: 20),
        decoration: const InputDecoration(
          counterText: "",
          border: InputBorder.none,
          contentPadding: EdgeInsets.only(bottom: 4)
        ),
      ),
    );
  }

  void _initializeData() {
    fazerForms = fazerFormsList;
  }
}