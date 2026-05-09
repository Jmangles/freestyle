enum TipType {
  general,
  rigging,
  health;

  int get value => switch (this) {
        TipType.general => 0,
        TipType.rigging => 1,
        TipType.health => 2,
      };

  static TipType fromValue(int value) => switch (value) {
        1 => TipType.rigging,
        2 => TipType.health,
        _ => TipType.general,
      };
}
