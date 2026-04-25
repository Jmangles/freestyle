import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/trick.dart';

class TrickCard extends StatelessWidget {
  final Trick trick;

  const TrickCard({super.key, required this.trick});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPositions =
        trick.startPositionName != null || trick.endPositionName != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: () => context.push('/trick/${trick.id}'),
        title: Text(
          trick.givenName,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (trick.technicalName != null &&
                trick.technicalName != trick.givenName)
              Text(
                trick.technicalName!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            if (hasPositions)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  _positionText(),
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  String _positionText() {
    if (trick.startPositionName != null && trick.endPositionName != null) {
      return '${trick.startPositionName} → ${trick.endPositionName}';
    }
    if (trick.startPositionName != null) return 'From: ${trick.startPositionName}';
    if (trick.endPositionName != null) return 'To: ${trick.endPositionName}';
    return '';
  }
}
