import 'package:flutter/widgets.dart';

import '../core/models/attachment.dart';
import '../core/models/form.dart';
import 'app_localizations.dart';

export 'app_localizations.dart';

extension L10nContext on BuildContext {
  /// UI strings for the device language (English or Japanese).
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Labels for values the models keep language-neutral.
extension AppLocalizationsLabels on AppLocalizations {
  String fieldError(FieldError error) => switch (error.kind) {
    FieldErrorKind.required => fieldRequired,
    FieldErrorKind.text => fieldText,
    FieldErrorKind.pickOption => fieldPickOption,
    FieldErrorKind.minLength => fieldMinLength(error.limit!),
    FieldErrorKind.maxLength => fieldMaxLength(error.limit!),
    FieldErrorKind.pattern => fieldPattern,
    FieldErrorKind.number => fieldNumber,
    FieldErrorKind.integer => fieldInteger,
    FieldErrorKind.minimum => fieldMinimum(error.limit!),
    FieldErrorKind.maximum => fieldMaximum(error.limit!),
    FieldErrorKind.choose => fieldChoose,
    FieldErrorKind.minItems => fieldMinItems(error.limit!),
    FieldErrorKind.maxItems => fieldMaxItems(error.limit!),
    FieldErrorKind.external => fieldExternal,
  };

  String attachmentLimit(AttachmentLimit limit) => switch (limit) {
    AttachmentLimit.fileCount => tooManyAttachments(PromptFile.maxFiles),
    AttachmentLimit.fileSize => attachmentTooLarge,
    AttachmentLimit.totalSize => attachmentsTooLarge,
  };

  /// An MCP server's `status`; values from a newer server pass through.
  String mcpStatus(String status) => switch (status) {
    'connected' => mcpConnected,
    'disconnected' => mcpDisconnected,
    'disabled' => mcpDisabled,
    'failed' => mcpFailed,
    'needs_auth' => mcpNeedsAuth,
    'needs_client_registration' => mcpNeedsClientRegistration,
    _ => status,
  };
}
