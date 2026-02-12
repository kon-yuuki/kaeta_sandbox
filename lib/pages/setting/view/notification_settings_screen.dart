import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  static const _prefKey = 'app_notifications_enabled';
  static const _detailKeys = <String, String>{
    'リストの更新 (追加・編集・削除)': 'notify_list_updates',
    '買い物完了': 'notify_shopping_complete',
    'ひとこと掲示板の更新': 'notify_board_updates',
    'スタンプでのリアクション': 'notify_reactions',
    'リマインド': 'notify_reminders',
    '運営からのお知らせ': 'notify_admin_announcements',
  };

  bool _enabled = false;
  bool _loading = true;
  final Map<String, bool> _details = {
    for (final label in _detailKeys.keys) label: true,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final granted = await NotificationService().isPermissionGranted();
    final saved = prefs.getBool(_prefKey);
    final enabled = saved ?? granted;
    await prefs.setBool(_prefKey, enabled);
    for (final entry in _detailKeys.entries) {
      _details[entry.key] = prefs.getBool(entry.value) ?? true;
    }
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _loading = false;
    });
  }

  Future<void> _openSystemSettings() async {
    final opened = await launchUrl(
      Uri.parse('app-settings:'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定アプリを開けませんでした')),
      );
    }
  }

  Future<void> _showOpenSettingsDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('通知を有効にできません'),
          content: const Text('端末の設定画面で通知を許可してください。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _openSystemSettings();
              },
              child: const Text('設定を開く'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _setEnabled(bool value) async {
    if (_loading) return;
    final messenger = ScaffoldMessenger.of(context);

    if (value) {
      final granted = await NotificationService().requestPermission();
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, granted);
      await NotificationService().setAppNotificationEnabled(granted);
      setState(() => _enabled = granted);
      if (!granted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('通知を有効にできませんでした。設定をご確認ください')),
        );
        await _showOpenSettingsDialog();
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, false);
    await NotificationService().setAppNotificationEnabled(false);
    if (!mounted) return;
    setState(() => _enabled = false);
  }

  Future<void> _setDetailEnabled(String label, bool value) async {
    final key = _detailKeys[label];
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    if (!mounted) return;
    setState(() {
      _details[label] = value;
    });
  }

  Widget _buildSettingRow(
    BuildContext context, {
    required String label,
    required bool value,
    required ValueChanged<bool>? onChanged,
    bool showDivider = true,
  }) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: colors.borderLow))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: onChanged == null ? colors.textDisabled : colors.textHigh,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: colors.surfaceHighOnInverse,
            activeTrackColor: colors.accentPrimary,
            inactiveThumbColor: colors.surfaceHighOnInverse,
            inactiveTrackColor: colors.surfacePrimary,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.surfaceTertiary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '通知設定',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '通知設定',
                      style: TextStyle(
                        color: colors.textLow,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: colors.surfaceHighOnInverse,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: _buildSettingRow(
                        context,
                        label: 'アプリの通知',
                        value: _enabled,
                        onChanged: _setEnabled,
                        showDivider: false,
                      ),
                    ),
                    if (_enabled) ...[
                      const SizedBox(height: 18),
                      Text(
                        'アプリ情報',
                        style: TextStyle(
                          color: colors.textLow,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: colors.surfaceHighOnInverse,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: _detailKeys.keys.map((label) {
                            final isLast = label == _detailKeys.keys.last;
                            return _buildSettingRow(
                              context,
                              label: label,
                              value: _details[label] ?? true,
                              onChanged: (value) => _setDetailEnabled(label, value),
                              showDivider: !isLast,
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
