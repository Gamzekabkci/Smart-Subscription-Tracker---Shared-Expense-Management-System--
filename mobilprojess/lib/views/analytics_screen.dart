import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../services/usage_service.dart';
import '../services/db_helper.dart';
import '../models/subscription_model.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final Color _neonGreen = const Color(0xFF8CFF32);
  final Color _aiPurple = const Color(0xFF6C63FF);

  bool _isLoading = true;

  List<Map<String, dynamic>> _usageList = [];
  List<AIInsight> _aiInsights = [];

  AIInsight? _dailyInsight;
  int _healthScore = 100;

  final Map<String, String> _packageMap = {
    // Müzik
    'Spotify': 'com.spotify.music',
    'YouTube Music': 'com.google.android.apps.youtube.music',
    'Apple Music': 'com.apple.android.music',
    'Deezer': 'deezer.android.app',
    'SoundCloud': 'com.soundcloud.android',
    'TIDAL': 'com.aspiro.tidal',

    // Video / Dizi / Film
    'Netflix': 'com.netflix.mediaclient',
    'YouTube': 'com.google.android.youtube',
    'Youtube': 'com.google.android.youtube',
    'YouTube Premium': 'com.google.android.youtube',
    'Youtube Premium': 'com.google.android.youtube',
    'Disney+': 'com.disney.disneyplus',
    'Prime Video': 'com.amazon.avod.thirdpartyclient',
    'Amazon Prime Video': 'com.amazon.avod.thirdpartyclient',
    'BluTV': 'com.dsmart.blu.android',
    'Exxen': 'com.exxen.android',
    'Gain': 'com.gainapp',
    'MUBI': 'com.mubi',
    'Twitch': 'tv.twitch.android.app',

    // Eğitim
    'Duolingo': 'com.duolingo',
    'Udemy': 'com.udemy.android',
    'Coursera': 'org.coursera.android',
    'Khan Academy': 'org.khanacademy.android',
    'LinkedIn Learning': 'com.linkedin.android.learning',

    // Üretkenlik / Not / İş
    'Notion': 'notion.id',
    'Evernote': 'com.evernote',
    'Todoist': 'com.todoist',
    'Trello': 'com.trello',
    'Slack': 'com.Slack',
    'Microsoft Teams': 'com.microsoft.teams',
    'Zoom': 'us.zoom.videomeetings',
    'Google Drive': 'com.google.android.apps.docs',
    'Dropbox': 'com.dropbox.android',
    'OneDrive': 'com.microsoft.skydrive',

    // Tasarım / İçerik
    'Canva': 'com.canva.editor',
    'CapCut': 'com.lemon.lvoverseas',
    'Picsart': 'com.picsart.studio',
    'Lightroom': 'com.adobe.lrmobile',
    'Adobe Lightroom': 'com.adobe.lrmobile',

    // AI / Chatbot
    'ChatGPT': 'com.openai.chatgpt',
    'Gemini': 'com.google.android.apps.bard',
    'Microsoft Copilot': 'com.microsoft.copilot',
    'Perplexity': 'ai.perplexity.app.android',

    // Spor / Sağlık
    'Strava': 'com.strava',
    'Nike Training Club': 'com.nike.ntc',
    'Nike Run Club': 'com.nike.plusgps',
    'Fitbit': 'com.fitbit.FitbitMobile',
    'MyFitnessPal': 'com.myfitnesspal.android',

    // Oyun / Oyun servisleri
    'Xbox Game Pass': 'com.gamepass',
    'PlayStation App': 'com.scee.psxandroid',
    'GeForce NOW': 'com.nvidia.geforcenow',
    'Steam': 'com.valvesoftware.android.steam.community',

    // Finans / Premium servisler
    'Papara': 'com.mobillium.papara',
    'Binance': 'com.binance.dev',
    'TradingView': 'com.tradingview.tradingviewapp',
  };

  final Map<String, String> _websiteMap = {
    'ChatGPT Web': 'chat.openai.com',
    'Canva Web': 'canva.com',
    'Notion Web': 'notion.so',
    'Figma': 'figma.com',
    'GitHub Copilot': 'github.com',
    'iCloud': 'icloud.com',
    'Google One': 'one.google.com',
    'Adobe Creative Cloud': 'adobe.com',
    'Grammarly': 'grammarly.com',
  };

  @override
  void initState() {
    super.initState();
    _fetchUsageData();
  }

  String _normalizeSubscriptionName(String name) {
    final n = name.trim().toLowerCase();

    if (n.contains('youtube')) {
      return 'YouTube';
    }

    if (n.contains('spotify')) {
      return 'Spotify';
    }

    if (n.contains('netflix')) {
      return 'Netflix';
    }

    if (n.contains('prime')) {
      return 'Prime Video';
    }

    if (n.contains('disney')) {
      return 'Disney+';
    }

    return name.trim();
  }

  String? _findPackageName(String subscriptionName) {
    final normalizedInput = subscriptionName.trim().toLowerCase();

    for (final entry in _packageMap.entries) {
      final normalizedKey = entry.key.trim().toLowerCase();

      if (normalizedInput == normalizedKey ||
          normalizedInput.contains(normalizedKey) ||
          normalizedKey.contains(normalizedInput)) {
        return entry.value;
      }
    }

    return null;
  }

  bool _isWebsiteOnlySubscription(String subscriptionName) {
    final normalizedInput = subscriptionName.trim().toLowerCase();

    for (final entry in _websiteMap.entries) {
      final normalizedKey = entry.key.trim().toLowerCase();

      if (normalizedInput == normalizedKey ||
          normalizedInput.contains(normalizedKey) ||
          normalizedKey.contains(normalizedInput)) {
        return true;
      }
    }

    return false;
  }

  Future<double> _getGroupedUsageMinutes(String groupedName) async {
    if (groupedName == 'YouTube') {
      final youtubeUsage = await UsageService.getAppUsage(
        'com.google.android.youtube',
      );

      final youtubeMusicUsage = await UsageService.getAppUsage(
        'com.google.android.apps.youtube.music',
      );

      return youtubeUsage + youtubeMusicUsage;
    }

    final pkg = _findPackageName(groupedName);

    if (pkg == null) {
      return 0;
    }

    return await UsageService.getAppUsage(pkg);
  }

  double _effectivePrice(Subscription sub) {
    if (sub.isShared && sub.personCount > 0) {
      return sub.price / sub.personCount;
    }

    return sub.price;
  }

  int _remainingDays(DateTime billingDate) {
    final now = DateTime.now();
    DateTime thisMonth = DateTime(now.year, now.month, billingDate.day);

    if (thisMonth.isBefore(now)) {
      thisMonth = DateTime(now.year, now.month + 1, billingDate.day);
    }

    return thisMonth.difference(now).inDays;
  }

  Future<void> _fetchUsageData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        if (!mounted) return;

        setState(() {
          _usageList = [];
          _aiInsights = [];
          _dailyInsight = null;
          _healthScore = 100;
          _isLoading = false;
        });

        return;
      }

      final subs = await DbHelper.instance.getSubscriptionsByUser(
        currentUser.uid,
      );

      final Map<String, Map<String, dynamic>> groupedUsage = {};
      final Map<String, double> usageCache = {};

      for (var sub in subs) {
        final String groupedName = _normalizeSubscriptionName(sub.name);

        double usageInMinutes = 0;

        if (usageCache.containsKey(groupedName)) {
          usageInMinutes = usageCache[groupedName]!;
        } else {
          usageInMinutes = await _getGroupedUsageMinutes(groupedName);
          usageCache[groupedName] = usageInMinutes;
        }

        final double effectivePrice = _effectivePrice(sub);
        final bool isWebsiteOnly = _isWebsiteOnlySubscription(sub.name);

        if (!groupedUsage.containsKey(groupedName)) {
          groupedUsage[groupedName] = {
            'name': groupedName,
            'price': 0.0,
            'originalPrice': 0.0,
            'category': sub.category,
            'usage': usageInMinutes,
            'costPerMinute': 0.0,
            'isTrial': sub.isTrial,
            'isShared': sub.isShared,
            'billingDate': sub.billingDate,
            'isWebsiteOnly': isWebsiteOnly,
          };
        }

        groupedUsage[groupedName]!['price'] =
            (groupedUsage[groupedName]!['price'] as double) + effectivePrice;

        groupedUsage[groupedName]!['originalPrice'] =
            (groupedUsage[groupedName]!['originalPrice'] as double) + sub.price;

        groupedUsage[groupedName]!['isTrial'] =
            (groupedUsage[groupedName]!['isTrial'] as bool) && sub.isTrial;

        groupedUsage[groupedName]!['isShared'] =
            (groupedUsage[groupedName]!['isShared'] as bool) || sub.isShared;

        groupedUsage[groupedName]!['isWebsiteOnly'] =
            (groupedUsage[groupedName]!['isWebsiteOnly'] as bool) || isWebsiteOnly;
      }

      final List<Map<String, dynamic>> tempUsage =
      groupedUsage.values.map((item) {
        final price = item['price'] as double;
        final usage = item['usage'] as double;

        item['costPerMinute'] = price / (usage + 0.1);

        return item;
      }).toList();

      tempUsage.sort((a, b) {
        final bUsage = b['usage'] as double;
        final aUsage = a['usage'] as double;
        return bUsage.compareTo(aUsage);
      });

      final score = _calculateHealthScore(subs, tempUsage);
      final insights = _generateAIInsights(subs, tempUsage, score);
      final daily = _pickDailyInsight(insights);

      if (!mounted) return;

      setState(() {
        _usageList = tempUsage;
        _aiInsights = insights;
        _dailyInsight = daily;
        _healthScore = score;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _usageList = [];
        _aiInsights = [];
        _dailyInsight = null;
        _healthScore = 100;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Analytics verileri yüklenirken hata oluştu: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<AIInsight> _generateAIInsights(
      List<Subscription> subs,
      List<Map<String, dynamic>> usageList,
      int healthScore,
      ) {
    final List<AIInsight> insights = [];

    if (subs.isEmpty) {
      insights.add(
        AIInsight(
          title: "Henüz analiz için veri yok",
          description:
          "Abonelik ekledikçe SubPulse AI sana kişisel tasarruf önerileri sunacak.",
          type: AIInsightType.general,
          priority: 1,
          icon: Icons.auto_awesome_rounded,
        ),
      );

      return insights;
    }

    final unusedApps = usageList.where((item) {
      final usage = item['usage'] as double;
      final price = item['price'] as double;
      final isTrial = item['isTrial'] as bool;
      final isWebsiteOnly = item['isWebsiteOnly'] as bool? ?? false;

      return usage <= 30 && price > 0 && !isTrial && !isWebsiteOnly;
    }).toList();

    if (unusedApps.isNotEmpty) {
      unusedApps.sort((a, b) {
        final bPrice = b['price'] as double;
        final aPrice = a['price'] as double;
        return bPrice.compareTo(aPrice);
      });

      final app = unusedApps.first;
      final name = app['name'];
      final usage = app['usage'] as double;
      final price = app['price'] as double;
      final yearlySaving = price * 12;

      insights.add(
        AIInsight(
          title: "Kullanılmayan abonelik tespit edildi",
          description:
          "$name aboneliğini bu ay sadece ${usage.toStringAsFixed(0)} dakika kullanmışsın. Aylık maliyeti kullanımına göre yüksek görünüyor. İptal edersen yılda yaklaşık ${yearlySaving.toStringAsFixed(0)} TL tasarruf edebilirsin.",
          type: AIInsightType.unused,
          priority: 10,
          icon: Icons.timer_off_rounded,
        ),
      );
    }

    final websiteOnlyApps = usageList.where((item) {
      return item['isWebsiteOnly'] as bool? ?? false;
    }).toList();

    if (websiteOnlyApps.isNotEmpty) {
      final app = websiteOnlyApps.first;

      insights.add(
        AIInsight(
          title: "Web aboneliği manuel kontrol edilmeli",
          description:
          "${app['name']} daha çok web üzerinden kullanılıyor olabilir. Android kullanım verisi sadece mobil uygulamaları ölçer, bu nedenle bu aboneliğin kullanımını manuel kontrol etmen daha doğru olur.",
          type: AIInsightType.general,
          priority: 6,
          icon: Icons.language_rounded,
        ),
      );
    }

    final Map<String, List<Subscription>> categoryGroups = {};

    for (final sub in subs) {
      categoryGroups.putIfAbsent(sub.category, () => []);
      categoryGroups[sub.category]!.add(sub);
    }

    final crowdedCategories = categoryGroups.entries
        .where((entry) => entry.value.length >= 2)
        .toList();

    if (crowdedCategories.isNotEmpty) {
      crowdedCategories.sort((a, b) {
        final bTotal = b.value.fold<double>(
          0,
              (sum, sub) => sum + _effectivePrice(sub),
        );

        final aTotal = a.value.fold<double>(
          0,
              (sum, sub) => sum + _effectivePrice(sub),
        );

        return bTotal.compareTo(aTotal);
      });

      final category = crowdedCategories.first.key;
      final categorySubs = crowdedCategories.first.value;
      final total = categorySubs.fold<double>(
        0,
            (sum, sub) => sum + _effectivePrice(sub),
      );

      insights.add(
        AIInsight(
          title: "Benzer abonelikler fazla olabilir",
          description:
          "$category kategorisinde ${categorySubs.length} aboneliğin var. Bu kategoriye ayda yaklaşık ${total.toStringAsFixed(0)} TL harcıyorsun. En az kullandığın aboneliği iptal ederek bütçeni azaltabilirsin.",
          type: AIInsightType.comparison,
          priority: 8,
          icon: Icons.compare_arrows_rounded,
        ),
      );
    }

    final endingTrials = subs.where((sub) {
      return sub.isTrial && _remainingDays(sub.billingDate) <= 3;
    }).toList();

    if (endingTrials.isNotEmpty) {
      endingTrials.sort(
            (a, b) => _remainingDays(a.billingDate).compareTo(
          _remainingDays(b.billingDate),
        ),
      );

      final sub = endingTrials.first;
      final days = _remainingDays(sub.billingDate);

      insights.add(
        AIInsight(
          title: "Deneme süresi bitmek üzere",
          description:
          "${sub.name} deneme süren $days gün içinde bitiyor. Kullanımın düşükse ücretli döneme geçmeden iptal etmeyi düşünebilirsin.",
          type: AIInsightType.trial,
          priority: 9,
          icon: Icons.warning_amber_rounded,
        ),
      );
    }

    final shareableSubs = subs.where((sub) {
      return !sub.isShared && sub.price >= 100;
    }).toList();

    if (shareableSubs.isNotEmpty) {
      shareableSubs.sort((a, b) => b.price.compareTo(a.price));

      final sub = shareableSubs.first;
      final fourPersonPrice = sub.price / 4;
      final saving = sub.price - fourPersonPrice;

      insights.add(
        AIInsight(
          title: "Ortak abonelik önerisi",
          description:
          "${sub.name} aboneliğini 4 kişiyle paylaşırsan kişi başı maliyetin ${sub.price.toStringAsFixed(0)} TL yerine ${fourPersonPrice.toStringAsFixed(0)} TL olur. Aylık yaklaşık ${saving.toStringAsFixed(0)} TL avantaj sağlayabilirsin.",
          type: AIInsightType.shared,
          priority: 7,
          icon: Icons.group_add_rounded,
        ),
      );
    }

    if (unusedApps.isNotEmpty) {
      final yearlySaving = unusedApps.fold<double>(
        0,
            (sum, app) => sum + ((app['price'] as double) * 12),
      );

      insights.add(
        AIInsight(
          title: "Yıllık tasarruf tahmini",
          description:
          "Düşük kullandığın ${unusedApps.length} aboneliği gözden geçirirsen yılda yaklaşık ${yearlySaving.toStringAsFixed(0)} TL tasarruf edebilirsin.",
          type: AIInsightType.yearlySaving,
          priority: 6,
          icon: Icons.savings_rounded,
        ),
      );
    }

    final totalMonthly = subs.fold<double>(
      0,
          (sum, sub) => sum + _effectivePrice(sub),
    );

    if (totalMonthly > 0) {
      final Map<String, double> categoryTotals = {};

      for (final sub in subs) {
        categoryTotals[sub.category] =
            (categoryTotals[sub.category] ?? 0) + _effectivePrice(sub);
      }

      final sortedCategories = categoryTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final topCategory = sortedCategories.first;
      final percentage = (topCategory.value / totalMonthly) * 100;

      insights.add(
        AIInsight(
          title: "Kategori bazlı bütçe tavsiyesi",
          description:
          "Bu ay en çok harcama yaptığın kategori ${topCategory.key}. Toplam abonelik giderinin yaklaşık %${percentage.toStringAsFixed(0)} kısmı bu kategoriden geliyor.",
          type: AIInsightType.categoryBudget,
          priority: 5,
          icon: Icons.pie_chart_rounded,
        ),
      );
    }

    AIInsight actionInsight;

    if (unusedApps.isNotEmpty) {
      final app = unusedApps.first;

      actionInsight = AIInsight(
        title: "Bugünün aksiyonu",
        description:
        "Bugün ${app['name']} aboneliğini gözden geçir. Son kullanımına göre maliyeti yüksek görünüyor.",
        type: AIInsightType.action,
        priority: 11,
        icon: Icons.task_alt_rounded,
      );
    } else if (endingTrials.isNotEmpty) {
      final sub = endingTrials.first;

      actionInsight = AIInsight(
        title: "Bugünün aksiyonu",
        description:
        "Bugün ${sub.name} deneme süresini kontrol et. Ücretli döneme geçmeden karar vermen iyi olabilir.",
        type: AIInsightType.action,
        priority: 11,
        icon: Icons.task_alt_rounded,
      );
    } else {
      actionInsight = AIInsight(
        title: "Bugünün aksiyonu",
        description:
        "Bugün aboneliklerini kontrol et. Düzenli takip sayesinde gereksiz harcamaları erken fark edebilirsin.",
        type: AIInsightType.action,
        priority: 4,
        icon: Icons.task_alt_rounded,
      );
    }

    insights.add(actionInsight);

    insights.add(
      AIInsight(
        title: "Abonelik sağlık skoru",
        description:
        "Abonelik sağlık skorun $healthScore/100. Skor, kullanım, deneme süreleri, kategori yoğunluğu ve tasarruf potansiyeline göre hesaplanır.",
        type: AIInsightType.healthScore,
        priority: 3,
        icon: Icons.health_and_safety_rounded,
      ),
    );

    insights.sort((a, b) => b.priority.compareTo(a.priority));

    return insights;
  }

  int _calculateHealthScore(
      List<Subscription> subs,
      List<Map<String, dynamic>> usageList,
      ) {
    if (subs.isEmpty) return 100;

    int score = 100;

    final unusedCount = usageList.where((item) {
      final usage = item['usage'] as double;
      final price = item['price'] as double;
      final isTrial = item['isTrial'] as bool;
      final isWebsiteOnly = item['isWebsiteOnly'] as bool? ?? false;

      return usage <= 30 && price > 0 && !isTrial && !isWebsiteOnly;
    }).length;

    score -= unusedCount * 15;

    final endingTrialCount = subs.where((sub) {
      return sub.isTrial && _remainingDays(sub.billingDate) <= 3;
    }).length;

    score -= endingTrialCount * 10;

    final totalMonthly = subs.fold<double>(
      0,
          (sum, sub) => sum + _effectivePrice(sub),
    );

    if (totalMonthly > 0) {
      final Map<String, double> categoryTotals = {};

      for (final sub in subs) {
        categoryTotals[sub.category] =
            (categoryTotals[sub.category] ?? 0) + _effectivePrice(sub);
      }

      final topCategory = categoryTotals.values.reduce(
            (a, b) => a > b ? a : b,
      );

      final percentage = (topCategory / totalMonthly) * 100;

      if (percentage > 70) {
        score -= 10;
      }
    }

    final sharedCount = subs.where((sub) => sub.isShared).length;

    if (sharedCount > 0) {
      score += 5;
    }

    if (score < 0) return 0;
    if (score > 100) return 100;

    return score;
  }

  AIInsight _pickDailyInsight(List<AIInsight> insights) {
    if (insights.isEmpty) {
      return AIInsight(
        title: "Günün önerisi",
        description:
        "Aboneliklerini ekledikçe SubPulse AI her gün sana farklı bir kişisel öneri sunacak.",
        type: AIInsightType.general,
        priority: 1,
        icon: Icons.auto_awesome_rounded,
      );
    }

    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final index = dayOfYear % insights.length;

    return insights[index];
  }

  void _showAIDetails() {
    final theme = Theme.of(context);
    final bgColor = theme.scaffoldBackgroundColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final cardColor = theme.colorScheme.surface;

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 45,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _neonGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          Icons.psychology_rounded,
                          color: _neonGreen,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "SubPulse AI Analizi",
                              style: TextStyle(
                                color: textColor,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Tüm kişisel önerilerin burada.",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  _buildHealthScoreCard(cardColor, textColor),
                  const SizedBox(height: 20),
                  ..._aiInsights.map((insight) {
                    return _buildInsightDetailCard(insight);
                  }),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHealthScoreCard(Color cardColor, Color textColor) {
    Color scoreColor;

    if (_healthScore >= 80) {
      scoreColor = _neonGreen;
    } else if (_healthScore >= 55) {
      scoreColor = Colors.orangeAccent;
    } else {
      scoreColor = Colors.redAccent;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: scoreColor.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: _healthScore / 100,
                  strokeWidth: 7,
                  color: scoreColor,
                  backgroundColor: Colors.grey.withValues(alpha: 0.18),
                ),
              ),
              Text(
                "$_healthScore",
                style: TextStyle(
                  color: scoreColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Abonelik Sağlık Skoru",
                  style: TextStyle(
                    color: textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _healthScore >= 80
                      ? "Genel durumun iyi görünüyor."
                      : _healthScore >= 55
                      ? "Bazı abonelikleri gözden geçirmen iyi olabilir."
                      : "Tasarruf potansiyelin yüksek görünüyor.",
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightDetailCard(AIInsight insight) {
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surface;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final color = _colorForInsight(insight.type);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              insight.icon,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  insight.description,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForInsight(AIInsightType type) {
    switch (type) {
      case AIInsightType.unused:
        return Colors.redAccent;
      case AIInsightType.comparison:
        return Colors.blueAccent;
      case AIInsightType.trial:
        return Colors.orangeAccent;
      case AIInsightType.shared:
        return _neonGreen;
      case AIInsightType.yearlySaving:
        return Colors.amber;
      case AIInsightType.categoryBudget:
        return Colors.purpleAccent;
      case AIInsightType.action:
        return Colors.cyanAccent;
      case AIInsightType.healthScore:
        return _neonGreen;
      case AIInsightType.general:
        return _aiPurple;
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
        child: CircularProgressIndicator(color: _neonGreen),
      )
          : RefreshIndicator(
        onRefresh: _fetchUsageData,
        color: _neonGreen,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildAIHeader(),
              const SizedBox(height: 20),
              _buildAIInsightCard(),
              const SizedBox(height: 35),
              Text(
                "Uygulama Verimlilik Listesi",
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              if (_usageList.isEmpty)
                _buildEmptyAnalyticsState()
              else
                ..._usageList.map((data) => _buildUsageCard(data)),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAIHeader() {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _neonGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.psychology_rounded,
            color: _neonGreen,
            size: 28,
          ),
        ),
        const SizedBox(width: 15),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "SubPulse AI",
              style: TextStyle(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              "Senin için akıllı tasarruf yolları.",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAIInsightCard() {
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surface;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    final insight = _dailyInsight ??
        AIInsight(
          title: "Günün önerisi",
          description:
          "Aboneliklerini ekledikçe SubPulse AI sana kişisel öneriler sunacak.",
          type: AIInsightType.general,
          priority: 1,
          icon: Icons.auto_awesome_rounded,
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cardColor,
            _aiPurple.withValues(alpha: 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: _aiPurple.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _aiPurple.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _aiPurple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "GÜNÜN ÖNERİSİ",
                  style: TextStyle(
                    color: textColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Icon(
                insight.icon,
                color: _neonGreen,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            insight.description,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _showAIDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: _neonGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 0,
              ),
              child: const Text(
                "Detayları Gör",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAnalyticsState() {
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surface;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: _neonGreen.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.analytics_outlined,
            color: _neonGreen,
            size: 48,
          ),
          const SizedBox(height: 15),
          Text(
            "Henüz analiz verisi yok",
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Bu kullanıcı için abonelik eklediğinde verimlilik analizi burada görünecek.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageCard(Map<String, dynamic> data) {
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surface;
    final bgColor = theme.scaffoldBackgroundColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    final double usage = data['usage'] as double;
    final bool isTrial = data['isTrial'] as bool;
    final double costPerMinute = data['costPerMinute'] as double;
    final bool isWebsiteOnly = data['isWebsiteOnly'] as bool? ?? false;

    String usageText;

    if (isWebsiteOnly) {
      usageText = "Web kullanımı manuel kontrol edilmeli";
    } else {
      usageText = usage >= 60
          ? "${(usage / 60).toStringAsFixed(1)} saat"
          : "${usage.toStringAsFixed(0)} dk";
    }

    final bool isEfficient = costPerMinute < 0.5 || isTrial;
    final bool hasPackage = _findPackageName(data['name'].toString()) != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              isWebsiteOnly
                  ? Icons.language_rounded
                  : !hasPackage
                  ? Icons.help_outline_rounded
                  : usage > 0
                  ? Icons.bolt_rounded
                  : Icons.timer_off_outlined,
              color: isWebsiteOnly
                  ? Colors.blueAccent
                  : !hasPackage
                  ? Colors.grey
                  : isEfficient
                  ? _neonGreen
                  : Colors.redAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['name'].toString(),
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Kullanım: $usageText",
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isTrial ? "DENEME" : "${(data['price'] as double).toStringAsFixed(0)} TL",
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isWebsiteOnly
                    ? "Web"
                    : isEfficient
                    ? "Yüksek Verim"
                    : "Düşük Verim",
                style: TextStyle(
                  color: isWebsiteOnly
                      ? Colors.blueAccent
                      : isEfficient
                      ? _neonGreen
                      : Colors.orangeAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum AIInsightType {
  unused,
  comparison,
  trial,
  shared,
  yearlySaving,
  categoryBudget,
  action,
  healthScore,
  general,
}

class AIInsight {
  final String title;
  final String description;
  final AIInsightType type;
  final int priority;
  final IconData icon;

  AIInsight({
    required this.title,
    required this.description,
    required this.type,
    required this.priority,
    required this.icon,
  });
}