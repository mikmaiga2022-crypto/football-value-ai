import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/theme_mode.dart';
import '../../app/theme/tokens.dart';
import '../../core/auth/session.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/version.dart';
import '../../data/models/app_user.dart';
import '../../data/models/competition.dart';
import '../../data/models/system_status.dart';
import '../../widgets/async_panel.dart';
import '../../widgets/info_banner.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_dot.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final user = session.user;
    final themeMode = ref.watch(themeModeProvider);
    final coverage = ref.watch(coverageProvider);
    final config = ref.watch(appConfigProvider).asData?.value;
    final health = ref.watch(healthProvider).asData?.value;
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () => refreshServerData(ref),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: Tokens.space2),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Tokens.screenPadding,
          0,
          Tokens.screenPadding,
          Tokens.space8,
        ),
        children: [
          if (user != null) _AccountCard(user: user),
          const SizedBox(height: Tokens.space6),
          const SectionHeader('Apparence'),
          const SizedBox(height: Tokens.space2),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Tokens.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thème',
                    style: Tokens.bodyStrong.copyWith(color: scheme.onSurface),
                  ),
                  const SizedBox(height: Tokens.space3),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Sombre'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Clair'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('Auto'),
                        ),
                      ],
                      selected: {themeMode},
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      onSelectionChanged: (selection) =>
                          ref.read(themeModeProvider.notifier).select(selection.first),
                    ),
                  ),
                  const SizedBox(height: Tokens.space2),
                  Text(
                    'La préférence est conservée pendant la session.',
                    style: Tokens.caption.copyWith(color: surfaces.muted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Tokens.space6),
          const SectionHeader('Couverture et quota'),
          const SizedBox(height: Tokens.space2),
          AsyncPanel<CoveragePlan>(
            value: coverage,
            skeletonCount: 1,
            skeletonHeight: 120,
            onRetry: () => refreshServerData(ref),
            builder: (plan) => _QuotaCard(plan: plan),
          ),
          const SizedBox(height: Tokens.space6),
          const SectionHeader('Données'),
          const SizedBox(height: Tokens.space2),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Tokens.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    label: 'Mode',
                    value: config == null
                        ? '—'
                        : config.isZeroBudget
                            ? 'Pilote 0 €'
                            : 'Standard',
                  ),
                  const SizedBox(height: Tokens.space3),
                  _InfoRow(
                    label: 'Modèle',
                    value: 'Statistique (dé-vig + Poisson/Elo)',
                  ),
                  const SizedBox(height: Tokens.space3),
                  _InfoRow(
                    label: 'Live',
                    value: (config?.features.live ?? false) ? 'Activé' : 'Désactivé',
                  ),
                  const SizedBox(height: Tokens.space3),
                  _InfoRow(
                    label: 'Notifications',
                    value: (config?.features.notifications ?? false)
                        ? 'Disponibles'
                        : 'Pas encore disponibles',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Tokens.space2),
          Text(
            'Aucun montant de bankroll n’est prérempli. La simulation sera proposée '
            'avec les recommandations, jamais avant.',
            style: Tokens.caption.copyWith(color: surfaces.muted),
          ),
          const SizedBox(height: Tokens.space6),
          const SectionHeader('Avertissement légal'),
          const SizedBox(height: Tokens.space2),
          const _DisclaimerCard(),
          const SizedBox(height: Tokens.space6),
          Container(
            padding: const EdgeInsets.all(Tokens.space4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Tokens.radiusCard),
              border: Border.all(color: surfaces.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FOOTBALL VALUE AI $appVersion',
                        style: Tokens.bodyStrong.copyWith(color: scheme.onSurface),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Android · API ${health?.apiVersion ?? '—'}',
                        style: Tokens.caption.copyWith(color: surfaces.muted),
                      ),
                    ],
                  ),
                ),
                StatusDot(
                  color: Theme.of(context).colorScheme.primary,
                  label: 'Bêta privée',
                ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.space4),
          OutlinedButton.icon(
            onPressed: () => _confirmLogout(context, ref),
            icon: const Icon(Icons.logout),
            label: const Text('Se déconnecter'),
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error.withValues(alpha: 0.6)),
              minimumSize: const Size.fromHeight(Tokens.minTouchTarget),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text(
          'La session et les jetons stockés sur cet appareil seront effacés. '
          'Vos données restent sur le serveur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await ref.read(sessionProvider.notifier).logout();
    }
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    final initials = _initials(user);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space4),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(Tokens.radiusPill),
                border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
              ),
              child: Text(
                initials,
                style: Tokens.bodyStrong.copyWith(color: scheme.primary),
              ),
            ),
            const SizedBox(width: Tokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName ?? user.shortName,
                    style: Tokens.h2.copyWith(color: scheme.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    style: Tokens.caption.copyWith(color: surfaces.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: Tokens.space2),
                  Text(
                    'Rôle : ${_roleLabel(user.role)} · ${user.timezone}',
                    style: Tokens.caption.copyWith(color: surfaces.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(AppUser user) {
    final source = (user.displayName ?? user.shortName).trim();
    if (source.isEmpty) return '?';
    final parts = source.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return source.substring(0, source.length >= 2 ? 2 : 1).toUpperCase();
  }

  static String _roleLabel(String role) => switch (role) {
        'admin' => 'administrateur',
        'analyst' => 'analyste',
        _ => 'utilisateur',
      };
}

class _QuotaCard extends StatelessWidget {
  const _QuotaCard({required this.plan});

  final CoveragePlan plan;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    final quota = plan.quota;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Crédits cotes utilisés',
                    style: Tokens.bodyStrong.copyWith(color: scheme.onSurface),
                  ),
                ),
                Text(
                  '${formatCount(quota.usedMonth)} / ${formatCount(quota.monthlyBudget)}',
                  style: Tokens.number.copyWith(
                    fontSize: 18,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Tokens.space3),
            ClipRRect(
              borderRadius: BorderRadius.circular(Tokens.radiusPill),
              child: LinearProgressIndicator(
                value: quota.ratio,
                minHeight: 8,
                backgroundColor: surfaces.surfaceAlt,
                color: quota.exhausted ? scheme.error : scheme.primary,
              ),
            ),
            const SizedBox(height: Tokens.space3),
            Text(
              quota.exhausted
                  ? 'Arrêt dur atteint : plus aucun appel automatique.'
                  : '${formatCount(quota.remaining)} crédit(s) restant(s) sur le budget mensuel. '
                      'Aujourd’hui : ${formatCount(quota.usedToday)}.',
              style: Tokens.caption.copyWith(color: surfaces.muted),
            ),
            const SizedBox(height: Tokens.space2),
            Text(
              '${plan.served.length} compétition(s) servie(s) · plafond fournisseur '
              '${formatCount(quota.monthlyLimit)} crédits',
              style: Tokens.caption.copyWith(color: surfaces.muted),
            ),
            if (quota.degradedReason != null) ...[
              const SizedBox(height: Tokens.space3),
              InfoBanner(
                tone: BannerTone.warning,
                message: quota.degradedReason!,
              ),
            ],
            if (plan.notes.isNotEmpty) ...[
              const SizedBox(height: Tokens.space3),
              for (final note in plan.notes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '· $note',
                    style: Tokens.caption.copyWith(color: surfaces.muted),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DisclaimerCard extends ConsumerWidget {
  const _DisclaimerCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disclaimer = ref.watch(disclaimerProvider);
    final surfaces = context.surfaces;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '18+ · Jeu responsable',
              style: Tokens.bodyStrong.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: Tokens.space2),
            AsyncPanel<Disclaimer>(
              value: disclaimer,
              skeletonCount: 1,
              skeletonHeight: 48,
              onRetry: () async {
                ref.invalidate(disclaimerProvider);
              },
              builder: (data) => Text(
                data.text,
                style: Tokens.caption.copyWith(color: surfaces.muted),
              ),
            ),
            const SizedBox(height: Tokens.space2),
            Text(
              'Les probabilités sont des estimations. Aucun gain n’est garanti. '
              'Les pertes sont possibles.',
              style: Tokens.caption.copyWith(color: surfaces.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label.toUpperCase(),
            style: Tokens.section.copyWith(
              color: context.surfaces.muted,
              fontSize: 11,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Tokens.body.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
