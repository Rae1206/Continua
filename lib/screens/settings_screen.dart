import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Duration _pickerDurationFromSeconds(int totalSeconds) {
    final clamped = totalSeconds < 60 ? 60 : totalSeconds;
    final hours = (clamped ~/ 3600) % 24;
    final minutes = (clamped % 3600) ~/ 60;
    return Duration(hours: hours, minutes: minutes);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Estado de notificaciones
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: settings.notificationsEnabled
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        settings.notificationsEnabled
                            ? Icons.notifications_active
                            : Icons.notifications_off,
                        color: settings.notificationsEnabled
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notificaciones',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                            Text(
                            settings.notificationsEnabled
                                ? 'Activas - Recibirás versículos bíblicos'
                                : 'Desactivadas',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: settings.notificationsEnabled,
                      onChanged: (value) {
                        notifier.setNotificationsEnabled(value);
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Frecuencia de notificaciones
            Text(
              'Frecuencia de versículos',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '¿Con qué frecuencia quieres recibir versículos?',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Selector de intervalo con Timer Picker
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          color: settings.notificationsEnabled
                              ? Theme.of(context).primaryColor
                              : Colors.grey,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatInterval(settings.intervalSeconds),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: settings.notificationsEnabled
                                    ? null
                                    : Colors.grey,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  SizedBox(
                    height: 200,
                    child: CupertinoTimerPicker(
                      mode: CupertinoTimerPickerMode.hm,
                      initialTimerDuration: _pickerDurationFromSeconds(
                        settings.intervalSeconds,
                      ),
                      onTimerDurationChanged: (Duration duration) {
                        if (settings.notificationsEnabled) {
                          // Minimum 1 minute
                          final seconds = duration.inSeconds;
                          if (seconds >= 60) {
                            notifier.setIntervalSeconds(seconds);
                          }
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      'Mínimo: 1 minuto',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Opciones rápidas
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Opciones rápidas',
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _QuickIntervalChip(
                        label: '1 min',
                        seconds: 60,
                        isSelected: settings.intervalSeconds == 60,
                        enabled: settings.notificationsEnabled,
                        onTap: () => notifier.setIntervalSeconds(60),
                      ),
                      _QuickIntervalChip(
                        label: '15 min',
                        seconds: 900,
                        isSelected: settings.intervalSeconds == 900,
                        enabled: settings.notificationsEnabled,
                        onTap: () => notifier.setIntervalSeconds(900),
                      ),
                      _QuickIntervalChip(
                        label: '30 min',
                        seconds: 1800,
                        isSelected: settings.intervalSeconds == 1800,
                        enabled: settings.notificationsEnabled,
                        onTap: () => notifier.setIntervalSeconds(1800),
                      ),
                      _QuickIntervalChip(
                        label: '1 hora',
                        seconds: 3600,
                        isSelected: settings.intervalSeconds == 3600,
                        enabled: settings.notificationsEnabled,
                        onTap: () => notifier.setIntervalSeconds(3600),
                      ),
                      _QuickIntervalChip(
                        label: '2 horas',
                        seconds: 7200,
                        isSelected: settings.intervalSeconds == 7200,
                        enabled: settings.notificationsEnabled,
                        onTap: () => notifier.setIntervalSeconds(7200),
                      ),
                      _QuickIntervalChip(
                        label: '6 horas',
                        seconds: 21600,
                        isSelected: settings.intervalSeconds == 21600,
                        enabled: settings.notificationsEnabled,
                        onTap: () => notifier.setIntervalSeconds(21600),
                      ),
                      _QuickIntervalChip(
                        label: '12 horas',
                        seconds: 43200,
                        isSelected: settings.intervalSeconds == 43200,
                        enabled: settings.notificationsEnabled,
                        onTap: () => notifier.setIntervalSeconds(43200),
                      ),
                      _QuickIntervalChip(
                        label: '24 horas',
                        seconds: 86400,
                        isSelected: settings.intervalSeconds == 86400,
                        enabled: settings.notificationsEnabled,
                        onTap: () => notifier.setIntervalSeconds(86400),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatInterval(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0 && minutes > 0) {
      return '$hours hora${hours > 1 ? 's' : ''} $minutes min';
    } else if (hours > 0) {
      return '$hours hora${hours > 1 ? 's' : ''}';
    } else if (minutes > 0) {
      return '$minutes minuto${minutes > 1 ? 's' : ''}';
    } else {
      return '$seconds seg';
    }
  }
}

/// Chip para selección rápida de intervalo
class _QuickIntervalChip extends StatelessWidget {
  final String label;
  final int seconds;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  const _QuickIntervalChip({
    required this.label,
    required this.seconds,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      backgroundColor: isSelected
          ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
          : null,
      side: BorderSide(
        color: isSelected
            ? Theme.of(context).primaryColor
            : Colors.grey.shade300,
      ),
      labelStyle: TextStyle(
        color: isSelected
            ? Theme.of(context).primaryColor
            : (enabled ? null : Colors.grey),
        fontWeight: isSelected ? FontWeight.bold : null,
      ),
      onPressed: enabled ? onTap : null,
    );
  }
}
