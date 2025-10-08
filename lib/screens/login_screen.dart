// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purepulse_app/utils/colors.dart';
import 'package:rive/rive.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;
  bool _isLoading = false;
  String? _errorMessage;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  // Rive animation controller
  late RiveAnimationController _riveController;
  SMIBool? _isChecking;
  SMIBool? _isHandsUp;
  SMITrigger? _trigSuccess;
  SMITrigger? _trigFail;

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(_onFocusChange);
    _passwordFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _emailFocusNode.removeListener(_onFocusChange);
    _passwordFocusNode.removeListener(_onFocusChange);
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _onRiveInit(Artboard artboard) {
    final controller = StateMachineController.fromArtboard(artboard, 'State Machine 1');
    artboard.addController(controller!);
    _isChecking = controller.findInput<bool>('isChecking') as SMIBool;
    _isHandsUp = controller.findInput<bool>('isHandsUp') as SMIBool;
    _trigSuccess = controller.findInput<bool>('trigSuccess') as SMITrigger;
    _trigFail = controller.findInput<bool>('trigFail') as SMITrigger;
  }

  void _onFocusChange() {
    _isChecking?.value = _emailFocusNode.hasFocus || _passwordFocusNode.hasFocus;
  }

  void _onPasswordChange(String value) {
    _isHandsUp?.value = value.isNotEmpty;
  }
  
  Future<void> _handleAuthAction() async {
    // Hide keyboard
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        _trigSuccess?.fire();
      } else {
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        await userCredential.user?.sendEmailVerification();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent! Please check your inbox.')),
        );
        _trigSuccess?.fire();
        await Future.delayed(const Duration(seconds: 1));
        setState(() => _isLogin = true);
      }
    } on FirebaseAuthException catch (e) {
      _trigFail?.fire();
      setState(() {
        _errorMessage = e.message ?? 'An unknown error occurred.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: secondaryColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            padding: const EdgeInsets.all(28.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Animated Mascot
                SizedBox(
                  height: 200,
                  child: RiveAnimation.asset(
                    'assets/teddy_login_animation.riv',
                    onInit: _onRiveInit,
                  ),
                ),
                Text(
                  _isLogin ? 'Welcome Back!' : 'Create Account',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                _buildTextField(
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  labelText: 'Email Address',
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  labelText: 'Password',
                  obscureText: true,
                  onChanged: _onPasswordChange,
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: errorColor, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _handleAuthAction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          _isLogin ? 'LOGIN' : 'SIGN UP',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_isLogin ? "Don't have an account?" : 'Already have an account?', style: const TextStyle(color: subtleTextColor)),
                    TextButton(
                      onPressed: () => setState(() => _isLogin = !_isLogin),
                      child: Text(_isLogin ? 'Sign Up' : 'Login', style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String labelText,
    bool obscureText = false,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryColor, width: 2)),
      ),
    );
  }
}