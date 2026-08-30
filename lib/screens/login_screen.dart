import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../di/service_locator.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/auth_service.dart';
import '../utils/design_tokens.dart';

/// Sign-in screen — Google one-tap + email/password.
///
/// Reached from Settings → Account. Cloud sync starts automatically via
/// CloudSyncService's authStateChanges listener, so on success this
/// screen only pops. The app remains fully usable signed out.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _register = false;
  bool _obscure = true;
  bool _busy = false;
  String? _errorCode;

  AuthService get _auth => getIt<AuthService>();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _setBusy(bool busy) {
    if (mounted) setState(() => _busy = busy);
  }

  void _fail(Object e) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _errorCode = e is FirebaseAuthException ? e.code : 'network';
    });
  }

  Future<void> _signInGoogle() async {
    setState(() => _errorCode = null);
    _setBusy(true);
    try {
      final user = await _auth.signInWithGoogle();
      if (!mounted) return;
      if (user != null) Navigator.of(context).pop();
    } catch (e) {
      _fail(e);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _submitEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _errorCode = null);
    _setBusy(true);
    try {
      final email = _email.text.trim();
      final password = _password.text;
      final user = _register
          ? await _auth.registerWithEmail(email, password)
          : await _auth.signInWithEmail(email, password);
      if (!mounted) return;
      if (user != null) Navigator.of(context).pop();
    } catch (e) {
      _fail(e);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _forgotPassword() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: _email.text.trim());
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.resetPasswordTitle),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.emailLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.dialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.resetPasswordCta),
          ),
        ],
      ),
    );
    if (send != true || !mounted) return;
    _setBusy(true);
    try {
      await _auth.sendPasswordReset(controller.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).resetPasswordSent)),
      );
    } catch (e) {
      _fail(e);
    } finally {
      _setBusy(false);
    }
  }

  String _errorText(AppLocalizations l10n) => switch (_errorCode) {
        'invalid-email' => l10n.authErrorInvalidEmail,
        'user-not-found' => l10n.authErrorUserNotFound,
        'wrong-password' || 'invalid-credential' => l10n.authErrorWrongPassword,
        'email-already-in-use' => l10n.authErrorEmailInUse,
        'weak-password' => l10n.authErrorWeakPassword,
        'too-many-requests' => l10n.authErrorTooManyRequests,
        'network' => l10n.authErrorNetwork,
        _ => l10n.authErrorGeneric,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? AppColors.ground : AppColors.paper;
    final onSurface = isDark ? AppColors.paperOnGround : AppColors.ink;
    final onSurfaceVariant = isDark
        ? AppColors.paperOnGroundSoft
        : AppColors.inkSoft;
    final ruleColor = isDark ? AppColors.ruleOnGround : AppColors.rule;
    final fill = isDark ? AppColors.groundElev : AppColors.paperRaised;
    final errorColor = Theme.of(context).colorScheme.error;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.loginTitle, style: AppType.headlineSmall(color: onSurface)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s6, AppSpacing.s4, AppSpacing.s6, AppSpacing.s6),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.loginSubtitle,
                  style: AppType.bodyLarge(color: onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.s6),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  style: AppType.bodyLarge(color: onSurface),
                  decoration: _fieldDecoration(l10n.emailLabel, fill, ruleColor, onSurfaceVariant),
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? l10n.authErrorInvalidEmail : null,
                ),
                const SizedBox(height: AppSpacing.s4),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submitEmail(),
                  style: AppType.bodyLarge(color: onSurface),
                  decoration: _fieldDecoration(
                    l10n.passwordLabel, fill, ruleColor, onSurfaceVariant,
                  ).copyWith(
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: onSurfaceVariant,
                      ),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6)
                      ? l10n.authErrorWeakPassword
                      : null,
                ),
                if (_errorCode != null) ...[
                  const SizedBox(height: AppSpacing.s3),
                  Text(
                    _errorText(l10n),
                    style: AppType.bodyMedium(color: errorColor),
                  ),
                ],
                if (!_register) ...[
                  const SizedBox(height: AppSpacing.s2),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _busy ? null : _forgotPassword,
                      child: Text(l10n.forgotPassword),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.s2),
                FilledButton(
                  onPressed: _busy ? null : _submitEmail,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
                  ),
                  child: _busy
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: onSurface,
                          ),
                        )
                      : Text(
                          _register ? l10n.loginRegisterCta : l10n.loginEmailCta,
                          style: AppType.labelLarge(color: onSurface),
                        ),
                ),
                const SizedBox(height: AppSpacing.s2),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _register = !_register;
                          _errorCode = null;
                        }),
                  child: Text(_register ? l10n.loginToggleToSignIn : l10n.loginToggleToRegister),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: ruleColor)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
                        child: Text('OR', style: AppType.monoEyebrow(color: onSurfaceVariant)),
                      ),
                      Expanded(child: Divider(color: ruleColor)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _signInGoogle,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
                    side: BorderSide(color: ruleColor),
                  ),
                  icon: const _GoogleMark(size: 20),
                  label: Text(
                    l10n.loginGoogleCta,
                    style: AppType.labelLarge(color: onSurface),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(
    String label,
    Color fill,
    Color border,
    Color hint,
  ) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppType.bodyMedium(color: hint),
      filled: true,
      fillColor: fill,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s3,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        borderSide: BorderSide(color: border),
      ),
    );
  }
}

/// Four-colour Google "G" drawn as arcs — avoids shipping a logo asset.
class _GoogleMark extends StatelessWidget {
  final double size;
  const _GoogleMark({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _GoogleMarkPainter()),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.22;
    final radius = (size.width - stroke) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final arcRect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    // Angles are clockwise from +x in Flutter's y-down space:
    // 180° = 9 o'clock, 270° = 12 o'clock.
    canvas.drawArc(
      arcRect, 3.14159, 3.14159, false,
      paint..color = const Color(0xFF4285F4),
    ); // blue: 9:00 → 3:00 through the top
    canvas.drawArc(
      arcRect, 0.35, 0.43, false,
      paint..color = const Color(0xFFEA4335),
    ); // red: just below the bar → 4:30
    canvas.drawArc(
      arcRect, 0.7854, 1.5708, false,
      paint..color = const Color(0xFFFBBC05),
    ); // yellow: 4:30 → 7:30
    canvas.drawArc(
      arcRect, 2.3562, 0.7854, false,
      paint..color = const Color(0xFF34A853),
    ); // green: 7:30 → 9:00
    // Horizontal bar of the G, from center to the right edge.
    canvas.drawRect(
      Rect.fromLTWH(center.dx, center.dy - stroke / 2, radius, stroke),
      paint
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
