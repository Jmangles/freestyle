// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'FreestyleDB';

  @override
  String get cancelButton => 'Cancelar';

  @override
  String get applyButton => 'Aplicar';

  @override
  String get addButton => 'Agregar';

  @override
  String get editButton => 'Editar';

  @override
  String get deleteButton => 'Eliminar';

  @override
  String get noneOption => 'Ninguno';

  @override
  String get anyOption => 'Cualquiera';

  @override
  String get requiredValidator => 'Requerido';

  @override
  String get backTooltip => 'Atrás';

  @override
  String get homeTooltip => 'Inicio';

  @override
  String get descriptionLabel => 'Descripción';

  @override
  String get tipsLabel => 'Consejos';

  @override
  String get prerequisitesLabel => 'Prerrequisitos';

  @override
  String get originalPerformerLabel => 'Ejecutante original';

  @override
  String get technicalNameLabel => 'Nombre técnico';

  @override
  String get difficultyLabel => 'Dificultad';

  @override
  String get leashPositionLabel => 'Posición de la cuerda';

  @override
  String get loopStartLabel => 'Inicio del bucle (s)';

  @override
  String get loopEndLabel => 'Fin del bucle (s)';

  @override
  String get searchHint => 'Buscar...';

  @override
  String errorWithDetail(String detail) {
    return 'Error: $detail';
  }

  @override
  String get adminLabel => 'Admin';

  @override
  String get filterTooltip => 'Filtrar';

  @override
  String get profileTooltip => 'Perfil';

  @override
  String get signInTooltip => 'Iniciar sesión';

  @override
  String get submitTrickButton => 'Enviar truco';

  @override
  String get failedToLoadTricks => 'Error al cargar los trucos';

  @override
  String get retryButton => 'Reintentar';

  @override
  String get noTricksYet => 'Aún no hay trucos. ¡Sé el primero en enviar uno!';

  @override
  String get searchByNameHint => 'Buscar por nombre...';

  @override
  String get trickDetailTitle => 'Detalle del truco';

  @override
  String get copyLinkTooltip => 'Copiar enlace';

  @override
  String get linkCopiedMessage => 'Enlace copiado';

  @override
  String get viewProgressionTooltip => 'Ver progresión';

  @override
  String get editTrickTooltip => 'Editar truco';

  @override
  String get deleteTrickTooltip => 'Eliminar truco';

  @override
  String get deleteTrickDialogTitle => 'Eliminar truco';

  @override
  String deleteTrickConfirmMessage(String name) {
    return '¿Estás seguro de que quieres eliminar \"$name\"? Esta acción no se puede deshacer.';
  }

  @override
  String get couldNotOpenVideoLink => 'No se pudo abrir el enlace del video';

  @override
  String get watchVideoButton => 'Ver video';

  @override
  String get dateFirstPerformedLabel => 'Fecha de primera ejecución';

  @override
  String get dateSubmittedLabel => 'Fecha de envío';

  @override
  String get communityVotesLabel => 'Votos de la comunidad';

  @override
  String get myConsistencyLabel => 'Mi consistencia';

  @override
  String get landedDetailsLabel => 'Detalles de aterrizaje';

  @override
  String get allFieldsOptional => 'Todos los campos son opcionales';

  @override
  String get difficultyVoteLabel => 'Voto de dificultad';

  @override
  String get videoLinkLabel => 'Enlace de video';

  @override
  String get videoLinkHint => 'https://';

  @override
  String get saveDetailsButton => 'Guardar detalles';

  @override
  String get yourLandingVideoLabel => 'Tu video de aterrizaje';

  @override
  String get editTrickTitle => 'Editar truco';

  @override
  String get submitTrickTitle => 'Enviar un truco';

  @override
  String get tbdOption => 'Por definir';

  @override
  String get givenNameLabel => 'Nombre común';

  @override
  String get difficultyRequiredLabel => 'Dificultad *';

  @override
  String get startPositionRequiredLabel => 'Posición inicial *';

  @override
  String get endPositionRequiredLabel => 'Posición final *';

  @override
  String get dateFirstPerformedOptional =>
      'Fecha de primera ejecución (opcional)';

  @override
  String dateFirstPerformedWithDate(String date) {
    return 'Fecha de primera ejecución: $date';
  }

  @override
  String get videoLinkUrlLabel => 'Enlace de video (URL)';

  @override
  String get saveChangesButton => 'Guardar cambios';

  @override
  String get submitForReviewButton => 'Enviar para revisión';

  @override
  String get trickUpdated => 'Truco actualizado.';

  @override
  String get trickSubmittedForReview => '¡Truco enviado para revisión!';

  @override
  String get similarTricksWarning => 'Trucos con nombres similares:';

  @override
  String get selectPrerequisiteTitle => 'Seleccionar prerrequisito';

  @override
  String get profileTitle => 'Perfil';

  @override
  String get signOutTooltip => 'Cerrar sesión';

  @override
  String get signOutConfirmMessage =>
      '¿Estás seguro de que quieres cerrar sesión?';

  @override
  String get unknownUser => 'Usuario desconocido';

  @override
  String get darkModeLabel => 'Modo oscuro';

  @override
  String myTricksCount(int count) {
    return 'Mis trucos ($count)';
  }

  @override
  String get noTricksTracked =>
      'Aún no hay trucos registrados.\n¡Explora la lista y establece tu consistencia!';

  @override
  String get resetPasswordDialogTitle => 'Restablecer contraseña';

  @override
  String get emailLabel => 'Correo electrónico';

  @override
  String get sendResetLinkButton => 'Enviar enlace de restablecimiento';

  @override
  String get passwordResetEmailSent =>
      'Correo de restablecimiento enviado — revisa tu bandeja de entrada.';

  @override
  String get signInToYourAccount => 'Inicia sesión en tu cuenta';

  @override
  String get passwordLabel => 'Contraseña';

  @override
  String get forgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get enterYourEmailValidator => 'Ingresa tu correo electrónico';

  @override
  String get enterYourPasswordValidator => 'Ingresa tu contraseña';

  @override
  String get signInButton => 'Iniciar sesión';

  @override
  String get dontHaveAccountRegister => '¿No tienes cuenta? Regístrate';

  @override
  String get createAccountTitle => 'Crear cuenta';

  @override
  String get usernameLabel => 'Nombre de usuario';

  @override
  String get enterUsernameValidator => 'Ingresa un nombre de usuario';

  @override
  String get enterPasswordValidator => 'Ingresa una contraseña';

  @override
  String get minimumSixCharsValidator => 'Mínimo 6 caracteres';

  @override
  String get registerButton => 'Registrarse';

  @override
  String get alreadyHaveAccount => '¿Ya tienes cuenta? Inicia sesión';

  @override
  String get accountCreated =>
      '¡Cuenta creada! Revisa tu correo para confirmar y luego inicia sesión.';

  @override
  String get setNewPasswordTitle => 'Establecer nueva contraseña';

  @override
  String get chooseNewPassword => 'Elige una nueva contraseña para tu cuenta.';

  @override
  String get newPasswordLabel => 'Nueva contraseña';

  @override
  String get confirmPasswordLabel => 'Confirmar contraseña';

  @override
  String get enterNewPasswordValidator => 'Ingresa una nueva contraseña';

  @override
  String get passwordMinSixCharsValidator =>
      'La contraseña debe tener al menos 6 caracteres';

  @override
  String get passwordsDoNotMatch => 'Las contraseñas no coinciden';

  @override
  String get updatePasswordButton => 'Actualizar contraseña';

  @override
  String get passwordUpdatedSuccessfully => 'Contraseña actualizada con éxito.';

  @override
  String get adminTitle => 'Admin';

  @override
  String get addPositionTooltip => 'Agregar posición';

  @override
  String get addPositionDialogTitle => 'Agregar posición';

  @override
  String get addPositionHint => 'ej. De pie, Colgado';

  @override
  String positionAdded(String name) {
    return 'Posición \"$name\" agregada.';
  }

  @override
  String get noAdminAccess => 'No tienes acceso de administrador.';

  @override
  String get noPendingTricks => 'No hay trucos pendientes.';

  @override
  String get performerLabel => 'Ejecutante';

  @override
  String get videoLabel => 'Video';

  @override
  String get approveButton => 'Aprobar';

  @override
  String get rejectButton => 'Rechazar';

  @override
  String submittedDate(String date) {
    return 'enviado el $date';
  }

  @override
  String get trickProgressionTitle => 'Progresión de trucos';

  @override
  String get noPrerequisitesFound =>
      'No se encontraron prerrequisitos ni trucos desbloqueados.';

  @override
  String get thisTrickLegend => 'Este truco';

  @override
  String get youveLandedThisLegend => 'Has aterrizado este truco';

  @override
  String get notYetLandedLegend => 'Aún no aterrizado';

  @override
  String get pinchToZoom => 'Pellizca para acercar · Arrastra para mover';

  @override
  String get filterTricksTitle => 'Filtrar trucos';

  @override
  String get clearAllButton => 'Borrar todo';

  @override
  String get difficultyTierSection => 'Nivel de dificultad';

  @override
  String tierRangeLabel(String tier) {
    return 'Nivel $tier';
  }

  @override
  String get positionSection => 'Posición';

  @override
  String get startLabel => 'Inicio';

  @override
  String get endLabel => 'Fin';

  @override
  String get statusSection => 'Estado';

  @override
  String get yearLandedSection => 'Año de aterrizaje';

  @override
  String get includeTbdChip => 'Incluir TBD';

  @override
  String get searchByPerformerHint => 'Buscar por ejecutante...';

  @override
  String get sortTricksTitle => 'Ordenar trucos';

  @override
  String get orderSection => 'Orden';

  @override
  String get ascendingOption => 'Ascendente';

  @override
  String get descendingOption => 'Descendente';

  @override
  String get groupBySection => 'Agrupar por';

  @override
  String get sortWithinGroupBySection => 'Ordenar dentro del grupo por';

  @override
  String get sortLabelDifficultyTier => 'Nivel de dificultad';

  @override
  String get sortLabelStartPosition => 'Posición inicial';

  @override
  String get sortLabelYearLanded => 'Año de aterrizaje';

  @override
  String get sortLabelConsistency => 'Consistencia';

  @override
  String get sortLabelEndPosition => 'Posición final';

  @override
  String get sortLabelAlphabetical => 'Alfabético';

  @override
  String get statusNeverAttempted => 'Nunca intentado';

  @override
  String get statusAttempting => 'En aprendizaje';

  @override
  String get statusLandedAtLeastOnce => 'Aterrizado al menos una vez';

  @override
  String get consistencyOnce => 'Una vez';

  @override
  String get consistencySometimes => 'A veces';

  @override
  String get consistencyOften => 'Con frecuencia';

  @override
  String get consistencyGenerally => 'Generalmente';

  @override
  String get consistencyAlways => 'Siempre';

  @override
  String get leashFrontside => 'Frontal';

  @override
  String get leashBackside => 'Trasero';

  @override
  String get leashCenter => 'Centro';

  @override
  String get suggestEditTooltip => 'Sugerir edición';

  @override
  String get suggestEditTitle => 'Sugerir edición';

  @override
  String get suggestChangesButton => 'Sugerir cambios';

  @override
  String get suggestionSubmittedForReview =>
      '¡Sugerencia enviada para revisión!';

  @override
  String get suggestionNoChanges =>
      'No se detectaron cambios — edita al menos un campo para sugerir.';

  @override
  String get pendingSuggestionsSection => 'Sugerencias pendientes';

  @override
  String get noPendingSuggestions => 'No hay sugerencias pendientes.';

  @override
  String forTrickLabel(String name) {
    return 'Para: $name';
  }

  @override
  String get groupToBeDetetermined => 'Por definir';

  @override
  String groupDifficulty(String tier) {
    return 'Dificultad $tier';
  }

  @override
  String get groupUnknown => 'Desconocido';

  @override
  String get groupLanded => 'Aterrizado';

  @override
  String get tricksNavLabel => 'Trucos';

  @override
  String get tipsNavLabel => 'Consejos';

  @override
  String get tipTypeGeneral => 'General';

  @override
  String get tipTypeRigging => 'Aparejo';

  @override
  String get tipTypeHealth => 'Salud';

  @override
  String get allTypesFilter => 'Todos';

  @override
  String get submitTipButton => 'Enviar consejo';

  @override
  String get submitTipTitle => 'Enviar un consejo';

  @override
  String get editTipTitle => 'Editar consejo';

  @override
  String get failedToLoadTips => 'Error al cargar los consejos';

  @override
  String get noTipsYet => 'Sin consejos aún. ¡Sé el primero en enviar uno!';

  @override
  String get tipBodyLabel => 'Contenido';

  @override
  String get tipTitleLabel => 'Título';

  @override
  String get tipHeaderLabel => 'Resumen';

  @override
  String get tipTypeLabel => 'Categoría';

  @override
  String get tipSubmittedForReview => '¡Consejo enviado para revisión!';

  @override
  String get tipUpdated => 'Consejo actualizado.';

  @override
  String get noPendingTips => 'No hay consejos pendientes.';

  @override
  String get pendingTipsSection => 'Consejos pendientes';

  @override
  String get declineButton => 'Rechazar';

  @override
  String submittedOnLabel(String date) {
    return 'Enviado el $date';
  }

  @override
  String get closeButton => 'Cerrar';

  @override
  String get tricksByTierTitle => 'TRUCOS POR NIVEL';

  @override
  String get coloredByConsistency => '· Coloreado por consistencia';

  @override
  String get columnTrick => 'TRUCO';

  @override
  String get columnTier => 'NIVEL';

  @override
  String get columnConsistency => 'CONSISTENCIA';

  @override
  String get columnUnlocks => 'DESBLOQUEOS';

  @override
  String get tabMyTricks => 'Mis trucos';

  @override
  String get tabReadyToStart => 'Listo para empezar';

  @override
  String get tabMakingProgress => 'Progresando';

  @override
  String get tabHighValue => 'Alto valor';

  @override
  String get tabReadyToStartDesc =>
      'Todos los prerrequisitos cumplidos — empieza a trabajar en estos';

  @override
  String get tabMakingProgressDesc =>
      'Tienes al menos un prerrequisito para estos';

  @override
  String get tabHighValueDesc =>
      'Aterrizar estos desbloquea la mayor cantidad de trucos nuevos';

  @override
  String tricksProgress(int landedCount, int attemptingCount) {
    return '$landedCount trucos aterrizados, $attemptingCount trucos en progreso';
  }

  @override
  String get coreTrickLabel => 'Truco fundamental';

  @override
  String get coreTrickSubtitle =>
      'Aparece en el filtro de trucos fundamentales';

  @override
  String get coreOnlyFilter => 'Solo trucos fundamentales';

  @override
  String get pointScoreLabel => 'Puntos totales';

  @override
  String levelLabel(int level) {
    return 'Nivel $level';
  }

  @override
  String ptsToNextLevel(int pts, int next) {
    return '$pts pts al Nv. $next';
  }

  @override
  String get editorToolsSection => 'Herramientas de Editor';

  @override
  String get editorModeLabel => 'Modo de Revisión de Contenido';

  @override
  String get editorModeSubtitle =>
      'Resaltar contenido faltante en las tarjetas de trucos';

  @override
  String get editorMissingPrefix => 'Faltante:';

  @override
  String get editorAllPresent => 'Todos los campos presentes';

  @override
  String get editorShowOnlyMissing => 'Mostrar solo trucos con falta de:';
}
