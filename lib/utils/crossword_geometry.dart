// grid_geometry.dart

class OverlapPoint {
  final int row;
  final int col;
  final int rowCharIndex; // Which index in the "row word" is the overlap
  final int colCharIndex; // Which index in the "col word" is the overlap

  OverlapPoint({
    required this.row,
    required this.col,
    required this.rowCharIndex,
    required this.colCharIndex,
  });
}

class GridGeometry {
  final int rowCount;
  final int colCount;
  final List<int> rowLengths; // e.g., [5, 5]
  final List<int> colLengths; // e.g., [3, 3]
  final List<OverlapPoint> overlaps;

  GridGeometry({
    required this.rowCount,
    required this.colCount,
    required this.rowLengths,
    required this.colLengths,
    required this.overlaps,
  }) {
    // These run the moment you create a puzzle to guarantee it's valid
    _validateGeometry();
    _validateConsistency();
  }

  // 1. Checks if overlaps fit inside the words
  void _validateGeometry() {
    for (var o in overlaps) {
      if (o.row >= rowCount || o.col >= colCount) {
        throw Exception("Overlap out of bounds");
      }
      if (rowLengths[o.row] <= o.rowCharIndex) {
        throw Exception("Row ${o.row} length too short for overlap");
      }
      if (colLengths[o.col] <= o.colCharIndex) {
        throw Exception("Col ${o.col} length too short for overlap");
      }
    }
  }

  // 2. Checks if the physical distances between overlaps make sense
  void _validateConsistency() {
    if (overlaps.length >= 2) {
      int rowDiff = (overlaps[1].rowCharIndex - overlaps[0].rowCharIndex).abs();
      int colDiff = (overlaps[1].colCharIndex - overlaps[0].colCharIndex).abs();
      
      if (rowDiff != colDiff) {
        throw Exception("Geometric Inconsistency: Row difference ($rowDiff) and Col difference ($colDiff) do not match!");
      }
    }
  }

  // 3. Helper method you will use in your UI to draw the grid
  bool isOverlap(int r, int c) {
    return overlaps.any((point) => point.row == r && point.col == c);
  }
}

// --- YOUR PUZZLE INSTANCE ---

// Initialize a crossword grid geometry class including overlaps
final myPuzzle = GridGeometry(
  rowCount: 2,
  colCount: 2,
  rowLengths: [5, 5],
  colLengths: [3, 3],
  overlaps: [
    OverlapPoint(row: 0, col: 0, rowCharIndex: 0, colCharIndex: 0),
    // NOTE: This second overlap will currently trigger your Geometry Inconsistency error!
    // Row diff is 2 (2 - 0), but Col diff is 1 (1 - 0). 
    OverlapPoint(row: 1, col: 1, rowCharIndex: 2, colCharIndex: 1), 
  ],
);