import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'usage_stats_plugin.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';
import 'package:device_apps/device_apps.dart';
import 'utils/app_filter.dart';
import 'models/child_profile.dart';
import 'providers/profile_provider.dart';
import 'widgets/top_apps_tracker.dart';
import 'services/app_usage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/app_usage_entry.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ProfileProvider(),
      child: const MyApp(),
    ),
  );
}

// Kayıt sınıfı
class RecordEntry {
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;

  RecordEntry({
    required this.startTime,
    required this.endTime,
    required this.duration,
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KidScope',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
        reverseCurve: Curves.easeOut,
      ),
    );

    _controller.forward().then((_) {
      Timer(const Duration(milliseconds: 500), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProfileSelectionScreen()),
        );
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate the logo size based on screen size
              double logoSize = constraints.maxWidth * 0.5; // 50% of screen width
              // Cap the maximum size
              logoSize = logoSize.clamp(100.0, 300.0);
              
              return Padding(
                padding: const EdgeInsets.all(50.0),
                child: Image.asset(
                  'assets/images/new_logo.png',
                  width: logoSize,
                  height: logoSize,
                  fit: BoxFit.contain,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class ProfileSelectionScreen extends StatelessWidget {
  const ProfileSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample profile list with IDs
    final List<ChildProfile> profiles = [
      const ChildProfile(id: '1', name: 'Ahmet', avatarEmoji: '👦'),
      const ChildProfile(id: '2', name: 'Ayşe', avatarEmoji: '👧'),
      const ChildProfile(id: '3', name: 'Mehmet', avatarEmoji: '👦'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('KidScope'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: Colors.grey[100],
      body: Center(
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          mainAxisSpacing: 24,
          crossAxisSpacing: 24,
          children: [
            ...profiles.map((profile) => _buildProfileCard(context, profile)),
            _buildAddProfileCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, ChildProfile profile) {
    return GestureDetector(
      onTap: () {
        // Set selected profile and navigate
        context.read<ProfileProvider>().setSelectedProfile(profile);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blue, width: 4),
            ),
            child: Center(
              child: Text(
                profile.avatarEmoji ?? '👤',
                style: const TextStyle(fontSize: 50),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddProfileCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Yeni profil ekleme işlemi
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Yeni Profil'),
            content: const Text('Yeni profil ekleme özelliği yakında!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tamam'),
              ),
            ],
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey, width: 4),
            ),
            child: const Icon(
              Icons.add,
              size: 50,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Profil Ekle',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _isRecording = false;
  bool _hasPermission = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _timer;
  DateTime? _recordStartTime;
  List<AppUsageEntry> _usageHistory = [];
  StreamSubscription<List<AppUsageInfo>>? _usageSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionStatus();
  }

  Future<void> _checkPermissionStatus() async {
    final hasPermission = await UsageStatsPlugin.checkPermission();
    setState(() {
      _hasPermission = hasPermission;
    });
  }

  Future<void> _requestUsagePermission() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('İzin isteği gönderiliyor...'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.blue,
        ),
      );
    }

    final permissionResult = await UsageStatsPlugin.requestPermission();
    
    if (!mounted) return;

    if (permissionResult) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('İzin ekranı açıldı, lütfen izin verin'),
          duration: Duration(seconds: 4),
          backgroundColor: Colors.green,
        ),
      );
      await Future.delayed(const Duration(seconds: 1));
      await _checkPermissionStatus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('İzin ekranı açılamadı, lütfen ayarlardan manuel olarak izin verin'),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _startRecording() async {
    if (!_hasPermission) {
      await _requestUsagePermission();
      if (!_hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('İzin alınamadı, lütfen ayarlardan izinleri kontrol edin'),
              duration: Duration(seconds: 3),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    try {
      final usageStream = await UsageStatsPlugin.startTracking();
      
      if (usageStream != null) {
        // Yeni kayıt başlatıldığında tüm geçmişi temizle
        setState(() {
          _recordingDuration = Duration.zero;
          _isRecording = true;
          _recordStartTime = DateTime.now();
          _usageHistory = []; // Geçmişi temizle
        });

        // Süre sayacını başlat
        _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
          if (mounted) {
            setState(() {
              _recordingDuration += const Duration(seconds: 2);
            });
          }
        });

        // Kullanım verilerini dinle
        _usageSubscription?.cancel();
        _usageSubscription = usageStream
          .throttleTime(const Duration(seconds: 3))
          .listen(
          (stats) async {
            if (mounted) {
              // Sadece bu kayıt periyodunda kullanılan uygulamaları filtrele
              final userApps = stats.where((app) => 
                AppFilter.isUserApp(app.packageName) &&
                (app.duration ?? Duration.zero) > Duration.zero &&
                app.startTime.isAfter(_recordStartTime!)
              );
              
              // AppUsageEntry listesine dönüştür
              final entries = await Future.wait(
                userApps.map((app) async {
                  final appInfo = await DeviceApps.getApp(app.packageName, true);
                  return AppUsageEntry(
                    packageName: app.packageName,
                    appName: appInfo?.appName ?? app.appName,
                    startTime: app.startTime,
                    endTime: app.endTime,
                    duration: app.duration ?? Duration.zero,
                    appInfo: appInfo,
                    isRunning: app.isRunning,
                  );
                })
              );
              
              if (mounted) {
                setState(() {
                  // Yeni gelen verileri mevcut verilerle birleştir
                  final Map<String, AppUsageEntry> usageMap = {};
                  
                  // Önce mevcut verileri ekle
                  for (var entry in _usageHistory) {
                    usageMap[entry.packageName] = entry;
                  }
                  
                  // Yeni verileri ekle/güncelle
                  for (var entry in entries) {
                    usageMap[entry.packageName] = entry;
                  }
                  
                  // Map'i listeye çevir ve süreye göre sırala
                  _usageHistory = usageMap.values.toList()
                    ..sort((a, b) => b.duration.compareTo(a.duration));
                });
              }
            }
          },
          onError: (error) {
            print('Usage stats stream error: $error');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Kullanım verileri alınırken hata oluştu'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kayıt başladı'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kayıt başlatılamadı, lütfen tekrar deneyin'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error starting recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kayıt başlatılırken bir hata oluştu'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      _timer?.cancel();
      _usageSubscription?.cancel();
      
      print('Kayıt durduruluyor...');
      final finalStats = await UsageStatsPlugin.stopTracking();
      
      if (mounted) {
        // Önce kayıt durumunu güncelle
        setState(() {
          _isRecording = false;
          _recordingDuration = Duration.zero;
        });

        // Son kullanım verilerini güncelle
        if (finalStats.isNotEmpty && _recordStartTime != null) {
          final lastApps = finalStats.where((app) => 
            AppFilter.isUserApp(app.packageName) &&
            (app.duration ?? Duration.zero) > Duration.zero &&
            app.startTime.isAfter(_recordStartTime!)
          );
          
          // Mevcut verileri map'e dönüştür
          final usageMap = Map.fromEntries(
            _usageHistory.map((e) => MapEntry(e.packageName, e))
          );
          
          // Son verileri ekle/güncelle
          for (var app in lastApps) {
            final appInfo = await DeviceApps.getApp(app.packageName, true);
            usageMap[app.packageName] = AppUsageEntry(
              packageName: app.packageName,
              appName: appInfo?.appName ?? app.appName,
              startTime: app.startTime,
              endTime: app.endTime,
              duration: app.duration ?? Duration.zero,
              appInfo: appInfo,
              isRunning: false, // Kayıt durduğu için hiçbir uygulama çalışmıyor
            );
          }
          
          // Son verileri state'e kaydet
          if (mounted) {
            setState(() {
              // Map'i listeye çevir ve süreye göre sırala
              _usageHistory = usageMap.values.toList()
                ..sort((a, b) => b.duration.compareTo(a.duration));
              _recordStartTime = null;
            });
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kayıt durduruldu'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error stopping recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kayıt durdurulurken bir hata oluştu'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  List<Widget> get _pages => [
    ScreenTimeScreen(
      key: const PageStorageKey('screenTime'),
      recordingDuration: _recordingDuration,
      isRecording: _isRecording,
      usageHistory: _usageHistory,
    ),
    HistoryScreen(
      key: const PageStorageKey('history'),
      isRecording: _isRecording,
      usageHistory: _usageHistory,
    ),
    const LimitsScreen(),
    const ReportsScreen(),
    const SettingsScreen(),
  ];

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _usageSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedProfile = context.watch<ProfileProvider>().selectedProfile;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('KidScope'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_isRecording)
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  _buildBlinkingDot(),
                  const SizedBox(width: 8),
                  const Text(
                    'Kayıt',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          if (selectedProfile != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: GestureDetector(
                onTap: () {
                  // Navigate back to profile selection
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileSelectionScreen()),
                  );
                },
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    selectedProfile.avatarEmoji ?? '👤',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.timer),
              label: 'Ekran Süresi',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'Geçmiş',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.block),
              label: 'Limits',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              label: 'Reports',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ElevatedButton(
          onPressed: _isRecording ? _stopRecording : _startRecording,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isRecording ? Colors.red : Colors.blue,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_isRecording ? Icons.stop : Icons.play_arrow),
              const SizedBox(width: 8),
              Text(
                _isRecording ? 'Kaydı Durdur' : 'Kayıt Başlat',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildBlinkingDot() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(seconds: 2), // Slower blink
      builder: (context, value, child) {
        return Opacity(
          opacity: value < 0.5 ? 1.0 : 0.0,
          child: Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red,
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted && _isRecording) {
          // Use microtask to avoid immediate setState
          Future.microtask(() => setState(() {}));
        }
      },
    );
  }
}

// History Screen
class HistoryScreen extends StatefulWidget {
  final bool isRecording;
  final List<AppUsageEntry> usageHistory;

  const HistoryScreen({
    super.key,
    this.isRecording = false,
    this.usageHistory = const [],
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    setState(() => _isLoading = true);
    
    for (var usage in widget.usageHistory) {
      await AppUsageService.getAppInfo(usage.packageName);
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  List<AppUsageEntry> get _filteredHistory {
    return widget.usageHistory
        .where((usage) => 
          AppFilter.isUserApp(usage.packageName) && 
          usage.duration > Duration.zero)
        .toList()
      ..sort((a, b) => b.duration.compareTo(a.duration));
  }

  @override
  Widget build(BuildContext context) {
    final filteredHistory = _filteredHistory;
    
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Geçmiş',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (filteredHistory.isNotEmpty)
                  Text(
                    '${filteredHistory.length} uygulama',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : !widget.isRecording && filteredHistory.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Kayıt kapalı',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Uygulama kullanım geçmişini görmek için kaydı başlatın',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : widget.isRecording && filteredHistory.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 24),
                            Text(
                              'Uygulama kullanımı takip ediliyor...',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredHistory.length,
                        itemBuilder: (context, index) {
                          final usage = filteredHistory[index];
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: _buildAppIcon(usage.appInfo),
                              title: Text(
                                usage.appName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Başlangıç: ${usage.formattedStartTime}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    'Bitiş: ${usage.formattedEndTime}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: usage.isRunning
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  usage.formattedDuration,
                                  style: TextStyle(
                                    color: usage.isRunning ? Colors.green : Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppIcon(Application? appInfo) {
    if (appInfo is ApplicationWithIcon) {
      return CircleAvatar(
        backgroundColor: Colors.transparent,
        child: Image.memory(
          appInfo.icon,
          width: 40,
          height: 40,
        ),
      );
    }
    
    return CircleAvatar(
      backgroundColor: Colors.blue.shade100,
      child: Icon(
        Icons.android,
        color: Colors.blue.shade700,
      ),
    );
  }
}

// App Limit Model
class AppLimit {
  final String appName;
  final String iconUrl;
  int limitHours;

  AppLimit({
    required this.appName,
    required this.iconUrl,
    this.limitHours = 0,
  });
}

// Limits Screen
class LimitsScreen extends StatefulWidget {
  const LimitsScreen({super.key});

  @override
  State<LimitsScreen> createState() => _LimitsScreenState();
}

class _LimitsScreenState extends State<LimitsScreen> {
  // Fixed list of 3 predefined apps with their official icons
  final List<AppLimit> predefinedApps = [
    AppLimit(
      appName: 'YouTube',
      iconUrl: 'https://play-lh.googleusercontent.com/lMoItBgdPPVDJsNOVtP26EKHePkwBg-PkuY9NOrc-fumRtTFP4XhpUNk_22syN4Datc=s48-rw',
    ),
    AppLimit(
      appName: 'Chrome',
      iconUrl: 'https://play-lh.googleusercontent.com/KwUBNPbMTk9jDXYS2AeX3illtVRTkrKVh5xR1Mg4WHd0CG4nDENXg1q4wS_-RJLVmw=s48-rw',
    ),
    AppLimit(
      appName: 'Gmail',
      iconUrl: 'https://play-lh.googleusercontent.com/KSuaRLiI_FlDP8cM4MzJ23ml3og5Hxb9AapaGTMZ2GgR103mvJ3AAnoOFz1yheeQBBI=s48-rw',
    ),
  ];

  void _showTimeLimitPicker(BuildContext context, AppLimit app) {
    // Initialize with current limit or minimum value if not set
    double selectedHours = app.limitHours > 0 ? app.limitHours.toDouble() : 1.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App Info Header
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      app.iconUrl,
                      width: 48,
                      height: 48,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 48,
                        height: 48,
                        color: Colors.grey[200],
                        child: const Icon(Icons.android, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.appName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Set daily time limit',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Hours Display
              Text(
                '${selectedHours.round()} hours',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 24),

              // Slider
              Slider(
                value: selectedHours,
                min: 1,
                max: 24,
                divisions: 23,
                label: '${selectedHours.round()} hours',
                onChanged: (value) {
                  setState(() => selectedHours = value);
                },
              ),
              const SizedBox(height: 32),

              // Set Limit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // UI-only update
                    this.setState(() {
                      app.limitHours = selectedHours.round();
                    });
                    
                    // Close the bottom sheet
                    Navigator.pop(context);
                    
                    // Show UI-only feedback
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Time limit of ${selectedHours.round()} hours set for ${app.appName}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(16),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Set Limit',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeLimit(AppLimit app) {
    setState(() {
      app.limitHours = 0;
    });

    // Show UI-only feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Time limit removed for ${app.appName}',
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'App Limits',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            // Fixed list of 3 predefined apps
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: predefinedApps.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final app = predefinedApps[index];
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () => _showTimeLimitPicker(context, app),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // App Icon
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              app.iconUrl,
                              width: 48,
                              height: 48,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 48,
                                height: 48,
                                color: Colors.grey[200],
                                child: const Icon(Icons.android, color: Colors.grey),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          
                          // App Name and Limit
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  app.appName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (app.limitHours > 0) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '${app.limitHours} hours limit',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          
                          // Remove Limit Button (only shown if limit is set)
                          if (app.limitHours > 0)
                            IconButton(
                              onPressed: () => _removeLimit(app),
                              icon: const Icon(Icons.close),
                              color: Colors.red[300],
                              tooltip: 'Remove limit',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              iconSize: 20,
                            ),
                          
                          // Right Arrow (only shown if no limit is set)
                          if (app.limitHours == 0)
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey[400],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Reports Screen
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Raporlar',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                const TendencyWidget(),
                const SizedBox(height: 20),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.blue,
                  tabs: const [
                    Tab(text: 'Günlük'),
                    Tab(text: 'Haftalık'),
                    Tab(text: 'Aylık'),
                    Tab(text: 'Yıllık'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                DailyReportSection(),
                WeeklyReportSection(),
                MonthlyReportSection(),
                YearlyReportSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TendencyWidget extends StatelessWidget {
  const TendencyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kullanım Eğilimi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              _buildTendencyItem(
                icon: Icons.trending_down,
                color: Colors.green,
                title: 'Oyun',
                subtitle: '15% azalma',
              ),
              const SizedBox(width: 20),
              _buildTendencyItem(
                icon: Icons.trending_up,
                color: Colors.orange,
                title: 'Eğitim',
                subtitle: '23% artış',
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              _buildTendencyItem(
                icon: Icons.trending_flat,
                color: Colors.blue,
                title: 'Sosyal',
                subtitle: 'Sabit',
              ),
              const SizedBox(width: 20),
              _buildTendencyItem(
                icon: Icons.trending_down,
                color: Colors.green,
                title: 'Video',
                subtitle: '8% azalma',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTendencyItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
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
}

class DailyReportSection extends StatelessWidget {
  const DailyReportSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildTimelineCard(
          time: '09:00',
          title: 'Eğitim Uygulamaları',
          duration: '45 dakika',
          color: Colors.blue,
          details: 'Khan Academy, Duolingo',
        ),
        _buildTimelineCard(
          time: '11:30',
          title: 'Oyun',
          duration: '30 dakika',
          color: Colors.orange,
          details: 'Minecraft',
        ),
        _buildTimelineCard(
          time: '14:15',
          title: 'Video İzleme',
          duration: '25 dakika',
          color: Colors.purple,
          details: 'YouTube Kids',
        ),
        _buildTimelineCard(
          time: '16:45',
          title: 'Sosyal Medya',
          duration: '20 dakika',
          color: Colors.green,
          details: 'WhatsApp',
        ),
      ],
    );
  }

  Widget _buildTimelineCard({
    required String time,
    required String title,
    required String duration,
    required Color color,
    required String details,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 2,
            height: 100,
            color: color.withOpacity(0.3),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  details,
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    duration,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WeeklyReportSection extends StatelessWidget {
  const WeeklyReportSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildWeekdayCard(
          day: 'Pazartesi',
          totalTime: '2s 15d',
          categories: [
            CategoryUsage(name: 'Eğitim', percentage: 45, color: Colors.blue),
            CategoryUsage(name: 'Oyun', percentage: 30, color: Colors.orange),
            CategoryUsage(name: 'Video', percentage: 25, color: Colors.purple),
          ],
        ),
        _buildWeekdayCard(
          day: 'Salı',
          totalTime: '1s 45d',
          categories: [
            CategoryUsage(name: 'Eğitim', percentage: 50, color: Colors.blue),
            CategoryUsage(name: 'Oyun', percentage: 20, color: Colors.orange),
            CategoryUsage(name: 'Video', percentage: 30, color: Colors.purple),
          ],
        ),
        _buildWeekdayCard(
          day: 'Çarşamba',
          totalTime: '2s 30d',
          categories: [
            CategoryUsage(name: 'Eğitim', percentage: 40, color: Colors.blue),
            CategoryUsage(name: 'Oyun', percentage: 35, color: Colors.orange),
            CategoryUsage(name: 'Video', percentage: 25, color: Colors.purple),
          ],
        ),
        _buildWeekdayCard(
          day: 'Perşembe',
          totalTime: '2s',
          categories: [
            CategoryUsage(name: 'Eğitim', percentage: 55, color: Colors.blue),
            CategoryUsage(name: 'Oyun', percentage: 25, color: Colors.orange),
            CategoryUsage(name: 'Video', percentage: 20, color: Colors.purple),
          ],
        ),
      ],
    );
  }

  Widget _buildWeekdayCard({
    required String day,
    required String totalTime,
    required List<CategoryUsage> categories,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  day,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  totalTime,
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            ...categories.map((category) => Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        category.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${category.percentage}%',
                      style: TextStyle(
                        color: category.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: category.percentage / 100,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(category.color),
                ),
                const SizedBox(height: 10),
              ],
            )).toList(),
          ],
        ),
      ),
    );
  }
}

class CategoryUsage {
  final String name;
  final int percentage;
  final Color color;

  CategoryUsage({
    required this.name,
    required this.percentage,
    required this.color,
  });
}

class MonthlyReportSection extends StatelessWidget {
  const MonthlyReportSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildMonthlyStats(),
        const SizedBox(height: 20),
        _buildTopApps(),
      ],
    );
  }

  Widget _buildMonthlyStats() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aylık İstatistikler',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildStatItem(
              icon: Icons.timer,
              title: 'Toplam Süre',
              value: '45 saat',
              color: Colors.blue,
            ),
            const SizedBox(height: 15),
            _buildStatItem(
              icon: Icons.school,
              title: 'Eğitim Süresi',
              value: '20 saat',
              color: Colors.green,
            ),
            const SizedBox(height: 15),
            _buildStatItem(
              icon: Icons.games,
              title: 'Oyun Süresi',
              value: '15 saat',
              color: Colors.orange,
            ),
            const SizedBox(height: 15),
            _buildStatItem(
              icon: Icons.video_library,
              title: 'Video İzleme',
              value: '10 saat',
              color: Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopApps() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'En Çok Kullanılan Uygulamalar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildTopAppItem(
              name: 'Khan Academy',
              category: 'Eğitim',
              duration: '12 saat',
              color: Colors.blue,
            ),
            const SizedBox(height: 15),
            _buildTopAppItem(
              name: 'Minecraft',
              category: 'Oyun',
              duration: '8 saat',
              color: Colors.orange,
            ),
            const SizedBox(height: 15),
            _buildTopAppItem(
              name: 'YouTube Kids',
              category: 'Video',
              duration: '6 saat',
              color: Colors.red,
            ),
            const SizedBox(height: 15),
            _buildTopAppItem(
              name: 'Duolingo',
              category: 'Eğitim',
              duration: '5 saat',
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAppItem({
    required String name,
    required String category,
    required String duration,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.android, color: color),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                category,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            duration,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class YearlyReportSection extends StatelessWidget {
  const YearlyReportSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildYearlyOverview(),
        const SizedBox(height: 20),
        _buildQuarterlyBreakdown(),
      ],
    );
  }

  Widget _buildYearlyOverview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Yıllık Genel Bakış',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildOverviewItem(
              title: 'Toplam Ekran Süresi',
              value: '520 saat',
              change: '-5%',
              isPositive: true,
            ),
            const SizedBox(height: 15),
            _buildOverviewItem(
              title: 'Eğitim Uygulamaları',
              value: '245 saat',
              change: '+15%',
              isPositive: true,
            ),
            const SizedBox(height: 15),
            _buildOverviewItem(
              title: 'Oyun Süresi',
              value: '180 saat',
              change: '-20%',
              isPositive: true,
            ),
            const SizedBox(height: 15),
            _buildOverviewItem(
              title: 'Video İzleme',
              value: '95 saat',
              change: '-8%',
              isPositive: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewItem({
    required String title,
    required String value,
    required String change,
    required bool isPositive,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: (isPositive ? Colors.green : Colors.red).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            change,
            style: TextStyle(
              color: isPositive ? Colors.green : Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuarterlyBreakdown() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Çeyreklik Dağılım',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildQuarterItem(
              quarter: 'Q1',
              totalTime: '140 saat',
              education: 60,
              gaming: 50,
              video: 30,
            ),
            const SizedBox(height: 20),
            _buildQuarterItem(
              quarter: 'Q2',
              totalTime: '125 saat',
              education: 65,
              gaming: 40,
              video: 20,
            ),
            const SizedBox(height: 20),
            _buildQuarterItem(
              quarter: 'Q3',
              totalTime: '130 saat',
              education: 70,
              gaming: 35,
              video: 25,
            ),
            const SizedBox(height: 20),
            _buildQuarterItem(
              quarter: 'Q4',
              totalTime: '125 saat',
              education: 75,
              gaming: 30,
              video: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuarterItem({
    required String quarter,
    required String totalTime,
    required int education,
    required int gaming,
    required int video,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              quarter,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              totalTime,
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildProgressBar('Eğitim', education, Colors.blue),
        const SizedBox(height: 8),
        _buildProgressBar('Oyun', gaming, Colors.orange),
        const SizedBox(height: 8),
        _buildProgressBar('Video', video, Colors.purple),
      ],
    );
  }

  Widget _buildProgressBar(String label, int percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$percentage%',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }
}

// Settings Screen
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Ayarlar',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          
          // Profile Settings
          _buildSettingsSection(
            title: 'Profil Ayarları',
            items: [
              SettingsItem(
                icon: Icons.person,
                title: 'Profil Bilgileri',
                subtitle: 'İsim, yaş ve diğer bilgiler',
              ),
              SettingsItem(
                icon: Icons.notifications,
                title: 'Bildirimler',
                subtitle: 'Bildirim tercihleri',
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // App Settings
          _buildSettingsSection(
            title: 'Uygulama Ayarları',
            items: [
              SettingsItem(
                icon: Icons.lock_clock,
                title: 'Zaman Sınırları',
                subtitle: 'Varsayılan süre limitleri',
              ),
              SettingsItem(
                icon: Icons.category,
                title: 'Kategori Yönetimi',
                subtitle: 'Uygulama kategorileri',
              ),
              SettingsItem(
                icon: Icons.bar_chart,
                title: 'Rapor Tercihleri',
                subtitle: 'Rapor görünümü ve detayları',
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // System Settings
          _buildSettingsSection(
            title: 'Sistem',
            items: [
              SettingsItem(
                icon: Icons.language,
                title: 'Dil',
                subtitle: 'Türkçe',
              ),
              SettingsItem(
                icon: Icons.brightness_6,
                title: 'Tema',
                subtitle: 'Açık tema',
              ),
              SettingsItem(
                icon: Icons.info,
                title: 'Hakkında',
                subtitle: 'Versiyon 1.0.0',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required List<SettingsItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: items.map((item) => _buildSettingsItemTile(item)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsItemTile(SettingsItem item) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          item.icon,
          color: Colors.blue,
        ),
      ),
      title: Text(
        item.title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        item.subtitle,
        style: TextStyle(
          color: Colors.grey[600],
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.grey,
      ),
      onTap: () {
        // Settings item tap handler would go here
      },
    );
  }
}

class SettingsItem {
  final IconData icon;
  final String title;
  final String subtitle;

  const SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class ScreenTimeScreen extends StatelessWidget {
  final Duration recordingDuration;
  final bool isRecording;
  final List<AppUsageEntry> usageHistory;

  const ScreenTimeScreen({
    super.key, 
    this.recordingDuration = Duration.zero,
    this.isRecording = false,
    this.usageHistory = const [],
  });

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Ekran Süresi',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 30),

          // Screen Time Stats Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDuration(recordingDuration),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      isRecording ? Icons.fiber_manual_record : Icons.stop,
                      color: isRecording ? Colors.red : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isRecording ? 'Kayıt devam ediyor' : 'Kayıt durdu',
                      style: TextStyle(
                        color: isRecording ? Colors.red : Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // Top Apps Section with real-time tracking
          TopAppsTracker(
            isRecording: isRecording,
            usageHistory: usageHistory,
          ),

          const SizedBox(height: 30),

          // Digital Risk Score
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dijital Skor Puanı',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _calculateScore().toString(),
                  style: const TextStyle(
                    fontSize: 36,
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

  int _calculateScore() {
    if (usageHistory.isEmpty) return 100;
    
    final totalUsage = usageHistory.fold<Duration>(
      Duration.zero,
      (total, app) => total + (app.duration ?? Duration.zero),
    );

    final hoursUsed = totalUsage.inHours;
    int score = 100;
    
    if (hoursUsed > 8) {
      score -= 60;
    } else if (hoursUsed > 6) {
      score -= 40;
    } else if (hoursUsed > 4) {
      score -= 20;
    } else if (hoursUsed > 2) {
      score -= 10;
    }

    return score.clamp(0, 100);
  }
}
