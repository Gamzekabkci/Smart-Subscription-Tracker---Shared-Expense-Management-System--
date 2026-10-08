import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../services/notification_service.dart';
import '../services/db_helper.dart';
import '../main.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  final int activeSubs;

  const SettingsScreen({super.key, required this.activeSubs});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _name = "Kullanıcı";
  String _surname = "";
  bool _isNotifications = true;
  bool _isDarkMode = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String get _fullName {
    final fullName = "$_name $_surname".trim();
    return fullName.isNotEmpty ? fullName : "Kullanıcı";
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      await currentUser.reload();
    }

    final refreshedUser = firebase_auth.FirebaseAuth.instance.currentUser;
    final firebaseName = refreshedUser?.displayName?.trim() ?? "";

    String savedName = prefs.getString('user_name') ?? "";
    String savedSurname = prefs.getString('user_surname') ?? "";

    if (firebaseName.isNotEmpty) {
      final parts = firebaseName.split(' ');

      savedName = parts.isNotEmpty ? parts.first : "Kullanıcı";
      savedSurname = parts.length > 1 ? parts.sublist(1).join(' ') : "";

      await prefs.setString('user_name', savedName);
      await prefs.setString('user_surname', savedSurname);
      await prefs.setString('user_full_name', firebaseName);
    }

    if (!mounted) return;

    setState(() {
      _name = savedName.isNotEmpty ? savedName : "Kullanıcı";
      _surname = savedSurname;
      _isNotifications = prefs.getBool('notifications') ?? true;
      _isDarkMode = prefs.getBool('dark_mode') ?? true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.scaffoldBackgroundColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            Text(
              "Profil & Ayarlar",
              style: TextStyle(
                color: textColor,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 25),

            _buildProfileHeader(),

            const SizedBox(height: 30),

            _buildSectionLabel("Hesap Yönetimi"),

            _buildSettingTile(
              icon: Icons.edit_note_rounded,
              title: "Profili Düzenle",
              subtitle: "İsim ve soyismini güncelle",
              onTap: () => _showEditProfileDialog(),
            ),

            _buildSettingTile(
              icon: Icons.lock_reset_rounded,
              title: "Şifre Değiştir",
              subtitle: "Giriş şifresini kalıcı olarak yenile",
              onTap: () => _showChangePasswordDialog(),
            ),

            _buildSettingTile(
              icon: Icons.logout_rounded,
              title: "Çıkış Yap",
              subtitle: "Hesabından güvenli bir şekilde çık",
              textColor: Colors.orangeAccent,
              onTap: () => _showLogoutDialog(),
            ),

            const SizedBox(height: 20),

            _buildSectionLabel("Tercihler"),

            _buildSettingTile(
              icon: Icons.dark_mode_outlined,
              title: "Karanlık Mod",
              subtitle: "Temayı değiştir",
              trailing: Switch(
                value: _isDarkMode,
                activeThumbColor: primaryColor,
                onChanged: (val) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('dark_mode', val);

                  if (!mounted) return;

                  setState(() {
                    _isDarkMode = val;
                  });

                  themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                },
              ),
            ),

            _buildSettingTile(
              icon: Icons.notifications_none_rounded,
              title: "Bildirimler",
              subtitle: "Vadesi gelen ödemeler için uyarı al",
              trailing: Switch(
                value: _isNotifications,
                activeThumbColor: primaryColor,
                onChanged: (val) async {
                  await NotificationService.instance.setNotificationsEnabled(val);

                  if (!mounted) return;

                  setState(() {
                    _isNotifications = val;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        val
                            ? "Bildirimler aktif edildi."
                            : "Bildirimler kapatıldı.",
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            _buildSectionLabel("Tehlikeli Bölge"),

            _buildSettingTile(
              icon: Icons.delete_forever_outlined,
              title: "Tüm Verileri Temizle",
              subtitle: "Bu hesaba ait abonelikleri sil",
              textColor: Colors.redAccent,
              onTap: () => _showDeleteAllDialog(),
            ),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final theme = Theme.of(context);
    final cardBg = theme.colorScheme.surface;
    final primaryColor = theme.colorScheme.primary;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    final firstInitial = _name.isNotEmpty ? _name[0] : "";
    final secondInitial = _surname.isNotEmpty ? _surname[0] : "";

    final initials = "$firstInitial$secondInitial".trim().isNotEmpty
        ? "$firstInitial$secondInitial".toUpperCase()
        : "K";

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: primaryColor.withValues(alpha: 0.1),
            child: Text(
              initials,
              style: TextStyle(
                color: primaryColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(width: 20),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fullName,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  "${widget.activeSubs} Aktif Abonelik",
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 10, top: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    Color? textColor,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final cardBg = theme.colorScheme.surface;
    final defaultTextColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          icon,
          color: textColor ?? defaultTextColor,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: textColor ?? defaultTextColor,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 11,
          ),
        ),
        trailing: trailing ??
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.grey,
              size: 14,
            ),
      ),
    );
  }

  void _showEditProfileDialog() {
    final theme = Theme.of(context);
    final nameCtrl = TextEditingController(text: _name);
    final surnameCtrl = TextEditingController(text: _surname);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          "Profil Bilgileri",
          style: TextStyle(
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
              ),
              decoration: const InputDecoration(
                labelText: "İsim",
                labelStyle: TextStyle(color: Colors.grey),
              ),
            ),

            TextField(
              controller: surnameCtrl,
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
              ),
              decoration: const InputDecoration(
                labelText: "Soyisim",
                labelStyle: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Vazgeç"),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
            ),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();

              final newName = nameCtrl.text.trim();
              final newSurname = surnameCtrl.text.trim();
              final fullName = "$newName $newSurname".trim();

              await prefs.setString(
                'user_name',
                newName.isNotEmpty ? newName : "Kullanıcı",
              );
              await prefs.setString('user_surname', newSurname);
              await prefs.setString(
                'user_full_name',
                fullName.isNotEmpty ? fullName : "Kullanıcı",
              );

              await firebase_auth.FirebaseAuth.instance.currentUser
                  ?.updateDisplayName(
                fullName.isNotEmpty ? fullName : "Kullanıcı",
              );

              await _loadData();

              if (!mounted) return;

              Navigator.pop(context);
            },
            child: const Text(
              "Güncelle",
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final theme = Theme.of(context);
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          "Yeni Şifre Belirle",
          style: TextStyle(
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        content: TextField(
          controller: passCtrl,
          obscureText: true,
          style: TextStyle(
            color: theme.textTheme.bodyLarge?.color,
          ),
          decoration: const InputDecoration(
            labelText: "Yeni Şifre",
            labelStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal"),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
            ),
            onPressed: () async {
              final newPassword = passCtrl.text.trim();

              if (newPassword.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Şifre en az 6 karakter olmalı."),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                await firebase_auth.FirebaseAuth.instance.currentUser
                    ?.updatePassword(newPassword);

                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Şifre başarıyla güncellendi!"),
                    backgroundColor: Colors.green,
                  ),
                );

                Navigator.pop(context);
              } on firebase_auth.FirebaseAuthException catch (e) {
                if (!mounted) return;

                String message = "Şifre güncellenemedi.";

                if (e.code == 'requires-recent-login') {
                  message =
                  "Şifre değiştirmek için tekrar giriş yapmanız gerekiyor.";
                } else if (e.code == 'weak-password') {
                  message = "Şifre çok zayıf.";
                } else {
                  message = "Hata: ${e.message}";
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              "Şifreyi Değiştir",
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAllDialog() {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          "Tüm Veriler Silinsin mi?",
          style: TextStyle(
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        content: const Text(
          "Bu işlem geri alınamaz. Sadece bu hesaba ait abonelikler silinecektir.",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal"),
          ),

          TextButton(
            onPressed: () async {
              final currentUser =
                  firebase_auth.FirebaseAuth.instance.currentUser;

              if (currentUser != null) {
                await DbHelper.instance.deleteSubscriptionsByUser(
                  currentUser.uid,
                );
                await NotificationService.instance.rescheduleAll();
              }

              if (!mounted) return;

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Bu hesaba ait abonelikler temizlendi."),
                ),
              );
            },
            child: const Text(
              "Evet, Hepsini Sil",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          "Çıkış Yap",
          style: TextStyle(
            color: theme.textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          "Hesabınızdan çıkış yapmak istediğinize emin misiniz?",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "İptal",
              style: TextStyle(color: Colors.grey),
            ),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () async {
              await firebase_auth.FirebaseAuth.instance.signOut();

              if (!mounted) return;

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const LoginScreen(),
                ),
                    (Route<dynamic> route) => false,
              );
            },
            child: const Text(
              "Çıkış Yap",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}