import 'package:flutter/material.dart';
import "dart:math";


class SudokuDraggableGrid extends StatefulWidget {
  const SudokuDraggableGrid({super.key});

  @override
  State<SudokuDraggableGrid> createState() => _SudokuDraggableGridState();
}
enum PuzzleDifficulty { easy, medium, hard }

class _SudokuDraggableGridState extends State<SudokuDraggableGrid> {
  late List<int?> _board;
  final Random _random = Random();
  
  // Track active player difficulty selection
  PuzzleDifficulty _currentDifficulty = PuzzleDifficulty.medium; 

  @override
  void initState() {
    super.initState();
    _currentDifficulty = PuzzleDifficulty.medium; // DOUBLE INSURANCE: Explicitly verify it's assigned before setup methods run
    _generateRandomPuzzle();
  }

   void _generateRandomPuzzle() {
    setState(() {
      // 1. Generate base sequence 1, 2, 3 dynamically and shuffle it
      final List<int> firstRow = List.generate(3, (i) => i + 1)..shuffle(_random);
      
      // 2. Perform a mathematical shift to build the 2nd and 3rd rows safely without bracket inputs
      final List<int> secondRow = List.generate(3, (i) => firstRow[(i + 1) % 3]);
      final List<int> thirdRow = List.generate(3, (i) => firstRow[(i + 2) % 3]);

      // Flatten safely using cascading operators
      final List<int> completeGrid = List<int>.from(firstRow)
        ..addAll(secondRow)
        ..addAll(thirdRow);

      _board = List<int?>.from(completeGrid);
      
      int holesCount;
      switch (_currentDifficulty) {
        case PuzzleDifficulty.easy:
          holesCount = 2;
          break;
        case PuzzleDifficulty.medium:
          holesCount = 5;
          break;
        case PuzzleDifficulty.hard:
          holesCount = 7;
          break;
      }

      final List<int> indices = List.generate(9, (index) => index)..shuffle(_random);
      for (int i = 0; i < holesCount; i++) {
        _board[indices[i]] = null;
      }
    });
  }

  // Calculates the missing inventory counts using standard multipliers
  List<int> _getSidebarPool() {
    // Generates three 1s, three 2s, and three 3s dynamically: [1,1,1,2,2,2,3,3,3]
    final List<int> requiredPool = List.generate(9, (index) => (index ~/ 3) + 1);
    
    for (var num in _board) {
      if (num != null) {
        requiredPool.remove(num);
      }
    }
    return requiredPool;
  }

  // Performs cross-checking to highlight duplicate values within any row or column
  Set<int> _findConflictingIndices() {
    final Set<int> conflictingIndices = {};

    // 1. Check rows for matching duplicates
    for (int row = 0; row < 3; row++) {
      final Map<int, List<int>> rowValues = {};
      for (int col = 0; col < 3; col++) {
        int index = row * 3 + col;
        int? val = _board[index];
        if (val != null) {
          rowValues.putIfAbsent(val, () => []).add(index);
        }
      }
      rowValues.forEach((val, indices) {
        if (indices.length > 1) conflictingIndices.addAll(indices);
      });
    }

    // 2. Check columns for matching duplicates
    for (int col = 0; col < 3; col++) {
      final Map<int, List<int>> colValues = {};
      for (int row = 0; row < 3; row++) {
        int index = row * 3 + col;
        int? val = _board[index];
        if (val != null) {
          colValues.putIfAbsent(val, () => []).add(index);
        }
      }
      colValues.forEach((val, indices) {
        if (indices.length > 1) conflictingIndices.addAll(indices);
      });
    }

    return conflictingIndices;
  }

  @override
  Widget build(BuildContext context) {
    final conflictingIndices = _findConflictingIndices();
    final sidebarPool = _getSidebarPool();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "3x3 Sudoku Mini Puzzle",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 6),
        const Text(
          "Each row and column must contain digits 1, 2, and 3",
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 24),

// diff selector
Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: PuzzleDifficulty.values.map((difficulty) {
    // Determine if this specific button is currently active
    final bool isSelected = _currentDifficulty == difficulty;
    
    // Convert enum name to a clean display string (e.g. "easy" -> "Easy")
    final String label = difficulty.name[0].toUpperCase() + difficulty.name.substring(1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _currentDifficulty = difficulty; // Guaranteed non-null transfer
            _generateRandomPuzzle();
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.blue : Colors.grey[300],
          foregroundColor: isSelected ? Colors.white : Colors.black87,
          elevation: isSelected ? 2 : 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }).toList(),
),
const SizedBox(height: 24),


        // sudoku grid
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.blueGrey,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blueGrey, width: 3),
          ),
          width: 300,
          height: 300,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _board.length,
            itemBuilder: (context, index) {
              final isConflicting = conflictingIndices.contains(index);
              final tileValue = _board[index];

              return DragTarget<Map<String, dynamic>>(
                onAcceptWithDetails: (details) {
                  setState(() {
                    final data = details.data;
                    final String from = data['from'];
                    final int draggedValue = data['value'];

                    if (from == 'board') {
                      final int originalIndex = data['index'];
                      final temp = _board[index];
                      _board[index] = _board[originalIndex];
                      _board[originalIndex] = temp;
                    } else if (from == 'sidebar') {
                      _board[index] = draggedValue;
                    }
                  });
                },
                builder: (context, candidateData, rejectedData) {
                  if (tileValue == null) {
                    return _buildTile(null);
                  }

                  return Draggable<Map<String, dynamic>>(
                    data: {'from': 'board', 'index': index, 'value': tileValue},
                    dragAnchorStrategy: pointerDragAnchorStrategy,
                    feedback: Material(
                      color: Colors.transparent,
                      child: _buildTile(tileValue, isDragging: true, hasConflict: isConflicting),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.2,
                      child: _buildTile(tileValue, hasConflict: isConflicting),
                    ),
                    child: _buildTile(tileValue, hasConflict: isConflicting),
                  );
                },
              );
            },
          ),
        ),

        const SizedBox(height: 30),
        const Text(
          "Available Inventory (Drag to Grid)",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black54),
        ),
        const SizedBox(height: 12),

        // overflow pool
        DragTarget<Map<String, dynamic>>(
  onAcceptWithDetails: (details) {
    setState(() {
      final data = details.data;
      if (data['from'] == 'board') {
        final int originalIndex = data['index'];
        _board[originalIndex] = null;
      }
    });
  },
  builder: (context, candidateData, rejectedData) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 320,

      padding: const EdgeInsets.all(12), 
      decoration: BoxDecoration(
        color: candidateData.isNotEmpty ? Colors.red.withValues() : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: candidateData.isNotEmpty ? Colors.red : Colors.grey[400]!,
          width: 2,
        ),
      ),
      child: sidebarPool.isEmpty && !_board.contains(null) && conflictingIndices.isEmpty
          ? const Center(
              child: Text(
                "Solved!",
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            )
          : Wrap(
              // Wrap automatically flows items onto new rows to prevent layout overflow
              alignment: WrapAlignment.center,
              spacing: 8.0,    // Horizontal space between tiles
              runSpacing: 8.0, // Vertical space between wrapped rows
              children: sidebarPool.map((number) {
                return Draggable<Map<String, dynamic>>(
                  data: {'from': 'sidebar', 'value': number},
                  dragAnchorStrategy: pointerDragAnchorStrategy,
                  feedback: Material(
                    color: Colors.transparent,
                    child: _buildTile(number, isDragging: true),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.3,
                    child: _buildTile(number),
                  ),
                  child: _buildTile(number),
                );
              }).toList(),
            ),
    );
  },
),

        const SizedBox(height: 30),

        // regen puzzle
        ElevatedButton.icon(
          onPressed: _generateRandomPuzzle,
          icon: const Icon(Icons.casino, color: Colors.white),
          label: const Text("New Puzzle", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTile(int? value, {bool isDragging = false, bool hasConflict = false}) {
    Color tileColor = Colors.white;
    Color textColor = Colors.black87;

    if (hasConflict) {
      tileColor = const Color(0xFFFFEBEE); 
      textColor = Colors.red;
    } else if (isDragging) {
      tileColor = Colors.blue;
      textColor = Colors.white;
    }

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
                color: value == null ? Colors.blueGrey : tileColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                      color: hasConflict ? Colors.red : (value == null ? Colors.transparent : Colors.grey[300]!),
                      width: hasConflict ? 2 : 1,
                ),
                boxShadow: isDragging
                ? [const BoxShadow(color: Colors.black12, blurRadius: 6, spreadRadius: 1)]
                : null,
                ),
      alignment: Alignment.center,
      child: Text(
      value != null ? '$value' : '',
      style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 22,
                      ),
                  ),
          );
        }
}

class SudokuPg extends StatelessWidget {
  const SudokuPg({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
              appBar: AppBar(title: const Text('Sudoku Training', 
                                         style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 26,
                                                fontWeight: .bold, 
                                         ),
        
        ), 
        
        centerTitle: true,
        backgroundColor:  const Color(0xFF177E89),
        ),
      body: Center(
        child: SudokuDraggableGrid(),
      ),
    );
  }
}
