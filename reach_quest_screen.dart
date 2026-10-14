
import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math';

// ============================================================
// REACH QUEST - TILE MOVEMENT MODEL
// ============================================================

class ReachTask {
  final String tileId;
  final int? from; // null means the tile bank
  final int to;

  const ReachTask({
    required this.tileId,
    required this.from,
    required this.to,
  });
}

class TransferRecord {
  final String tileId;
  final int? from;
  final int to;
  final double seconds;
  final bool isCorrection;
  final bool correct;

  const TransferRecord({
    required this.tileId,
    required this.from,
    required this.to,
    required this.seconds,
    required this.isCorrection,
    required this.correct,
  });
}

// ============================================================
// REACH QUEST SCREEN
// ============================================================

class ReachQuestScreen extends StatefulWidget {
  const ReachQuestScreen({super.key});

  @override
  State<ReachQuestScreen> createState() => _ReachQuestScreenState();
}

class _ReachQuestScreenState extends State<ReachQuestScreen> {
  static const Color primaryColor = Color(0xFF177E89);

  // Fixed assessment sequence.
  // Each task is valid if all preceding tasks are completed.
  late List<ReachTask> tasks;

  @override
  void initState() {
    super.initState();
    tasks = generateRandomTasks();
  }


  List<ReachTask> generateRandomTasks() {
    final random = Random();

    final List<ReachTask> generatedTasks = [];

    // Virtual board used ONLY to plan valid movements.
    final Map<int, String?> simulatedBoard = {
      for (int i = 1; i <= 9; i++) i: null,
    };

    final Set<String> simulatedBank = {'A', 'B'};

    // Randomize target positions.
    // Each of the 9 positions is visited once.
    final positions = List<int>.generate(
      9,
      (index) => index + 1,
    )..shuffle(random);

    for (int i = 0; i < positions.length; i++) {
      final destination = positions[i];

      String selectedTile;
      int? source;

      // Introduce Tile A on the first task.
      if (i == 0) {
        selectedTile = 'A';
        source = null;
      }

      // Introduce Tile B on the third task.
      else if (i == 2) {
        selectedTile = 'B';
        source = null;
      }

      // Otherwise choose an existing board tile.
      else {
        final occupiedPositions = simulatedBoard.keys
            .where((position) =>
                simulatedBoard[position] != null)
            .toList();

        source = occupiedPositions[
            random.nextInt(occupiedPositions.length)];

        selectedTile = simulatedBoard[source]!;
      }

      // Save the generated instruction.
      generatedTasks.add(
        ReachTask(
          tileId: selectedTile,
          from: source,
          to: destination,
        ),
      );

      // Update the simulated board for the NEXT task.
      if (source == null) {
        simulatedBank.remove(selectedTile);
      } else {
        simulatedBoard[source] = null;
      }

      simulatedBoard[destination] = selectedTile;
    }

    return generatedTasks;
}


  // Board occupancy: null means empty.
  final Map<int, String?> board = {
    for (int i = 1; i <= 9; i++) i: null,
  };

  final Set<String> tileBank = {'A', 'B'};

  String? heldTile;
  int? pickupSource;

  int taskIndex = 0;
  int wrongPlacements = 0;
  int firstAttemptCorrect = 0;
  int completedTasks = 0;

  bool started = false;
  bool finished = false;
  bool isCorrection = false;
  bool firstAttemptFailed = false;

  // When correcting a mistake, the source changes
  // to the position where the tile was wrongly placed.
  int? correctionSource;

  String message = 'Press Start Assessment to begin.';

  final Stopwatch stopwatch = Stopwatch();
  Timer? displayTimer;

  final List<TransferRecord> records = [];
  final Set<int> reachedTargets = {};

  ReachTask get currentTask => tasks[taskIndex];

  bool get isHolding => heldTile != null;

  int? get expectedSource =>
      isCorrection ? correctionSource : currentTask.from;

  int get expectedTarget => currentTask.to;

  double get elapsedSeconds =>
      stopwatch.elapsedMilliseconds / 1000.0;

  // ==========================================================
  // ASSESSMENT METRICS
  // ==========================================================

  double get placementAccuracy {
    if (completedTasks == 0) return 0;
    return firstAttemptCorrect / completedTasks * 100;
  }

  double get reachCoverage {
    final prescribedTargets =
        tasks.map((task) => task.to).toSet();

    if (prescribedTargets.isEmpty) return 0;

    return reachedTargets.length /
        prescribedTargets.length *
        100;
  }

  // Includes the initial transfer for each completed task,
  // including transfers that end at an incorrect location.
  // Correction movements are excluded.
  double get medianInitialTransferTime {
    final times = records
        .where((r) => !r.isCorrection)
        .map((r) => r.seconds)
        .toList()
      ..sort();

    if (times.isEmpty) return 0;

    final middle = times.length ~/ 2;

    if (times.length.isOdd) {
      return times[middle];
    }

    return (times[middle - 1] + times[middle]) / 2;
  }

  int get correctionMovements =>
      records.where((r) => r.isCorrection).length;

  // ==========================================================
  // START / RESET ASSESSMENT
  // ==========================================================

  void startAssessment() {
    displayTimer?.cancel();

    stopwatch
      ..stop()
      ..reset();

    setState(() {
      // Generate a new sequence for every session.
      tasks = generateRandomTasks();

      // Reset all board positions.

      // Return tiles to the bank.
      tileBank
        ..clear()
        ..addAll({'A', 'B'});

      heldTile = null;
      pickupSource = null;
      correctionSource = null;

      taskIndex = 0;
      wrongPlacements = 0;
      firstAttemptCorrect = 0;
      completedTasks = 0;

      started = true;
      finished = false;
      isCorrection = false;
      firstAttemptFailed = false;

      records.clear();
      reachedTargets.clear();

      message = nextInstruction();
    });

    displayTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) {
        if (mounted && stopwatch.isRunning) {
          setState(() {});
        }
      },
    );
  }

  void stopAssessment() {
    stopwatch.stop();
    displayTimer?.cancel();

    setState(() {
      started = false;
      finished = false;
      heldTile = null;
      message = 'Assessment stopped. Press Start to reset.';
    });
  }

  // ==========================================================
  // PICKUP LOGIC
  // ==========================================================

  void pickupFromBank(String tileId) {
    if (!started || finished || isHolding) return;

    if (expectedSource != null ||
        currentTask.tileId != tileId ||
        !tileBank.contains(tileId)) {
      setState(() {
        message = 'Please follow the displayed instruction.';
      });
      return;
    }

    setState(() {
      tileBank.remove(tileId);
      heldTile = tileId;
      pickupSource = null;

      stopwatch
        ..reset()
        ..start();

      message = 'Tile $tileId lifted. '
          'Place it at Position $expectedTarget.';
    });
  }

  void pickupFromBoard(int position) {
    if (!started || finished || isHolding) return;

    final tile = board[position];

    if (expectedSource != position ||
        tile != currentTask.tileId) {
      setState(() {
        message = 'Please pick up Tile ${currentTask.tileId} '
            'from ${sourceName(expectedSource)}.';
      });
      return;
    }

    setState(() {
      heldTile = tile;
      board[position] = null;
      pickupSource = position;

      stopwatch
        ..reset()
        ..start();

      message = 'Tile $tile lifted. '
          'Place it at Position $expectedTarget.';
    });
  }

  // ==========================================================
  // PLACEMENT LOGIC
  // ==========================================================

  void placeTile(int position) {
    if (!started || finished || !isHolding) return;

    // Occupied slots cannot accept another tile.
    if (board[position] != null) {
      setState(() {
        message = 'Position $position is occupied. '
            'Please choose an empty position.';
      });
      return;
    }

    stopwatch.stop();
    final transferTime = elapsedSeconds;

    final correct = position == expectedTarget;

    setState(() {
      // Update the ACTUAL physical board position,
      // even if the placement is incorrect.
      board[position] = heldTile;

      records.add(
        TransferRecord(
          tileId: heldTile!,
          from: pickupSource,
          to: position,
          seconds: transferTime,
          isCorrection: isCorrection,
          correct: correct,
        ),
      );

      heldTile = null;
      pickupSource = null;

      if (correct) {
        handleCorrectPlacement();
      } else {
        handleWrongPlacement(position);
      }
    });
  }

  void handleWrongPlacement(int position) {
    wrongPlacements++;
    firstAttemptFailed = true;

    // The tile is physically at the wrong position.
    // The next instruction must start from there.
    isCorrection = true;
    correctionSource = position;

    message = 'Incorrect placement at Position $position. '
        'Move Tile ${currentTask.tileId} '
        'from Position $position to Position $expectedTarget.';
  }

  void handleCorrectPlacement() {
    // If no mistakes occurred on the initial transfer,
    // count this as a first-attempt success.
    if (!firstAttemptFailed) {
      firstAttemptCorrect++;
    }

    completedTasks++;
    reachedTargets.add(expectedTarget);

    isCorrection = false;
    correctionSource = null;
    firstAttemptFailed = false;

    if (taskIndex < tasks.length - 1) {
      taskIndex++;
      message = 'Correct! ' + nextInstruction();
    } else {
      finished = true;
      displayTimer?.cancel();
      message = 'Assessment completed!';
    }
  }

  // ==========================================================
  // BOARD INTERACTION
  // ==========================================================

  void handleBoardTap(int position) {
    if (!started || finished) return;

    if (isHolding) {
      placeTile(position);
    } else {
      pickupFromBoard(position);
    }
  }

  String sourceName(int? source) {
    return source == null ? 'the Bank' : 'Position $source';
  }

  String nextInstruction() {
    if (expectedSource == null) {
      return 'Pick up a tile from the Bank '
          'and place it at Position $expectedTarget.';
    }

    return 'Move the tile from Position $expectedSource '
        'to Position $expectedTarget.';
  }

  @override
  void dispose() {
    displayTimer?.cancel();
    stopwatch.stop();
    super.dispose();
  }

  // ==========================================================
  // TILE BANK INTERFACE
  // ==========================================================


  Widget buildTileBank() {
    return Card(
      color: const Color(0xFFE4F2F3),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Tile Bank',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'Pick up a tile from the bank when instructed.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 65,
              child: ElevatedButton.icon(
                onPressed: started &&
                        !finished &&
                        !isHolding &&
                        expectedSource == null
                    ? () {
                        // Automatically select the expected tile.
                        pickupFromBank(currentTask.tileId);
                      }
                    : null,

                icon: const Icon(
                  Icons.pan_tool_alt_rounded,
                  size: 26,
                ),

                label: const Text(
                  'Pick Up Tile From Bank',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ==========================================================
  // BOARD INTERFACE
  // ==========================================================

  Widget buildBoard() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 9,
      itemBuilder: (context, index) {
        final position = index + 1;
        final tile = board[position];

        final isSource = started &&
            !finished &&
            !isHolding &&
            expectedSource == position;

        final isTarget = started &&
            !finished &&
            isHolding &&
            expectedTarget == position;

        Color background = Colors.white;
        Color border = Colors.grey.shade300;

        if (tile != null) {
          background = const Color(0xFFDCECF6);
        }

        if (isSource) {
          background = const Color(0xFFD8EBFC);
          border = Colors.blue;
        }

        if (isTarget) {
          background = const Color(0xFFDDF4E8);
          border = Colors.green;
        }

        return Material(
          color: background,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => handleBoardTap(position),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: border,
                  width: isSource || isTarget ? 3 : 1,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    tile != null ? '●' : 'Empty',
                    style: TextStyle(
                      fontSize: tile == null ? 17 : 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Position $position',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ==========================================================
  // RESULTS INTERFACE
  // ==========================================================

  Widget resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildResults() {
    return Card(
      color: const Color(0xFFE4F3EB),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assessment Results',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            resultRow(
              'Completed Tasks',
              '$completedTasks / ${tasks.length}',
            ),

            resultRow(
              'Placement Accuracy',
              '${placementAccuracy.toStringAsFixed(1)}%',
            ),

            resultRow(
              'Reach Coverage',
              '${reachCoverage.toStringAsFixed(1)}%',
            ),

            resultRow(
              'Median Initial Transfer Time',
              '${medianInitialTransferTime.toStringAsFixed(2)} s',
            ),

            resultRow(
              'Wrong Placements',
              '$wrongPlacements',
            ),

            resultRow(
              'Correction Movements',
              '$correctionMovements',
            ),

            const SizedBox(height: 16),

            const Text(
              'Individual Transfer Records',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            ...records.asMap().entries.map((entry) {
              final r = entry.value;
              final type = r.isCorrection
                  ? 'Correction'
                  : 'Initial transfer';

              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  '${sourceName(r.from)} → Position ${r.to}',
                ),
                subtitle: Text(
                  'Tile ${r.tileId} • $type • '
                  '${r.correct ? "Correct" : "Incorrect"}',
                ),
                trailing: Text(
                  '${r.seconds.toStringAsFixed(2)} s',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // MAIN SCREEN INTERFACE
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final instruction = isCorrection
        ? 'Correction: Move the tile from '
            'Position $expectedSource '
            'to Position $expectedTarget.'
        : nextInstruction();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reach Quest'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Motor Assessment',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Follow the instructions to move each tile.',
                  style: TextStyle(fontSize: 17),
                ),

                const SizedBox(height: 20),

                if (started && !finished)
                  Card(
                    color: isCorrection
                        ? const Color(0xFFFFF0D9)
                        : const Color(0xFFE1F2F3),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            'Task ${taskIndex + 1} '
                            'of ${tasks.length}',
                            style: const TextStyle(fontSize: 17),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            instruction,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (!started || finished)
                  SizedBox(
                    height: 58,
                    child: ElevatedButton(
                      onPressed: startAssessment,
                      child: Text(
                        finished
                            ? 'Restart Assessment'
                            : 'Start Assessment',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                buildTileBank(),

                const SizedBox(height: 16),

                buildBoard(),

                const SizedBox(height: 18),

                if (isHolding)
                  Text(
                    'Currently Holding: Tile $heldTile',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),

                const SizedBox(height: 12),

                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),

                const SizedBox(height: 16),

                Text(
                  '${elapsedSeconds.toStringAsFixed(1)} s',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),

                const SizedBox(height: 20),

                if (started && !finished)
                  OutlinedButton(
                    onPressed: stopAssessment,
                    child: const Text('Stop Assessment'),
                  ),

                if (finished) ...[
                  const SizedBox(height: 24),
                  buildResults(),
                ],

                const SizedBox(height: 24),

                const Text(
                  'Simulation Mode: Tile pickup and placement '
                  'are simulated through screen taps. '
                  'No ESP32 sensors are connected yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
