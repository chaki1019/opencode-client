/// A question the agent (or an integration) asks the user, as a v2 form
/// (`GET /api/session/:id/form`, `form.created`).
///
/// Answers are keyed by field `key`. A field's value is a `String`, a `num`,
/// a `bool` or a `List<String>`; option fields answer with the option's
/// `value`, not its label.
class FormRequest {
  const FormRequest({
    required this.id,
    required this.sessionId,
    required this.title,
    required this.fields,
    this.isSupported = true,
  });

  /// Returns null when [json] lacks the identifying fields.
  static FormRequest? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final sessionId = json['sessionID'];
    if (id is! String || sessionId is! String) return null;
    final fields = <FormFieldSpec>[];
    var supported = true;
    for (final raw in json['fields'] is List ? json['fields'] as List : []) {
      final field = FormFieldSpec.tryParse(raw);
      if (field == null) {
        supported = false;
      } else {
        fields.add(field);
      }
    }
    return FormRequest(
      id: id,
      sessionId: sessionId,
      title: json['title'] as String? ?? '',
      fields: fields,
      isSupported: supported,
    );
  }

  final String id;
  final String sessionId;
  final String title;
  final List<FormFieldSpec> fields;

  /// False when a field has a type this app cannot render. Such a form can
  /// only be dismissed.
  final bool isSupported;

  /// Starting values: each field's default, and `false` for switches.
  Map<String, Object?> initialValues() => {
    for (final field in fields)
      field.key:
          field.defaultValue ??
          (field.type == FormFieldType.boolean ? false : null),
  };

  /// Whether [field] applies given the current [values]. Conditions refer to
  /// earlier fields, so a field hidden by a hidden field stays hidden.
  bool isVisible(FormFieldSpec field, Map<String, Object?> values) {
    for (final condition in field.when) {
      final target = fields.where((f) => f.key == condition.key).firstOrNull;
      if (target != null && !isVisible(target, values)) return false;
      if (!condition.matches(values[condition.key])) return false;
    }
    return true;
  }

  /// Problems with [values], keyed by field. Hidden fields are not checked.
  Map<String, FieldError> validate(Map<String, Object?> values) => {
    for (final field in fields)
      if (isVisible(field, values))
        field.key: ?field.validate(values[field.key]),
  };

  /// The `answer` object to submit: visible fields that have a value.
  Map<String, Object> answer(Map<String, Object?> values) => {
    for (final field in fields)
      if (isVisible(field, values) && !_isEmpty(values[field.key]))
        field.key: values[field.key]!,
  };
}

enum FormFieldType { string, number, integer, boolean, multiselect, external }

class FormOption {
  const FormOption({
    required this.value,
    required this.label,
    this.description,
  });

  final String value;
  final String label;
  final String? description;
}

/// Shows a field only when an earlier field equals (or does not equal) a
/// value.
class FormCondition {
  const FormCondition({required this.key, required this.op, this.value});

  final String key;

  /// `eq` or `neq`.
  final String op;
  final Object? value;

  bool matches(Object? actual) {
    final equal = actual == value;
    return op == 'neq' ? !equal : equal;
  }
}

class FormFieldSpec {
  const FormFieldSpec({
    required this.key,
    required this.type,
    this.title,
    this.description,
    this.required = false,
    this.defaultValue,
    this.when = const [],
    this.options = const [],
    this.custom = false,
    this.placeholder,
    this.minLength,
    this.maxLength,
    this.pattern,
    this.minimum,
    this.maximum,
    this.minItems,
    this.maxItems,
    this.url,
  });

  /// Returns null for a field this app cannot render.
  static FormFieldSpec? tryParse(Object? json) {
    if (json is! Map) return null;
    final key = json['key'];
    final type = switch (json['type']) {
      'string' => FormFieldType.string,
      'number' => FormFieldType.number,
      'integer' => FormFieldType.integer,
      'boolean' => FormFieldType.boolean,
      'multiselect' => FormFieldType.multiselect,
      'external' => FormFieldType.external,
      _ => null,
    };
    if (key is! String || type == null) return null;
    final defaultValue = json['default'];
    return FormFieldSpec(
      key: key,
      type: type,
      title: json['title'] as String?,
      description: json['description'] as String?,
      // An external step must always be acknowledged.
      required: type == FormFieldType.external || json['required'] == true,
      defaultValue: switch (defaultValue) {
        final String v => v,
        final num v => v,
        final bool v => v,
        final List<Object?> v => v.whereType<String>().toList(),
        _ => null,
      },
      when: [
        for (final c in json['when'] is List ? json['when'] as List : [])
          if (c is Map && c['key'] is String)
            FormCondition(
              key: c['key'] as String,
              op: c['op'] as String? ?? 'eq',
              value: c['value'],
            ),
      ],
      options: [
        for (final o in json['options'] is List ? json['options'] as List : [])
          if (o is Map && o['value'] is String)
            FormOption(
              value: o['value'] as String,
              label: o['label'] as String? ?? o['value'] as String,
              description: o['description'] as String?,
            ),
      ],
      custom: json['custom'] == true,
      placeholder: json['placeholder'] as String?,
      minLength: _int(json['minLength']),
      maxLength: _int(json['maxLength']),
      pattern: json['pattern'] as String?,
      minimum: json['minimum'] as num?,
      maximum: json['maximum'] as num?,
      minItems: _int(json['minItems']),
      maxItems: _int(json['maxItems']),
      url: json['url'] as String?,
    );
  }

  final String key;
  final FormFieldType type;
  final String? title;
  final String? description;
  final bool required;
  final Object? defaultValue;
  final List<FormCondition> when;
  final List<FormOption> options;

  /// Whether free text is allowed besides [options].
  final bool custom;
  final String? placeholder;
  final int? minLength;
  final int? maxLength;
  final String? pattern;
  final num? minimum;
  final num? maximum;
  final int? minItems;
  final int? maxItems;

  /// For [FormFieldType.external]: the page the user must visit.
  final String? url;

  /// The heading to show: the title, else the description, else the key.
  String get label => title ?? description ?? key;

  /// The explanation under the heading, when the title is separate.
  String? get help => title == null ? null : description;

  /// A single-choice string field.
  bool get isChoice => type == FormFieldType.string && options.isNotEmpty;

  /// Returns why [value] is not acceptable, or null when it is.
  FieldError? validate(Object? value) {
    if (_isEmpty(value)) {
      return required ? const FieldError(FieldErrorKind.required) : null;
    }
    switch (type) {
      case FormFieldType.string:
        if (value is! String) return const FieldError(FieldErrorKind.text);
        if (isChoice && !custom && !options.any((o) => o.value == value)) {
          return const FieldError(FieldErrorKind.pickOption);
        }
        if (minLength != null && value.length < minLength!) {
          return FieldError(FieldErrorKind.minLength, minLength);
        }
        if (maxLength != null && value.length > maxLength!) {
          return FieldError(FieldErrorKind.maxLength, maxLength);
        }
        if (pattern != null && !_matches(pattern!, value)) {
          return const FieldError(FieldErrorKind.pattern);
        }
      case FormFieldType.number || FormFieldType.integer:
        if (value is! num || !value.isFinite) {
          return const FieldError(FieldErrorKind.number);
        }
        if (type == FormFieldType.integer && value != value.roundToDouble()) {
          return const FieldError(FieldErrorKind.integer);
        }
        if (minimum != null && value < minimum!) {
          return FieldError(FieldErrorKind.minimum, minimum);
        }
        if (maximum != null && value > maximum!) {
          return FieldError(FieldErrorKind.maximum, maximum);
        }
      case FormFieldType.boolean:
        if (value is! bool) return const FieldError(FieldErrorKind.choose);
      case FormFieldType.multiselect:
        if (value is! List<String>) {
          return const FieldError(FieldErrorKind.choose);
        }
        if (!custom && value.any((v) => !options.any((o) => o.value == v))) {
          return const FieldError(FieldErrorKind.pickOption);
        }
        if (minItems != null && value.length < minItems!) {
          return FieldError(FieldErrorKind.minItems, minItems);
        }
        if (maxItems != null && value.length > maxItems!) {
          return FieldError(FieldErrorKind.maxItems, maxItems);
        }
      case FormFieldType.external:
        if (value != true) return const FieldError(FieldErrorKind.external);
    }
    return null;
  }

  static bool _matches(String pattern, String value) {
    try {
      return RegExp(pattern).hasMatch(value);
    } on FormatException {
      return true; // A pattern Dart cannot parse is left to the server.
    }
  }

  static int? _int(Object? value) => value is num ? value.toInt() : null;
}

bool _isEmpty(Object? value) =>
    value == null ||
    (value is String && value.trim().isEmpty) ||
    (value is List && value.isEmpty);

enum FieldErrorKind {
  required,
  text,
  pickOption,
  minLength,
  maxLength,
  pattern,
  number,
  integer,
  minimum,
  maximum,
  choose,
  minItems,
  maxItems,
  external,
}

/// Why a field's value was rejected; [limit] is the bound it broke, if any.
class FieldError {
  const FieldError(this.kind, [this.limit]);

  final FieldErrorKind kind;
  final num? limit;
}
