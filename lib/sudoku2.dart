import 'package:flutter/material.dart';
import 'dart:math';

class SudokuDraggableGrid extends StatefulWidget {
  const SudokuDraggableGrid({super.key});

  @override
  State<SudokuDraggableGrid> createState() => _SudokuDraggableGridState();
}

enum PuzzleDifficulty { easy, medium, hard }

class _SudokuDraggableGridState extends State<SudokuDraggableGrid> {
  late List<int?> _board;
  late List<bool> _isInitialTile;
  final Random _random = Random();
  
  PuzzleDifficulty _currentDifficulty = PuzzleDifficulty.medium; 
  int _activeBoxIndex = 0;
  bool _showHintCard = false;
  bool _showHintBox = false;

  @override
  void initState() {
    super.initState();
    _currentDifficulty = PuzzleDifficulty.medium;
    _generateRandomPuzzle();
  }

  void _generateRandomPuzzle() {
    setState(() {
      final List<int> baseSolution = [
        5, 3, 4, 6, 7, 8, 9, 1, 2,
        6, 7, 2, 1, 9, 5, 3, 4, 8,
        1, 9, 8, 3, 4, 2, 5, 6, 7,
        8, 5, 9, 7, 6, 1, 4, 2, 3,
        4, 2, 6, 8, 5, 3, 7, 9, 1,
        7, 1, 3, 9, 2, 4, 8, 5, 6,
        9, 6, 1, 5, 3, 7, 2, 8, 4,
        2, 8, 7, 4, 1, 9, 6, 3, 5,
        3, 4, 5, 2, 8, 6, 1, 7, 9,
      ];

      final List<int> digitMapping = List.generate(9, (i) => i + 1)..shuffle(_random);
      final List<int> completeGrid = baseSolution.map((val) => digitMapping[val - 1]).toList();

      _board = List<int?>.from(completeGrid);
      _isInitialTile = List.filled(81, true);
      
      int holesCount;
      switch (_currentDifficulty) {
        case PuzzleDifficulty.easy:
          holesCount = 30;
          break;
        case PuzzleDifficulty.medium:
          holesCount = 45;
          break;
        case PuzzleDifficulty.hard:
          holesCount = 55;
          break;
      }

      final List<int> indices = List.generate(81, (index) => index)..shuffle(_random);
      for (int i = 0; i < holesCount; i++) {
        int holeIndex = indices[i];
        _board[holeIndex] = null;
        _isInitialTile[holeIndex] = false;
      }
      _activeBoxIndex = 0;
      _showHintBox = false;
    });
  }

  Map<int, int> _getRemainingCounts() {
    final Map<int, int> counts = {for (int i = 1; i <= 9; i++) i: 9};
    for (var val in _board) {
      if (val != null) {
        counts[val] = (counts[val]! - 1).clamp(0, 9);
      }
    }
    return counts;
  }

  List<int> _getRemainingNumbersForActiveBox() {
    final Set<int> presentInBox = {};
    int boxRow = _activeBoxIndex ~/ 3;
    int boxCol = _activeBoxIndex % 3;

    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        int row = boxRow * 3 + r;
        int col = boxCol * 3 + c;
        int index = row * 9 + col;
        int? val = _board[index];
        if (val != null) {
          presentInBox.add(val);
        }
      }
    }

    final List<int> missing = [];
    for (int i = 1; i <= 9; i++) {
      if (!presentInBox.contains(i)) {
        missing.add(i);
      }
    }
    return missing;
  }

  Set<int> _findConflictingIndices() {
    final Set<int> conflictingIndices = {};

    // 1. Check rows
    for (int row = 0; row < 9; row++) {
      final Map<int, List<int>> rowValues = {};
      for (int col = 0; col < 9; col++) {
        int index = row * 9 + col;
        int? val = _board[index];
        if (val != null) {
          rowValues.putIfAbsent(val, () => []).add(index);
        }
      }
      rowValues.forEach((val, indices) {
        if (indices.length > 1) conflictingIndices.addAll(indices);
      });
    }

    // 2. Check columns
    for (int col = 0; col < 9; col++) {
      final Map<int, List<int>> colValues = {};
      for (int row = 0; row < 9; row++) {
        int index = row * 9 + col;
        int? val = _board[index];
        if (val != null) {
          colValues.putIfAbsent(val, () => []).add(index);
        }
      }
      colValues.forEach((val, indices) {
        if (indices.length > 1) conflictingIndices.addAll(indices);
      });
    }

    // 3. Check 3x3 subgrids
    for (int boxRow = 0; boxRow < 3; boxRow++) {
      for (int boxCol = 0; boxCol < 3; boxCol++) {
        final Map<int, List<int>> boxValues = {};
        for (int r = 0; r < 3; r++) {
          for (int c = 0; c < 3; c++) {
            int row = boxRow * 3 + r;
            int col = boxCol * 3 + c;
            int index = row * 9 + col;
            int? val = _board[index];
            if (val != null) {
              boxValues.putIfAbsent(val, () => []).add(index);
            }
          }
        }
        boxValues.forEach((val, indices) {
          if (indices.length > 1) conflictingIndices.addAll(indices);
        });
      }
    }

    return conflictingIndices;
  }

  int _getBoxIndexForCell(int cellIndex) {
    int row = cellIndex ~/ 9;
    int col = cellIndex % 9;
    return (row ~/ 3) * 3 + (col ~/ 3);
  }

  @override
  Widget build(BuildContext context) {
    const customColor = Color(0xFF177E89);
    final conflictingIndices = _findConflictingIndices();
    final remainingCounts = _getRemainingCounts();
    final bool isCompletelyFilled = remainingCounts.values.every((count) => count == 0);
    final missingInBox = _getRemainingNumbersForActiveBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "9x9 Sudoku (Active 3x3 Box Focus)",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          const Text(
            "Tap any cell inside a 3x3 region to make it active and light.",
            style: TextStyle(fontSize: 12, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),

          // Difficulty Selector & Hint Icon Button Side-by-Side
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: PuzzleDifficulty.values.map((difficulty) {
                  final bool isSelected = _currentDifficulty == difficulty;
                  final String label = difficulty.name[0].toUpperCase() + difficulty.name.substring(1);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _currentDifficulty = difficulty;
                          _generateRandomPuzzle();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected ? customColor : Colors.grey[200],
                        foregroundColor: isSelected ? Colors.white : Colors.black87,
                        elevation: isSelected ? 2 : 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(width: 8),
              // Hint Icon Button placed to the right of difficulty settings
              IconButton(
                onPressed: () {
                  setState(() {
                    _showHintCard = !_showHintCard;
                  });
                },
                icon: Icon(
                  _showHintCard ? Icons.lightbulb : Icons.lightbulb_outline,
                  color: _showHintCard ? Colors.amber.shade700 : customColor,
                ),
                tooltip: "Toggle Hint Panel",
                style: IconButton.styleFrom(
                  backgroundColor: _showHintCard ? Colors.amber.shade50 : Colors.grey[200],
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Main Board & Optional Hints Card side-by-side
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              // Main Sudoku Board
              Container(
                width: 366,
                height: 366,
                padding: const EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[400]!, width: 2),
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: 9,
                  itemBuilder: (context, boxIndex) {
                    final bool isActiveBox = boxIndex == _activeBoxIndex;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isActiveBox ? customColor.withValues(alpha: 0.1) : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isActiveBox ? customColor : Colors.grey[300]!,
                          width: isActiveBox ? 2 : 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                        itemCount: 9,
                        itemBuilder: (context, innerIndex) {
                          int boxRow = boxIndex ~/ 3;
                          int boxCol = boxIndex % 3;
                          int r = innerIndex ~/ 3;
                          int c = innerIndex % 3;
                          int globalIndex = (boxRow * 3 + r) * 9 + (boxCol * 3 + c);

                          final isConflicting = conflictingIndices.contains(globalIndex);
                          final tileValue = _board[globalIndex];
                          final isInitial = _isInitialTile[globalIndex];

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _activeBoxIndex = boxIndex;
                                _showHintBox = false; 
                              });
                            },
                            child: DragTarget<Map<String, dynamic>>(
                              onAcceptWithDetails: (details) {
                                if (!isActiveBox) return;
                                if (isInitial) return;

                                setState(() {
                                  final data = details.data;
                                  final String from = data['from'];
                                  final int draggedValue = data['value'];

                                  if (from == 'board') {
                                    final int originalIndex = data['index'];
                                    if (!_isInitialTile[originalIndex] && _getBoxIndexForCell(originalIndex) == _activeBoxIndex) {
                                      final temp = _board[globalIndex];
                                      _board[globalIndex] = _board[originalIndex];
                                      _board[originalIndex] = temp;
                                    }
                                  } else if (from == 'sidebar') {
                                    _board[globalIndex] = draggedValue;
                                  }
                                });
                              },
                              builder: (context, candidateData, rejectedData) {
                                if (tileValue == null) {
                                  return _buildBoardTile(null, isActive: isActiveBox, isInitial: false);
                                }

                                if (isInitial) {
                                  return _buildBoardTile(tileValue, hasConflict: isConflicting, isActive: isActiveBox, isInitial: true);
                                }

                                return Draggable<Map<String, dynamic>>(
                                  data: {'from': 'board', 'index': globalIndex, 'value': tileValue},
                                  dragAnchorStrategy: pointerDragAnchorStrategy,
                                  feedback: Material(
                                    color: Colors.transparent,
                                    child: _buildBoardTile(tileValue, isDragging: true, hasConflict: isConflicting, isActive: isActiveBox, isInitial: false),
                                  ),
                                  childWhenDragging: Opacity(
                                    opacity: 0.2,
                                    child: _buildBoardTile(tileValue, hasConflict: isConflicting, isActive: isActiveBox, isInitial: false),
                                  ),
                                  child: _buildBoardTile(tileValue, hasConflict: isConflicting, isActive: isActiveBox, isInitial: false),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),

              // Hints Card Widget (Shown only when toggled on)
              if (_showHintCard)
                Container(
                  width: 200,
                  height: 366,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 4, spreadRadius: 1),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.lightbulb_outline, color: customColor, size: 20),
                          SizedBox(width: 6),
                          Text(
                            "Box Hint",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Text(
                        "Active Box: #${_activeBoxIndex + 1}",
                        style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Missing numbers in this 3x3 region:",
                        style: TextStyle(fontSize: 11, color: Colors.black45),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Center(
                          child: !_showHintBox
                              ? ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _showHintBox = true;
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: customColor,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text(
                                    "Show Hint",
                                    style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                )
                              : missingInBox.isEmpty
                                  ? const Text(
                                      "Box complete!",
                                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                                      textAlign: TextAlign.center,
                                    )
                                  : Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: missingInBox.map((num) {
                                        return Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: customColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: customColor, width: 1),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '$num',
                                            style: const TextStyle(
                                              color: customColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                        ),
                      ),
                      if (_showHintBox)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _showHintBox = false;
                            });
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(double.infinity, 24),
                          ),
                          child: const Text(
                            "Hide Hint",
                            style: TextStyle(fontSize: 11, color: Colors.redAccent),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),
          const Text(
            "Available Inventory (Drag to Active 3x3 Box)",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black54),
          ),
          const SizedBox(height: 8),

          // Sidebar Pool Container
          DragTarget<Map<String, dynamic>>(
            onAcceptWithDetails: (details) {
              setState(() {
                final data = details.data;
                if (data['from'] == 'board') {
                  final int originalIndex = data['index'];
                  if (!_isInitialTile[originalIndex]) {
                    _board[originalIndex] = null;
                  }
                }
              });
            },
            builder: (context, candidateData, rejectedData) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 390,
                constraints: const BoxConstraints(minHeight: 75, maxHeight: 110),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  color: candidateData.isNotEmpty ? Colors.red.withValues(alpha: 0.1) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: candidateData.isNotEmpty ? Colors.red : Colors.grey[300]!,
                    width: 2,
                  ),
                ),
                child: isCompletelyFilled && conflictingIndices.isEmpty
                    ? const Center(
                        child: Text(
                          "Solved!",
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: remainingCounts.entries.map((entry) {
                            final int number = entry.key;
                            final int count = entry.value;

                            if (count <= 0) return const SizedBox.shrink();

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3.5),
                              child: Draggable<Map<String, dynamic>>(
                                data: {'from': 'sidebar', 'value': number},
                                dragAnchorStrategy: pointerDragAnchorStrategy,
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: _buildInventoryItem(number, count, isDragging: true),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: 0.3,
                                  child: _buildInventoryItem(number, count),
                                ),
                                child: _buildInventoryItem(number, count),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
              );
            },
          ),

          const SizedBox(height: 16),

          // New Puzzle Button
          ElevatedButton.icon(
            onPressed: _generateRandomPuzzle,
            icon: const Icon(Icons.casino, color: Colors.white),
            label: const Text("New Puzzle", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: customColor,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryItem(int number, int count, {bool isDragging = false}) {
    const customColor = Color(0xFF177E89);
    double size = isDragging ? 34 : 33;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isDragging ? customColor : Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isDragging ? customColor : customColor.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: isDragging
                ? [const BoxShadow(color: Colors.black12, blurRadius: 4, spreadRadius: 1)]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: TextStyle(
              color: isDragging ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          "$count left",
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildBoardTile(int? value, {bool isDragging = false, bool hasConflict = false, bool isActive = true, bool isInitial = false}) {
    const customColor = Color(0xFF177E89);
    Color tileColor;
    Color textColor = Colors.black87;
    Color borderColor = isActive ? customColor.withValues(alpha: 0.4) : Colors.grey[300]!;
    double borderWidth = 1;

    if (isInitial) {
      tileColor = Colors.grey[200]!;
      textColor = Colors.black;
    } else {
      tileColor = Colors.white;
    }

    if (hasConflict) {
      if (isInitial) {
        tileColor = const Color(0xFFFFCCBC); 
        textColor = const Color(0xFFB71C1C); 
        borderColor = Colors.red.shade700;
        borderWidth = 2.0;
      } else {
        tileColor = const Color(0xFFFFEBEE); 
        textColor = Colors.red;
        borderColor = Colors.red;
        borderWidth = 2.0;
      }
    } else if (isDragging) {
      tileColor = customColor;
      textColor = Colors.white;
    }

    double size = isDragging ? 35 : 34;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: value == null 
            ? (isActive ? customColor.withValues(alpha: 0.1) : Colors.grey[50]!) 
            : tileColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: hasConflict ? borderColor : (isActive ? customColor.withValues(alpha: 0.4) : Colors.grey[300]!),
          width: hasConflict ? borderWidth : 1,
        ),
        boxShadow: isDragging
            ? [const BoxShadow(color: Colors.black12, blurRadius: 4, spreadRadius: 1)]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        value != null ? '$value' : '',
        style: TextStyle(
          color: value == null ? Colors.transparent : textColor,
          fontWeight: isInitial ? FontWeight.w900 : FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }
}

class SudokuPg extends StatelessWidget {
  const SudokuPg({super.key});

  @override
  Widget build(BuildContext context) {
    const customColor = Color(0xFF177E89);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Sudoku Training', 
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold, 
          ),
        ),
        centerTitle: true,
        backgroundColor: customColor,
      ),
      body: const Center(
        child: SudokuDraggableGrid(),
      ),
    );
  }
}