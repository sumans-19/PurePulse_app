import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import 'signup_screen.dart';
import '../home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = context.read<AuthService>();
    final credential = await authService.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (credential != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authService.errorMessage ?? 'Login failed'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                
                // Premium Logo Section
                Container(
                  height: 100,
                  width: 100,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).primaryColor,
                        Theme.of(context).primaryColor.withAlpha(180),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withAlpha(100),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.air,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 28),
                
                // App Title
                Text(
                  'PurePlus',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Subtitle
                Text(
                  'Monitor air quality, protect your health',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 48),
                
                // Welcome Text
                Text(
                  'Welcome Back',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sign in to your account to continue',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    labelStyle: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIcon: Icon(
                      Icons.email_outlined,
                      color: Theme.of(context).primaryColor,
                    ),
                    filled: true,
                    fillColor: isDark 
                      ? Colors.grey[800]
                      : Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey[300]!,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey[300]!,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).primaryColor,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.red,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
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
                    labelText: 'Password',
                    labelStyle: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIcon: Icon(
                      Icons.lock_outline,
                      color: Theme.of(context).primaryColor,
                    ),
                    filled: true,
                    fillColor: isDark 
                      ? Colors.grey[800]
                      : Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey[300]!,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey[300]!,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).primaryColor,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.red,
                      ),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Theme.of(context).primaryColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                
                // Forgot Password Link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // TODO: Implement forgot password
                    },
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                
                // Login Button
                Consumer<AuthService>(
                  builder: (context, authService, _) {
                    return ElevatedButton(
                      onPressed: authService.isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Theme.of(context).primaryColor,
                        disabledBackgroundColor: Colors.grey[400],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: authService.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: Colors.white,
                              ),
                            ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                
                // Divider with text
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: Colors.grey[300],
                        thickness: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'New to PurePlus?',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: Colors.grey[300],
                        thickness: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Sign Up Link
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SignupScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                      color: Theme.of(context).primaryColor,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Create New Account',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).primaryColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}