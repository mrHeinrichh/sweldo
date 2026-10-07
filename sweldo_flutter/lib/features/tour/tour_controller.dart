import 'package:flutter/widgets.dart';

import '../../core/storage/local_store.dart';

/// One stop on the guide.
class TourStep {
  const TourStep({
    required this.title,
    required this.body,
    this.target,
    this.route,
    this.tryIt,
    this.payrollStep,
  });

  /// Id of the [TourTarget] to spotlight; null shows a centred card.
  final String? target;

  /// Page to open before the step (a go_router path).
  final String? route;
  final String title;
  final String body;

  /// Invites the person to use the highlighted control during the step.
  final String? tryIt;

  /// Payroll wizard step to open first (0 team, 1 schedule, 2 review).
  final int? payrollStep;
}

/// The guide's position and the widgets it can point at.
class TourController extends ChangeNotifier {
  TourController({required this.steps, LocalStore? store}) : _store = store;

  static const _seenKey = 'sweldo-tour-seen-v1';

  final List<TourStep> steps;
  final LocalStore? _store;
  final Map<String, GlobalKey> _targets = {};

  bool _open = false;
  int _index = 0;

  /// +1 when moving forward, -1 when moving back: steps whose target isn't
  /// on screen are skipped in this direction.
  int direction = 1;

  bool get isOpen => _open;
  int get index => _index;
  TourStep get step => steps[_index];
  bool get isLast => _index == steps.length - 1;

  bool get hasBeenSeen => _store?.readString(_seenKey) == '1';

  GlobalKey? keyFor(String id) => _targets[id];

  void register(String id, GlobalKey key) => _targets[id] = key;

  void unregister(String id, GlobalKey key) {
    if (_targets[id] == key) _targets.remove(id);
  }

  void start() {
    _index = 0;
    direction = 1;
    _open = true;
    notifyListeners();
  }

  void next() {
    if (!_open) return;
    if (isLast) return finish();
    direction = 1;
    _index++;
    notifyListeners();
  }

  void back() {
    if (!_open || _index == 0) return;
    direction = -1;
    _index--;
    notifyListeners();
  }

  /// Moves past a step that can't be shown right now.
  void skipUnavailable() => direction > 0 ? next() : back();

  void finish() {
    _open = false;
    _store?.writeString(_seenKey, '1');
    notifyListeners();
  }
}

/// Makes the [TourController] available below it.
class TourScope extends InheritedNotifier<TourController> {
  const TourScope({
    super.key,
    required TourController controller,
    required super.child,
  }) : super(notifier: controller);

  static TourController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TourScope>()?.notifier;

  /// Lookup without subscribing, safe in didChangeDependencies.
  static TourController? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TourScope>()?.notifier;
}

/// Marks a widget the guide can spotlight.
class TourTarget extends StatefulWidget {
  const TourTarget({super.key, required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  State<TourTarget> createState() => _TourTargetState();
}

class _TourTargetState extends State<TourTarget> {
  final _key = GlobalKey();
  TourController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = TourScope.read(context);
    if (controller != _controller) {
      _controller?.unregister(widget.id, _key);
      _controller = controller?..register(widget.id, _key);
    }
  }

  @override
  void dispose() {
    _controller?.unregister(widget.id, _key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.child);
}
