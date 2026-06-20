import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for Keyboard Events & rootBundle
import 'dart:async';  // for Timer
import 'dart:io';     // for File
import 'package:lang_puz_02/utils/app_logger.dart';
// handles different path formats among platforms. p prevents naming collision like "context"
// import 'package:path/path.dart' as p;  
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Desktop SQLite FFI

void main() async {
  //Wakes up Native Engine before runApp wakes the UI asking for data, 
  //so the correct desktop bridge is already in place.
  WidgetsFlutterBinding.ensureInitialized();
    // Initialize desktop SQLite FFI for Windows development
  sqfliteFfiInit();  
  // Initialize the physical log file
  await AppLogger.init();
  databaseFactory = databaseFactoryFfi; // Set factory to FFI instead of default mobile

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

enum CellType { colCell, rowCell, overlapCell } // Strict lists
enum TypeDirection { neutral, across, down }

// --- DATABASE HELPER ---
class DatabaseHelper {
  // Outline: App code calls (e.g.) DatabaseHelper.instance.getAllFazerForms() to get data.
  // getAllFazerForms calls _executeSafeQuery, 
  // executeSafeQuery calls get database which checks for existence, opens db, and returns it

  static final DatabaseHelper instance = DatabaseHelper._init(); // Final only assigned one time
  static Database? _database;   // Static means unchanging once built. Empty at start, no db opened yet
  // Constructor
  DatabaseHelper._init();  //No Return Type + Name Matches + parens ( EMPTY in this case ) 
   // and this one is private.  Bcs defined, no default constructor.

   // Methods
  Future<Database> get database async {
      if (_database != null) return _database!;

      // 1. Define the expected path
      String path = await getDatabasesPath();
      String fullPath = '$path/verball.db';

      // 2. Validate existence (The Fail-Fast Check)
      // This throws the message up to the caller to catch and handle
      // Caller was _loadDataFromDatabase, 
      // which called DatabaseHelper.instance.getAllFazerForms(), 
      // which called _executeSafeQuery, which called this getter
      if (!await File(fullPath).exists()) {
        throw FileSystemException(
          "CRITICAL: Database file 'verball.db' not found at $fullPath. "
          "Please check your installation path and configuration settings."
        );
      }

      // 3. Only proceed if it exists
      _database = await openDatabase(fullPath);
      return _database!;
    }  // ======================

  // Separates db existence logic from getAllFazerForms, and we can reuse the safety check for other queries.
  Future<T> _executeSafeQuery<T>(Future<T> Function(Database db) action) async {
    final db = await instance.database; // This will trigger the Fail-Fast check
    return await action(db);
  }

  // Your query function becomes much simpler:
  Future<List<VerbForm>> getAllFazerForms() async {
    return await _executeSafeQuery((db) async {
      final List<Map<String, dynamic>> maps = await db.query('verb_forms', where: 'verb_id = ?', whereArgs: [1]);
      return List.generate(maps.length, (i) => VerbForm(
        maps[i]['form_text'] as String,
        maps[i]['label_short'] as String,
      ));
    });
}
}

// --- WIDGET DEFINITIONS ---
class CrosswordHomepage extends StatefulWidget {
  const CrosswordHomepage({super.key});

  @override
  State<CrosswordHomepage> createState() => _CrosswordHomepageState();
}

class _CrosswordHomepageState extends State<CrosswordHomepage> {
  final int colLen = 3;
  final int rowLen = 5;
  final int ovrCol = 2; 
  final int ovrRow = 5; 

  final Map<int, TextEditingController> colControllers = {};
  final Map<int, TextEditingController> rowControllers = {};
  final Map<int, FocusNode> colNodes = {};
  final Map<int, FocusNode> rowNodes = {};

  TypeDirection currentDirection = TypeDirection.neutral;

  bool isValidated = false;
  bool showRedLetters = false;
  String colTenseLabel = "";
  String rowTenseLabel = "";
  String verbDisplayMode = "Guess!"; 
  
  Timer? flashTimer;

  // DB Data Variables
  List<VerbForm> fazerForms = [];
  bool isLoading = true; // Track loading state

  @override
  void initState() {
    super.initState();
    _initializeGrid();
    _loadDataFromDatabase(); 
  }

  // --- ASYNC DATA LOADING ---
  Future<void> _loadDataFromDatabase() async {
  try {
    final forms = await DatabaseHelper.instance.getAllFazerForms();
    // The await finished. Did the user leave the screen?
    // If yes, stop the whole function right here.
    if (!mounted) return;  // After await always call mounted check before using context or setState
    setState(() {
      fazerForms = forms;
    });

  } on FileSystemException catch (e) {
    AppLogger.error("Database file not found: ${e.message}");
    // The await threw an error. Did the user leave the screen?
    // We MUST check this before trying to show a dialog using 'context'.
    if (!mounted) return;
    setState(() {
      isLoading = false; // Hide the loading spinner even if there's an error
    });
    // Show a dialog or snackbar to inform the user about the missing database
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
    setState(() {
      isLoading = false; // Hide the loading spinner even if there's an error
    });
    } // If the widget is still mounted
  } // finally
  } // _loadDataFromDatabase

  @override
  void dispose() {
    flashTimer?.cancel();
    final allNodes = {...colNodes.values, ...rowNodes.values};
    for (var node in allNodes) { node.dispose(); }

    final allControllers = {...colControllers.values, ...rowControllers.values};
    for (var controller in allControllers) { controller.dispose(); }
    super.dispose();
  }

  void _initializeGrid() {
    int overlapColIndex = ovrCol - 1;
    int overlapRowIndex = ovrRow - 1;

    TextEditingController overlapController = TextEditingController();
    FocusNode overlapNode = _createCustomFocusNode();
    overlapController.addListener(_validatePuzzle);

    for (int i = 0; i < rowLen; i++) {
      if (i == overlapRowIndex) {
        rowControllers[i] = overlapController;
        rowNodes[i] = overlapNode;
      } else {
        rowControllers[i] = TextEditingController()..addListener(_validatePuzzle);
        rowNodes[i] = _createCustomFocusNode();
      }
    }

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
        } else {
          rowNodes[currentIndex]!.requestFocus();
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
        } else {
          colNodes[currentIndex]!.requestFocus();
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

  void _validatePuzzle() {
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
    // Show a loading spinner if the database is still being read
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
        border: Border.all(color: Colors.black87),
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
}