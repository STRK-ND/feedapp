/// Editorial list-mode article card.
///
/// Used in the Continuous Feed view (alongside the existing CardStack).
/// Hairline-bounded, no image by default, header row with mono
/// source title, large serif headline, JetBrains-Mono dateline.
///
/// Different visual densities are encoded by the parent section eyebrow:
/// `older` sections compress the gap and use a smaller headline.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/article.dart';
import '../providers/settings_notifier.dart';
import '../services/cache_manager.dart';
import '../utils/design_tokens.dart';

class ListArticleCard extends StatelessWidget {
  final Article article;
  final int index;
  final bool showUnreadDot;
  final double measure;
  final VoidCallback onTap;

  const ListArticleCard({
    super.key,
    required this.article,
    required this.index,
    required this.onTap,
    required this.measure,
    this.showUnreadDot = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ruleColor = isDark ? AppColors.ruleOnGround : AppColors.rule;
    final ink = isDark ? AppColors.paperOnGround : AppColors.ink;
    final soft = isDark ? AppColors.paperOnGroundSoft : AppColors.inkSoft;
    final sourceColor = _sourceColor(article.sourceColor);

    return Semantics(
      button: true,
      label:
          '${article.title}. From ${article.sourceName}. ${article.isSaved ? 'Saved. ' : ''}Tap to read.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s6,
            vertical: AppSpacing.s3,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: measure),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (showUnreadDot && !article.isRead) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s2 + 2),
                    ],
                    Expanded(
                      child: Text(
                        article.sourceName.toUpperCase(),
                        style: AppType.monoEyebrow(color: sourceColor)
                            .copyWith(letterSpacing: 0.6),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    Text(
                      _formatDateline(article.pubDate),
                      style: AppType.monoDateline(color: soft)
                          .copyWith(letterSpacing: 0.05),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.s2),
                Text(
                  article.title,
                  style: AppType.titleLarge(color: ink)
                      .copyWith(fontSize: 19, height: 1.22),
                ),
                if (article.description.isNotEmpty) ...[
                  SizedBox(height: AppSpacing.s2),
                  Text(
                    article.description,
                    style: AppType.bodyMedium(color: soft),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                SizedBox(height: AppSpacing.s3),
                Consumer<SettingsNotifier>(
                  builder: (context, settings, _) {
                    if (!settings.showImages) return const SizedBox.shrink();
                    if (article.imageUrl == null) return const SizedBox.shrink();
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      child: CachedNetworkImage(
                        imageUrl: article.imageUrl!,
                        fit: BoxFit.cover,
                        cacheManager: AppCacheManager(),
                        width: double.infinity,
                        height: 200,
                        fadeInDuration: AppMotion.base,
                        placeholder: (context, _) =>
                            Container(color: ruleColor),
                        errorWidget: (context, _, __) =>
                            Container(color: ruleColor),
                      ),
                    );
                  },
                ),
                SizedBox(height: AppSpacing.s3),
                Container(
                  height: 0.5,
                  color: ruleColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Format as "08/12 · 14:03" or "Yesterday" — concise editorial dateline.
String _formatDateline(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dtDay = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(dtDay).inDays;
  if (diff == 0) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} · $hh:$mm';
  }
  if (diff == 1) return 'YESTERDAY';
  if (diff < 7) return '${diff}D AGO';
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${(dt.year % 100).toString().padLeft(2, '0')}';
}

Color _sourceColor(String? hex) {
  if (hex == null || hex.isEmpty) return AppColors.primary;
  final cleaned = hex.replaceFirst('#', '');
  if (cleaned.length == 6) {
    return Color(int.parse('0xFF$cleaned'));
  }
  return AppColors.primary;
}
