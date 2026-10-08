import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../services/notification_service.dart';
import '../services/usage_service.dart';
import '../services/db_helper.dart';
import '../models/subscription_model.dart';
import 'add_subscription_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';
import 'shared_screen.dart';
import 'notification_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  double _toplamHarcama = 0.0;
  double _aylikKazanc = 0.0;
  double _yillikProjeksiyon = 0.0;
  Map<String, double> _kategoriHarcamalari = {};
  List<Subscription> _abonelikListesi = [];

  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _verileriYukle();
  }

  Future<void> _checkPermissions() async {
    await UsageService.checkAndRequestPermission();
  }

  Future<void> _verileriYukle() async {
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      if (!mounted) return;

      setState(() {
        _currentUserId = null;
        _toplamHarcama = 0.0;
        _aylikKazanc = 0.0;
        _yillikProjeksiyon = 0.0;
        _abonelikListesi = [];
        _kategoriHarcamalari = {};
      });

      return;
    }

    final uid = currentUser.uid;
    final list = await DbHelper.instance.getSubscriptionsByUser(uid);

    double toplam = 0.0;
    double kumbara = 0.0;
    double yillikYuk = 0.0;
    Map<String, double> kategoriGruplari = {};

    for (var sub in list) {
      double userPortion = sub.isShared
          ? (sub.price / (sub.personCount > 0 ? sub.personCount : 1))
          : sub.price;

      yillikYuk += sub.isTrial ? (userPortion * 11) : (userPortion * 12);

      if (sub.isTrial) {
        kumbara += userPortion;
      } else {
        toplam += userPortion;
      }

      kategoriGruplari[sub.category] =
          (kategoriGruplari[sub.category] ?? 0) + userPortion;
    }

    list.sort(
          (a, b) => _hesaplaKalanGun(a.billingDate).compareTo(
        _hesaplaKalanGun(b.billingDate),
      ),
    );

    if (!mounted) return;

    setState(() {
      _currentUserId = uid;
      _toplamHarcama = toplam;
      _aylikKazanc = kumbara;
      _yillikProjeksiyon = yillikYuk;
      _abonelikListesi = list;
      _kategoriHarcamalari = kategoriGruplari;
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'SubPulse',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: textColor,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
            icon: Icon(
              Icons.notifications_none,
              color: textColor,
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeContent(),
          const AnalyticsScreen(),
          const SharedScreen(),
          SettingsScreen(activeSubs: _abonelikListesi.length),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
        backgroundColor: primaryColor,
        child: Icon(
          Icons.add,
          color: theme.brightness == Brightness.dark
              ? Colors.black
              : Colors.white,
          size: 30,
        ),
        onPressed: () async {
          bool? refresh = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddSubscriptionScreen(),
            ),
          );

          if (refresh == true) {
            await _verileriYukle();
          }
        },
      )
          : null,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHomeContent() {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final primaryColor = theme.colorScheme.primary;

    if (_currentUserId == null) {
      return const Center(
        child: Text(
          "Oturum bulunamadı. Lütfen tekrar giriş yapın.",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Akıllı Finans ve Abonelik Yönetimi',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 25),
          _buildMainWaveChart(),
          const SizedBox(height: 20),
          _buildEfficiencyAlert(),
          const SizedBox(height: 25),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'TOPLAM AYLIK HARCAMA:',
                  '${_toplamHarcama.toStringAsFixed(2)} TL',
                  textColor,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildSummaryCard(
                  'AYLIK KAZANÇ:',
                  '${_aylikKazanc.toStringAsFixed(2)} TL',
                  primaryColor,
                  isSavings: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _buildYearlyProjectionCard(),
          const SizedBox(height: 25),
          _buildCategorySection(),
          const SizedBox(height: 30),
          _buildSubscriptionList(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildYearlyProjectionCard() {
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surface;
    final primaryColor = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "12 AYLIK TAHMİNİ MALİYET:",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "${_yillikProjeksiyon.toStringAsFixed(2)} TL",
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Icon(
            Icons.timeline,
            color: primaryColor.withValues(alpha: 0.3),
            size: 35,
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionList() {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Abonelikler',
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        _abonelikListesi.isEmpty
            ? const Center(
          child: Text(
            "Bu kullanıcı için abonelik bulunamadı.",
            style: TextStyle(color: Colors.grey),
          ),
        )
            : ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _abonelikListesi.length,
          itemBuilder: (context, index) {
            final sub = _abonelikListesi[index];

            return Dismissible(
              key: Key("${sub.id}_${sub.userId}"),
              direction: DismissDirection.horizontal,
              background: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 20),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.edit,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              secondaryBackground: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.delete_sweep,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  bool? refresh = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AddSubscriptionScreen(subscription: sub),
                    ),
                  );

                  if (refresh == true) {
                    await _verileriYukle();
                  }

                  return false;
                } else {
                  return true;
                }
              },
              onDismissed: (direction) async {
                final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;

                if (sub.id != null && uid != null) {
                  await DbHelper.instance.deleteSubscriptionByUser(
                    sub.id!,
                    uid,
                  );
                  await NotificationService.instance.rescheduleAll();
                  await _verileriYukle();
                }
              },
              child: _buildSubscriptionItem(sub),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSubscriptionItem(Subscription sub) {
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surface;
    final primaryColor = theme.colorScheme.primary;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    double userPortion = sub.isShared
        ? (sub.price / (sub.personCount > 0 ? sub.personCount : 1))
        : sub.price;

    int kalan = _hesaplaKalanGun(sub.billingDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
        border: sub.isTrial
            ? Border.all(
          color: Colors.orangeAccent.withValues(alpha: 0.35),
          width: 1.2,
        )
            : null,
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: sub.isTrial
                ? Colors.orangeAccent.withValues(alpha: 0.12)
                : primaryColor.withValues(alpha: 0.1),
            child: Icon(
              sub.isTrial
                  ? Icons.hourglass_top_rounded
                  : Icons.subscriptions,
              color: sub.isTrial ? Colors.orangeAccent : primaryColor,
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sub.name,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),

                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      sub.category,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                    ),

                    Text(
                      '$kalan gün kaldı',
                      style: TextStyle(
                        color: kalan <= 3
                            ? Colors.redAccent
                            : Colors.blueAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    if (sub.isTrial)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.orangeAccent.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Text(
                          "Ücretsiz Deneme",
                          style: TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                    if (sub.isShared)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "Ortak ${sub.personCount} Kişi",
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                sub.isTrial
                    ? 'Ücretsiz'
                    : '-${userPortion.toStringAsFixed(2)} TL',
                style: TextStyle(
                  color: sub.isTrial ? Colors.orangeAccent : textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              if (sub.isTrial)
                const Text(
                  "Deneme",
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else if (sub.isShared)
                Text(
                  "Kişi başı",
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainWaveChart() {
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surface;
    final primaryColor = theme.colorScheme.primary;

    final simdi = DateTime.now();

    final sonAylarTarihleri = List.generate(
      6,
          (i) => DateTime(simdi.year, simdi.month - 5 + i, 1),
    );

    final ayIsimleri = [
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];

    List<BarChartGroupData> barGroups = [];

    for (int i = 0; i < sonAylarTarihleri.length; i++) {
      final oAyTarihi = sonAylarTarihleri[i];
      double oAykiToplamHarcama = 0;

      for (var sub in _abonelikListesi) {
        if (sub.isTrial) continue;

        double portion = sub.isShared
            ? (sub.price / (sub.personCount > 0 ? sub.personCount : 1))
            : sub.price;

        bool faturaKesildiMi =
            oAyTarihi.isAfter(sub.billingDate) ||
                oAyTarihi.isAtSameMomentAs(
                  DateTime(sub.billingDate.year, sub.billingDate.month, 1),
                );

        if (faturaKesildiMi) {
          oAykiToplamHarcama += portion;
        }
      }

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: oAykiToplamHarcama,
              color: primaryColor,
              width: 14,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 180,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(25),
      ),
      child: BarChart(
        BarChartData(
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  final index = val.toInt();

                  if (index < 0 || index >= sonAylarTarihleri.length) {
                    return const SizedBox();
                  }

                  return Text(
                    ayIsimleri[sonAylarTarihleri[index].month - 1],
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 9,
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: barGroups,
        ),
      ),
    );
  }

  Widget _buildEfficiencyAlert() {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    final yaklasan = _abonelikListesi
        .where((s) => s.isTrial && _hesaplaKalanGun(s.billingDate) <= 3)
        .toList();

    if (yaklasan.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.orangeAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orangeAccent,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              '${yaklasan.first.name} deneme süresi bitiyor!',
              style: TextStyle(color: textColor, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection() {
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surface;
    final primaryColor = theme.colorScheme.primary;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Harcama Dağılımı',
                style: TextStyle(
                  fontSize: 16,
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_kategoriHarcamalari.isNotEmpty)
                Icon(
                  Icons.pie_chart_outline,
                  size: 18,
                  color: primaryColor,
                ),
            ],
          ),
          const SizedBox(height: 20),
          _kategoriHarcamalari.isEmpty
              ? const Text(
            "Veri bekleniyor...",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          )
              : Row(
            children: [
              SizedBox(
                height: 100,
                width: 100,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 25,
                    sections: _kategoriHarcamalari.entries.map((e) {
                      return PieChartSectionData(
                        color: _getCategoryColor(e.key),
                        value: e.value,
                        title: '',
                        radius: 15,
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: _kategoriHarcamalari.entries.map((e) {
                    return _buildCategoryItem(
                      '${e.key}: ${e.value.toStringAsFixed(0)} TL',
                      _getCategoryColor(e.key),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          CircleAvatar(radius: 4, backgroundColor: color),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      String title,
      String value,
      Color valueColor, {
        bool isSavings = false,
      }) {
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surface;
    final primaryColor = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (isSavings)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'SAVED',
                style: TextStyle(
                  color: primaryColor.withValues(alpha: 0.7),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final theme = Theme.of(context);
    final bottomNavBg = theme.colorScheme.surface;
    final primaryColor = theme.colorScheme.primary;
    final unselectedColor =
    theme.brightness == Brightness.dark ? Colors.white54 : Colors.black54;

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: bottomNavBg,
      selectedItemColor: primaryColor,
      unselectedItemColor: unselectedColor,
      currentIndex: _selectedIndex,
      onTap: (index) async {
        setState(() => _selectedIndex = index);

        if (index == 0 || index == 3) {
          await _verileriYukle();
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_filled),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.analytics_outlined),
          label: 'Analytics',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.group_outlined),
          label: 'Shared',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          label: 'Settings',
        ),
      ],
    );
  }

  int _hesaplaKalanGun(DateTime billingDate) {
    final simdi = DateTime.now();
    DateTime buAy = DateTime(simdi.year, simdi.month, billingDate.day);

    if (buAy.isBefore(simdi)) {
      buAy = DateTime(simdi.year, simdi.month + 1, billingDate.day);
    }

    return buAy.difference(simdi).inDays;
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Eğlence':
        return const Color(0xFF8CFF32);
      case 'Yazılım':
        return Colors.blueAccent;
      case 'Eğitim':
        return Colors.purpleAccent;
      case 'Spor':
        return Colors.orangeAccent;
      default:
        return Colors.blueGrey;
    }
  }
}