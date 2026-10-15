import 'package:flutter/material.dart';
import 'dart:math';

class NoteData {
  final int lane;
  double topPosition; // Starts further above screen (-0.3) to appear sooner
  bool isHit;

  NoteData({
    required this.lane,
    this.topPosition = -0.3,
    this.isHit = false,
  });
}

class RhythmSwapGame extends StatefulWidget {
  const RhythmSwapGame({super.key});

  @override
  State<RhythmSwapGame> createState() => _RhythmSwapGameState();
}

class _RhythmSwapGameState extends State<RhythmSwapGame> with SingleTickerProviderStateMixin {
  late AnimationController _gameController;
  final List<NoteData> _activeNotes = [];
  final Random _random = Random();
  
  int _score = 0;
  int _combo = 0;
  double _spawnTimer = 0;

  // Feedback tracking for indicators
  String _lastJudgment = '';
  Color _lastJudgmentColor = Colors.grey;

  // Track pressed state for each lane button
  final List<bool> _pressedLanes = [false, false, false];

  // Tracking metrics for the 30-tile limit
  int _totalSpawned = 0;
  int _totalHit = 0;
  bool _isGameOver = false;

  static const int _maxTiles = 30;
  static const Color _primaryColor = Color(0xFF177E89);
  
  // Perfect hit position constant used for both line rendering and hit detection
  static const double _perfectPosition = 0.85;

  @override
  void initState() {
    super.initState();
    _resetGame();

    // Game loop running at 60 FPS via Ticker
    _gameController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _gameController.addListener(_updateGameLoop);
  }

  void _resetGame() {
    setState(() {
      _activeNotes.clear();
      _score = 0;
      _combo = 0;
      _spawnTimer = 0;
      _totalSpawned = 0;
      _totalHit = 0;
      _lastJudgment = '';
      _lastJudgmentColor = Colors.grey;
      _pressedLanes.fillRange(0, 3, false);
      _isGameOver = false;
    });
  }

  @override
  void dispose() {
    _gameController.dispose();
    super.dispose();
  }

  void _updateGameLoop() {
    if (_isGameOver) return;

    setState(() {
      double deltaTime = 0.016; // approximate delta for 60fps
      _spawnTimer += deltaTime;

      // Spawn a new note every 1.5 seconds if we haven't reached 30 tiles
      if (_spawnTimer > 1.5 && _totalSpawned < _maxTiles) {
        _spawnTimer = 0;
        _totalSpawned++;
        int lane = _random.nextInt(3);
        _activeNotes.add(NoteData(lane: lane));
      }

      // Falling speed (0.45)
      for (var note in _activeNotes) {
        note.topPosition += deltaTime * 0.45; 
      }

      // Check for missed notes that passed the bottom interceptor line
      for (int i = _activeNotes.length - 1; i >= 0; i--) {
        var note = _activeNotes[i];
        if (note.topPosition > 0.95) {
          // Missed note
          _combo = 0;
          _lastJudgment = 'MISS';
          _lastJudgmentColor = Colors.red;
          _activeNotes.removeAt(i);
        }
      }

      // Check if game is finished (all 30 tiles spawned and resolved)
      if (_totalSpawned >= _maxTiles && _activeNotes.isEmpty) {
        _isGameOver = true;
      }
    });
  }

  void _handleLaneTap(int lane) {
    if (_isGameOver) return;
    setState(() {
      int hitIndex = -1;
      String judgment = '';
      Color judgmentColor = Colors.grey;

      // Look for a note in this lane within the hit window (~0.70 to 0.95)
      for (int i = 0; i < _activeNotes.length; i++) {
        var note = _activeNotes[i];
        if (note.lane == lane && !note.isHit) {
          if (note.topPosition >= 0.70 && note.topPosition <= 0.95) {
            hitIndex = i;
            double diff = note.topPosition - _perfectPosition;

            // Timing windows aligned precisely with the target line
            if (diff.abs() <= 0.03) {
              judgment = 'PERFECT';
              judgmentColor = Colors.green;
              _score += 100 * (_combo > 0 ? _combo : 1);
            } else if (diff < 0) {
              judgment = 'EARLY';
              judgmentColor = Colors.orange;
              _score += 50 * (_combo > 0 ? _combo : 1);
            } else {
              judgment = 'LATE';
              judgmentColor = Colors.blue;
              _score += 50 * (_combo > 0 ? _combo : 1);
            }
            break;
          }
        }
      }

      if (hitIndex != -1) {
        _combo++;
        _totalHit++;
        _activeNotes.removeAt(hitIndex);
        _lastJudgment = judgment;
        _lastJudgmentColor = judgmentColor;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 360,
        height: 600,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, spreadRadius: 2)],
        ),
        child: _isGameOver ? _buildFeedbackView() : _buildGamePlayView(),
      ),
    );
  }

  Widget _buildGamePlayView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Score, Combo & Tile Count Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Score: $_score", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text("Tile: $_totalSpawned/$_maxTiles", style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w600)),
            Text("Combo: x$_combo", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.orange)),
          ],
        ),

        // Falling Notes Area with Side Indicator Panel
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                // Rhythm Track (takes flex space, pushing lanes naturally left)
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ClipRect(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          double trackHeight = constraints.maxHeight;
                          double targetTopOffset = _perfectPosition * (trackHeight - 24);

                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Lane dividers
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: List.generate(2, (_) => Container(width: 1, color: Colors.grey[300])),
                              ),
                              // Falling Notes
                              ..._activeNotes.map((note) {
                                double laneWidth = constraints.maxWidth / 3;
                                double leftPos = note.lane * laneWidth + (laneWidth - 60) / 2;
                                double topPos = note.topPosition * (trackHeight - 24);

                                return Positioned(
                                  left: leftPos,
                                  top: topPos,
                                  child: Container(
                                    width: 60,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: _primaryColor,
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
                                    ),
                                  ),
                                );
                              }),
                              // Interceptor Line Indicator
                              Positioned(
                                top: targetTopOffset + 12,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 2,
                                  color: _primaryColor.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Side Indicator Panel
                SizedBox(
                  width: 80,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "STATUS",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          width: double.infinity,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _lastJudgmentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _lastJudgmentColor, width: 1.5),
                          ),
                          child: Text(
                            _lastJudgment.isEmpty ? '-' : _lastJudgment,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _lastJudgment.isEmpty ? Colors.grey : _lastJudgmentColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildIndicatorLegend("PERF", Colors.green),
                        const SizedBox(height: 6),
                        _buildIndicatorLegend("EARLY", Colors.orange),
                        const SizedBox(height: 6),
                        _buildIndicatorLegend("LATE", Colors.blue),
                        const SizedBox(height: 6),
                        _buildIndicatorLegend("MISS", Colors.red),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Tappable Lane Buttons perfectly matched to the track's left layout and width
        Column(
          children: [
            const Text(
              "Tap lane buttons when notes reach the line!",
              style: TextStyle(fontSize: 12, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 70,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _primaryColor, width: 2),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          clipBehavior: Clip.none,
                          children: List.generate(3, (index) {
                            double laneWidth = constraints.maxWidth / 3;
                            double leftPos = index * laneWidth + (laneWidth - 60) / 2;
                            bool isPressed = _pressedLanes[index];

                            return Positioned(
                              left: leftPos,
                              top: 0,
                              child: GestureDetector(
                                onTapDown: (_) {
                                  setState(() {
                                    _pressedLanes[index] = true;
                                  });
                                  _handleLaneTap(index);
                                },
                                onTapUp: (_) {
                                  setState(() {
                                    _pressedLanes[index] = false;
                                  });
                                },
                                onTapCancel: () {
                                  setState(() {
                                    _pressedLanes[index] = false;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 50),
                                  width: 60, // Exactly matches note width
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: isPressed ? const Color(0xFF0F525A) : _primaryColor,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: isPressed
                                        ? [const BoxShadow(color: Colors.black12, blurRadius: 1, offset: Offset(0, 1))]
                                        : [const BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 2))],
                                    border: isPressed ? Border.all(color: Colors.white, width: 1.5) : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    "L${index + 1}",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: isPressed ? 11.5 : 12,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Empty spacing box to balance out the side status panel width so widths line up perfectly
                const SizedBox(width: 80),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIndicatorLegend(String label, Color color) {
    bool isActive = _lastJudgment == (label == "PERF" ? "PERFECT" : label);
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackView() {
    double accuracy = _maxTiles > 0 ? (_totalHit / _maxTiles) * 100 : 0.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.emoji_events, size: 64, color: Colors.amber),
        const SizedBox(height: 12),
        const Text(
          "Performance Summary",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: [
              _buildFeedbackRow("Final Score", "$_score"),
              const Divider(height: 20),
              _buildFeedbackRow("Tiles Hit", "$_totalHit / $_maxTiles"),
              const Divider(height: 20),
              _buildFeedbackRow("Accuracy", "${accuracy.toStringAsFixed(1)}%"),
            ],
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _resetGame,
          icon: const Icon(Icons.replay, color: Colors.white),
          label: const Text(
            "Play Again",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 15, color: Colors.black54, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class RhythmGamePg extends StatelessWidget {
  const RhythmGamePg({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF177E89);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Rhythm Game', 
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold, 
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
      ),
      body: const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: RhythmSwapGame(),
      ),
    );
  }
}