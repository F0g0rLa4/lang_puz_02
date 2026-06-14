import 'package:flutter/material.dart';

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
  VerbForm(this.form, this.label);
}

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
    fazerForms = [
      // --- INDICATIVO ---
      // Presente
      VerbForm("faço", "1st pres. indic."),
      VerbForm("fazes", "2nd pres. indic."),
      VerbForm("faz", "3rd pres. indic."),
      VerbForm("fazemos", "1st pl. pres. indic."),
      VerbForm("fazeis", "2nd pl. pres. indic."),
      VerbForm("fazem", "3rd pl. pres. indic."),
      // Pretérito Perfeito
      VerbForm("fiz", "1st pret. perf. indic."),
      VerbForm("fizeste", "2nd pret. perf. indic."),
      VerbForm("fez", "3rd pret. perf. indic."),
      VerbForm("fizemos", "1st pl. pret. perf. indic."),
      VerbForm("fizestes", "2nd pl. pret. perf. indic."),
      VerbForm("fizeram", "3rd pl. pret. perf. indic."),
      // Pretérito Imperfeito
      VerbForm("fazia", "1st pret. imperf. indic."),
      VerbForm("fazias", "2nd pret. imperf. indic."),
      VerbForm("fazia", "3rd pret. imperf. indic."),
      VerbForm("fazíamos", "1st pl. pret. imperf. indic."),
      VerbForm("fazíeis", "2nd pl. pret. imperf. indic."),
      VerbForm("faziam", "3rd pl. pret. imperf. indic."),
      // Pretérito Mais-que-Perfeito
      VerbForm("fizera", "1st m-q-perf. indic."),
      VerbForm("fizeras", "2nd m-q-perf. indic."),
      VerbForm("fizera", "3rd m-q-perf. indic."),
      VerbForm("fizéramos", "1st pl. m-q-perf. indic."),
      VerbForm("fizéreis", "2nd pl. m-q-perf. indic."),
      VerbForm("fizeram", "3rd pl. m-q-perf. indic."),
      // Futuro do Presente
      VerbForm("farei", "1st fut. pres. indic."),
      VerbForm("farás", "2nd fut. pres. indic."),
      VerbForm("fará", "3rd fut. pres. indic."),
      VerbForm("faremos", "1st pl. fut. pres. indic."),
      VerbForm("fareis", "2nd pl. fut. pres. indic."),
      VerbForm("farão", "3rd pl. fut. pres. indic."),
      // Futuro do Pretérito (Condicional)
      VerbForm("faria", "1st fut. pret. indic."),
      VerbForm("farias", "2nd fut. pret. indic."),
      VerbForm("faria", "3rd fut. pret. indic."),
      VerbForm("faríamos", "1st pl. fut. pret. indic."),
      VerbForm("faríeis", "2nd pl. fut. pret. indic."),
      VerbForm("fariam", "3rd pl. fut. pret. indic."),

      // --- SUBJUNTIVO ---
      // Presente
      VerbForm("faça", "1st pres. subj."),
      VerbForm("faças", "2nd pres. subj."),
      VerbForm("faça", "3rd pres. subj."),
      VerbForm("façamos", "1st pl. pres. subj."),
      VerbForm("façais", "2nd pl. pres. subj."),
      VerbForm("façam", "3rd pl. pres. subj."),
      // Imperfeito
      VerbForm("fizesse", "1st imperf. subj."),
      VerbForm("fizesses", "2nd imperf. subj."),
      VerbForm("fizesse", "3rd imperf. subj."),
      VerbForm("fizéssemos", "1st pl. imperf. subj."),
      VerbForm("fizésseis", "2nd pl. imperf. subj."),
      VerbForm("fizessem", "3rd pl. imperf. subj."),
      // Futuro
      VerbForm("fizer", "1st fut. subj."),
      VerbForm("fizeres", "2nd fut. subj."),
      VerbForm("fizer", "3rd fut. subj."),
      VerbForm("fizermos", "1st pl. fut. subj."),
      VerbForm("fizerdes", "2nd pl. fut. subj."),
      VerbForm("fizerem", "3rd pl. fut. subj."),

      // --- IMPERATIVO ---
      VerbForm("faze", "2nd imperat. afirm."), // ou faz
      VerbForm("faça", "3rd imperat. afirm."),
      VerbForm("façamos", "1st pl. imperat. afirm."),
      VerbForm("fazei", "2nd pl. imperat. afirm."),
      VerbForm("façam", "3rd pl. imperat. afirm."),

      // --- INFINITIVO PESSOAL ---
      VerbForm("fazer", "1st inf. pessoal"),
      VerbForm("fazeres", "2nd inf. pessoal"),
      VerbForm("fazer", "3rd inf. pessoal"),
      VerbForm("fazermos", "1st pl. inf. pessoal"),
      VerbForm("fazerdes", "2nd pl. inf. pessoal"),
      VerbForm("fazerem", "3rd pl. inf. pessoal"),

      // --- FORMAS NOMINAIS ---
      VerbForm("fazer", "inf. impessoal"),
      VerbForm("fazendo", "gerúndio"),
      VerbForm("feito", "particípio"),
    ];
  }
}