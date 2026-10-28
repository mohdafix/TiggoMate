import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import 'app_notification.dart';

class AuthSheet extends StatefulWidget {
  final VoidCallback onProfileUpdated;

  const AuthSheet({super.key, required this.onProfileUpdated});

  static Future<void> show(BuildContext context, {required VoidCallback onProfileUpdated}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AuthSheet(onProfileUpdated: onProfileUpdated),
    );
  }

  @override
  State<AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<AuthSheet> {
  final _authService = AuthService();
  bool _isSignUp = false;
  bool _loading = false;
  String? _errorMessage;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _plateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = _authService.currentUser;
    _nameController.text = user.displayName;
    _plateController.text = user.carPlate;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _plateController.dispose();
    super.dispose();
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
        widget.onProfileUpdated();
        Navigator.of(context).pop();
        AppNotification.show(
          context,
          message: res.message,
          type: NotificationType.success,
          icon: Icons.check_circle_rounded,
        );
      } else {
        setState(() => _errorMessage = res.message);
      }
    }
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
        widget.onProfileUpdated();
        Navigator.of(context).pop();
        AppNotification.show(
          context,
          message: res.message,
          type: NotificationType.success,
          icon: Icons.check_circle_rounded,
        );
      } else {
        setState(() => _errorMessage = res.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D1219) : Colors.white;
    final tileBg = isDark ? const Color(0xFF131922) : const Color(0xFFF3F4F6);
    final border = isDark ? const Color(0xFF232D3D) : const Color(0xFFE5E7EB);
    final textSec = isDark ? Colors.white54 : const Color(0xFF6B7280);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: border, width: 1.5)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D2AA).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.cloud_sync, color: Color(0xFF00D2AA), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TiggoMate Cloud Sync', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        Text('Firebase Authentication & Storage', style: TextStyle(fontSize: 11, color: textSec)),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: textSec, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (user.isAuthenticated) ...[
              // Already Authenticated View
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tileBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFF00D2AA).withValues(alpha: 0.2),
                          child: Text(
                            user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U',
                            style: const TextStyle(color: Color(0xFF00D2AA), fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.displayName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              Text(user.email, style: TextStyle(fontSize: 12, color: textSec)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF00D2AA))),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Cloud Synced • Plate ${user.carPlate}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF00D2AA)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Divider(height: 24, color: border),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.logout, size: 16),
                            label: const Text('Switch Account'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white70 : const Color(0xFF374151),
                              side: BorderSide(color: border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              await _authService.signOut();
                              setState(() {});
                              widget.onProfileUpdated();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Sign In / Sign Up Form
              // Google One-Tap Sign In
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _handleGoogleSignIn,
                  icon: Icon(Icons.g_mobiledata, size: 26, color: isDark ? Colors.white : const Color(0xFF2563EB)),
                  label: Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E40AF),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: Color(0xFF2F81F7), width: 1.2),
                    backgroundColor: const Color(0xFF2F81F7).withValues(alpha: isDark ? 0.12 : 0.08),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(child: Divider(color: border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('OR EMAIL', style: TextStyle(fontSize: 10, color: textSec, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(child: Divider(color: border)),
                ],
              ),
              const SizedBox(height: 14),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
              ],

              if (_isSignUp) ...[
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline, size: 20),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _plateController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Plate (e.g. VRT 3342)',
                    prefixIcon: Icon(Icons.badge_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'alex@gmail.com',
                  prefixIcon: Icon(Icons.email_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline, size: 20),
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _handleEmailAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D2AA),
                    foregroundColor: const Color(0xFF090D12),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : Text(
                          _isSignUp ? 'Create Firebase Account' : 'Sign In with Email',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              Center(
                child: TextButton(
                  onPressed: () => setState(() {
                    _isSignUp = !_isSignUp;
                    _errorMessage = null;
                  }),
                  child: Text(
                    _isSignUp ? 'Already have an account? Sign In' : "Don't have an account? Register",
                    style: TextStyle(fontSize: 12.5, color: textSec),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
