import 'package:usage_stats/usage_stats.dart';
import 'dart:io';

class UsageService {
  // 1. İzin kontrolü ve Ayarlara yönlendirme
  static Future<void> checkAndRequestPermission() async {
    if (Platform.isAndroid) {
      bool? isPermissionGranted = await UsageStats.checkUsagePermission();

      if (isPermissionGranted == null || !isPermissionGranted) {
        UsageStats.grantUsagePermission();
      }
    }
  }


  static Future<double> getAppUsage(String packageName) async {
    if (!Platform.isAndroid) return 0.0;

    try {
      // Son 30 günlük veriyi hedefliyoruz
      DateTime endDate = DateTime.now();
      DateTime startDate = endDate.subtract(const Duration(days: 30));

      // Sistemden istatistikleri çek
      List<UsageInfo> usageStats = await UsageStats.queryUsageStats(startDate, endDate);

      double totalMs = 0;

      // Aynı paket ismine ait tüm kayıtları toplayalım (Bazen birden fazla kayıt dönebilir)
      for (var info in usageStats) {
        if (info.packageName == packageName) {
          totalMs += double.parse(info.totalTimeInForeground ?? "0");
        }
      }

      // Analiz sayfamız dakika beklediği için milisaniyeyi dakikaya çeviriyoruz
      // ms / 1000 = saniye -> saniye / 60 = dakika
      return totalMs / 60000;

    } catch (e) {
      print("Kullanım verisi çekme hatası: $e");
      return 0.0;
    }
  }
}