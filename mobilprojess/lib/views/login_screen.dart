import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'dashboard_screen.dart';
import 'register_screen.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Tasarım Renkleri
  final Color _neonGreen = const Color(0xFF8CFF32);
  final Color _darkBackground = const Color(0xFF10121D);
  final Color _glassCard = const Color(0xFF1C1E2D);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- ŞİFREMİ UNUTTUM DİYALOĞU ---
  void _showForgotPasswordDialog() {
    final emailResetController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _glassCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Şifreyi Sıfırla",
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "E-posta adresinizi girin, size bir şifre sıfırlama bağlantısı gönderelim.",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 20),
            _buildGlassInputField(
              controller: emailResetController,
              hint: "E-posta",
              icon: Icons.email,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              emailResetController.dispose();
              Navigator.pop(dialogContext);
            },
            child: const Text(
              "İptal",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonGreen),
            onPressed: () async {
              String email = emailResetController.text.trim();

              if (email.isNotEmpty) {
                try {
                  await AuthService().sendPasswordReset(email);

                  if (!mounted || !dialogContext.mounted) return;

                  emailResetController.dispose();
                  Navigator.pop(dialogContext);

                  _showSnackBar(
                    "Şifre sıfırlama bağlantısı mail adresinize gönderildi!",
                    Colors.green,
                  );
                } catch (e) {
                  if (!mounted) return;

                  _showSnackBar("Hata: $e", Colors.red);
                }
              }
            },
            child: const Text(
              "Gönder",
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  // Hızlı SnackBar gösterme yardımcı fonksiyonu
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 100.0),
        child: Column(
          children: [
            // 1. Logo ve Başlık
            Text(
              'SubPulse',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: _neonGreen,
                letterSpacing: -1,
              ),
            ),
            Text(
              'Akıllı Finans ve Abonelik Yönetimi',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 80),

            // 2. Giriş Formu
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

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _showForgotPasswordDialog,
                child: Text(
                  'Şifremi Unuttum?',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),

            // 3. GİRİŞ YAP BUTONU
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
                onPressed: () async {
                  String email = _emailController.text.trim();
                  String password = _passwordController.text.trim();

                  if (email.isEmpty || password.isEmpty) {
                    _showSnackBar("Lütfen tüm alanları doldurun!", Colors.orange);
                    return;
                  }

                  try {
                    final user = await AuthService().signIn(email, password);

                    if (!mounted) return;

                    if (user != null) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DashboardScreen(),
                        ),
                      );
                    }
                  } catch (e) {
                    if (!mounted) return;

                    _showSnackBar(e.toString(), Colors.red);
                  }
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'GİRİŞ YAP',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 10),
                    Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Ortalama Ayırıcı
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Text(
                    'Veya',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Sosyal Giriş
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSocialLoginButton('assets/icons/google.svg', () {
                  debugPrint("Google Girişi Beklemede...");
                }),
                const SizedBox(width: 20),
                _buildSocialLoginButton('assets/icons/apple.svg', () {
                  debugPrint("Apple Girişi Beklemede...");
                }),
              ],
            ),
            const SizedBox(height: 50),

            // Kayıt Ol Linki
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Hesabın yok mu?',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'Kayıt Ol',
                    style: TextStyle(
                      color: _neonGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- YARDIMCI WIDGET'LAR ---

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
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
          ),
          prefixIcon: Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(20),
        ),
      ),
    );
  }

  Widget _buildSocialLoginButton(String iconPath, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _glassCard,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: SvgPicture.asset(iconPath, height: 25),
      ),
    );
  }
}