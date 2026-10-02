import 'package:flutter/material.dart';

import '../../core/models/catalog.dart';
import '../../core/models/session.dart';
import '../../l10n/l10n.dart';

/// Picks a model in two steps: the provider first, then one of its models.
/// With a single provider the model list is shown straight away. Only the
/// model step has a search field.
///
/// Pops the enclosing route with the chosen [ModelRef].
class ModelPicker extends StatefulWidget {
  const ModelPicker({
    super.key,
    required this.models,
    this.current,
    this.scrollController,
  });

  final List<ModelOption> models;
  final ModelRef? current;
  final ScrollController? scrollController;

  @override
  State<ModelPicker> createState() => _ModelPickerState();
}

class _Provider {
  _Provider(this.id, this.name);

  final String id;
  final String name;
  final List<ModelOption> models = [];
}

class _ModelPickerState extends State<ModelPicker>
    with SingleTickerProviderStateMixin {
  final _search = TextEditingController();
  late final _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  )..addStatusListener((_) => setState(() {}));
  late final _curve = CurvedAnimation(
    parent: _slide,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  String _query = '';

  /// The provider being drilled into, or null on the provider step.
  String? _providerID;

  /// The provider whose models are on screen. Kept while sliding back so the
  /// model step does not go blank mid-animation.
  String? _shownProviderID;

  @override
  void dispose() {
    _curve.dispose();
    _slide.dispose();
    _search.dispose();
    super.dispose();
  }

  /// Providers in the order the server lists their models.
  List<_Provider> get _providers {
    final byId = <String, _Provider>{};
    for (final m in widget.models) {
      byId
          .putIfAbsent(
            m.providerID,
            () => _Provider(m.providerID, m.providerName),
          )
          .models
          .add(m);
    }
    return byId.values.toList();
  }

  bool _matches(ModelOption m) =>
      _query.isEmpty ||
      m.name.toLowerCase().contains(_query) ||
      m.id.toLowerCase().contains(_query);

  void _open(String? providerID) {
    _search.clear();
    setState(() {
      _providerID = providerID;
      if (providerID != null) _shownProviderID = providerID;
      _query = '';
    });
    final instant = MediaQuery.of(context).disableAnimations;
    if (providerID == null) {
      instant ? _slide.value = 0 : _slide.reverse();
    } else {
      instant ? _slide.value = 1 : _slide.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final providers = _providers;
    if (providers.length == 1) {
      return _modelStep(context, providers.single, showHeader: false);
    }
    final onModels = _providerID != null;
    final shown = providers.where((p) => p.id == _shownProviderID).firstOrNull;

    return PopScope(
      canPop: !onModels,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _open(null);
      },
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!_slide.isCompleted || shown == null)
              SlideTransition(
                position: Tween(
                  begin: Offset.zero,
                  end: const Offset(-0.3, 0),
                ).animate(_curve),
                child: IgnorePointer(
                  ignoring: onModels,
                  child: _providerStep(context, providers, active: !onModels),
                ),
              ),
            if (!_slide.isDismissed && shown != null)
              SlideTransition(
                position: Tween(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(_curve),
                child: IgnorePointer(
                  ignoring: !onModels,
                  child: Material(
                    color:
                        Theme.of(context).bottomSheetTheme.backgroundColor ??
                        Theme.of(context).colorScheme.surfaceContainerLow,
                    child: _modelStep(
                      context,
                      shown,
                      showHeader: true,
                      active: onModels,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// [active] decides which step drives the sheet's scroll controller while
  /// both are on screen.
  Widget _providerStep(
    BuildContext context,
    List<_Provider> providers, {
    required bool active,
  }) {
    return ListView.builder(
      controller: active ? widget.scrollController : null,
      primary: false,
      itemCount: providers.length,
      itemBuilder: (context, index) {
        final provider = providers[index];
        final inUse = provider.id == widget.current?.providerID;
        return ListTile(
          title: Text(provider.name),
          subtitle: Text(context.l10n.modelCount(provider.models.length)),
          leading: inUse
              ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
              : const SizedBox(width: 24),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _open(provider.id),
        );
      },
    );
  }

  Widget _modelStep(
    BuildContext context,
    _Provider provider, {
    required bool showHeader,
    bool active = true,
  }) {
    final models = provider.models.where(_matches).toList();
    return Column(
      children: [
        if (showHeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 16, 4),
            child: Row(
              children: [
                BackButton(onPressed: () => _open(null)),
                Expanded(
                  child: Text(
                    provider.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: context.l10n.searchModels,
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: active ? widget.scrollController : null,
            primary: false,
            itemCount: models.length,
            itemBuilder: (context, index) =>
                _ModelTile(option: models[index], current: widget.current),
          ),
        ),
      ],
    );
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({required this.option, required this.current});

  final ModelOption option;
  final ModelRef? current;

  @override
  Widget build(BuildContext context) {
    ModelRef ref([String? variant]) => ModelRef(
      providerID: option.providerID,
      id: option.id,
      variant: variant,
    );
    final inUse =
        current?.providerID == option.providerID && current?.id == option.id;
    return ListTile(
      title: Text(option.name),
      leading: inUse
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : const SizedBox(width: 24),
      onTap: () => Navigator.pop(context, ref()),
      trailing: option.variants.isEmpty
          ? null
          : PopupMenuButton<String>(
              tooltip: context.l10n.variant,
              icon: const Icon(Icons.tune),
              onSelected: (v) => Navigator.pop(context, ref(v)),
              itemBuilder: (_) => [
                for (final v in option.variants)
                  PopupMenuItem(value: v, child: Text(v)),
              ],
            ),
    );
  }
}
