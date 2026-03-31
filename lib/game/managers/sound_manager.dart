import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundManager {
  static const _muteKey = 'sound_muted';

  final Map<String, AudioPlayer> _players = {};
  bool _muted = false;
  bool _disposed = false;

  bool get muted => _muted;

  final List<String> _soundNames = [
    'card_play',
    'deal',
    'trick_win',
    'trick_collect',
    'round_win',
    'round_loss',
    'victory',
    'defeat',
    'poison_joker',
    'bid',
    'trump',
  ];

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _muted = prefs.getBool(_muteKey) ?? false;

      for (final name in _soundNames) {
        _players[name] = AudioPlayer();
      }
    } catch (_) {
      // In test environments, platform channels may not be available
    }
  }

  Future<void> toggleMute() async {
    _muted = !_muted;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_muteKey, _muted);
  }

  Future<void> setMuted(bool value) async {
    _muted = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_muteKey, _muted);
  }

  Future<void> _play(String name) async {
    if (_muted || _disposed) return;
    final player = _players[name];
    if (player == null) return;
    try {
      await player.play(AssetSource('sounds/$name.wav'));
    } catch (_) {
      // Sound file may not exist yet (placeholder phase) — silently skip
    }
  }

  void playCardSound() => _play('card_play');
  void playDealSound() => _play('deal');
  void playTrickWinSound() => _play('trick_win');
  void playTrickCollectSound() => _play('trick_collect');
  void playRoundWinSound() => _play('round_win');
  void playRoundLossSound() => _play('round_loss');
  void playVictorySound() => _play('victory');
  void playDefeatSound() => _play('defeat');
  void playPoisonJokerSound() => _play('poison_joker');
  void playBidSound() => _play('bid');
  void playTrumpSound() => _play('trump');

  void dispose() {
    _disposed = true;
    for (final player in _players.values) {
      player.dispose();
    }
    _players.clear();
  }
}
