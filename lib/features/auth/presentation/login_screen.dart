import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/localization.dart';
import '../../../core/theme/theme.dart';
import 'auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'sarwarkhancs619@gmail.com');
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      final success = await ref.read(authProvider.notifier).login(
            _emailController.text,
            _passwordController.text,
          );
      if (!success && mounted) {
        final error = ref.read(authProvider).errorMessage ?? 'Invalid email or password';
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    error,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Background premium gradient
          Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.blueOrangeGradient,
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Language Selector at the top right (white for dark gradient background)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            ref.read(localeProvider.notifier).toggleLanguage();
                          },
                          icon: const Icon(Icons.language, color: Colors.white),
                          label: Text(
                            locale.languageCode == 'en' ? 'اردو' : 'English',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Logo/App Info
                      Container(
                        height: 90,
                        width: 90,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.diversity_3,
                          size: 48,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        localizations.translate('app_name'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        localizations.translate('app_tagline'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                              color: Colors.white70,
                            ),
                      ),
                      const SizedBox(height: 40),
 
                       // Login Form Card
                       Card(
                         elevation: 8,
                        child: Padding(
                          padding: const EdgeInsets.all(28.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  localizations.translate('login_title'),
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 16),
                                if (authState.errorMessage != null && !authState.isLoading) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.red.shade300),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            authState.errorMessage!,
                                            style: TextStyle(
                                              color: Colors.red.shade900,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ] else
                                  const SizedBox(height: 8),
                                
                                // Email Field
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    labelText: localizations.translate('email'),
                                    prefixIcon: const Icon(Icons.email_outlined),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter email address';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                
                                // Password Field
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: localizations.translate('password'),
                                    prefixIcon: const Icon(Icons.lock_outlined),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter password';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                
                                // Remember Me & Forgot Password
                                Row(
                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                   children: [
                                     Expanded(
                                       child: Row(
                                         mainAxisSize: MainAxisSize.min,
                                         children: [
                                           Checkbox(
                                             value: _rememberMe,
                                             activeColor: AppTheme.primaryColor,
                                             onChanged: (value) {
                                               setState(() {
                                                 _rememberMe = value ?? false;
                                               });
                                             },
                                           ),
                                           Flexible(
                                             child: Text(
                                               localizations.translate('remember_me'),
                                               style: const TextStyle(fontSize: 14),
                                               overflow: TextOverflow.ellipsis,
                                             ),
                                           ),
                                         ],
                                       ),
                                     ),
                                     Flexible(
                                       child: TextButton(
                                         onPressed: () {},
                                         child: Text(
                                           localizations.translate('forgot_password'),
                                           style: const TextStyle(
                                             fontSize: 13,
                                             color: AppTheme.primaryColor,
                                           ),
                                           overflow: TextOverflow.ellipsis,
                                         ),
                                       ),
                                     ),
                                   ],
                                 ),
                                const SizedBox(height: 24),
                                
                                // Submit Button
                                authState.isLoading
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                          color: AppTheme.primaryColor,
                                        ),
                                      )
                                    : ElevatedButton(
                                        onPressed: _submit,
                                        child: Text(localizations.translate('login')),
                                      ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                                         // Staff sign-in notice
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.15)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_user_outlined, color: AppTheme.primaryColor, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Sign in using your Roshni staff credentials or administrator account.',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
