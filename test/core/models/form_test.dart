import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/models/form.dart';

void main() {
  test('parses every field type and builds the answer from option values', () {
    final form = FormRequest.tryParse({
      'id': 'frm_1',
      'sessionID': 'ses_1',
      'title': 'Settings',
      'fields': [
        {
          'key': 'choice',
          'type': 'string',
          'required': true,
          'options': [
            {'value': 'wire-value', 'label': 'Display Label'},
          ],
        },
        {
          'key': 'tags',
          'type': 'multiselect',
          'required': true,
          'options': [
            {'value': 'a', 'label': 'Alpha'},
          ],
        },
        {'key': 'count', 'type': 'integer', 'required': true, 'minimum': 1},
        {'key': 'ratio', 'type': 'number', 'required': true},
        {'key': 'enabled', 'type': 'boolean', 'required': true},
      ],
    })!;
    expect(form.isSupported, isTrue);
    expect(form.fields.first.isChoice, isTrue);
    expect(form.fields.first.options.single.label, 'Display Label');

    final values = form.initialValues();
    expect(values['enabled'], isFalse);
    expect(form.validate(values).keys, ['choice', 'tags', 'count', 'ratio']);

    values
      ..['choice'] = 'wire-value'
      ..['tags'] = ['a']
      ..['count'] = 2
      ..['ratio'] = 0.5
      ..['enabled'] = true;
    expect(form.validate(values), isEmpty);
    expect(form.answer(values), {
      'choice': 'wire-value',
      'tags': ['a'],
      'count': 2,
      'ratio': 0.5,
      'enabled': true,
    });
  });

  test('checks ranges, whole numbers, closed choices and lengths', () {
    final form = FormRequest.tryParse({
      'id': 'f',
      'sessionID': 's',
      'fields': [
        {'key': 'n', 'type': 'integer', 'minimum': 1, 'maximum': 3},
        {
          'key': 'pick',
          'type': 'string',
          'options': [
            {'value': 'x', 'label': 'X'},
          ],
        },
        {'key': 'name', 'type': 'string', 'minLength': 3},
        {
          'key': 'many',
          'type': 'multiselect',
          'maxItems': 1,
          'custom': true,
          'options': [
            {'value': 'a', 'label': 'A'},
          ],
        },
      ],
    })!;
    expect(form.validate({'n': 2.5}).keys, ['n']);
    expect(form.validate({'n': 4}).keys, ['n']);
    expect(form.validate({'n': 'abc'}).keys, ['n']);
    expect(form.validate({'pick': 'y'}).keys, ['pick']);
    expect(form.validate({'name': 'ab'}).keys, ['name']);
    expect(
      form.validate({
        'many': ['a', 'free'],
      }).keys,
      ['many'],
    );
    expect(
      form.validate({
        'many': ['free'],
      }),
      isEmpty,
    );
    // Optional fields may stay empty and are left out of the answer.
    expect(form.validate({}), isEmpty);
    expect(form.answer({'name': '  '}), isEmpty);
  });

  test('hides conditional fields and leaves them out of the answer', () {
    final form = FormRequest.tryParse({
      'id': 'frm_conditional',
      'sessionID': 'ses_1',
      'title': 'Conditional',
      'fields': [
        {'key': 'mode', 'type': 'boolean', 'required': true},
        {
          'key': 'value',
          'type': 'string',
          'required': true,
          'when': [
            {'key': 'mode', 'op': 'eq', 'value': true},
          ],
        },
      ],
    })!;
    final values = form.initialValues()..['value'] = 'stale';
    expect(form.isVisible(form.fields[1], values), isFalse);
    expect(form.validate(values), isEmpty);
    expect(form.answer(values), {'mode': false});

    values
      ..['mode'] = true
      ..['value'] = null;
    expect(form.validate(values).keys, ['value']);
  });

  test('external steps are required and answered with true', () {
    final form = FormRequest.tryParse({
      'id': 'frm_external',
      'sessionID': 'global',
      'title': 'Authenticate',
      'fields': [
        {'key': 'auth', 'type': 'external', 'url': 'https://example.com'},
      ],
    })!;
    final field = form.fields.single;
    expect(field.required, isTrue);
    expect(field.url, 'https://example.com');
    expect(form.validate({}).keys, ['auth']);
    expect(form.answer({'auth': true}), {'auth': true});
  });

  test('marks forms with unknown field types as unsupported', () {
    final form = FormRequest.tryParse({
      'id': 'f',
      'sessionID': 's',
      'fields': [
        {'key': 'file', 'type': 'upload'},
      ],
    })!;
    expect(form.isSupported, isFalse);
    expect(FormRequest.tryParse({'title': 'no id'}), isNull);
  });
}
