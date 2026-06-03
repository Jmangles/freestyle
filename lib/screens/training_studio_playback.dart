import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../constants/playback_constants.dart';
import '../models/trick_annotation.dart';
import '../utils/safe_state.dart';
import '../video/training_video_controller.dart';

mixin TrainingStudioPlaybackMixin<T extends StatefulWidget>
    on SafeStateMixin<T> {
  Player get player;
  TrainingVideoController get videoController;

  // Called when the player receives its first valid duration (ready to show content).
  // The host should clear its loading flag here.
  void onPlayerDurationReady();

  late final StreamSubscription<Duration> _posSub;
  late final StreamSubscription<Duration> _durSub;
  late final StreamSubscription<bool> _completedSub;
  late final StreamSubscription<bool> _playingSub;
  late final StreamSubscription<bool> _bufferingSub;

  bool buffering = false;
  bool looping = false;
  bool awaitingWebAutoplay = false;
  DateTime? lastCompletedAt;

  // Debug counters/info — only populated in debug mode.
  String dbgQualityInfo = '';
  int dbgFwdFalseEof = 0;
  int dbgFwdRealEof = 0;
  int dbgFwdDebounced = 0;
  int get dbgFwdFired => dbgFwdFalseEof + dbgFwdRealEof;
  final List<String> dbgLog = [];

  void setupPlaybackSubscriptions() {
    _completedSub = player.stream.completed.listen(_onCompleted);
    _durSub = player.stream.duration.listen(_onDuration);
    _posSub = player.stream.position.listen(_onPosition);
    _playingSub = player.stream.playing.listen(_onPlaying);
    _bufferingSub = player.stream.buffering.listen(_onBuffering);
  }

  void disposePlaybackSubscriptions() {
    _posSub.cancel();
    _durSub.cancel();
    _completedSub.cancel();
    _playingSub.cancel();
    _bufferingSub.cancel();
  }

  // Manual looping so the playback rate is preserved on each cycle.
  // PlaylistMode.loop is not used because libmpv loops the demuxer (when it
  // finishes reading the network stream) rather than the renderer (when the
  // last frame is displayed), causing early loops on Android.
  // keep-open=yes makes libmpv pause instead of stop at EOF, so buffered
  // frames past the network EOF can still be displayed before we loop.
  //
  // False-EOF detection: if completed fires while position is still far from
  // the end, the demuxer finished downloading before the renderer caught up —
  // call play() to drain the buffer. 1-second threshold (instead of a
  // shorter value) covers Android's position-stream staleness: the stream can
  // lag ~500 ms behind the renderer, so a 300 ms window was insufficient and
  // the renderer's true EOF was mis-classified as false EOF.
  //
  // Debounce: calling play() at a keep-open EOF causes an immediate
  // re-completion event. We collapse any bursts within kEofDebounce so the
  // first event drives the decision and subsequent ones are ignored.
  void _onCompleted(bool done) {
    if (!done || looping) return;

    final total = videoController.state.totalDuration;

    if (total < kEofTolerance) return;

    final now = DateTime.now();
    final ctrlPos = videoController.state.position;
    final playerPos = player.state.position;

    if (lastCompletedAt != null &&
        now.difference(lastCompletedAt!) < kEofDebounce) {
      _dbgEvent(
          'FWD debounce ctrl=${ctrlPos.inMilliseconds} player=${playerPos.inMilliseconds}',
          _DbgCounter.fwdDebounced);
      return;
    }

    lastCompletedAt = now;

    if (ctrlPos < total - kEofTolerance) {
      _dbgEvent(
          'FWD false-EOF ctrl=${ctrlPos.inMilliseconds} player=${playerPos.inMilliseconds} total=${total.inMilliseconds}',
          _DbgCounter.fwdFalseEof);
      // False EOF — demuxer hit network EOF but buffered frames remain.
      player.play();
      return;
    }

    _dbgEvent(
        'FWD real-EOF→loop ctrl=${ctrlPos.inMilliseconds} player=${playerPos.inMilliseconds} total=${total.inMilliseconds}',
        _DbgCounter.fwdRealEof);

    looping = true;
    
    player.seek(Duration.zero).then((_) {
      if (!mounted) return;

      player.setRate(videoController.state.speed);
      player.play();
    });
  }

  void _onDuration(Duration duration) {
    if (duration <= Duration.zero) return;

    videoController.setDuration(duration);

    if (!mounted) return;

    onPlayerDurationReady();

    // On web, play:true in open() can lose a race against the duration event
    // with local blob URLs. Nudge play immediately, then once more after a short
    // delay to cover the case where play() is silently absorbed with no events.
    if (kIsWeb) {
      player.play();
      Future.delayed(kWebAutoplayRetryDelay, () {
        if (mounted && awaitingWebAutoplay) player.play();
      });
    }
  }

  void _onPosition(Duration pos) {
    final prev = videoController.state.position;

    if (!looping && prev > kJumpMinPrev && pos < prev - kEofDebounce) {
      final total = videoController.state.totalDuration;

      final isEofLoop = total > Duration.zero &&
          prev >= total - kEofTolerance &&
          pos < kNearStartThreshold;

      if (isEofLoop) looping = true;

      _dbgEvent('POS↩ ${prev.inMilliseconds}→${pos.inMilliseconds}ms'
          ' player=${player.state.position.inMilliseconds}ms'
          ' loop=$looping eofLoop=$isEofLoop');
    }

    if (looping && pos > kLoopClearThreshold) {
      looping = false;
    }

    // Position advancing is the reliable signal that autoplay actually worked.
    if (kIsWeb &&
        awaitingWebAutoplay &&
        pos > kWebAutoplayAdvanceThreshold) {
      awaitingWebAutoplay = false;
    }

    videoController.updatePosition(pos);
    
    safeSetState(() {});
  }

  void _onPlaying(bool playing) {
    _dbgEvent(
        'FWD playing=$playing pos=${videoController.state.position.inMilliseconds}ms'
        ' loop=$looping');
    if (kIsWeb) {
      // Don't clear on playing=true — it can fire briefly before the player
      // settles back to false. Cleared by position advancement instead.
      if (!playing && awaitingWebAutoplay) {
        player.play();
      }
    }
    if (playing) {
      videoController.play();
    } else {
      videoController.pause();
    }
  }

  void _onBuffering(bool b) {
    safeSetState(() => buffering = b);
  }

  Future<void> play() async {
    videoController.play();
    await player.play();
  }

  Future<void> pause() async {
    awaitingWebAutoplay = false;
    videoController.pause();
    await player.pause();
  }

  Future<void> restart() async {
    videoController.restart();
    await player.seek(videoController.state.position);
    await player.play();
  }

  Future<void> _step(void Function() move) async {
    await player.pause();
    move();
    await player.seek(videoController.state.position);
  }

  Future<void> stepForward() => _step(videoController.stepForward);
  Future<void> stepBackward() => _step(videoController.stepBackward);

  Future<void> togglePlayPause() async {
    if (videoController.state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> setSpeed(double speed) async {
    videoController.setSpeed(speed);
    await player.setRate(speed);
  }

  void onScrub(double value) {
    if (videoController.state.totalDuration == Duration.zero) return;
    final newPosition = videoController.state.totalDuration * value;
    videoController.updatePosition(newPosition);
    player.seek(newPosition);
  }

  void seekToAnnotation(TrickAnnotation a) {
    setSpeed(0.25);
    videoController.updatePosition(Duration(milliseconds: a.startMs));
    player.seek(videoController.state.position);
    play();
  }

  void _dbgEvent(String msg, [_DbgCounter? counter]) {
    if (!kDebugMode) return;

    switch (counter) {
      case _DbgCounter.fwdFalseEof:
        dbgFwdFalseEof++;
      case _DbgCounter.fwdRealEof:
        dbgFwdRealEof++;
      case _DbgCounter.fwdDebounced:
        dbgFwdDebounced++;
      case null:
        break;
    }

    final ts = DateTime.now();

    final entry =
        '${ts.second.toString().padLeft(2, '0')}.${ts.millisecond.toString().padLeft(3, '0')} $msg';

    dbgLog.add(entry);

    if (dbgLog.length > 12) dbgLog.removeAt(0);

    debugPrint('[TS] $msg');

    safeSetState(() {});
  }
}

enum _DbgCounter { fwdFalseEof, fwdRealEof, fwdDebounced }
