/// Bounded style variation for tie-breaks — deterministic from seed.
enum BotStyle { methodical, pressure, resource }

class BotPersona {
  final BotStyle style;

  const BotPersona(this.style);

  static BotPersona fromSeed(int seatIndex, int roundIndex, int trickIndex) {
    final v = (seatIndex * 31 + roundIndex * 17 + trickIndex * 13) % 3;
    return BotPersona(BotStyle.values[v]);
  }

  @override
  bool operator ==(Object other) => other is BotPersona && other.style == style;

  @override
  int get hashCode => style.hashCode;
}
