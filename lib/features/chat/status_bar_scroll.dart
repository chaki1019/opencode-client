import 'package:flutter/widgets.dart';

/// Makes the iOS status-bar tap scroll a reversed list to its oldest loaded
/// item. [Scaffold] scrolls its primary controller to offset 0 on that tap,
/// which in a reversed list is the newest end.
///
/// [builder] gets the controller to give the list. It runs under a
/// [PrimaryScrollController] that only answers the tap, so the scaffold
/// body should opt out of inheriting it with [PrimaryScrollController.none].
class StatusBarScrollsToOldest extends StatefulWidget {
  const StatusBarScrollsToOldest({super.key, required this.builder});

  final Widget Function(BuildContext context, ScrollController controller)
  builder;

  @override
  State<StatusBarScrollsToOldest> createState() =>
      _StatusBarScrollsToOldestState();
}

class _StatusBarScrollsToOldestState extends State<StatusBarScrollsToOldest> {
  final _list = ScrollController();
  late final _proxy = _ToOldestEnd(_list);

  @override
  void dispose() {
    _proxy.dispose();
    _list.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PrimaryScrollController(
    controller: _proxy,
    child: widget.builder(context, _list),
  );
}

/// Forwards "scroll to top" to the far end of [target].
class _ToOldestEnd extends ScrollController {
  _ToOldestEnd(this.target);

  final ScrollController target;

  @override
  bool get hasClients => target.hasClients;

  @override
  Future<void> animateTo(
    double offset, {
    required Duration duration,
    required Curve curve,
  }) => target.animateTo(
    target.position.maxScrollExtent,
    duration: duration,
    curve: curve,
  );
}
