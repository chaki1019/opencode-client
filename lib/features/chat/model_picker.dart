import 'package:flutter/material.dart';

import '../../core/models/catalog.dart';
import '../../core/models/session.dart';
import '../../l10n/l10n.dart';

/// Picks a model from one list, grouped under provider headings, with a
/// filter field on top. The filter matches model names and ids as well as
/// provider names, and drops the headings of providers with no match.
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

class _ModelPickerState extends State<ModelPicker> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Providers in the order the server lists their models, each holding only
  /// the models that match the filter. Providers left empty are dropped.
  List<_Provider> get _providers {
    final byId = <String, _Provider>{};
    for (final m in widget.models) {
      final provider = byId.putIfAbsent(
        m.providerID,
        () => _Provider(m.providerID, m.providerName),
      );
      if (_matches(m)) provider.models.add(m);
    }
    return byId.values.where((p) => p.models.isNotEmpty).toList();
  }

  bool _matches(ModelOption m) =>
      _query.isEmpty ||
      m.name.toLowerCase().contains(_query) ||
      m.id.toLowerCase().contains(_query) ||
      m.providerName.toLowerCase().contains(_query);

  @override
  Widget build(BuildContext context) {
    final providers = _providers;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: context.l10n.searchModels,
                    isDense: true,
                  ),
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                ),
              ),
              // Closes from anywhere in a long list, without scrolling back
              // to the top first.
              IconButton(
                key: const Key('model-picker-close'),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Expanded(
          child: providers.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    context.l10n.noMatchingModels,
                    textAlign: TextAlign.center,
                  ),
                )
              : CustomScrollView(
                  controller: widget.scrollController,
                  primary: false,
                  slivers: [
                    // Each heading stays pinned under the filter field until
                    // the next provider's heading pushes it out.
                    for (final p in providers)
                      SliverMainAxisGroup(
                        key: ValueKey(p.id),
                        slivers: [
                          PinnedHeaderSliver(
                            child: _ProviderHeading(name: p.name),
                          ),
                          SliverList.builder(
                            itemCount: p.models.length,
                            itemBuilder: (context, index) => _ModelTile(
                              option: p.models[index],
                              current: widget.current,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ProviderHeading extends StatelessWidget {
  const _ProviderHeading({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Opaque, so models scrolling under the pinned heading don't show
    // through. Matches the bottom sheet's own background.
    return ColoredBox(
      color:
          theme.bottomSheetTheme.backgroundColor ??
          theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Text(
          name,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
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
