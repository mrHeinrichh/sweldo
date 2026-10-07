import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/sw_button.dart';
import '../domain/story_script.dart';
import 'story_stage.dart';
import '../../../core/theme/sw_icons.dart';

/// A video-style player for the Sweldo story: scene progress bars, play and
/// pause, scene skipping, replay, keyboard control and captions.
///
/// It starts on a poster frame and plays only when asked. With reduced
/// motion on, it steps through still frames instead of animating.
class StoryPlayer extends StatefulWidget {
  const StoryPlayer({
    super.key,
    this.onFinishedAction,
    this.finishedLabel,
    this.autoplay = false,
  });

  /// Start playing as soon as the player appears (presentation mode).
  final bool autoplay;

  /// Call to action offered on the last frame.
  final VoidCallback? onFinishedAction;
  final String? finishedLabel;

  @override
  State<StoryPlayer> createState() => _StoryPlayerState();
}

class _StoryPlayerState extends State<StoryPlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(
        vsync: this,
        duration: Duration(milliseconds: (StoryScript.total * 1000).round()),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) setState(() {});
      });

  final _focus = FocusNode(debugLabel: 'story');
  bool _started = false;

  /// A poster frame that shows the payoff: Ana's payout, stamped.
  static const _posterAt = 25.6;

  double get _seconds => _controller.value * StoryScript.total;
  bool get _finished => _controller.isCompleted;

  @override
  void initState() {
    super.initState();
    _controller.value = _posterAt / StoryScript.total;
    if (widget.autoplay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_started) _start();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _reduced => SwMotion.reduced(context);

  void _start() {
    setState(() => _started = true);
    if (_reduced) {
      _controller.value = StoryScript.scenes.first.keyFrame / StoryScript.total;
    } else {
      _controller.forward(from: 0);
    }
  }

  void _toggle() {
    if (!_started) return _start();
    if (_reduced) return _step(1);
    setState(() {
      if (_controller.isAnimating) {
        _controller.stop();
      } else if (_finished) {
        _controller.forward(from: 0);
      } else {
        _controller.forward();
      }
    });
  }

  /// Jumps to a scene; keeps playing if it was playing.
  void _seekScene(int index) {
    final scenes = StoryScript.scenes;
    final i = index.clamp(0, scenes.length - 1);
    final wasPlaying = _controller.isAnimating;
    setState(() => _started = true);
    if (_reduced) {
      _controller.value = scenes[i].keyFrame / StoryScript.total;
      return;
    }
    _controller.value = scenes[i].start / StoryScript.total;
    if (wasPlaying) _controller.forward();
  }

  void _step(int delta) => _seekScene(StoryScript.sceneAt(_seconds) + delta);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final format = constraints.maxWidth >= 700
            ? StageFormat.landscape
            : StageFormat.portrait;
        final stage = format.size;
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.space): _toggle,
            const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                _step(1),
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                _step(-1),
          },
          child: Focus(
            focusNode: _focus,
            child: AspectRatio(
              aspectRatio: stage.width / stage.height,
              child: ClipRRect(
                borderRadius: const BorderRadius.all(SwRadius.panel),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: SwColors.rule),
                    borderRadius: const BorderRadius.all(SwRadius.panel),
                  ),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final g = _seconds;
                      final scene = StoryScript.scenes[StoryScript.sceneAt(g)];
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: () {
                                _focus.requestFocus();
                                _toggle();
                              },
                              child: Semantics(
                                label: 'Sweldo story. ${scene.caption}',
                                liveRegion: _started,
                                child: ExcludeSemantics(
                                  child: FittedBox(
                                    child: StoryStage(g: g, format: format),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_started) ..._controls(g, format),
                          if (!_started) _poster(format),
                          if (_started && _finished && !_reduced)
                            _endCard(format),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _controls(double g, StageFormat format) {
    final scenes = StoryScript.scenes;
    final playing = _controller.isAnimating;
    return [
      Positioned(
        top: 14,
        left: 52,
        right: 52,
        child: Row(
          children: [
            for (var i = 0; i < scenes.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                flex: (scenes[i].duration * 10).round(),
                child: Semantics(
                  button: true,
                  label: 'Scene ${i + 1} of ${scenes.length}',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _seekScene(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(2),
                        ),
                        child: LinearProgressIndicator(
                          value: seg(g, scenes[i].start, scenes[i].end),
                          minHeight: 4,
                          color: SwColors.stamp,
                          backgroundColor: SwColors.ink.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      Positioned(
        left: 48,
        right: 48,
        bottom: 14,
        child: Row(
          children: [
            _RoundControl(
              icon: _reduced
                  ? SwIcons.previous
                  : playing
                  ? SwIcons.pause
                  : SwIcons.play,
              tooltip: _reduced
                  ? 'Previous scene'
                  : playing
                  ? 'Pause'
                  : 'Play',
              onPressed: _reduced ? () => _step(-1) : _toggle,
            ),
            const SizedBox(width: SwSpace.sm),
            _RoundControl(
              icon: SwIcons.next,
              tooltip: 'Next scene',
              onPressed: () => _step(1),
            ),
            const SizedBox(width: SwSpace.md),
            Text(
              '${_clock(g)} / ${_clock(StoryScript.total)}',
              style: SwType.figures.copyWith(fontSize: 12),
            ),
            const Spacer(),
            _RoundControl(
              icon: SwIcons.replay,
              tooltip: 'Replay from the start',
              onPressed: _start,
            ),
          ],
        ),
      ),
    ];
  }

  /// A title card in the lower left, so the poster frame stays visible.
  Widget _poster(StageFormat format) {
    final compact = format == StageFormat.portrait;
    return Positioned(
      left: compact ? 16 : 40,
      right: compact ? 16 : null,
      bottom: compact ? 16 : 40,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 24, 14),
        decoration: BoxDecoration(
          color: SwColors.sheet,
          borderRadius: const BorderRadius.all(SwRadius.sheet),
          border: Border.all(color: SwColors.rule),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A14213A),
              blurRadius: 24,
              offset: Offset(0, 10),
              spreadRadius: -6,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              label: 'Play the Sweldo story',
              child: Material(
                color: SwColors.stamp,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _start,
                  child: const SizedBox.square(
                    dimension: 60,
                    child: Icon(SwIcons.play, color: Colors.white, size: 34),
                  ),
                ),
              ),
            ),
            const SizedBox(width: SwSpace.lg),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Watch Ana get paid', style: SwType.title),
                  const SizedBox(height: 2),
                  Text(
                    _reduced
                        ? '7 scenes. Step through at your own pace.'
                        : '${StoryScript.total.round()} seconds, from payroll to pesos',
                    style: SwType.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _endCard(StageFormat format) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 64,
      child: Center(
        child: Wrap(
          spacing: SwSpace.md,
          runSpacing: SwSpace.sm,
          alignment: WrapAlignment.center,
          children: [
            if (widget.onFinishedAction != null)
              SwButton(
                label: widget.finishedLabel ?? 'Get started',
                onPressed: widget.onFinishedAction,
              ),
            SwButton(
              label: 'Watch again',
              icon: SwIcons.replay,
              tone: SwButtonTone.secondary,
              onPressed: _start,
            ),
          ],
        ),
      ),
    );
  }

  static String _clock(double seconds) {
    final s = seconds.floor();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(side: BorderSide(color: SwColors.rule)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 38,
            child: AnimatedSwitcher(
              duration: SwMotion.of(context, SwMotion.quick),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(
                icon,
                key: ValueKey(icon),
                size: 20,
                color: SwColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
