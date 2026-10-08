import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/db_helper.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controller tanımlamaları
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Tasarım Renkleri
  final Color _neonGreen = const Color(0xFF8CFF32);
  final Color _glassCard = const Color(0xFF1C1E2D);

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- KAYIT MANTIĞI ---
  Future<void> _handleRegister() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      String fullText = _fullNameController.text.trim();
      List<String> nameParts = fullText.split(' ');
      String firstName = nameParts.isNotEmpty ? nameParts[0] : "Kullanıcı";
      String lastName =
      nameParts.length > 1 ? nameParts.sublist(1).join(' ') : "";

      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // 1. Firebase Auth'a kullanıcı oluştur
      final credential =
      await firebase_auth.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Firebase profil adını güncelle
      await credential.user?.updateDisplayName(fullText);

      // 2. SharedPreferences'a kaydet
      await prefs.setString('user_name', firstName);
      await prefs.setString('user_surname', lastName);
      await prefs.setString('user_email', email);

      // Güvenlik için şifreyi SharedPreferences'a kaydetmeyin
      // await prefs.setString('user_password', password);

      // 3. Lokal SQLite'a da kaydetmek istiyorsanız
      try {
        final newUser = User(
          name: firstName,
          email: email,
          password: password,
        );
        await DbHelper.instance.insertUser(newUser);
      } catch (e) {
        debugPrint("DB Kayıt Hatası: $e");
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Hesap başarıyla oluşturuldu!"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message = "Kayıt başarısız.";

      if (e.code == 'email-already-in-use') {
        message = "Bu e-posta zaten kayıtlı.";
      } else if (e.code == 'weak-password') {
        message = "Şifre en az 6 karakter olmalı.";
      } else if (e.code == 'invalid-email') {
        message = "E-posta formatı hatalı.";
      } else {
        message = "Kayıt hatası: ${e.message}";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Beklenmeyen hata: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SubPulse',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _neonGreen,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Akıllı abonelik takibi için hemen kaydol.',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 40),

              // Giriş Alanları
              _buildGlassInputField(
                controller: _fullNameController,
                hint: 'Ad Soyad',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 20),
              _buildGlassInputField(
                controller: _emailController,
                hint: 'E-posta Adresi',
                icon: Icons.mail_outline,
              ),
              const SizedBox(height: 20),
              _buildGlassInputField(
                controller: _passwordController,
                hint: 'Şifre',
                icon: Icons.lock_outline,
                isPassword: true,
              ),
              const SizedBox(height: 20),
              _buildGlassInputField(
                controller: _confirmPasswordController,
                hint: 'Şifre Tekrar',
                icon: Icons.lock_outline,
                isPassword: true,
              ),

              const SizedBox(height: 70),

              // --- HESAP OLUŞTUR BUTONU ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _neonGreen,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      if (_passwordController.text !=
                          _confirmPasswordController.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Şifreler uyuşmuyor!'),
                          ),
                        );
                        return;
                      }

                      _handleRegister();
                    }
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'HESAP OLUŞTUR',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 10),
                      Icon(Icons.person_add_alt, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // --- YARDIMCI UI BİLEŞENLERİ ---

  Widget _buildGlassInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _glassCard,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white),
        validator: (value) =>
        value == null || value.isEmpty ? "Bu alan boş bırakılamaz" : null,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withAlpha(100)),
          prefixIcon: Icon(icon, color: Colors.white.withAlpha(120)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(20),
        ),
      ),
    );
  }
}