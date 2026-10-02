import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/api/api_errors.dart';
import '../../core/models/form.dart';
import '../../core/models/prompts.dart';
import '../../core/models/session.dart';
import 'prompt_providers.dart';

/// Permission requests and questions waiting on the user, shown above the
/// input. One of each is shown at a time, oldest first.
class SessionPromptsPanel extends ConsumerWidget {
  const SessionPromptsPanel({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions =
        ref.watch(permissionsProvider(session.id)).value ?? const [];
    final forms = ref.watch(formsProvider(session)).value ?? const [];
    if (permissions.isEmpty && forms.isEmpty) return const SizedBox.shrink();

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.55,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (permissions.isNotEmpty)
              PermissionCard(
                key: ValueKey(permissions.first.id),
                request: permissions.first,
                waiting: permissions.length - 1,
              ),
            if (forms.isNotEmpty)
              FormCard(
                key: ValueKey(forms.first.id),
                session: session,
                form: forms.first,
                waiting: forms.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}

class PermissionCard extends ConsumerStatefulWidget {
  const PermissionCard({super.key, required this.request, this.waiting = 0});

  final PermissionRequest request;

  /// How many more requests are queued behind this one.
  final int waiting;

  @override
  ConsumerState<PermissionCard> createState() => _PermissionCardState();
}

class _PermissionCardState extends ConsumerState<PermissionCard> {
  bool _busy = false;

  Future<void> _reply(PermissionDecision decision) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(permissionsProvider(widget.request.sessionId).notifier)
          .reply(widget.request, decision);
    } on OpenCodeApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('返答できませんでした: ${e.detail}')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final request = widget.request;
    final description = request.description;
    final patterns = request.resources.where((r) => r != '*').toList();

    return Card(
      color: theme.colorScheme.tertiaryContainer,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_open, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '「${request.action}」の許可が必要です',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (widget.waiting > 0)
                  Text(
                    'ほか${widget.waiting}件',
                    style: theme.textTheme.labelSmall,
                  ),
              ],
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(description, maxLines: 6, overflow: TextOverflow.ellipsis),
            ],
            if (patterns.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                patterns.join('\n'),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: AppFonts.mono,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  key: const Key('permission-reject'),
                  onPressed: _busy
                      ? null
                      : () => _reply(PermissionDecision.reject),
                  child: const Text('拒否'),
                ),
                OutlinedButton(
                  key: const Key('permission-always'),
                  onPressed: _busy
                      ? null
                      : () => _reply(PermissionDecision.always),
                  child: const Text('常に許可'),
                ),
                FilledButton(
                  key: const Key('permission-once'),
                  onPressed: _busy
                      ? null
                      : () => _reply(PermissionDecision.once),
                  child: const Text('今回だけ許可'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A question from the agent, rendered field by field.
class FormCard extends ConsumerStatefulWidget {
  const FormCard({
    super.key,
    required this.session,
    required this.form,
    this.waiting = 0,
  });

  final Session session;
  final FormRequest form;
  final int waiting;

  @override
  ConsumerState<FormCard> createState() => _FormCardState();
}

class _FormCardState extends ConsumerState<FormCard> {
  late final Map<String, Object?> _values = widget.form.initialValues();
  Map<String, String> _errors = const {};
  bool _busy = false;

  FormsNotifier get _notifier =>
      ref.read(formsProvider(widget.session).notifier);

  void _set(String key, Object? value) => setState(() {
    _values[key] = value;
    if (_errors.containsKey(key)) _errors = {..._errors}..remove(key);
  });

  Future<void> _submit() async {
    final errors = widget.form.validate(_values);
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }
    await _run(
      () => _notifier.submit(widget.form, widget.form.answer(_values)),
      '送信できませんでした',
    );
  }

  Future<void> _cancel() =>
      _run(() => _notifier.cancel(widget.form), '取り消せませんでした');

  Future<void> _run(Future<void> Function() action, String failure) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
    } on OpenCodeApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$failure: ${e.detail}')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final form = widget.form;
    return Card(
      color: theme.colorScheme.secondaryContainer,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.help_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    form.title.isEmpty ? '質問があります' : form.title,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (widget.waiting > 0)
                  Text(
                    'ほか${widget.waiting}件',
                    style: theme.textTheme.labelSmall,
                  ),
              ],
            ),
            if (!form.isSupported)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('この質問にはアプリが対応していない項目があります。取り消すか、別のクライアントで答えてください。'),
              )
            else
              for (final field in form.fields)
                if (form.isVisible(field, _values))
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: FormFieldInput(
                      key: ValueKey('form-field-${field.key}'),
                      field: field,
                      value: _values[field.key],
                      error: _errors[field.key],
                      enabled: !_busy,
                      onChanged: (v) => _set(field.key, v),
                    ),
                  ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  key: const Key('form-cancel'),
                  onPressed: _busy ? null : _cancel,
                  child: const Text('答えない'),
                ),
                if (form.isSupported)
                  FilledButton(
                    key: const Key('form-submit'),
                    onPressed: _busy ? null : _submit,
                    child: const Text('送信'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The input for one form field.
class FormFieldInput extends StatelessWidget {
  const FormFieldInput({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.error,
    this.enabled = true,
  });

  final FormFieldSpec field;
  final Object? value;
  final ValueChanged<Object?> onChanged;
  final String? error;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = Text(
      field.required ? '${field.label} *' : field.label,
      style: theme.textTheme.labelLarge,
    );
    final help = field.help;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (field.type != FormFieldType.boolean) heading,
        if (help != null && field.type != FormFieldType.boolean)
          Text(help, style: theme.textTheme.bodySmall),
        _input(context, heading),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }

  Widget _input(BuildContext context, Widget heading) {
    switch (field.type) {
      case FormFieldType.boolean:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: heading,
          subtitle: field.help == null ? null : Text(field.help!),
          value: value == true,
          onChanged: enabled ? onChanged : null,
        );
      case FormFieldType.string when field.isChoice:
        final selected = value as String?;
        final isCustom =
            selected != null && !field.options.any((o) => o.value == selected);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OptionChips(
              options: field.options,
              selected: {?selected},
              enabled: enabled,
              onTap: (v) => onChanged(selected == v ? null : v),
            ),
            if (field.custom)
              _TextInput(
                initial: isCustom ? selected : '',
                hint: 'その他（自由入力）',
                enabled: enabled,
                onChanged: (v) => onChanged(v.isEmpty ? null : v),
              ),
          ],
        );
      case FormFieldType.string:
        return _TextInput(
          initial: value as String? ?? '',
          hint: field.placeholder,
          enabled: enabled,
          maxLines: 4,
          onChanged: (v) => onChanged(v.isEmpty ? null : v),
        );
      case FormFieldType.number || FormFieldType.integer:
        final integer = field.type == FormFieldType.integer;
        return _TextInput(
          initial: value?.toString() ?? '',
          hint: field.placeholder,
          enabled: enabled,
          keyboardType: TextInputType.numberWithOptions(
            decimal: !integer,
            signed: true,
          ),
          // Keep unparsable text so validation can point at it.
          onChanged: (v) => onChanged(
            v.trim().isEmpty
                ? null
                : (integer ? int.tryParse(v.trim()) : null) ??
                      num.tryParse(v.trim()) ??
                      v,
          ),
        );
      case FormFieldType.multiselect:
        final selected = [...?(value as List<String>?)];
        final optionValues = {for (final o in field.options) o.value};
        final extra = selected.where((v) => !optionValues.contains(v));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OptionChips(
              options: field.options,
              selected: selected.toSet(),
              enabled: enabled,
              onTap: (v) => onChanged(
                selected.contains(v) ? (selected..remove(v)) : [...selected, v],
              ),
            ),
            if (field.custom)
              _TextInput(
                initial: extra.join(', '),
                hint: 'その他（カンマ区切り）',
                enabled: enabled,
                onChanged: (text) => onChanged([
                  ...selected.where(optionValues.contains),
                  for (final part in text.split(','))
                    if (part.trim().isNotEmpty) part.trim(),
                ]),
              ),
          ],
        );
      case FormFieldType.external:
        final url = field.url ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: SelectableText(url)),
                IconButton(
                  tooltip: 'URLをコピー',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () => Clipboard.setData(ClipboardData(text: url)),
                ),
              ],
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('ブラウザで完了した'),
              value: value == true,
              onChanged: enabled ? (v) => onChanged(v == true) : null,
            ),
          ],
        );
    }
  }
}

class _OptionChips extends StatelessWidget {
  const _OptionChips({
    required this.options,
    required this.selected,
    required this.onTap,
    required this.enabled,
  });

  final List<FormOption> options;
  final Set<String> selected;
  final ValueChanged<String> onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final option in options)
          Tooltip(
            message: option.description ?? '',
            child: FilterChip(
              label: Text(option.label),
              selected: selected.contains(option.value),
              onSelected: enabled ? (_) => onTap(option.value) : null,
            ),
          ),
      ],
    );
  }
}

/// A text field that owns its controller, so typing is not reset when the
/// parent rebuilds with the parsed value.
class _TextInput extends StatefulWidget {
  const _TextInput({
    required this.initial,
    required this.onChanged,
    this.hint,
    this.enabled = true,
    this.maxLines = 1,
    this.keyboardType,
  });

  final String initial;
  final ValueChanged<String> onChanged;
  final String? hint;
  final bool enabled;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: TextField(
        controller: _controller,
        enabled: widget.enabled,
        minLines: 1,
        maxLines: widget.maxLines,
        keyboardType: widget.keyboardType,
        decoration: InputDecoration(
          hintText: widget.hint,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

/// The agent's todo list, collapsed to the current item.
class TodoStrip extends ConsumerStatefulWidget {
  const TodoStrip({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<TodoStrip> createState() => _TodoStripState();
}

class _TodoStripState extends ConsumerState<TodoStrip> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final todos = ref.watch(todosProvider(widget.sessionId));
    if (todos == null || todos.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final done = todos.where((t) => t.status == 'completed').length;
    final current =
        todos.where((t) => t.isActive).firstOrNull ??
        todos.where((t) => !t.isDone).firstOrNull;

    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        color: scheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: InkWell(
          key: const Key('todo-strip'),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Todo $done/${todos.length}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontFamily: AppFonts.mono,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _expanded ? '' : (current?.content ?? 'すべて完了'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Icon(
                          _expanded ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    if (_expanded) TodoList(todos: todos),
                  ],
                ),
              ),
              LinearProgressIndicator(
                value: done / todos.length,
                minHeight: 2,
                backgroundColor: Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TodoList extends StatelessWidget {
  const TodoList({super.key, required this.todos});

  final List<TodoItem> todos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final todo in todos)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  switch (todo.status) {
                    'completed' => Icons.check_box,
                    'cancelled' => Icons.indeterminate_check_box_outlined,
                    'in_progress' => Icons.play_arrow,
                    _ => Icons.check_box_outline_blank,
                  },
                  size: 18,
                  color: todo.isActive ? theme.colorScheme.primary : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    todo.content,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      decoration: todo.status == 'cancelled'
                          ? TextDecoration.lineThrough
                          : null,
                      fontWeight: todo.isActive ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
