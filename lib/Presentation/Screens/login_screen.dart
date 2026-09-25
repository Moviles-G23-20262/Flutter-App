import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../Widgets/common_widgets.dart';
import '../State Management/app_state.dart';
import '../../Domain/Entities/user_entity.dart';

/// Login / welcome screen for Campus Swap.
class LoginScreen extends StatefulWidget {
  final AppState appState;

  const LoginScreen({super.key, required this.appState});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  String _errorMsg  = '';
  bool   _loading   = false;
  bool   _obscure   = true;

  // Demo credentials
  static const _demoEmail    = 'uwu';
  static const _demoPassword = 'uwu123';

  Future<void> _handleLogin() async {
    if (_loading) return;
    final email    = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMsg = 'Please enter your credentials.');
      return;
    }

    setState(() { _loading = true; _errorMsg = ''; });

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    if (email == _demoEmail && password == _demoPassword) {
      widget.appState.login(
        UserEntity(
          id:        'demo-user-001',
          email:     'maria.santos@university.edu',
          fullName:  'Maria Santos',
          major:     'BS Computer Science',
          faculty:   'Faculty of Engineering',
          rating:    4.9,
          createdAt: DateTime.now(),
        ),
      );
    } else {
      setState(() {
        _loading  = false;
        _errorMsg = 'Wrong credentials. Check the demo note below.';
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg         = brightness == Brightness.dark ? AppColors.darkBg      : AppColors.lightBg;
    final txPrimary  = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txMuted    = brightness == Brightness.dark ? AppColors.darkTextMuted   : AppColors.lightTextMuted;
    final accentHi   = brightness == Brightness.dark ? AppColors.darkAccentHi   : AppColors.lightAccentHi;
    final elevated   = brightness == Brightness.dark ? AppColors.darkElevated    : AppColors.lightElevated;
    final borderSubtle = brightness == Brightness.dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;
    final errorColor = brightness == Brightness.dark ? AppColors.darkError       : AppColors.lightError;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 56),

              // ── Logo + title ───────────────────────────────────────────
              const CampusSwapLogo(size: 72),
              const SizedBox(height: 16),
              Text(
                'Campus Swap',
                style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeLg),
              ),
              const SizedBox(height: 6),
              Text(
                'Buy. Sell. Swap. All on campus.',
                style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),

              // ── Login card ─────────────────────────────────────────────
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back',
                        style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd)),
                    const SizedBox(height: 20),

                    // Username
                    Text('Username',
                        style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    AppTextField(
                      placeholder: 'Enter your username',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => setState(() => _errorMsg = ''),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),

                    // Password
                    Text('Password',
                        style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    AppTextField(
                      placeholder: 'Enter your password',
                      controller: _passwordController,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() => _errorMsg = ''),
                      suffixIcon: GestureDetector(
                        onTap: () => setState(() => _obscure = !_obscure),
                        child: Icon(
                          _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: txMuted,
                          size: 20,
                        ),
                      ),
                    ),

                    // Error message
                    if (_errorMsg.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: elevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderSubtle),
                        ),
                        child: Text(_errorMsg,
                            style: AppTextStyles.body(errorColor, fontSize: AppTextStyles.sizeXs)),
                      ),
                    ],
                    const SizedBox(height: 18),

                    // Login button
                    PrimaryButton(
                      label: _loading ? 'Logging in…' : 'Log In',
                      onPressed: _loading ? null : _handleLogin,
                      leadingIcon: _loading
                          ? null
                          : const Icon(Icons.login_rounded, color: Colors.white, size: 16),
                      fullWidth: true,
                      isLoading: _loading,
                    ),
                    const SizedBox(height: 12),

                    // Sign up link
                    Center(
                      child: RichText(
                        text: TextSpan(
                          text: 'No account? ',
                          style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs),
                          children: [
                            TextSpan(
                              text: 'Sign up free',
                              style: AppTextStyles.body(accentHi, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Demo credentials sticky note ───────────────────────────
              _DemoNote(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wiggling demo-credentials note shown on the login screen.
class _DemoNote extends StatefulWidget {
  @override
  State<_DemoNote> createState() => _DemoNoteState();
}

class _DemoNoteState extends State<_DemoNote> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _rotation = Tween<double>(begin: -0.026, end: 0.026).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness   = Theme.of(context).brightness;
    final elevated     = brightness == Brightness.dark ? AppColors.darkElevated     : AppColors.lightElevated;
    final borderSubtle = brightness == Brightness.dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;
    final txPrimary    = brightness == Brightness.dark ? AppColors.darkTextPrimary  : AppColors.lightTextPrimary;
    final txSecondary  = brightness == Brightness.dark ? AppColors.darkTextSecondary: AppColors.lightTextSecondary;
    final txMuted      = brightness == Brightness.dark ? AppColors.darkTextMuted    : AppColors.lightTextMuted;

    return AnimatedBuilder(
      animation: _rotation,
      builder: (_, child) => Transform.rotate(angle: _rotation.value, child: child),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
        decoration: BoxDecoration(
          color: elevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderSubtle),
          boxShadow: [
            BoxShadow(
              color: brightness == Brightness.dark ? AppColors.darkShadowCard : AppColors.lightShadowCard,
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pin decoration
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: 28, height: 8,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: borderSubtle,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.edit_rounded, color: txMuted, size: 16),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Demo Credentials',
                        style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('username: uwu',
                        style: AppTextStyles.mono(txSecondary, fontSize: AppTextStyles.sizeXs)),
                    Text('password: uwu123',
                        style: AppTextStyles.mono(txSecondary, fontSize: AppTextStyles.sizeXs)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
