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

class _ModelPickerState extends State<ModelPicker> {
  final _search = TextEditingController();
  String _query = '';
  String? _providerID;

  @override
  void dispose() {
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
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final providers = _providers;
    final single = providers.length == 1;
    final selected = single
        ? providers.single
        : providers.where((p) => p.id == _providerID).firstOrNull;

    return PopScope(
      canPop: single || selected == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _open(null);
      },
      child: Column(
        children: [
          if (selected != null && !single)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 16, 4),
              child: Row(
                children: [
                  BackButton(onPressed: () => _open(null)),
                  Expanded(
                    child: Text(
                      selected.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          if (selected != null)
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
          Expanded(child: _body(context, providers, selected)),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    List<_Provider> providers,
    _Provider? selected,
  ) {
    if (selected != null) {
      final models = selected.models.where(_matches).toList();
      return ListView.builder(
        controller: widget.scrollController,
        itemCount: models.length,
        itemBuilder: (context, index) =>
            _ModelTile(option: models[index], current: widget.current),
      );
    }
    return ListView.builder(
      controller: widget.scrollController,
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
