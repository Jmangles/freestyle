// Layout breakpoints shared across screens.

/// Subdirectory name under the app documents directory where trick videos are stored.
const String kTricksDirectory = 'tricks';

/// Screen width below which mobile-quality video is preferred on web.
const double kMobileWidthBreakpoint = 600.0;

/// Screen width below which the annotation sidebar collapses to an overlay.
const double kAnnotationSidebarBreakpoint = 1280.0;

// ─── Home screen grid ─────────────────────────────────────────────────────

/// Minimum cell width (px) keyed by grid-size setting (1–3).
const Map<int, double> kGridCellWidth = {1: 225.0, 2: 275.0, 3: 325.0};

/// Minimum column count keyed by grid-size setting (1–3).
const Map<int, int> kGridMinColumns = {1: 3, 2: 2, 3: 1};

/// Row height for compact grid cells (grid-size 0–1).
const double kGridCompactExtent = 64.0;

/// Row height for normal grid cells (grid-size 2–3).
const double kGridNormalExtent = 100.0;
