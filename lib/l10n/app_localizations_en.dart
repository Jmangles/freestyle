// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'FreestyleDB';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get applyButton => 'Apply';

  @override
  String get addButton => 'Add';

  @override
  String get editButton => 'Edit';

  @override
  String get deleteButton => 'Delete';

  @override
  String get noneOption => 'None';

  @override
  String get anyOption => 'Any';

  @override
  String get requiredValidator => 'Required';

  @override
  String get backTooltip => 'Back';

  @override
  String get homeTooltip => 'Home';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get tipsLabel => 'Tips';

  @override
  String get prerequisitesLabel => 'Prerequisites';

  @override
  String get originalPerformerLabel => 'Original Performer';

  @override
  String get technicalNameLabel => 'Technical Name';

  @override
  String get difficultyLabel => 'Difficulty';

  @override
  String get leashPositionLabel => 'Leash Position';

  @override
  String get loopStartLabel => 'Loop start (s)';

  @override
  String get loopEndLabel => 'Loop end (s)';

  @override
  String get searchHint => 'Search...';

  @override
  String errorWithDetail(String detail) {
    return 'Error: $detail';
  }

  @override
  String get adminLabel => 'Admin';

  @override
  String get filterTooltip => 'Filter';

  @override
  String get profileTooltip => 'Profile';

  @override
  String get signInTooltip => 'Sign In';

  @override
  String get submitTrickButton => 'Submit Trick';

  @override
  String get failedToLoadTricks => 'Failed to load tricks';

  @override
  String get retryButton => 'Retry';

  @override
  String get noTricksYet => 'No tricks yet. Be the first to submit one!';

  @override
  String get searchByNameHint => 'Search by name...';

  @override
  String get trickDetailTitle => 'Trick Detail';

  @override
  String get viewProgressionTooltip => 'View Progression';

  @override
  String get editTrickTooltip => 'Edit Trick';

  @override
  String get deleteTrickTooltip => 'Delete Trick';

  @override
  String get deleteTrickDialogTitle => 'Delete Trick';

  @override
  String deleteTrickConfirmMessage(String name) {
    return 'Are you sure you want to delete \"$name\"? This cannot be undone.';
  }

  @override
  String get couldNotOpenVideoLink => 'Could not open video link';

  @override
  String get watchVideoButton => 'Watch Video';

  @override
  String get dateFirstPerformedLabel => 'Date First Performed';

  @override
  String get dateSubmittedLabel => 'Date Submitted';

  @override
  String get communityVotesLabel => 'Community Votes';

  @override
  String get myConsistencyLabel => 'My Consistency';

  @override
  String get landedDetailsLabel => 'Landed Details';

  @override
  String get allFieldsOptional => 'All fields optional';

  @override
  String get difficultyVoteLabel => 'Difficulty Vote';

  @override
  String get videoLinkLabel => 'Video Link';

  @override
  String get videoLinkHint => 'https://';

  @override
  String get saveDetailsButton => 'Save details';

  @override
  String get yourLandingVideoLabel => 'Your Landing Video';

  @override
  String get editTrickTitle => 'Edit Trick';

  @override
  String get submitTrickTitle => 'Submit a Trick';

  @override
  String get tbdOption => 'TBD';

  @override
  String get givenNameLabel => 'Given Name';

  @override
  String get difficultyRequiredLabel => 'Difficulty *';

  @override
  String get startPositionRequiredLabel => 'Start Position *';

  @override
  String get endPositionRequiredLabel => 'End Position *';

  @override
  String get dateFirstPerformedOptional => 'Date First Performed (optional)';

  @override
  String dateFirstPerformedWithDate(String date) {
    return 'Date First Performed: $date';
  }

  @override
  String get videoLinkUrlLabel => 'Video Link (URL)';

  @override
  String get saveChangesButton => 'Save Changes';

  @override
  String get submitForReviewButton => 'Submit for Review';

  @override
  String get trickUpdated => 'Trick updated.';

  @override
  String get trickSubmittedForReview => 'Trick submitted for review!';

  @override
  String get similarTricksWarning => 'Tricks with similar names:';

  @override
  String get selectPrerequisiteTitle => 'Select Prerequisite';

  @override
  String get profileTitle => 'Profile';

  @override
  String get signOutTooltip => 'Sign Out';

  @override
  String get unknownUser => 'Unknown User';

  @override
  String get darkModeLabel => 'Dark Mode';

  @override
  String myTricksCount(int count) {
    return 'My Tricks ($count)';
  }

  @override
  String get noTricksTracked =>
      'No tricks tracked yet.\nBrowse the trick list and set your consistency!';

  @override
  String get resetPasswordDialogTitle => 'Reset Password';

  @override
  String get emailLabel => 'Email';

  @override
  String get sendResetLinkButton => 'Send Reset Link';

  @override
  String get passwordResetEmailSent =>
      'Password reset email sent — check your inbox.';

  @override
  String get signInToYourAccount => 'Sign in to your account';

  @override
  String get passwordLabel => 'Password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get enterYourEmailValidator => 'Enter your email';

  @override
  String get enterYourPasswordValidator => 'Enter your password';

  @override
  String get signInButton => 'Sign In';

  @override
  String get dontHaveAccountRegister => 'Don\'t have an account? Register';

  @override
  String get createAccountTitle => 'Create Account';

  @override
  String get usernameLabel => 'Username';

  @override
  String get enterUsernameValidator => 'Enter a username';

  @override
  String get enterPasswordValidator => 'Enter a password';

  @override
  String get minimumSixCharsValidator => 'Minimum 6 characters';

  @override
  String get registerButton => 'Register';

  @override
  String get alreadyHaveAccount => 'Already have an account? Sign in';

  @override
  String get accountCreated =>
      'Account created! Check your email to confirm, then sign in.';

  @override
  String get setNewPasswordTitle => 'Set New Password';

  @override
  String get chooseNewPassword => 'Choose a new password for your account.';

  @override
  String get newPasswordLabel => 'New Password';

  @override
  String get confirmPasswordLabel => 'Confirm Password';

  @override
  String get enterNewPasswordValidator => 'Enter a new password';

  @override
  String get passwordMinSixCharsValidator =>
      'Password must be at least 6 characters';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get updatePasswordButton => 'Update Password';

  @override
  String get passwordUpdatedSuccessfully => 'Password updated successfully.';

  @override
  String get adminTitle => 'Admin';

  @override
  String get addPositionTooltip => 'Add Position';

  @override
  String get addPositionDialogTitle => 'Add Position';

  @override
  String get addPositionHint => 'e.g. Standing, Hanging';

  @override
  String positionAdded(String name) {
    return 'Position \"$name\" added.';
  }

  @override
  String get noAdminAccess => 'You do not have admin access.';

  @override
  String get noPendingTricks => 'No pending tricks.';

  @override
  String get performerLabel => 'Performer';

  @override
  String get videoLabel => 'Video';

  @override
  String get approveButton => 'Approve';

  @override
  String get rejectButton => 'Reject';

  @override
  String submittedDate(String date) {
    return 'submitted $date';
  }

  @override
  String get trickProgressionTitle => 'Trick Progression';

  @override
  String get noPrerequisitesFound =>
      'No prerequisites or unlocked tricks found.';

  @override
  String get thisTrickLegend => 'This trick';

  @override
  String get youveLandedThisLegend => 'You\'ve landed this';

  @override
  String get notYetLandedLegend => 'Not yet landed';

  @override
  String get pinchToZoom => 'Pinch to zoom · Drag to pan';

  @override
  String get filterTricksTitle => 'Filter Tricks';

  @override
  String get clearAllButton => 'Clear All';

  @override
  String get difficultyTierSection => 'Difficulty Tier';

  @override
  String tierRangeLabel(String tier) {
    return 'Tier $tier';
  }

  @override
  String get positionSection => 'Position';

  @override
  String get startLabel => 'Start';

  @override
  String get endLabel => 'End';

  @override
  String get statusSection => 'Status';

  @override
  String get yearLandedSection => 'Year Landed';

  @override
  String get includeTbdChip => 'Include TBD';

  @override
  String get searchByPerformerHint => 'Search by performer...';

  @override
  String get sortTricksTitle => 'Sort Tricks';

  @override
  String get orderSection => 'Order';

  @override
  String get ascendingOption => 'Ascending';

  @override
  String get descendingOption => 'Descending';

  @override
  String get groupBySection => 'Group By';

  @override
  String get sortWithinGroupBySection => 'Sort Within Group By';

  @override
  String get sortLabelDifficultyTier => 'Difficulty Tier';

  @override
  String get sortLabelStartPosition => 'Start Position';

  @override
  String get sortLabelYearLanded => 'Year Landed';

  @override
  String get sortLabelConsistency => 'Consistency';

  @override
  String get sortLabelEndPosition => 'End Position';

  @override
  String get sortLabelAlphabetical => 'Alphabetical';

  @override
  String get statusNeverAttempted => 'Never Attempted';

  @override
  String get statusAttempting => 'Attempting';

  @override
  String get statusLandedAtLeastOnce => 'Landed at least once';

  @override
  String get consistencyOnce => 'Once';

  @override
  String get consistencySometimes => 'Sometimes';

  @override
  String get consistencyOften => 'Often';

  @override
  String get consistencyGenerally => 'Generally';

  @override
  String get consistencyAlways => 'Always';

  @override
  String get leashFrontside => 'Frontside';

  @override
  String get leashBackside => 'Backside';

  @override
  String get leashCenter => 'Center';

  @override
  String get groupToBeDetetermined => 'To Be Determined';

  @override
  String groupDifficulty(String tier) {
    return 'Difficulty $tier';
  }

  @override
  String get groupUnknown => 'Unknown';

  @override
  String get groupLanded => 'Landed';
}
