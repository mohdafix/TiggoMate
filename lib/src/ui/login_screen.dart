import 'package:flutter/material.dart';
import '../auth/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const LoginScreen({super.key, required this.onAuthenticated});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  bool _isSignUp = false;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController(text: 'Mohd Afix');
  final _plateController = TextEditingController(text: 'VRT 3342');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailAuth() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final res = _isSignUp
        ? await _authService.signUpWithEmail(
            email: _emailController.text,
            password: _passwordController.text,
            displayName: _nameController.text,
            carPlate: _plateController.text,
          )
        : await _authService.signInWithEmail(
            email: _emailController.text,
            password: _passwordController.text,
          );

    if (mounted) {
      setState(() => _loading = false);
      if (res.success) {
        widget.onAuthenticated();
      } else {
        setState(() => _errorMessage = res.message);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final res = await _authService.signInWithGoogle();
    if (mounted) {
      setState(() => _loading = false);
      if (res.success) {
        widget.onAuthenticated();
      } else {
        setState(() => _errorMessage = res.message);
      }
    }
  }

  Future<void> _handleGuestMode() async {
    setState(() => _loading = true);
    await _authService.continueAsGuest(
      name: _nameController.text.isNotEmpty ? _nameController.text : 'AFiX',
      plate: _plateController.text.isNotEmpty ? _plateController.text : 'VRT 3342',
    );
    if (mounted) {
      setState(() => _loading = false);
      widget.onAuthenticated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF131922) : Colors.white;
    final inputBg = isDark ? const Color(0xFF090D12) : const Color(0xFFF3F4F6);
    final border = isDark ? const Color(0xFF232D3D) : const Color(0xFFE5E7EB);
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSec = isDark ? Colors.white60 : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Branding Header
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cardBg,
                        border: Border.all(color: const Color(0xFF00D2AA).withValues(alpha: 0.4), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00D2AA).withValues(alpha: isDark ? 0.15 : 0.2),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.electric_bolt_rounded, size: 44, color: Color(0xFF00D2AA)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'TiggoMate',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Chery Tiggo 7 PHEV CSH • Smart Cloud Telemetry',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: textSec),
                  ),
                  const SizedBox(height: 28),

                  // Auth Card Container
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: border),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Segmented Tab Switcher (Sign In vs Register)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _isSignUp = false;
                                    _errorMessage = null;
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: !_isSignUp ? const Color(0xFF00D2AA).withValues(alpha: 0.2) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: !_isSignUp ? Border.all(color: const Color(0xFF00D2AA)) : null,
                                    ),
                                    child: Text(
                                      'Sign In',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: !_isSignUp ? const Color(0xFF00D2AA) : textSec,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _isSignUp = true;
                                    _errorMessage = null;
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _isSignUp ? const Color(0xFF00D2AA).withValues(alpha: 0.2) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: _isSignUp ? Border.all(color: const Color(0xFF00D2AA)) : null,
                                    ),
                                    child: Text(
                                      'Create Account',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _isSignUp ? const Color(0xFF00D2AA) : textSec,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Error Banner if present
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF85149).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFF85149)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, size: 18, color: Color(0xFFF85149)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFFF85149)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Sign Up extra fields
                        if (_isSignUp) ...[
                          TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Driver Name',
                              prefixIcon: const Icon(Icons.person_outline, size: 20, color: Color(0xFF00D2AA)),
                              filled: true,
                              fillColor: inputBg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00D2AA))),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _plateController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: 'Car Plate Number',
                              prefixIcon: const Icon(Icons.directions_car_outlined, size: 20, color: Color(0xFF00D2AA)),
                              filled: true,
                              fillColor: inputBg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00D2AA))),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Email Field
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            hintText: 'e.g. driver@tiggomate.my',
                            prefixIcon: const Icon(Icons.email_outlined, size: 20, color: Color(0xFF00D2AA)),
                            filled: true,
                            fillColor: inputBg,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00D2AA))),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Password Field
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline, size: 20, color: Color(0xFF00D2AA)),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 18, color: textSec),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            filled: true,
                            fillColor: inputBg,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00D2AA))),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Submit Primary Button
                        ElevatedButton(
                          onPressed: _loading ? null : _handleEmailAuth,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00D2AA),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: _loading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : Text(
                                  _isSignUp ? 'Create Cloud Account' : 'Sign In with Firebase',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                        ),
                        const SizedBox(height: 14),

                        // Google Sign-In Button
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _handleGoogleSignIn,
                          icon: Icon(Icons.g_mobiledata, size: 24, color: isDark ? Colors.white : const Color(0xFF2563EB)),
                          label: Text(
                            'Continue with Google',
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF1E40AF),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: isDark ? const Color(0xFF232D3D) : const Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Continue as Guest Option
                  TextButton.icon(
                    onPressed: _loading ? null : _handleGuestMode,
                    icon: Icon(Icons.arrow_forward, size: 16, color: textSec),
                    label: Text(
                      'Continue as Guest Driver (Offline Mode)',
                      style: TextStyle(color: textSec, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Firebase Firestore Database (Singapore • asia-southeast1)\nSyncs PHEV telemetry, trips, smart charging & service schedule across devices.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white38 : const Color(0xFF9CA3AF), height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
