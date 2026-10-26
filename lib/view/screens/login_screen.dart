import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../../view_model/app_view_model.dart';
import '../../view_model/login_view_model.dart';

/// Login / welcome screen for Campus Swap. Only draws [LoginViewModel] and forwards taps.
class LoginScreen extends StatefulWidget {
  final AppViewModel appState;

  /// Builds this screen's view-model; called once, and the screen disposes it.
  final LoginViewModel Function() createViewModel;

  const LoginScreen({super.key, required this.appState, required this.createViewModel});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final LoginViewModel _vm = widget.createViewModel();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();

  // Emojis never get into either field; an email has no spaces at all, so a pasted
  // " ana@uniandes.edu.co " is cleaned up while it is typed.
  static final _emailFormatters = <TextInputFormatter>[
    FilteringTextInputFormatter.deny(LoginViewModel.blockedCharacters),
    FilteringTextInputFormatter.deny(RegExp(r'\s')),
  ];
  static final _passwordFormatters = <TextInputFormatter>[
    FilteringTextInputFormatter.deny(LoginViewModel.blockedCharacters),
  ];

  @override
  void initState() {
    super.initState();
    _vm.init();
  }

  void _handleLogin() {
    FocusScope.of(context).unfocus();
    _vm.submit();
  }

  void _handleQuickUnlock() {
    FocusScope.of(context).unfocus();
    _vm.unlockWithFingerprint();
  }

  @override
  void dispose() {
    _vm.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: _vm, builder: (context, _) => _buildView(context));
  }

  Widget _buildView(BuildContext context) {
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
                      key: const Key('login-email'),
                      placeholder: 'Enter your email',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      inputFormatters: _emailFormatters,
                      errorText: _vm.emailError,
                      enabled: !_vm.isLoading,
                      onChanged: _vm.setEmail,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),

                    // Password
                    Text('Password',
                        style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    AppTextField(
                      key: const Key('login-password'),
                      placeholder: 'Enter your password',
                      controller: _passwordController,
                      obscureText: _vm.obscurePassword,
                      keyboardType: TextInputType.visiblePassword,
                      inputFormatters: _passwordFormatters,
                      errorText: _vm.passwordError,
                      enabled: !_vm.isLoading,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleLogin(),
                      onChanged: _vm.setPassword,
                      suffixIcon: GestureDetector(
                        key: const Key('toggle-password'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _vm.togglePasswordVisibility,
                        child: Icon(
                          _vm.obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: txMuted,
                          size: 20,
                        ),
                      ),
                    ),

                    // Error message
                    if (_vm.errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: elevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderSubtle),
                        ),
                        child: Text(_vm.errorMessage,
                            key: const Key('login-error'),
                            style: AppTextStyles.body(errorColor, fontSize: AppTextStyles.sizeXs)),
                      ),
                    ],
                    const SizedBox(height: 18),

                    // Login button
                    PrimaryButton(
                      key: const Key('login-button'),
                      label: _vm.isLoading ? 'Logging in…' : 'Log In',
                      onPressed: _vm.isLoading ? null : _handleLogin,
                      leadingIcon: _vm.isLoading
                          ? null
                          : const Icon(Icons.login_rounded, color: Colors.white, size: 16),
                      fullWidth: true,
                      isLoading: _vm.isLoading,
                    ),
                    if (_vm.canOfferQuickUnlock) ...[
                      const SizedBox(height: 10),
                      SecondaryButton(
                        key: const Key('quick-unlock'),
                        label: 'Quick Unlock with Fingerprint',
                        leadingIcon: Icon(Icons.fingerprint_rounded, color: accentHi, size: 20),
                        fullWidth: true,
                        onPressed: _vm.isLoading ? null : _handleQuickUnlock,
                      ),
                      if (_vm.quickUnlockEmail != null) ...[
                        const SizedBox(height: 6),
                        Center(
                          child: Text(_vm.quickUnlockEmail!,
                              key: const Key('enrolled-email'),
                              style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
                        ),
                      ],
                      Center(
                        child: TextButton(
                          key: const Key('forget-biometrics'),
                          onPressed: _vm.isLoading ? null : _vm.forgetFingerprintAccount,
                          style: TextButton.styleFrom(
                            foregroundColor: accentHi,
                            minimumSize: const Size(0, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: Text('Sign in with a different account',
                              style: AppTextStyles.body(accentHi, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Sign up link
                    Center(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _vm.isLoading ? null : () => widget.appState.navigateTo(AppScreen.register),
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
