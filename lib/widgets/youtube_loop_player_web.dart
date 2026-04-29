// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/widgets.dart';

class YoutubeLoopPlayer extends StatefulWidget {
  final String videoId;
  final int? startSeconds;
  final int? endSeconds;

  const YoutubeLoopPlayer({
    super.key,
    required this.videoId,
    this.startSeconds,
    this.endSeconds,
  });

  static bool get supported => true;

  @override
  State<YoutubeLoopPlayer> createState() => _YoutubeLoopPlayerWebState();
}

class _YoutubeLoopPlayerWebState extends State<YoutubeLoopPlayer> {
  late final String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId =
        'yt-${widget.videoId}-${DateTime.now().millisecondsSinceEpoch}';

    final start = widget.startSeconds ?? 0;
    final endParam =
        widget.endSeconds != null ? '&end=${widget.endSeconds}' : '';
    final src = 'https://www.youtube.com/embed/${widget.videoId}'
        '?autoplay=1&controls=1&modestbranding=1&rel=0'
        '&loop=1&playlist=${widget.videoId}&start=$start$endParam';

    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int id) {
      return html.IFrameElement()
        ..src = src
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true
        ..setAttribute(
            'allow', 'autoplay; encrypted-media; picture-in-picture');
    });
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: HtmlElementView(viewType: _viewId),
    );
  }
}
