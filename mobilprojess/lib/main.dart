import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Firebase çekirdek paketi
import 'firebase_options.dart'; // flutterfire configure ile oluşan dosya
import 'services/auth_service.dart';
import 'views/dashboard_screen.dart';
import 'views/login_screen.dart';
import 'utils/app_theme.dart';
import 'services/notification_service.dart';

// Tema yönetimi için global notifier
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

void main() async {
  // 1. ADIM: Flutter widget'larını ve asenkron işlemleri hazırla
  WidgetsFlutterBinding.ensureInitialized();

  // 2. ADIM: Firebase'i projedeki ayarlarla başlat
  // Bu satır olmadan Firebase servisleri (Auth, DB vb.) çalışmaz.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.instance.init();
  await NotificationService.instance.rescheduleAll();
  // 3. ADIM: Kullanıcının giriş yapıp yapmadığını kontrol et
  // Firebase Auth, kullanıcıyı cihazda otomatik hatırlar.
  final authService = AuthService();
  bool isLoggedIn = authService.currentUser != null;

  runApp(SubPulseApp(isLoggedIn: isLoggedIn));
}

class SubPulseApp extends StatelessWidget {
  final bool isLoggedIn;
  const SubPulseApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'SubPulse AI',
          debugShowCheckedModeBanner: false,

          // Tema Ayarları
          theme: AppThemes.lightTheme,
          darkTheme: AppThemes.darkTheme,
          themeMode: currentMode,

          // Başlangıç Sayfası
          home: isLoggedIn ? const DashboardScreen() : const LoginScreen(),
        );
      },
    );
  }
}