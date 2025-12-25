import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:spendrail_worker_app/l10n/app_localizations.dart';
import 'package:spendrail_worker_app/services/auth_service.dart';
import 'package:spendrail_worker_app/services/localization_service.dart';
import 'package:spendrail_worker_app/theme.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final userData = ref.watch(currentUserDataProvider);
    final currentLocale = ref.watch(localizationProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('profile')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: Column(
            children: [
              SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person, size: 64, color: theme.colorScheme.primary),
              ),
              SizedBox(height: AppSpacing.lg),
              userData.when(
                data: (user) {
                  if (user == null) return const SizedBox.shrink();
                  return Column(
                    children: [
                      Text(user.name, style: context.textStyles.headlineMedium?.bold),
                      SizedBox(height: AppSpacing.sm),
                      Text(user.email, style: context.textStyles.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => const SizedBox.shrink(),
              ),
              SizedBox(height: AppSpacing.xl),
              Card(
                child: Column(
                  children: [
                    ProfileListTile(
                      icon: Icons.language,
                      title: l10n.translate('language'),
                      subtitle: _getLanguageName(currentLocale.languageCode),
                      onTap: () => _showLanguageDialog(context, ref),
                    ),
                    const Divider(height: 1),
                    ProfileListTile(
                      icon: Icons.history,
                      title: l10n.translate('history'),
                      onTap: () => context.push('/history'),
                    ),
                    const Divider(height: 1),
                    ProfileListTile(
                      icon: Icons.analytics,
                      title: l10n.translate('analytics'),
                      onTap: () => context.push('/analytics'),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.xl),
              ElevatedButton.icon(
                onPressed: () async {
                  final authService = ref.read(authServiceProvider);
                  await authService.signOut();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
                icon: const Icon(Icons.logout),
                label: Text(l10n.translate('logout')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'hi':
        return 'हिन्दी';
      case 'mr':
        return 'मराठी';
      default:
        return 'English';
    }
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.read(localizationProvider);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('change_language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: LocalizationService.supportedLocales.map((locale) {
            return RadioListTile<String>(
              title: Text(_getLanguageName(locale.languageCode)),
              value: locale.languageCode,
              groupValue: currentLocale.languageCode,
              onChanged: (value) async {
                if (value != null) {
                  await ref.read(localizationProvider.notifier).setLocale(Locale(value));
                  final authService = ref.read(authServiceProvider);
                  await authService.updateUserLanguage(value);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).translate('cancel')),
          ),
        ],
      ),
    );
  }
}

class ProfileListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const ProfileListTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title, style: context.textStyles.bodyLarge),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
      onTap: onTap,
    );
  }
}
