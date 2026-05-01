import '../models/trick_filter.dart';
import '../models/trick_sort.dart';
import '../models/user_trick.dart';
import 'app_localizations.dart';

extension PrimarySortL10n on PrimarySort {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
        PrimarySort.difficulty => l10n.sortLabelDifficultyTier,
        PrimarySort.startPosition => l10n.sortLabelStartPosition,
        PrimarySort.yearLanded => l10n.sortLabelYearLanded,
        PrimarySort.consistency => l10n.sortLabelConsistency,
      };
}

extension SecondarySortL10n on SecondarySort {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
        SecondarySort.difficulty => l10n.sortLabelDifficultyTier,
        SecondarySort.startPosition => l10n.sortLabelStartPosition,
        SecondarySort.endPosition => l10n.sortLabelEndPosition,
        SecondarySort.consistency => l10n.sortLabelConsistency,
        SecondarySort.alphabetical => l10n.sortLabelAlphabetical,
      };
}

extension TrickStatusL10n on TrickStatus {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
        TrickStatus.neverAttempted => l10n.statusNeverAttempted,
        TrickStatus.attempting => l10n.statusAttempting,
        TrickStatus.landed => l10n.statusLandedAtLeastOnce,
      };
}

extension ConsistencyL10n on Consistency {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
        Consistency.never => l10n.statusAttempting,
        Consistency.once => l10n.consistencyOnce,
        Consistency.sometimes => l10n.consistencySometimes,
        Consistency.often => l10n.consistencyOften,
        Consistency.generally => l10n.consistencyGenerally,
        Consistency.always => l10n.consistencyAlways,
      };
}

extension LeashPositionL10n on LeashPosition {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
        LeashPosition.frontside => l10n.leashFrontside,
        LeashPosition.backside => l10n.leashBackside,
        LeashPosition.center => l10n.leashCenter,
      };
}

String translateGroupLabel(String raw, AppLocalizations l10n) {
  if (raw == 'To Be Determined') return l10n.groupToBeDetetermined;
  if (raw == 'Unknown') return l10n.groupUnknown;
  if (raw == 'Never Attempted') return l10n.statusNeverAttempted;
  if (raw == 'Attempting') return l10n.statusAttempting;
  if (raw == 'Landed') return l10n.groupLanded;
  if (raw.startsWith('Difficulty ')) return l10n.groupDifficulty(raw.substring(11));
  return raw;
}
