import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../Widgets/common_widgets.dart';
import '../State Management/app_state.dart';
import '../../Domain/exceptions/auth_exceptions.dart';
import '../../Domain/use_cases/login_use_case.dart';

/// Login / welcome screen for Campus Swap.
class LoginScreen extends StatefulWidget {
  final AppState appState;
  final LoginUseCase login;

  const LoginScreen({super.key, required this.appState, required this.login});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  String _errorMsg  = '';
  bool   _loading   = false;
  bool   _obscure   = true;

  Future<void> _handleLogin() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();

    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMsg = 'Please enter your email and password.');
      return;
    }

    setState(() { _loading = true; _errorMsg = ''; });

    try {
      final user = await widget.login.execute(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      // AppState switches to Home; this screen is replaced, so keep _loading as is.
      widget.appState.login(user);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _errorMsg = e.message; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _errorMsg = 'Unexpected error. Please try again.'; });
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
                    Text('Email',
                        style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    AppTextField(
                      placeholder: 'Enter your email',
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
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _loading ? null : () => widget.appState.navigateTo(AppScreen.register),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
