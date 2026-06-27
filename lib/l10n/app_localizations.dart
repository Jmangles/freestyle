import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'FreestyleDB'**
  String get appTitle;

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @applyButton.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get applyButton;

  /// No description provided for @addButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addButton;

  /// No description provided for @editButton.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editButton;

  /// No description provided for @deleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteButton;

  /// No description provided for @noneOption.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get noneOption;

  /// No description provided for @anyOption.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get anyOption;

  /// No description provided for @requiredValidator.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredValidator;

  /// No description provided for @backTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backTooltip;

  /// No description provided for @homeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTooltip;

  /// No description provided for @descriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionLabel;

  /// No description provided for @tipsLabel.
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get tipsLabel;

  /// No description provided for @prerequisitesLabel.
  ///
  /// In en, this message translates to:
  /// **'Prerequisites'**
  String get prerequisitesLabel;

  /// No description provided for @originalPerformerLabel.
  ///
  /// In en, this message translates to:
  /// **'Original Performer'**
  String get originalPerformerLabel;

  /// No description provided for @technicalNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Technical Name'**
  String get technicalNameLabel;

  /// No description provided for @difficultyLabel.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get difficultyLabel;

  /// No description provided for @leashPositionLabel.
  ///
  /// In en, this message translates to:
  /// **'Leash Position'**
  String get leashPositionLabel;

  /// No description provided for @loopStartLabel.
  ///
  /// In en, this message translates to:
  /// **'Loop start (s)'**
  String get loopStartLabel;

  /// No description provided for @loopEndLabel.
  ///
  /// In en, this message translates to:
  /// **'Loop end (s)'**
  String get loopEndLabel;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get searchHint;

  /// No description provided for @errorWithDetail.
  ///
  /// In en, this message translates to:
  /// **'Error: {detail}'**
  String errorWithDetail(String detail);

  /// No description provided for @adminLabel.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get adminLabel;

  /// No description provided for @filterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filterTooltip;

  /// No description provided for @profileTooltip.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTooltip;

  /// No description provided for @signInTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signInTooltip;

  /// No description provided for @submitTrickButton.
  ///
  /// In en, this message translates to:
  /// **'Submit Trick'**
  String get submitTrickButton;

  /// No description provided for @failedToLoadTricks.
  ///
  /// In en, this message translates to:
  /// **'Failed to load tricks'**
  String get failedToLoadTricks;

  /// No description provided for @retryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryButton;

  /// No description provided for @noTricksYet.
  ///
  /// In en, this message translates to:
  /// **'No tricks yet. Be the first to submit one!'**
  String get noTricksYet;

  /// No description provided for @searchByNameHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name...'**
  String get searchByNameHint;

  /// No description provided for @trickDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Trick Detail'**
  String get trickDetailTitle;

  /// No description provided for @copyLinkTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLinkTooltip;

  /// No description provided for @linkCopiedMessage.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get linkCopiedMessage;

  /// No description provided for @viewProgressionTooltip.
  ///
  /// In en, this message translates to:
  /// **'View Progression'**
  String get viewProgressionTooltip;

  /// No description provided for @editTrickTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit Trick'**
  String get editTrickTooltip;

  /// No description provided for @deleteTrickTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete Trick'**
  String get deleteTrickTooltip;

  /// No description provided for @deleteTrickDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Trick'**
  String get deleteTrickDialogTitle;

  /// No description provided for @deleteTrickConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? This cannot be undone.'**
  String deleteTrickConfirmMessage(String name);

  /// No description provided for @couldNotOpenVideoLink.
  ///
  /// In en, this message translates to:
  /// **'Could not open video link'**
  String get couldNotOpenVideoLink;

  /// No description provided for @watchVideoButton.
  ///
  /// In en, this message translates to:
  /// **'Watch Video'**
  String get watchVideoButton;

  /// No description provided for @dateFirstPerformedLabel.
  ///
  /// In en, this message translates to:
  /// **'Date First Performed'**
  String get dateFirstPerformedLabel;

  /// No description provided for @dateSubmittedLabel.
  ///
  /// In en, this message translates to:
  /// **'Date Submitted'**
  String get dateSubmittedLabel;

  /// No description provided for @communityVotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Community Votes'**
  String get communityVotesLabel;

  /// No description provided for @myConsistencyLabel.
  ///
  /// In en, this message translates to:
  /// **'My Consistency'**
  String get myConsistencyLabel;

  /// No description provided for @landedDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Landed Details'**
  String get landedDetailsLabel;

  /// No description provided for @allFieldsOptional.
  ///
  /// In en, this message translates to:
  /// **'All fields optional'**
  String get allFieldsOptional;

  /// No description provided for @difficultyVoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Difficulty Vote'**
  String get difficultyVoteLabel;

  /// No description provided for @videoLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Video Link'**
  String get videoLinkLabel;

  /// No description provided for @videoLinkHint.
  ///
  /// In en, this message translates to:
  /// **'https://'**
  String get videoLinkHint;

  /// No description provided for @saveDetailsButton.
  ///
  /// In en, this message translates to:
  /// **'Save details'**
  String get saveDetailsButton;

  /// No description provided for @yourLandingVideoLabel.
  ///
  /// In en, this message translates to:
  /// **'Your Landing Video'**
  String get yourLandingVideoLabel;

  /// No description provided for @editTrickTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Trick'**
  String get editTrickTitle;

  /// No description provided for @submitTrickTitle.
  ///
  /// In en, this message translates to:
  /// **'Submit a Trick'**
  String get submitTrickTitle;

  /// No description provided for @tbdOption.
  ///
  /// In en, this message translates to:
  /// **'TBD'**
  String get tbdOption;

  /// No description provided for @givenNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Given Name'**
  String get givenNameLabel;

  /// No description provided for @difficultyRequiredLabel.
  ///
  /// In en, this message translates to:
  /// **'Difficulty *'**
  String get difficultyRequiredLabel;

  /// No description provided for @startPositionRequiredLabel.
  ///
  /// In en, this message translates to:
  /// **'Start Position *'**
  String get startPositionRequiredLabel;

  /// No description provided for @endPositionRequiredLabel.
  ///
  /// In en, this message translates to:
  /// **'End Position *'**
  String get endPositionRequiredLabel;

  /// No description provided for @dateFirstPerformedOptional.
  ///
  /// In en, this message translates to:
  /// **'Date First Performed (optional)'**
  String get dateFirstPerformedOptional;

  /// No description provided for @dateFirstPerformedWithDate.
  ///
  /// In en, this message translates to:
  /// **'Date First Performed: {date}'**
  String dateFirstPerformedWithDate(String date);

  /// No description provided for @videoLinkUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Video Link (URL)'**
  String get videoLinkUrlLabel;

  /// No description provided for @saveChangesButton.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChangesButton;

  /// No description provided for @submitForReviewButton.
  ///
  /// In en, this message translates to:
  /// **'Submit for Review'**
  String get submitForReviewButton;

  /// No description provided for @trickUpdated.
  ///
  /// In en, this message translates to:
  /// **'Trick updated.'**
  String get trickUpdated;

  /// No description provided for @trickSubmittedForReview.
  ///
  /// In en, this message translates to:
  /// **'Trick submitted for review!'**
  String get trickSubmittedForReview;

  /// No description provided for @similarTricksWarning.
  ///
  /// In en, this message translates to:
  /// **'Tricks with similar names:'**
  String get similarTricksWarning;

  /// No description provided for @selectPrerequisiteTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Prerequisite'**
  String get selectPrerequisiteTitle;

  /// No description provided for @selectBaseTrickTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Base Trick'**
  String get selectBaseTrickTitle;

  /// No description provided for @variationOfLabel.
  ///
  /// In en, this message translates to:
  /// **'Variation of'**
  String get variationOfLabel;

  /// No description provided for @variationsLabel.
  ///
  /// In en, this message translates to:
  /// **'Variations'**
  String get variationsLabel;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @signOutTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOutTooltip;

  /// No description provided for @signOutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get signOutConfirmMessage;

  /// No description provided for @unknownUser.
  ///
  /// In en, this message translates to:
  /// **'Unknown User'**
  String get unknownUser;

  /// No description provided for @darkModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkModeLabel;

  /// No description provided for @myTricksCount.
  ///
  /// In en, this message translates to:
  /// **'My Tricks ({count})'**
  String myTricksCount(int count);

  /// No description provided for @noTricksTracked.
  ///
  /// In en, this message translates to:
  /// **'No tricks tracked yet.\nBrowse the trick list and set your consistency!'**
  String get noTricksTracked;

  /// No description provided for @resetPasswordDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPasswordDialogTitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @sendResetLinkButton.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get sendResetLinkButton;

  /// No description provided for @passwordResetEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent — check your inbox.'**
  String get passwordResetEmailSent;

  /// No description provided for @signInToYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your account'**
  String get signInToYourAccount;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @enterYourEmailValidator.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get enterYourEmailValidator;

  /// No description provided for @enterYourPasswordValidator.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterYourPasswordValidator;

  /// No description provided for @signInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signInButton;

  /// No description provided for @dontHaveAccountRegister.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Register'**
  String get dontHaveAccountRegister;

  /// No description provided for @createAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccountTitle;

  /// No description provided for @usernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameLabel;

  /// No description provided for @enterUsernameValidator.
  ///
  /// In en, this message translates to:
  /// **'Enter a username'**
  String get enterUsernameValidator;

  /// No description provided for @enterPasswordValidator.
  ///
  /// In en, this message translates to:
  /// **'Enter a password'**
  String get enterPasswordValidator;

  /// No description provided for @minimumSixCharsValidator.
  ///
  /// In en, this message translates to:
  /// **'Minimum 6 characters'**
  String get minimumSixCharsValidator;

  /// No description provided for @registerButton.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get registerButton;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get alreadyHaveAccount;

  /// No description provided for @accountCreated.
  ///
  /// In en, this message translates to:
  /// **'Account created! Check your email to confirm, then sign in.'**
  String get accountCreated;

  /// No description provided for @setNewPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Set New Password'**
  String get setNewPasswordTitle;

  /// No description provided for @chooseNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password for your account.'**
  String get chooseNewPassword;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPasswordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPasswordLabel;

  /// No description provided for @enterNewPasswordValidator.
  ///
  /// In en, this message translates to:
  /// **'Enter a new password'**
  String get enterNewPasswordValidator;

  /// No description provided for @passwordMinSixCharsValidator.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordMinSixCharsValidator;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @updatePasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Update Password'**
  String get updatePasswordButton;

  /// No description provided for @passwordUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Password updated successfully.'**
  String get passwordUpdatedSuccessfully;

  /// No description provided for @adminTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get adminTitle;

  /// No description provided for @addPositionTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add Position'**
  String get addPositionTooltip;

  /// No description provided for @addPositionDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Position'**
  String get addPositionDialogTitle;

  /// No description provided for @addPositionHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Standing, Hanging'**
  String get addPositionHint;

  /// No description provided for @positionAdded.
  ///
  /// In en, this message translates to:
  /// **'Position \"{name}\" added.'**
  String positionAdded(String name);

  /// No description provided for @noAdminAccess.
  ///
  /// In en, this message translates to:
  /// **'You do not have admin access.'**
  String get noAdminAccess;

  /// No description provided for @noPendingTricks.
  ///
  /// In en, this message translates to:
  /// **'No pending tricks.'**
  String get noPendingTricks;

  /// No description provided for @performerLabel.
  ///
  /// In en, this message translates to:
  /// **'Performer'**
  String get performerLabel;

  /// No description provided for @videoLabel.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get videoLabel;

  /// No description provided for @approveButton.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approveButton;

  /// No description provided for @rejectButton.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get rejectButton;

  /// No description provided for @submittedDate.
  ///
  /// In en, this message translates to:
  /// **'submitted {date}'**
  String submittedDate(String date);

  /// No description provided for @trickProgressionTitle.
  ///
  /// In en, this message translates to:
  /// **'Trick Progression'**
  String get trickProgressionTitle;

  /// No description provided for @noPrerequisitesFound.
  ///
  /// In en, this message translates to:
  /// **'No prerequisites or unlocked tricks found.'**
  String get noPrerequisitesFound;

  /// No description provided for @thisTrickLegend.
  ///
  /// In en, this message translates to:
  /// **'This trick'**
  String get thisTrickLegend;

  /// No description provided for @youveLandedThisLegend.
  ///
  /// In en, this message translates to:
  /// **'You\'ve landed this'**
  String get youveLandedThisLegend;

  /// No description provided for @notYetLandedLegend.
  ///
  /// In en, this message translates to:
  /// **'Not yet landed'**
  String get notYetLandedLegend;

  /// No description provided for @landedViaVariationLegend.
  ///
  /// In en, this message translates to:
  /// **'Landed via variation'**
  String get landedViaVariationLegend;

  /// No description provided for @pinchToZoom.
  ///
  /// In en, this message translates to:
  /// **'Pinch to zoom · Drag to pan'**
  String get pinchToZoom;

  /// No description provided for @filterTricksTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter Tricks'**
  String get filterTricksTitle;

  /// No description provided for @clearAllButton.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAllButton;

  /// No description provided for @difficultyTierSection.
  ///
  /// In en, this message translates to:
  /// **'Difficulty Tier'**
  String get difficultyTierSection;

  /// No description provided for @tierRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Tier {tier}'**
  String tierRangeLabel(String tier);

  /// No description provided for @positionSection.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get positionSection;

  /// No description provided for @startLabel.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startLabel;

  /// No description provided for @endLabel.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get endLabel;

  /// No description provided for @statusSection.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusSection;

  /// No description provided for @yearLandedSection.
  ///
  /// In en, this message translates to:
  /// **'Year Landed'**
  String get yearLandedSection;

  /// No description provided for @includeTbdChip.
  ///
  /// In en, this message translates to:
  /// **'Include TBD'**
  String get includeTbdChip;

  /// No description provided for @searchByPerformerHint.
  ///
  /// In en, this message translates to:
  /// **'Search by performer...'**
  String get searchByPerformerHint;

  /// No description provided for @sortTricksTitle.
  ///
  /// In en, this message translates to:
  /// **'Sort Tricks'**
  String get sortTricksTitle;

  /// No description provided for @orderSection.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get orderSection;

  /// No description provided for @ascendingOption.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get ascendingOption;

  /// No description provided for @descendingOption.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get descendingOption;

  /// No description provided for @groupBySection.
  ///
  /// In en, this message translates to:
  /// **'Group By'**
  String get groupBySection;

  /// No description provided for @sortWithinGroupBySection.
  ///
  /// In en, this message translates to:
  /// **'Sort Within Group By'**
  String get sortWithinGroupBySection;

  /// No description provided for @sortLabelDifficultyTier.
  ///
  /// In en, this message translates to:
  /// **'Difficulty Tier'**
  String get sortLabelDifficultyTier;

  /// No description provided for @sortLabelStartPosition.
  ///
  /// In en, this message translates to:
  /// **'Start Position'**
  String get sortLabelStartPosition;

  /// No description provided for @sortLabelYearLanded.
  ///
  /// In en, this message translates to:
  /// **'Year Landed'**
  String get sortLabelYearLanded;

  /// No description provided for @sortLabelConsistency.
  ///
  /// In en, this message translates to:
  /// **'Consistency'**
  String get sortLabelConsistency;

  /// No description provided for @sortLabelEndPosition.
  ///
  /// In en, this message translates to:
  /// **'End Position'**
  String get sortLabelEndPosition;

  /// No description provided for @sortLabelAlphabetical.
  ///
  /// In en, this message translates to:
  /// **'Alphabetical'**
  String get sortLabelAlphabetical;

  /// No description provided for @statusNeverAttempted.
  ///
  /// In en, this message translates to:
  /// **'Never Attempted'**
  String get statusNeverAttempted;

  /// No description provided for @statusAttempting.
  ///
  /// In en, this message translates to:
  /// **'Attempting'**
  String get statusAttempting;

  /// No description provided for @statusLandedAtLeastOnce.
  ///
  /// In en, this message translates to:
  /// **'Landed at least once'**
  String get statusLandedAtLeastOnce;

  /// No description provided for @consistencyOnce.
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get consistencyOnce;

  /// No description provided for @consistencySometimes.
  ///
  /// In en, this message translates to:
  /// **'Sometimes'**
  String get consistencySometimes;

  /// No description provided for @consistencyOften.
  ///
  /// In en, this message translates to:
  /// **'Often'**
  String get consistencyOften;

  /// No description provided for @consistencyGenerally.
  ///
  /// In en, this message translates to:
  /// **'Generally'**
  String get consistencyGenerally;

  /// No description provided for @consistencyAlways.
  ///
  /// In en, this message translates to:
  /// **'Always'**
  String get consistencyAlways;

  /// No description provided for @leashFrontside.
  ///
  /// In en, this message translates to:
  /// **'Frontside'**
  String get leashFrontside;

  /// No description provided for @leashBackside.
  ///
  /// In en, this message translates to:
  /// **'Backside'**
  String get leashBackside;

  /// No description provided for @leashCenter.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get leashCenter;

  /// No description provided for @suggestEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Suggest Edit'**
  String get suggestEditTooltip;

  /// No description provided for @suggestEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Suggest Edit'**
  String get suggestEditTitle;

  /// No description provided for @suggestChangesButton.
  ///
  /// In en, this message translates to:
  /// **'Suggest Changes'**
  String get suggestChangesButton;

  /// No description provided for @suggestionSubmittedForReview.
  ///
  /// In en, this message translates to:
  /// **'Suggestion submitted for review!'**
  String get suggestionSubmittedForReview;

  /// No description provided for @suggestionNoChanges.
  ///
  /// In en, this message translates to:
  /// **'No changes detected — edit at least one field to suggest.'**
  String get suggestionNoChanges;

  /// No description provided for @pendingSuggestionsSection.
  ///
  /// In en, this message translates to:
  /// **'Pending Suggestions'**
  String get pendingSuggestionsSection;

  /// No description provided for @noPendingSuggestions.
  ///
  /// In en, this message translates to:
  /// **'No pending suggestions.'**
  String get noPendingSuggestions;

  /// No description provided for @forTrickLabel.
  ///
  /// In en, this message translates to:
  /// **'For: {name}'**
  String forTrickLabel(String name);

  /// No description provided for @groupToBeDetetermined.
  ///
  /// In en, this message translates to:
  /// **'To Be Determined'**
  String get groupToBeDetetermined;

  /// No description provided for @groupDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty {tier}'**
  String groupDifficulty(String tier);

  /// No description provided for @groupUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get groupUnknown;

  /// No description provided for @groupLanded.
  ///
  /// In en, this message translates to:
  /// **'Landed'**
  String get groupLanded;

  /// No description provided for @tricksNavLabel.
  ///
  /// In en, this message translates to:
  /// **'Tricks'**
  String get tricksNavLabel;

  /// No description provided for @tipsNavLabel.
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get tipsNavLabel;

  /// No description provided for @tipTypeGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get tipTypeGeneral;

  /// No description provided for @tipTypeRigging.
  ///
  /// In en, this message translates to:
  /// **'Rigging'**
  String get tipTypeRigging;

  /// No description provided for @tipTypeHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get tipTypeHealth;

  /// No description provided for @allTypesFilter.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allTypesFilter;

  /// No description provided for @submitTipButton.
  ///
  /// In en, this message translates to:
  /// **'Submit Tip'**
  String get submitTipButton;

  /// No description provided for @submitTipTitle.
  ///
  /// In en, this message translates to:
  /// **'Submit a Tip'**
  String get submitTipTitle;

  /// No description provided for @editTipTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Tip'**
  String get editTipTitle;

  /// No description provided for @failedToLoadTips.
  ///
  /// In en, this message translates to:
  /// **'Failed to load tips'**
  String get failedToLoadTips;

  /// No description provided for @noTipsYet.
  ///
  /// In en, this message translates to:
  /// **'No tips yet. Be the first to submit one!'**
  String get noTipsYet;

  /// No description provided for @noMatchingTricks.
  ///
  /// In en, this message translates to:
  /// **'No tricks match your search.'**
  String get noMatchingTricks;

  /// No description provided for @pageNotFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find that page.'**
  String get pageNotFound;

  /// No description provided for @goHomeButton.
  ///
  /// In en, this message translates to:
  /// **'Go home'**
  String get goHomeButton;

  /// No description provided for @tipBodyLabel.
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get tipBodyLabel;

  /// No description provided for @tipTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get tipTitleLabel;

  /// No description provided for @tipHeaderLabel.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get tipHeaderLabel;

  /// No description provided for @tipTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get tipTypeLabel;

  /// No description provided for @tipSubmittedForReview.
  ///
  /// In en, this message translates to:
  /// **'Tip submitted for review!'**
  String get tipSubmittedForReview;

  /// No description provided for @tipUpdated.
  ///
  /// In en, this message translates to:
  /// **'Tip updated.'**
  String get tipUpdated;

  /// No description provided for @noPendingTips.
  ///
  /// In en, this message translates to:
  /// **'No pending tips.'**
  String get noPendingTips;

  /// No description provided for @pendingTipsSection.
  ///
  /// In en, this message translates to:
  /// **'Pending Tips'**
  String get pendingTipsSection;

  /// No description provided for @declineButton.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get declineButton;

  /// No description provided for @submittedOnLabel.
  ///
  /// In en, this message translates to:
  /// **'Submitted on {date}'**
  String submittedOnLabel(String date);

  /// No description provided for @closeButton.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeButton;

  /// No description provided for @tricksByTierTitle.
  ///
  /// In en, this message translates to:
  /// **'TRICKS BY TIER'**
  String get tricksByTierTitle;

  /// No description provided for @coloredByConsistency.
  ///
  /// In en, this message translates to:
  /// **'· Colored by Consistency'**
  String get coloredByConsistency;

  /// No description provided for @columnTrick.
  ///
  /// In en, this message translates to:
  /// **'TRICK'**
  String get columnTrick;

  /// No description provided for @columnTier.
  ///
  /// In en, this message translates to:
  /// **'TIER'**
  String get columnTier;

  /// No description provided for @columnConsistency.
  ///
  /// In en, this message translates to:
  /// **'CONSISTENCY'**
  String get columnConsistency;

  /// No description provided for @columnUnlocks.
  ///
  /// In en, this message translates to:
  /// **'UNLOCKS'**
  String get columnUnlocks;

  /// No description provided for @tabMyTricks.
  ///
  /// In en, this message translates to:
  /// **'My Tricks'**
  String get tabMyTricks;

  /// No description provided for @tabReadyToStart.
  ///
  /// In en, this message translates to:
  /// **'Ready to Start'**
  String get tabReadyToStart;

  /// No description provided for @tabMakingProgress.
  ///
  /// In en, this message translates to:
  /// **'Making Progress'**
  String get tabMakingProgress;

  /// No description provided for @tabHighValue.
  ///
  /// In en, this message translates to:
  /// **'High Value'**
  String get tabHighValue;

  /// No description provided for @tabReadyToStartDesc.
  ///
  /// In en, this message translates to:
  /// **'All prerequisites met — start working on these'**
  String get tabReadyToStartDesc;

  /// No description provided for @tabMakingProgressDesc.
  ///
  /// In en, this message translates to:
  /// **'You have at least one prerequisite for these'**
  String get tabMakingProgressDesc;

  /// No description provided for @tabHighValueDesc.
  ///
  /// In en, this message translates to:
  /// **'Landing these unlocks the most new tricks'**
  String get tabHighValueDesc;

  /// No description provided for @tricksProgress.
  ///
  /// In en, this message translates to:
  /// **'{landedCount} tricks landed, {attemptingCount} tricks in progress'**
  String tricksProgress(int landedCount, int attemptingCount);

  /// No description provided for @coreTrickLabel.
  ///
  /// In en, this message translates to:
  /// **'Core trick'**
  String get coreTrickLabel;

  /// No description provided for @coreTrickSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shown in the foundational tricks filter'**
  String get coreTrickSubtitle;

  /// No description provided for @coreOnlyFilter.
  ///
  /// In en, this message translates to:
  /// **'Core tricks only'**
  String get coreOnlyFilter;

  /// No description provided for @hideVariationsFilter.
  ///
  /// In en, this message translates to:
  /// **'Hide Variations'**
  String get hideVariationsFilter;

  /// No description provided for @pointScoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Points'**
  String get pointScoreLabel;

  /// No description provided for @levelLabel.
  ///
  /// In en, this message translates to:
  /// **'Level {level}'**
  String levelLabel(int level);

  /// No description provided for @ptsToNextLevel.
  ///
  /// In en, this message translates to:
  /// **'{pts} pts to Lv. {next}'**
  String ptsToNextLevel(int pts, int next);

  /// No description provided for @editorToolsSection.
  ///
  /// In en, this message translates to:
  /// **'Editor Tools'**
  String get editorToolsSection;

  /// No description provided for @editorModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Content Review Mode'**
  String get editorModeLabel;

  /// No description provided for @editorModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Highlight missing content on trick cards'**
  String get editorModeSubtitle;

  /// No description provided for @editorMissingPrefix.
  ///
  /// In en, this message translates to:
  /// **'Missing:'**
  String get editorMissingPrefix;

  /// No description provided for @editorAllPresent.
  ///
  /// In en, this message translates to:
  /// **'All fields present'**
  String get editorAllPresent;

  /// No description provided for @editorVariationBaseNotPrereq.
  ///
  /// In en, this message translates to:
  /// **'Variation base not listed as prerequisite'**
  String get editorVariationBaseNotPrereq;

  /// No description provided for @editorShowOnlyMissing.
  ///
  /// In en, this message translates to:
  /// **'Show only tricks missing:'**
  String get editorShowOnlyMissing;

  /// No description provided for @trainingStudioTitle.
  ///
  /// In en, this message translates to:
  /// **'Training Studio'**
  String get trainingStudioTitle;

  /// No description provided for @removeFromDevice.
  ///
  /// In en, this message translates to:
  /// **'Remove from device'**
  String get removeFromDevice;

  /// No description provided for @saveToDeviceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Save to device'**
  String get saveToDeviceTooltip;

  /// No description provided for @couldNotDeleteAnnotation.
  ///
  /// In en, this message translates to:
  /// **'Could not delete annotation: {error}'**
  String couldNotDeleteAnnotation(String error);

  /// No description provided for @couldNotSaveAnnotation.
  ///
  /// In en, this message translates to:
  /// **'Could not save annotation: {error}'**
  String couldNotSaveAnnotation(String error);

  /// No description provided for @noSavedVideoOffline.
  ///
  /// In en, this message translates to:
  /// **'No saved video available offline.'**
  String get noSavedVideoOffline;

  /// No description provided for @cachedVideoCleared.
  ///
  /// In en, this message translates to:
  /// **'Cached video was cleared — reopen the training studio to re-download'**
  String get cachedVideoCleared;

  /// No description provided for @couldNotSaveVideo.
  ///
  /// In en, this message translates to:
  /// **'Could not save video: {error}'**
  String couldNotSaveVideo(String error);

  /// No description provided for @couldNotDeleteVideo.
  ///
  /// In en, this message translates to:
  /// **'Could not delete video: {error}'**
  String couldNotDeleteVideo(String error);

  /// No description provided for @annotationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Annotations'**
  String get annotationsTitle;

  /// No description provided for @addAtTime.
  ///
  /// In en, this message translates to:
  /// **'Add at {time}'**
  String addAtTime(String time);

  /// No description provided for @noAnnotationsYet.
  ///
  /// In en, this message translates to:
  /// **'No annotations yet'**
  String get noAnnotationsYet;

  /// No description provided for @addAnnotationTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Annotation'**
  String get addAnnotationTitle;

  /// No description provided for @editAnnotationTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Annotation'**
  String get editAnnotationTitle;

  /// No description provided for @annotationTextLabel.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get annotationTextLabel;

  /// No description provided for @annotationStartLabel.
  ///
  /// In en, this message translates to:
  /// **'Start (s)'**
  String get annotationStartLabel;

  /// No description provided for @annotationEndLabel.
  ///
  /// In en, this message translates to:
  /// **'End (s)'**
  String get annotationEndLabel;

  /// No description provided for @annotationLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get annotationLanguageLabel;

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// No description provided for @lowStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'Low storage'**
  String get lowStorageTitle;

  /// No description provided for @lowStorageMessage.
  ///
  /// In en, this message translates to:
  /// **'Less than 1 GB of storage is available. Continue anyway?'**
  String get lowStorageMessage;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @deleteVideoMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete the saved video from your device?'**
  String get deleteVideoMessage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
