import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/supabase_service.dart';
import 'services/notification_controller.dart';
import 'services/firebase_messaging_service.dart';
import 'screens/settings_screen.dart';
import 'providers/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Run UI immediately - background services initialize in background
  runApp(const ProviderScope(child: MyApp()));

  // Initialize services AFTER UI is shown (non-blocking)
  _initializeServicesInBackground();
}

Future<void> _initializeServicesInBackground() async {
  // Initialize Supabase (non-blocking)
  try {
    await SupabaseService().init();
    debugPrint('Supabase initialized successfully');
  } catch (e) {
    debugPrint('Supabase initialization failed: $e');
  }

  // Start Firebase in background (don't await completion)
  FirebaseMessagingService.initialize();

  // Register device with a small delay to let Firebase get token
  // This is the same logic that works when changing interval
  await Future.delayed(const Duration(seconds: 3));
  try {
    final prefs = await SharedPreferences.getInstance();
    final intervalSeconds = prefs.getInt('interval_seconds') ?? 900;
    await FirebaseMessagingService.updateIntervalPreference(intervalSeconds);
    debugPrint('Device registered at startup with interval: $intervalSeconds');
  } catch (e) {
    debugPrint('Device registration at startup failed: $e');
  }

  // Request notification permission (non-blocking)
  try {
    await NotificationController.requestNotificationPermission();
  } catch (_) {}
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Keep Going',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isLoading = true;
  bool _alarmScheduled = false;

  @override
  void initState() {
    super.initState();
    // Register AlarmManager immediately.
    // AlarmManager is more reliable than WorkManager on Xiaomi/MIUI.
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final notifier = ref.read(settingsProvider.notifier);
      await notifier.load();

      if (!mounted) return;

      final settings = ref.read(settingsProvider);
      debugPrint(
        'HomeScreen: Current interval = ${settings.intervalSeconds} seconds (${settings.intervalSeconds ~/ 60} min)',
      );

      // Schedule alarm in background - don't await to avoid blocking UI
      _scheduleAlarmInBackground(settings.intervalSeconds);
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      // ALWAYS hide loading, even if something fails
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _scheduleAlarmInBackground(int intervalSeconds) async {
    try {
      await NotificationController.scheduleAlarm(intervalSeconds);
      debugPrint('HomeScreen: Alarm scheduled');
    } catch (e) {
      debugPrint('Error scheduling alarm: $e');
    }
    if (mounted) {
      setState(() => _alarmScheduled = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Show loading while settings are being loaded
    if (_isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    // Re-register alarm when interval changes
    ref.listen<SettingsState>(settingsProvider, (previous, next) {
      if (previous?.intervalSeconds != next.intervalSeconds) {
        NotificationController.scheduleAlarm(next.intervalSeconds);
      }
    });

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Keep Going',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            icon: Icon(Icons.settings, color: colorScheme.onSurfaceVariant),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(),
              // Main card with quote
              Card(
                color: colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.format_quote,
                        size: 48,
                        color: colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '¿Listo para recibir inspiración?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onPrimaryContainer,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Recibe quotes motivacionales\nautomáticamente',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onPrimaryContainer.withValues(
                            alpha: 0.7,
                          ),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Frequency indicator
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 20,
                      color: colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatFrequency(settings.intervalSeconds),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Add quote button
              FilledButton.tonalIcon(
                onPressed: () => _showAddQuoteDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Añadir'),
              ),

              const Spacer(),

              // Show quote now button
              FilledButton.icon(
                onPressed: () async {
                  final svc = SupabaseService();
                  await svc.init();
                  final q = await svc.fetchRandomQuote();
                  if (q != null) {
                    await NotificationController.showNotification(
                      q.text,
                      q.author,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Quote enviada!'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: colorScheme.primary,
                        ),
                      );
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('No quote found'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: colorScheme.error,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.send),
                label: const Text('Show quote now'),
              ),

              const SizedBox(height: 16),

              // Settings button
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
                icon: const Icon(Icons.tune),
                label: const Text('Configurar notificaciones'),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFrequency(int seconds) {
    if (seconds < 60) {
      return '$seconds segundos';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      return '$minutes minuto${minutes > 1 ? 's' : ''}';
    } else {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      if (minutes > 0) {
        return '$hours hora${hours > 1 ? 's' : ''} $minutes min';
      }
      return '$hours hora${hours > 1 ? 's' : ''}';
    }
  }

  Future<void> _showAddQuoteDialog(BuildContext context) async {
    final textController = TextEditingController();
    final authorController = TextEditingController();
    final colorScheme = Theme.of(context).colorScheme;
    bool isLoading = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Añadir Quote'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  labelText: 'Quote',
                  hintText: 'Ingresa el quote',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: authorController,
                decoration: const InputDecoration(
                  labelText: 'Autor',
                  hintText: 'Ingresa el autor',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (textController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('El quote no puede estar vacío'),
                          ),
                        );
                        return;
                      }
                      setState(() => isLoading = true);

                      final supabase = SupabaseService();
                      await supabase.init();
                      final success = await supabase.saveQuote(
                        textController.text.trim(),
                        authorController.text.trim(),
                      );

                      if (context.mounted) {
                        Navigator.of(context).pop(true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success ? 'Quote guardado!' : 'Error al guardar',
                            ),
                            backgroundColor: success
                                ? colorScheme.primary
                                : colorScheme.error,
                          ),
                        );
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
