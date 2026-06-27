// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'FreestyleDB';

  @override
  String get cancelButton => 'Annuler';

  @override
  String get applyButton => 'Appliquer';

  @override
  String get addButton => 'Ajouter';

  @override
  String get editButton => 'Modifier';

  @override
  String get deleteButton => 'Supprimer';

  @override
  String get noneOption => 'Aucun';

  @override
  String get anyOption => 'Tous';

  @override
  String get requiredValidator => 'Requis';

  @override
  String get backTooltip => 'Retour';

  @override
  String get homeTooltip => 'Accueil';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get tipsLabel => 'Conseils';

  @override
  String get prerequisitesLabel => 'Prérequis';

  @override
  String get originalPerformerLabel => 'Performeur d\'origine';

  @override
  String get technicalNameLabel => 'Nom technique';

  @override
  String get difficultyLabel => 'Difficulté';

  @override
  String get leashPositionLabel => 'Position de laisse';

  @override
  String get loopStartLabel => 'Début de boucle (s)';

  @override
  String get loopEndLabel => 'Fin de boucle (s)';

  @override
  String get searchHint => 'Rechercher...';

  @override
  String errorWithDetail(String detail) {
    return 'Erreur : $detail';
  }

  @override
  String get adminLabel => 'Admin';

  @override
  String get filterTooltip => 'Filtrer';

  @override
  String get profileTooltip => 'Profil';

  @override
  String get signInTooltip => 'Se connecter';

  @override
  String get submitTrickButton => 'Soumettre un trick';

  @override
  String get failedToLoadTricks => 'Échec du chargement des tricks';

  @override
  String get retryButton => 'Réessayer';

  @override
  String get noTricksYet =>
      'Aucun trick pour l\'instant. Soyez le premier à en soumettre un !';

  @override
  String get searchByNameHint => 'Rechercher par nom...';

  @override
  String get trickDetailTitle => 'Détail du trick';

  @override
  String get copyLinkTooltip => 'Copier le lien';

  @override
  String get linkCopiedMessage => 'Lien copié';

  @override
  String get viewProgressionTooltip => 'Voir la progression';

  @override
  String get editTrickTooltip => 'Modifier le trick';

  @override
  String get deleteTrickTooltip => 'Supprimer le trick';

  @override
  String get deleteTrickDialogTitle => 'Supprimer le trick';

  @override
  String deleteTrickConfirmMessage(String name) {
    return 'Êtes-vous sûr de vouloir supprimer \"$name\" ? Cette action est irréversible.';
  }

  @override
  String get couldNotOpenVideoLink => 'Impossible d\'ouvrir le lien vidéo';

  @override
  String get watchVideoButton => 'Regarder la vidéo';

  @override
  String get dateFirstPerformedLabel => 'Date de première réalisation';

  @override
  String get dateSubmittedLabel => 'Date de soumission';

  @override
  String get communityVotesLabel => 'Votes de la communauté';

  @override
  String get myConsistencyLabel => 'Ma constance';

  @override
  String get landedDetailsLabel => 'Détails de réception';

  @override
  String get allFieldsOptional => 'Tous les champs sont optionnels';

  @override
  String get difficultyVoteLabel => 'Vote de difficulté';

  @override
  String get videoLinkLabel => 'Lien vidéo';

  @override
  String get videoLinkHint => 'https://';

  @override
  String get saveDetailsButton => 'Enregistrer les détails';

  @override
  String get yourLandingVideoLabel => 'Votre vidéo de réception';

  @override
  String get editTrickTitle => 'Modifier le trick';

  @override
  String get submitTrickTitle => 'Soumettre un trick';

  @override
  String get tbdOption => 'À définir';

  @override
  String get givenNameLabel => 'Nom donné';

  @override
  String get difficultyRequiredLabel => 'Difficulté *';

  @override
  String get startPositionRequiredLabel => 'Position de départ *';

  @override
  String get endPositionRequiredLabel => 'Position d\'arrivée *';

  @override
  String get dateFirstPerformedOptional =>
      'Date de première réalisation (optionnel)';

  @override
  String dateFirstPerformedWithDate(String date) {
    return 'Date de première réalisation : $date';
  }

  @override
  String get videoLinkUrlLabel => 'Lien vidéo (URL)';

  @override
  String get saveChangesButton => 'Enregistrer les modifications';

  @override
  String get submitForReviewButton => 'Soumettre pour révision';

  @override
  String get trickUpdated => 'Trick mis à jour.';

  @override
  String get trickSubmittedForReview => 'Trick soumis pour révision !';

  @override
  String get similarTricksWarning => 'Tricks avec des noms similaires :';

  @override
  String get selectPrerequisiteTitle => 'Sélectionner un prérequis';

  @override
  String get selectBaseTrickTitle => 'Sélectionner le trick de base';

  @override
  String get variationOfLabel => 'Variation de';

  @override
  String get variationsLabel => 'Variations';

  @override
  String get profileTitle => 'Profil';

  @override
  String get signOutTooltip => 'Se déconnecter';

  @override
  String get signOutConfirmMessage =>
      'Êtes-vous sûr de vouloir vous déconnecter ?';

  @override
  String get unknownUser => 'Utilisateur inconnu';

  @override
  String get darkModeLabel => 'Mode sombre';

  @override
  String myTricksCount(int count) {
    return 'Mes tricks ($count)';
  }

  @override
  String get noTricksTracked =>
      'Aucun trick suivi pour l\'instant.\nParcourez la liste et définissez votre constance !';

  @override
  String get resetPasswordDialogTitle => 'Réinitialiser le mot de passe';

  @override
  String get emailLabel => 'E-mail';

  @override
  String get sendResetLinkButton => 'Envoyer le lien de réinitialisation';

  @override
  String get passwordResetEmailSent =>
      'E-mail de réinitialisation envoyé — vérifiez votre boîte de réception.';

  @override
  String get signInToYourAccount => 'Connectez-vous à votre compte';

  @override
  String get passwordLabel => 'Mot de passe';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get enterYourEmailValidator => 'Saisissez votre e-mail';

  @override
  String get enterYourPasswordValidator => 'Saisissez votre mot de passe';

  @override
  String get signInButton => 'Se connecter';

  @override
  String get dontHaveAccountRegister => 'Pas encore de compte ? S\'inscrire';

  @override
  String get createAccountTitle => 'Créer un compte';

  @override
  String get usernameLabel => 'Nom d\'utilisateur';

  @override
  String get enterUsernameValidator => 'Saisissez un nom d\'utilisateur';

  @override
  String get enterPasswordValidator => 'Saisissez un mot de passe';

  @override
  String get minimumSixCharsValidator => 'Minimum 6 caractères';

  @override
  String get registerButton => 'S\'inscrire';

  @override
  String get alreadyHaveAccount => 'Vous avez déjà un compte ? Se connecter';

  @override
  String get accountCreated =>
      'Compte créé ! Vérifiez votre e-mail pour confirmer, puis connectez-vous.';

  @override
  String get setNewPasswordTitle => 'Définir un nouveau mot de passe';

  @override
  String get chooseNewPassword =>
      'Choisissez un nouveau mot de passe pour votre compte.';

  @override
  String get newPasswordLabel => 'Nouveau mot de passe';

  @override
  String get confirmPasswordLabel => 'Confirmer le mot de passe';

  @override
  String get enterNewPasswordValidator => 'Saisissez un nouveau mot de passe';

  @override
  String get passwordMinSixCharsValidator =>
      'Le mot de passe doit comporter au moins 6 caractères';

  @override
  String get passwordsDoNotMatch => 'Les mots de passe ne correspondent pas';

  @override
  String get updatePasswordButton => 'Mettre à jour le mot de passe';

  @override
  String get passwordUpdatedSuccessfully =>
      'Mot de passe mis à jour avec succès.';

  @override
  String get adminTitle => 'Admin';

  @override
  String get addPositionTooltip => 'Ajouter une position';

  @override
  String get addPositionDialogTitle => 'Ajouter une position';

  @override
  String get addPositionHint => 'ex. Debout, Suspendu';

  @override
  String positionAdded(String name) {
    return 'Position \"$name\" ajoutée.';
  }

  @override
  String get noAdminAccess => 'Vous n\'avez pas accès à l\'administration.';

  @override
  String get noPendingTricks => 'Aucun trick en attente.';

  @override
  String get performerLabel => 'Performeur';

  @override
  String get videoLabel => 'Vidéo';

  @override
  String get approveButton => 'Approuver';

  @override
  String get rejectButton => 'Rejeter';

  @override
  String submittedDate(String date) {
    return 'soumis le $date';
  }

  @override
  String get trickProgressionTitle => 'Progression des tricks';

  @override
  String get noPrerequisitesFound =>
      'Aucun prérequis ni trick débloqué trouvé.';

  @override
  String get thisTrickLegend => 'Ce trick';

  @override
  String get youveLandedThisLegend => 'Vous avez réussi ce trick';

  @override
  String get notYetLandedLegend => 'Pas encore réussi';

  @override
  String get landedViaVariationLegend => 'Réussi via variation';

  @override
  String get pinchToZoom => 'Pincer pour zoomer · Glisser pour déplacer';

  @override
  String get filterTricksTitle => 'Filtrer les tricks';

  @override
  String get clearAllButton => 'Tout effacer';

  @override
  String get difficultyTierSection => 'Niveau de difficulté';

  @override
  String tierRangeLabel(String tier) {
    return 'Niveau $tier';
  }

  @override
  String get positionSection => 'Position';

  @override
  String get startLabel => 'Départ';

  @override
  String get endLabel => 'Arrivée';

  @override
  String get statusSection => 'Statut';

  @override
  String get yearLandedSection => 'Année de réception';

  @override
  String get includeTbdChip => 'Inclure TBD';

  @override
  String get searchByPerformerHint => 'Rechercher par performeur...';

  @override
  String get sortTricksTitle => 'Trier les tricks';

  @override
  String get orderSection => 'Ordre';

  @override
  String get ascendingOption => 'Croissant';

  @override
  String get descendingOption => 'Décroissant';

  @override
  String get groupBySection => 'Grouper par';

  @override
  String get sortWithinGroupBySection => 'Trier dans le groupe par';

  @override
  String get sortLabelDifficultyTier => 'Niveau de difficulté';

  @override
  String get sortLabelStartPosition => 'Position de départ';

  @override
  String get sortLabelYearLanded => 'Année de réception';

  @override
  String get sortLabelConsistency => 'Constance';

  @override
  String get sortLabelEndPosition => 'Position d\'arrivée';

  @override
  String get sortLabelAlphabetical => 'Alphabétique';

  @override
  String get statusNeverAttempted => 'Jamais essayé';

  @override
  String get statusAttempting => 'En apprentissage';

  @override
  String get statusLandedAtLeastOnce => 'Réussi au moins une fois';

  @override
  String get consistencyOnce => 'Une fois';

  @override
  String get consistencySometimes => 'Parfois';

  @override
  String get consistencyOften => 'Souvent';

  @override
  String get consistencyGenerally => 'En général';

  @override
  String get consistencyAlways => 'Toujours';

  @override
  String get leashFrontside => 'Face avant';

  @override
  String get leashBackside => 'Face arrière';

  @override
  String get leashCenter => 'Centre';

  @override
  String get suggestEditTooltip => 'Suggérer une modification';

  @override
  String get suggestEditTitle => 'Suggérer une modification';

  @override
  String get suggestChangesButton => 'Suggérer des modifications';

  @override
  String get suggestionSubmittedForReview =>
      'Suggestion soumise pour révision !';

  @override
  String get suggestionNoChanges =>
      'Aucune modification détectée — modifiez au moins un champ pour suggérer.';

  @override
  String get pendingSuggestionsSection => 'Suggestions en attente';

  @override
  String get noPendingSuggestions => 'Aucune suggestion en attente.';

  @override
  String forTrickLabel(String name) {
    return 'Pour : $name';
  }

  @override
  String get groupToBeDetetermined => 'À définir';

  @override
  String groupDifficulty(String tier) {
    return 'Difficulté $tier';
  }

  @override
  String get groupUnknown => 'Inconnu';

  @override
  String get groupLanded => 'Réussi';

  @override
  String get tricksNavLabel => 'Tricks';

  @override
  String get tipsNavLabel => 'Conseils';

  @override
  String get tipTypeGeneral => 'Général';

  @override
  String get tipTypeRigging => 'Gréement';

  @override
  String get tipTypeHealth => 'Santé';

  @override
  String get allTypesFilter => 'Tous';

  @override
  String get submitTipButton => 'Soumettre un conseil';

  @override
  String get submitTipTitle => 'Soumettre un conseil';

  @override
  String get editTipTitle => 'Modifier le conseil';

  @override
  String get failedToLoadTips => 'Échec du chargement des conseils';

  @override
  String get noTipsYet =>
      'Pas encore de conseils. Soyez le premier à en soumettre un !';

  @override
  String get noMatchingTricks => 'Aucun trick ne correspond à votre recherche.';

  @override
  String get pageNotFound => 'Page introuvable.';

  @override
  String get goHomeButton => 'Accueil';

  @override
  String get tipBodyLabel => 'Contenu';

  @override
  String get tipTitleLabel => 'Titre';

  @override
  String get tipHeaderLabel => 'Résumé';

  @override
  String get tipTypeLabel => 'Catégorie';

  @override
  String get tipSubmittedForReview => 'Conseil soumis pour révision !';

  @override
  String get tipUpdated => 'Conseil mis à jour.';

  @override
  String get noPendingTips => 'Aucun conseil en attente.';

  @override
  String get pendingTipsSection => 'Conseils en attente';

  @override
  String get declineButton => 'Refuser';

  @override
  String submittedOnLabel(String date) {
    return 'Soumis le $date';
  }

  @override
  String get closeButton => 'Fermer';

  @override
  String get tricksByTierTitle => 'TRICKS PAR NIVEAU';

  @override
  String get coloredByConsistency => '· Coloré par constance';

  @override
  String get columnTrick => 'TRICK';

  @override
  String get columnTier => 'NIVEAU';

  @override
  String get columnConsistency => 'CONSTANCE';

  @override
  String get columnUnlocks => 'DÉVERROUILLAGES';

  @override
  String get tabMyTricks => 'Mes tricks';

  @override
  String get tabReadyToStart => 'Prêt à commencer';

  @override
  String get tabMakingProgress => 'En progression';

  @override
  String get tabHighValue => 'Haute valeur';

  @override
  String get tabReadyToStartDesc =>
      'Tous les prérequis sont remplis — commencez à travailler dessus';

  @override
  String get tabMakingProgressDesc =>
      'Vous avez au moins un prérequis pour ces tricks';

  @override
  String get tabHighValueDesc =>
      'Réussir ces tricks débloque le plus grand nombre de nouveaux tricks';

  @override
  String tricksProgress(int landedCount, int attemptingCount) {
    return '$landedCount tricks réussis, $attemptingCount tricks en cours';
  }

  @override
  String get coreTrickLabel => 'Trick fondamental';

  @override
  String get coreTrickSubtitle =>
      'Affiché dans le filtre des tricks fondamentaux';

  @override
  String get coreOnlyFilter => 'Tricks fondamentaux uniquement';

  @override
  String get hideVariationsFilter => 'Masquer les variations';

  @override
  String get pointScoreLabel => 'Points totaux';

  @override
  String levelLabel(int level) {
    return 'Niveau $level';
  }

  @override
  String ptsToNextLevel(int pts, int next) {
    return '$pts pts pour le Niv. $next';
  }

  @override
  String get editorToolsSection => 'Outils Éditeur';

  @override
  String get editorModeLabel => 'Mode Révision de Contenu';

  @override
  String get editorModeSubtitle =>
      'Mettre en évidence le contenu manquant sur les fiches de tricks';

  @override
  String get editorMissingPrefix => 'Manquant :';

  @override
  String get editorAllPresent => 'Tous les champs présents';

  @override
  String get editorVariationBaseNotPrereq =>
      'Le trick de base n\'est pas listé comme prérequis';

  @override
  String get editorShowOnlyMissing =>
      'Afficher uniquement les tricks manquant :';

  @override
  String get trainingStudioTitle => 'Studio d\'entraînement';

  @override
  String get removeFromDevice => 'Supprimer de l\'appareil';

  @override
  String get saveToDeviceTooltip => 'Enregistrer sur l\'appareil';

  @override
  String couldNotDeleteAnnotation(String error) {
    return 'Impossible de supprimer l\'annotation : $error';
  }

  @override
  String couldNotSaveAnnotation(String error) {
    return 'Impossible d\'enregistrer l\'annotation : $error';
  }

  @override
  String get noSavedVideoOffline =>
      'Aucune vidéo enregistrée disponible hors ligne.';

  @override
  String get cachedVideoCleared =>
      'La vidéo mise en cache a été supprimée — rouvrez le studio d\'entraînement pour la télécharger à nouveau';

  @override
  String couldNotSaveVideo(String error) {
    return 'Impossible d\'enregistrer la vidéo : $error';
  }

  @override
  String couldNotDeleteVideo(String error) {
    return 'Impossible de supprimer la vidéo : $error';
  }

  @override
  String get annotationsTitle => 'Annotations';

  @override
  String addAtTime(String time) {
    return 'Ajouter à $time';
  }

  @override
  String get noAnnotationsYet => 'Aucune annotation pour l\'instant';

  @override
  String get addAnnotationTitle => 'Ajouter une annotation';

  @override
  String get editAnnotationTitle => 'Modifier l\'annotation';

  @override
  String get annotationTextLabel => 'Texte';

  @override
  String get annotationStartLabel => 'Début (s)';

  @override
  String get annotationEndLabel => 'Fin (s)';

  @override
  String get annotationLanguageLabel => 'Langue';

  @override
  String get saveButton => 'Enregistrer';

  @override
  String get lowStorageTitle => 'Stockage faible';

  @override
  String get lowStorageMessage =>
      'Moins de 1 Go de stockage disponible. Continuer quand même ?';

  @override
  String get continueButton => 'Continuer';

  @override
  String get deleteVideoMessage =>
      'Supprimer la vidéo enregistrée de votre appareil ?';
}
