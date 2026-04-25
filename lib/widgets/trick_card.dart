import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/trick.dart';
import '../models/user_trick.dart';

class TrickCard extends StatelessWidget {
  final Trick trick;
  final Consistency? consistency;
  final VoidCallback? onReturn;
  final bool listMode;

  const TrickCard({super.key, required this.trick, this.consistency, this.onReturn, this.listMode = false});

  @override
  Widget build(BuildContext context) {
    if (listMode) return _buildListTile(context);
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      color: consistency?.cardColor,
      child: InkWell(
        onTap: () async {
          await context.push('/trick/${trick.id}');
          onReturn?.call();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trick.givenName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (trick.technicalName != null &&
                  trick.technicalName!.isNotEmpty &&
                  trick.technicalName != trick.givenName) ...[
                const SizedBox(height: 2),
                Text(
                  trick.technicalName!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const Spacer(),
              if (trick.startPositionName != null ||
                  trick.endPositionName != null)
                Text(
                  _positionText(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListTile(BuildContext context) {
    final theme = Theme.of(context);
    final hasSubtitle = trick.technicalName != null &&
        trick.technicalName!.isNotEmpty &&
        trick.technicalName != trick.givenName;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      clipBehavior: Clip.antiAlias,
      color: consistency?.cardColor,
      child: ListTile(
        dense: true,
        title: Text(
          trick.givenName,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: hasSubtitle
            ? Text(trick.technicalName!,
                style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic))
            : null,
        trailing: (trick.startPositionName != null || trick.endPositionName != null)
            ? Text(
                _positionText(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        onTap: () async {
          await context.push('/trick/${trick.id}');
          onReturn?.call();
        },
      ),
    );
  }

  String _positionText() {
    if (trick.startPositionName != null && trick.endPositionName != null) {
      return '${trick.startPositionName} → ${trick.endPositionName}';
    }
    if (trick.startPositionName != null) return trick.startPositionName!;
    return trick.endPositionName ?? '';
  }
}
