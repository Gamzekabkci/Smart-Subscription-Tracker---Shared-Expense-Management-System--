import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../services/db_helper.dart';
import '../models/subscription_model.dart';
import 'add_subscription_screen.dart';

class SharedScreen extends StatefulWidget {
  const SharedScreen({super.key});

  @override
  State<SharedScreen> createState() => _SharedScreenState();
}

class _SharedScreenState extends State<SharedScreen> {
  List<Subscription> _sharedSubscriptions = [];
  double _totalSaved = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSharedData();
  }

  Future<void> _fetchSharedData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        if (!mounted) return;

        setState(() {
          _sharedSubscriptions = [];
          _totalSaved = 0.0;
          _isLoading = false;
        });

        return;
      }

      final allSubs = await DbHelper.instance.getSubscriptionsByUser(
        currentUser.uid,
      );

      final sharedSubs = allSubs.where((sub) => sub.isShared).toList();

      double savedAmount = 0.0;

      for (var sub in sharedSubs) {
        if (sub.personCount > 1) {
          savedAmount += sub.price - (sub.price / sub.personCount);
        }
      }

      if (!mounted) return;

      setState(() {
        _sharedSubscriptions = sharedSubs;
        _totalSaved = savedAmount;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _sharedSubscriptions = [];
        _totalSaved = 0.0;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Paylaşılan abonelikler yüklenirken hata oluştu: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatPhoneForWhatsApp(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleaned.startsWith('0')) {
      cleaned = '90${cleaned.substring(1)}';
    }

    if (cleaned.length == 10) {
      cleaned = '90$cleaned';
    }

    return cleaned;
  }

  Future<void> _sendWhatsAppReminderToMember(
      Subscription sub,
      SharedMember member,
      double amount,
      ) async {
    final phone = _formatPhoneForWhatsApp(member.phone);

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bu kişinin telefon numarası bulunamadı."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final String message =
        "Selam ${member.name}! SubPulse üzerinden takip ettiğimiz '${sub.name}' ortak aboneliğimiz için bu ayki payına düşen ${amount.toStringAsFixed(0)} TL ödemeyi hatırlatmak istedim. 💸";

    final Uri whatsappUrl = Uri.parse(
      "https://wa.me/$phone?text=${Uri.encodeComponent(message)}",
    );

    try {
      final opened = await launchUrl(
        whatsappUrl,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp açılamadı.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WhatsApp açılamadı.'),
        ),
      );
    }
  }

  void _showInviteQR(BuildContext context, Subscription sub) {
    final theme = Theme.of(context);

    final String uid =
        firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? "";

    final String qrPayload =
        "subpulse://join?ownerId=$uid&planId=${sub.id}&planName=${Uri.encodeComponent(sub.name)}";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        title: Center(
          child: Text(
            "Gruba Davet Et",
            style: TextStyle(
              color: theme.textTheme.bodyLarge?.color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "${sub.name} grubuna katılmak için arkadaşına bu kodu okut.",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: 200,
              height: 200,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: QrImageView(
                  data: qrPayload,
                  version: QrVersions.auto,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Kapat",
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openScanner() async {
    PermissionStatus status = await Permission.camera.request();

    if (status.isGranted) {
      if (!mounted) return;

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const QRScannerScreen(),
        ),
      );

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Başarıyla Okundu!\nVeri: $result\n(Gruba katılma altyapısı daha sonra bağlanacak)',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    } else {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Kamera izni verilmedi."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.scaffoldBackgroundColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          color: theme.colorScheme.primary,
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchSharedData,
        color: theme.colorScheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Tasarruf Havuzu",
                    style: TextStyle(
                      color: textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.qr_code_scanner_rounded,
                      color: textColor,
                    ),
                    onPressed: _openScanner,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              if (_sharedSubscriptions.isNotEmpty) ...[
                _buildWalletSummaryCard(),
                const SizedBox(height: 30),
                Text(
                  "Gruplarım",
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
              ],

              if (_sharedSubscriptions.isEmpty)
                _buildEmptyState()
              else
                ..._sharedSubscriptions.map(
                      (sub) => _buildSharedPlanCard(sub),
                ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final cardColor = theme.colorScheme.surface;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 30),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.group_add_rounded,
              size: 60,
              color: primaryColor,
            ),
          ),

          const SizedBox(height: 25),

          Text(
            "Dijital Muhasebecin Bekliyor",
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 10),

          const Text(
            "Bu kullanıcı için henüz ortak abonelik yok. Ortak abonelik eklerken rehberden kişileri seçebilirsin.",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 13,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 30),

          ElevatedButton.icon(
            onPressed: () async {
              bool? refresh = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddSubscriptionScreen(),
                ),
              );

              if (refresh == true) {
                await _fetchSharedData();
              }
            },
            icon: const Icon(
              Icons.add_circle_outline,
              color: Colors.black,
            ),
            label: const Text(
              "Ortak Abonelik Ekle",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 15,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletSummaryCard() {
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surface;
    final primaryColor = theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.1),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.savings_rounded,
                color: primaryColor,
                size: 24,
              ),
              const SizedBox(width: 10),
              const Text(
                "PAYLAŞILAN CÜZDAN",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          RichText(
            text: TextSpan(
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 15,
                height: 1.5,
              ),
              children: [
                const TextSpan(
                  text: "Bu ay ortak planlar sayesinde toplam ",
                ),
                TextSpan(
                  text: "${_totalSaved.toStringAsFixed(0)} TL ",
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const TextSpan(
                  text: "tasarruf ettin!",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedPlanCard(Subscription sub) {
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surface;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final primaryColor = theme.colorScheme.primary;

    double perPersonPrice = sub.price / (sub.personCount > 0 ? sub.personCount : 1);
    final members = sub.sharedMembers;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: primaryColor.withValues(alpha: 0.1),
                    radius: 18,
                    child: Icon(
                      Icons.group_work_rounded,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    sub.name,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${sub.price.toStringAsFixed(0)} TL",
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    "Kişi Başı: ${perPersonPrice.toStringAsFixed(0)} TL",
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),

          Divider(
            color: Colors.grey.withValues(alpha: 0.2),
            height: 30,
          ),

          _buildOwnerRow(),

          if (members.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                "Bu ortak aboneliğe rehberden kişi eklenmemiş.",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            )
          else
            ...members.map(
                  (member) => _buildMemberRow(
                sub,
                member,
                perPersonPrice,
              ),
            ),

          const SizedBox(height: 15),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showInviteQR(context, sub),
              icon: Icon(
                Icons.qr_code,
                color: textColor,
                size: 18,
              ),
              label: Text(
                "Davet Et",
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerRow() {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final primaryColor = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: primaryColor,
                child: const Text(
                  "S",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Text(
                "Sen",
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: primaryColor,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  "Ödedi",
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberRow(
      Subscription sub,
      SharedMember member,
      double perPersonPrice,
      ) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final primaryColor = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                  child: Text(
                    member.name.isNotEmpty ? member.name[0].toUpperCase() : "?",
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    member.name,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          ElevatedButton.icon(
            onPressed: () => _sendWhatsAppReminderToMember(
              sub,
              member,
              perPersonPrice,
            ),
            icon: const Icon(
              Icons.notifications_active_rounded,
              color: Colors.black,
              size: 14,
            ),
            label: const Text(
              "Hatırlat",
              style: TextStyle(
                color: Colors.black,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanned = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kodu Tarat',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              if (_isScanned) return;

              final List<Barcode> barcodes = capture.barcodes;

              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  setState(() => _isScanned = true);

                  final String code = barcode.rawValue!;

                  cameraController.stop();
                  Navigator.pop(context, code);
                  break;
                }
              }
            },
          ),

          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.greenAccent,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),

          const Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Text(
              "Arkadaşınızın 'Davet Et' kodunu çerçevenin içine hizalayın.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                backgroundColor: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}