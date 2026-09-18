import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../services/supabase_service.dart';
import '../../widgets/gradient_button.dart';

enum AuthViewMode { login, signUp, forgotPassword }

class AuthScreen extends StatefulWidget {
  final AuthViewMode initialMode;

  const AuthScreen({
    super.key,
    this.initialMode = AuthViewMode.login,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late AuthViewMode _currentMode;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isGuestLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _switchMode(AuthViewMode mode) {
    setState(() {
      _currentMode = mode;
      _errorMessage = null;
      _successMessage = null;
    });
  }

  Future<void> _handleEmailPasswordSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      if (_currentMode == AuthViewMode.login) {
        await SupabaseService.instance.signInWithEmailPassword(
          email: email,
          password: password,
        );
        // AuthGate will automatically navigate to MainScreen via sessionNotifier
      } else if (_currentMode == AuthViewMode.signUp) {
        if (password != _confirmPasswordController.text) {
          setState(() {
            _errorMessage = 'Passwords do not match.';
            _isLoading = false;
          });
          return;
        }

        final response = await SupabaseService.instance.signUpWithEmailPassword(
          email: email,
          password: password,
        );

        if (response?.session == null && SupabaseService.instance.isAvailable) {
          setState(() {
            _successMessage = 'Registration successful! Please check your email to verify your account.';
            _isLoading = false;
          });
          return;
        }
        // If session created or demo mode, AuthGate automatically navigates
      } else if (_currentMode == AuthViewMode.forgotPassword) {
        await SupabaseService.instance.resetPasswordForEmail(email: email);
        setState(() {
          _successMessage = 'Password reset instructions sent to $email.';
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      setState(() {
        _errorMessage = _cleanErrorMessage(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGuestLogin() async {
    setState(() {
      _isGuestLoading = true;
      _errorMessage = null;
    });

    try {
      await SupabaseService.instance.signInAnonymously();
      // AuthGate automatically transitions to MainScreen
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to continue as guest: ${_cleanErrorMessage(e.toString())}';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isGuestLoading = false);
      }
    }
  }

  String _cleanErrorMessage(String raw) {
    if (raw.contains('AuthException:')) {
      return raw.replaceFirst('AuthException:', '').trim();
    }
    if (raw.contains('Exception:')) {
      return raw.replaceFirst('Exception:', '').trim();
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = AppColors.backgroundFor(context);
    final cardColor = AppColors.surfaceFor(context);
    final borderColor = AppColors.borderFor(context);
    final textPrimary = AppColors.textPrimaryFor(context);
    final textSecondary = AppColors.textSecondaryFor(context);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Branding
                  _buildBrandHeader(textPrimary, textSecondary),
                  const SizedBox(height: 28),

                  // Main Auth Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor),
                      boxShadow: AppColors.cardShadowFor(context),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Mode Title
                          _buildCardTitle(textPrimary, textSecondary),
                          const SizedBox(height: 20),

                          // Feedback messages
                          if (_errorMessage != null) ...[
                            _buildAlertBanner(
                              message: _errorMessage!,
                              isError: true,
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_successMessage != null) ...[
                            _buildAlertBanner(
                              message: _successMessage!,
                              isError: false,
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Email Input
                          _buildEmailField(context),
                          const SizedBox(height: 14),

                          // Password Input (Login and SignUp only)
                          if (_currentMode != AuthViewMode.forgotPassword) ...[
                            _buildPasswordField(context),
                            const SizedBox(height: 14),
                          ],

                          // Confirm Password (SignUp only)
                          if (_currentMode == AuthViewMode.signUp) ...[
                            _buildConfirmPasswordField(context),
                            const SizedBox(height: 14),
                          ],

                          // Forgot Password Link (Login only)
                          if (_currentMode == AuthViewMode.login)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => _switchMode(AuthViewMode.forgotPassword),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: const Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                    color: AppColors.lovableTeal,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),

                          // Primary Submit Button
                          GradientButton(
                            label: _submitButtonLabel,
                            isLoading: _isLoading,
                            onPressed: _isLoading ? null : _handleEmailPasswordSubmit,
                          ),
                          const SizedBox(height: 16),

                          // Secondary Switch Links
                          _buildModeSwitchers(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Hackathon Judge 1-Tap Guest Access
                  _buildGuestDemoCard(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _submitButtonLabel {
    switch (_currentMode) {
      case AuthViewMode.login:
        return 'Sign In with Email';
      case AuthViewMode.signUp:
        return 'Create Account';
      case AuthViewMode.forgotPassword:
        return 'Send Reset Instructions';
    }
  }

  Widget _buildBrandHeader(Color textPrimary, Color textSecondary) {
    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            gradient: AppColors.lovableGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.lovableTeal.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.shield_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'JourneyGuard AI',
          style: AppTypography.displayLarge.copyWith(
            color: textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Climate-Adaptive Route Risk & Road Safety',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCardTitle(Color textPrimary, Color textSecondary) {
    final title = _currentMode == AuthViewMode.login
        ? 'Welcome Back'
        : _currentMode == AuthViewMode.signUp
            ? 'Create Your Account'
            : 'Reset Password';

    final subtitle = _currentMode == AuthViewMode.login
        ? 'Sign in to access personalized highway risk forecasts'
        : _currentMode == AuthViewMode.signUp
            ? 'Join verified commuters in Kerala road hazard alerts'
            : 'Enter your account email to receive a recovery link';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField(BuildContext context) {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: TextStyle(color: AppColors.textPrimaryFor(context), fontSize: 14),
      decoration: InputDecoration(
        labelText: 'Email Address',
        hintText: 'name@example.com',
        prefixIcon: const Icon(Icons.email_outlined, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.borderFor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.borderFor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lovableTeal, width: 2),
        ),
      ),
      validator: (val) {
        if (val == null || val.trim().isEmpty) return 'Please enter your email address.';
        if (!val.contains('@') || !val.contains('.')) return 'Please enter a valid email.';
        return null;
      },
    );
  }

  Widget _buildPasswordField(BuildContext context) {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: TextStyle(color: AppColors.textPrimaryFor(context), fontSize: 14),
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(Icons.lock_outline, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.borderFor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.borderFor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lovableTeal, width: 2),
        ),
      ),
      validator: (val) {
        if (val == null || val.isEmpty) return 'Please enter your password.';
        if (_currentMode == AuthViewMode.signUp && val.length < 6) {
          return 'Password must be at least 6 characters.';
        }
        return null;
      },
    );
  }

  Widget _buildConfirmPasswordField(BuildContext context) {
    return TextFormField(
      controller: _confirmPasswordController,
      obscureText: _obscureConfirmPassword,
      style: TextStyle(color: AppColors.textPrimaryFor(context), fontSize: 14),
      decoration: InputDecoration(
        labelText: 'Confirm Password',
        prefixIcon: const Icon(Icons.lock_reset_outlined, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
          ),
          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.borderFor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.borderFor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lovableTeal, width: 2),
        ),
      ),
      validator: (val) {
        if (val == null || val.isEmpty) return 'Please confirm your password.';
        if (val != _passwordController.text) return 'Passwords do not match.';
        return null;
      },
    );
  }

  Widget _buildModeSwitchers() {
    if (_currentMode == AuthViewMode.login) {
      return Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            "Don't have an account? ",
            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
          GestureDetector(
            onTap: () => _switchMode(AuthViewMode.signUp),
            child: const Text(
              'Sign Up',
              style: TextStyle(
                color: AppColors.lovableTeal,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    } else if (_currentMode == AuthViewMode.signUp) {
      return Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'Already have an account? ',
            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
          GestureDetector(
            onTap: () => _switchMode(AuthViewMode.login),
            child: const Text(
              'Log In',
              style: TextStyle(
                color: AppColors.lovableTeal,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    } else {
      return Center(
        child: TextButton.icon(
          onPressed: () => _switchMode(AuthViewMode.login),
          icon: const Icon(Icons.arrow_back, size: 16, color: AppColors.lovableTeal),
          label: const Text(
            'Back to Log In',
            style: TextStyle(
              color: AppColors.lovableTeal,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildGuestDemoCard(BuildContext context) {
    final borderColor = AppColors.borderFor(context);
    final surfaceColor = AppColors.surfaceFor(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: AppColors.cardShadowFor(context),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentIndigo.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_pin_circle_outlined,
                  color: AppColors.accentIndigo,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hackathon Demo Access',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Explore all AI risk models immediately with zero registration',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isGuestLoading ? null : _handleGuestLogin,
              icon: _isGuestLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bolt_rounded, color: AppColors.accentIndigo, size: 18),
              label: Text(
                _isGuestLoading ? 'Activating Demo Session...' : 'Continue as Guest (1-Tap Anonymous Auth)',
                style: const TextStyle(
                  color: AppColors.accentIndigo,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.accentIndigo, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBanner({required String message, required bool isError}) {
    final color = isError ? AppColors.riskCritical : AppColors.lovableGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
