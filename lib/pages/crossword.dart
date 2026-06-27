
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:lang_puz_02/utils/aa_logger_meta.dart';
import 'package:lang_puz_02/utils/dbhelper_models.dart';
// You must also import wherever you choose to put DatabaseHelper, VerbForm, CellType, and TypeDirection.
// e.g., import 'package:lang_puz_02/utils/database_helper.dart';

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

  List<VerbForm> fazerForms = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeGrid();
    _loadDataFromDatabase(); 
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

  // Handle Return Button with Confirmation
  void _confirmReturn() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Return to Choices?"),
          content: const Text("Do you want to return to Choices and lose your work?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Close dialog
              child: const Text("No"),
            ),
            TextButton(
              onPressed: () {
                // Pop the dialog, then replace current screen with fresh Home screen to reset state completely
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
      // We removed the standard AppBar to create the custom Header Row
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER ROW (Title left, Dropdown right) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    "CrossWord",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  // The Dropdown and List restricted to ~4 lines height
                  Container(
                    width: 250, // Keeps the dropdown from expanding too far left
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
                        Text("pickFrom: \"Fazer\"", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue[900])),
                        DropdownButton<String>(
                          value: verbDisplayMode,
                          isExpanded: true, // Fills the container width
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
                        const SizedBox(height: 4),
                        // Explicitly limits height to roughly 4 lines of text
                        SizedBox(
                          height: 90, 
                          child: _buildVerbList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(),

            // --- MAIN CONTENT BODY (Crossword Grid) ---
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
      
      // --- BOTTOM RIGHT RETURN BUTTON ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _confirmReturn,
        label: const Text("Return"),
        icon: const Icon(Icons.arrow_back),
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
      // Ensures the ListView takes up minimal required space
      shrinkWrap: true, 
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
