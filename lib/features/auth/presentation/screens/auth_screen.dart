import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_providers.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/constants/app_durations.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/sync/local_data_migrator.dart';
import '../../../../core/sync/migration_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/screen_insets.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/google_mark.dart';

/// Sign in, create an account, or carry on without one.
///
/// **Never a gate.** The app works fully without an account and always has —
/// this screen is reached from Settings, not placed in front of the dashboard.
/// Forcing a sign-up before a driver can log their first fill would trade the
/// thing that makes the app usable for a sync they have not asked for yet.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _name = TextEditingController();

  bool _registering = false;

  /// Errors stay hidden until the first submit, then follow every keystroke.
  ///
  /// Validating from the first character would mark an email as invalid while
  /// it is still being typed, which reads as the form arguing with the user.
  /// Validating only on submit means a corrected field keeps its red outline
  /// until they press again. Switching modes at the first submit gives the
  /// useful half of each.
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  /// The shortest password this form will create.
  ///
  /// **Applied to sign-up only.** Firebase's own floor is six characters, so
  /// an account created before this rule existed can have a six-character
  /// password — and enforcing eight on the sign-in form would lock that person
  /// out of their own data with a message about their password being too
  /// short, which they cannot act on.
  static const int _minPasswordLength = 8;

  /// Deliberately permissive: one or more non-space, non-@ characters, an `@`,
  /// a domain with at least one dot, and a two-letter-or-longer tail.
  ///
  /// **Catches typos, not RFC violations.** The addresses a stricter pattern
  /// rejects are overwhelmingly real ones with a plus tag or an unusual TLD,
  /// and a sign-up form that refuses a working address is a worse failure than
  /// one that lets a wrong address through to the verification email.
  static final RegExp _emailPattern = RegExp(r"^[^\s@]+@[^\s@]+\.[^\s@]{2,}$");

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _name.dispose();
    super.dispose();
  }

  /// Drops what the other mode does not use, and clears any error showing.
  ///
  /// The confirm field in particular: a value left in it from an abandoned
  /// sign-up would be validated against a different password the next time the
  /// user came back to register.
  void _switchMode(bool registering) {
    setState(() {
      _registering = registering;
      _autovalidate = AutovalidateMode.disabled;
      _confirm.clear();
    });
    _formKey.currentState?.reset();
  }

  // ---- validation -------------------------------------------------------

  String? _validateName(String? value) {
    if (!_registering) return null;
    return (value?.trim().isEmpty ?? true) ? context.l10n.required_ : null;
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return context.l10n.required_;
    if (!_emailPattern.hasMatch(text)) {
      return context.l10n.raw('authEmailInvalid');
    }
    return null;
  }

  /// Never trimmed. A leading or trailing space is a legitimate part of a
  /// password, and silently stripping it here would create an account whose
  /// password does not match what the user typed.
  String? _validatePassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return context.l10n.required_;
    if (_registering && text.length < _minPasswordLength) {
      return context.l10n.fmt('authPasswordTooShort', {
        'n': _minPasswordLength,
      });
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    if (!_registering) return null;
    final text = value ?? '';
    if (text.isEmpty) return context.l10n.required_;
    if (text != _password.text) {
      return context.l10n.raw('authPasswordsDontMatch');
    }
    return null;
  }

  /// Runs the form, then the credential call. Nothing reaches the network
  /// until every field passes.
  Future<void> _submit() async {
    setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
    if (!(_formKey.currentState?.validate() ?? false)) {
      showAppSnack(
        context,
        context.l10n.raw('authFixFields'),
        icon: Icons.error_outline_rounded,
      );
      return;
    }

    final controller = ref.read(authControllerProvider.notifier);
    final email = _email.text.trim();
    await _run(
      () => _registering
          ? controller.register(
              email: email,
              password: _password.text,
              displayName: _name.text.trim(),
            )
          : controller.signIn(email: email, password: _password.text),
    );
  }

  /// The reset link validates the email on its own.
  ///
  /// It is the one action on this screen that needs a single field rather than
  /// the whole form — running `validate()` here would light up the password as
  /// missing for someone who is trying to recover precisely because they do
  /// not have it.
  Future<void> _sendReset() async {
    final error = _validateEmail(_email.text);
    if (error != null) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      _formKey.currentState?.validate();
      showAppSnack(context, error, icon: Icons.error_outline_rounded);
      return;
    }

    final sent = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordReset(_email.text.trim());
    if (!mounted || !sent) return;
    showAppSnack(context, context.l10n.raw('authResetSent'));
  }

  /// Everything that has to happen after a successful sign-in, in one place.
  ///
  /// The migration runs here rather than inside the controller because it is a
  /// consequence of *this* screen's success, and because its result is what the
  /// driver is told about.
  Future<void> _afterSignIn() async {
    final l10n = context.l10n;
    final result = await ref
        .read(migrationControllerProvider.notifier)
        .migrateIfNeeded();

    if (!mounted) return;
    Navigator.of(context).maybePop();

    showAppSnack(
      context,
      _syncMessage(l10n, result),
      icon: Icons.cloud_done_rounded,
    );

    // Conflicts get their own message, after the first. They are not an error
    // and not what most sign-ins produce, but they are the one outcome where
    // the driver is looking at data that is not what this device held — and
    // finding that out silently is how people lose trust in a sync.
    final conflicts = result?.conflicts ?? 0;
    if (conflicts > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 2600));
      if (!mounted) return;
      showAppSnack(
        context,
        l10n.fmt('syncConflicts', {'n': conflicts}),
        icon: Icons.info_outline_rounded,
      );
    }
  }

  /// What the sign-in actually did to the data, in one sentence.
  static String _syncMessage(AppLocalizations l10n, MigrationResult? result) {
    if (result == null) return l10n.raw('syncCloudOn');
    if (result.failed) return l10n.raw('syncMigrateFailed');
    if (result.movedAnything) {
      return l10n.fmt('syncMerged', {'n': result.total});
    }
    return l10n.raw('syncNothingNew');
  }

  Future<void> _run(Future<bool> Function() action) async {
    final ok = await action();
    if (!mounted) return;

    if (ok) {
      await _afterSignIn();
      return;
    }

    final failure = ref.read(authControllerProvider.notifier).lastFailure;
    // Backing out of the Google sheet is a decision, not a failure worth a
    // message.
    if (failure == null || failure == AuthFailure.cancelled) return;
    showAppSnack(context, _messageFor(context.l10n, failure));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final busy = ref.watch(authControllerProvider).isLoading;
    final cloudReady = ref.watch(cloudAvailableProvider);
    final enabled = !busy && cloudReady;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.raw('authTitle'))),
      body: KeyboardAwareScrollPadding(
        builder: (context, padding) => ListView(
          padding: padding,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            const _Hero(),
            const SizedBox(height: 20),

            // Said before anything is typed, not after a failed attempt: a
            // build without credentials cannot sign anyone in, and letting
            // someone fill the form first would waste their time.
            if (!cloudReady) ...[
              _Notice(message: l10n.raw('authErrNotConfigured')),
              const SizedBox(height: 20),
            ],

            // Google first, and visually heaviest. Most drivers already have
            // the account on the phone, so it is one tap against a form.
            _GoogleButton(
              label: l10n.raw('authGoogle'),
              onPressed: enabled
                  ? () => _run(
                      ref
                          .read(authControllerProvider.notifier)
                          .continueWithGoogle,
                    )
                  : null,
            ),
            const SizedBox(height: 18),
            _OrDivider(label: l10n.raw('or')),
            const SizedBox(height: 18),

            _ModeTabs(
              registering: _registering,
              onChanged: busy ? null : _switchMode,
            ),
            const SizedBox(height: 16),

            Form(
              key: _formKey,
              autovalidateMode: _autovalidate,
              child: Column(
                children: [
                  if (_registering) ...[
                    AppTextField(
                      controller: _name,
                      label: _mandatory(l10n.raw('authName')),
                      prefixIcon: Icons.person_outline_rounded,
                      required: true,
                      textInputAction: TextInputAction.next,
                      validator: _validateName,
                    ),
                    const SizedBox(height: 10),
                  ],
                  AppTextField(
                    controller: _email,
                    label: _mandatory(l10n.raw('authEmail')),
                    prefixIcon: Icons.mail_outline_rounded,
                    required: true,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 10),
                  AppTextField(
                    controller: _password,
                    label: _mandatory(l10n.raw('authPassword')),
                    prefixIcon: Icons.lock_outline_rounded,
                    required: true,
                    obscure: true,
                    textInputAction: _registering
                        ? TextInputAction.next
                        : TextInputAction.done,
                    validator: _validatePassword,
                    // Retypes the match as the first field changes, so
                    // correcting the password does not leave a stale "do not
                    // match" under the one below it.
                    onChanged: (_) {
                      if (_registering &&
                          _autovalidate != AutovalidateMode.disabled) {
                        _formKey.currentState?.validate();
                      }
                    },
                  ),
                  if (_registering) ...[
                    const SizedBox(height: 10),
                    AppTextField(
                      controller: _confirm,
                      label: _mandatory(l10n.raw('authConfirmPassword')),
                      prefixIcon: Icons.lock_reset_rounded,
                      required: true,
                      obscure: true,
                      textInputAction: TextInputAction.done,
                      validator: _validateConfirm,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            FilledButton(
              onPressed: enabled ? _submit : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: AppColors.cyan,
                foregroundColor: context.colors.onPrimary,
              ),
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : Text(
                      _registering
                          ? l10n.raw('authSignUp')
                          : l10n.raw('authSignIn'),
                    ),
            ),

            if (!_registering)
              TextButton(
                onPressed: enabled ? _sendReset : null,
                child: Text(l10n.raw('authForgot')),
              ),

            const SizedBox(height: 6),
            // The way out. Offered last and quietly, because it is a real
            // choice rather than a dead end: the app is fully usable this way.
            TextButton.icon(
              onPressed: busy ? null : () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.smartphone_rounded, size: 18),
              label: Text(l10n.raw('authSkip')),
              style: TextButton.styleFrom(
                foregroundColor: context.tokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Marks a label as mandatory.
  ///
  /// **Local to this screen on purpose.** Everywhere else in the app the
  /// convention runs the other way — `AppTextField` appends "(optional)" to
  /// what is not required, and a form is mostly required fields, so silence
  /// means mandatory. This form is the exception: it is the only one where
  /// every single field is mandatory and where getting one wrong costs the
  /// user an account rather than a blank column, so it says so out loud.
  /// Putting the asterisk in `AppTextField` would have restyled thirty other
  /// fields to answer a question only this screen asks.
  static String _mandatory(String label) => '$label *';

  static String _messageFor(AppLocalizations l10n, AuthFailure failure) =>
      switch (failure) {
        AuthFailure.invalidEmail => l10n.raw('authErrInvalidEmail'),
        AuthFailure.wrongPassword => l10n.raw('authErrWrongPassword'),
        AuthFailure.userNotFound => l10n.raw('authErrUserNotFound'),
        AuthFailure.emailInUse => l10n.raw('authErrEmailInUse'),
        AuthFailure.weakPassword => l10n.raw('authErrWeakPassword'),
        AuthFailure.network => l10n.raw('authErrNetwork'),
        AuthFailure.notConfigured => l10n.raw('authErrNotConfigured'),
        AuthFailure.cancelled ||
        AuthFailure.unknown => l10n.raw('authErrUnknown'),
      };
}

/// The reason to sign in, said once at the top.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      children: [
        Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.cyan.withValues(alpha: 0.14),
          ),
          child: const Icon(
            Icons.cloud_sync_rounded,
            size: 32,
            color: AppColors.cyan,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          l10n.raw('authSubtitle'),
          textAlign: TextAlign.center,
          style: context.text.bodyMedium?.copyWith(
            color: context.tokens.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Google's own button shape: white surface, the mark on the leading edge.
///
/// Deliberately not tinted with the app's accent. A branded sign-in button is
/// recognised by its shape and colour, and restyling it makes people hesitate
/// over the one control they would otherwise use without thinking.
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;

    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDADCE0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const GoogleMark(size: 22),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // Fixed dark ink, not the theme's: the surface is always
                    // white, so theme text would vanish in dark mode.
                    style: context.text.titleSmall?.copyWith(
                      color: const Color(0xFF3C4043),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sign in / create account, as two halves of one control.
///
/// Replaces the text link this used to be. A link reading "don't have an
/// account?" makes the reader work out which mode they are currently in; a
/// segmented pair shows it.
class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.registering, required this.onChanged});

  final bool registering;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.tokens.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Tab(
              label: l10n.raw('authSignIn'),
              selected: !registering,
              onTap: onChanged == null ? null : () => onChanged!(false),
            ),
          ),
          Expanded(
            child: _Tab(
              label: l10n.raw('authSignUp'),
              selected: registering,
              onTap: onChanged == null ? null : () => onChanged!(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: AnimatedContainer(
      duration: AppDurations.stateChange,
      curve: Curves.fastOutSlowIn,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.cyan : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: context.text.titleSmall?.copyWith(
          color: selected
              ? context.colors.onPrimary
              : context.tokens.textSecondary,
        ),
      ),
    ),
  );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Divider(color: context.tokens.border)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          label,
          style: context.text.labelSmall?.copyWith(
            color: context.tokens.textSecondary,
          ),
        ),
      ),
      Expanded(child: Divider(color: context.tokens.border)),
    ],
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => GlassCard(
    accent: AppColors.amber,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 18,
          color: AppColors.amber,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: context.text.bodySmall)),
      ],
    ),
  );
}
