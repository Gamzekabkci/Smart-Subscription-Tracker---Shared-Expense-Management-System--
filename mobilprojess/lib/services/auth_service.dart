import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. Mevcut kullanıcıyı al (Oturum kontrolü için)
  User? get currentUser => _auth.currentUser;

  // 2. Giriş durumunu dinle (Stream yapısı - UI'ı otomatik güncellemek için)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 3. E-posta ve Şifre ile Giriş Yap
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      // Teknik hatayı anlaşılır bir mesaja çevirip fırlatıyoruz
      throw _handleAuthException(e);
    }
  }

  // 4. Şifre Sıfırlama Maili Gönder
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // 5. Çıkış Yap
  Future<void> signOut() async {
    await _auth.signOut();
  }
  Future<User?> signUp(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return result.user; // Başarılıysa kullanıcıyı döndürür ve Console'a kayıt düşer
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // --- ÖZEL HATA YÖNETİCİSİ ---
  // Firebase'in kodlarını (e.code) Türkçe mesajlara çevirir.
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return "Bu e-posta adresiyle kayıtlı bir kullanıcı bulunamadı.";
      case 'wrong-password':
        return "Hatalı şifre girdiniz.";
      case 'invalid-email':
        return "Geçersiz bir e-posta adresi girdiniz.";
      case 'user-disabled':
        return "Bu kullanıcı hesabı devre dışı bırakılmış.";
      case 'too-many-requests':
        return "Çok fazla başarısız deneme. Lütfen bir süre sonra tekrar deneyin.";
      default:
        return e.message ?? "Beklenmedik bir hata oluştu.";
    }
  }
}