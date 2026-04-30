// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class YoutubeLoopPlayer extends StatefulWidget {
  final String videoId;
  final int? startSeconds;
  final int? endSeconds;
  final bool isPortrait;

  const YoutubeLoopPlayer({
    super.key,
    required this.videoId,
    this.startSeconds,
    this.endSeconds,
    this.isPortrait = false,
  });

  static bool get supported => true;

  @override
  State<YoutubeLoopPlayer> createState() => _YoutubeLoopPlayerWebState();
}

class _YoutubeLoopPlayerWebState extends State<YoutubeLoopPlayer> {
  bool _open = false;
  String? _viewId;

  void _initPlayer() {
    if (_viewId != null) return;
    _viewId =
        'yt-${widget.videoId}-${DateTime.now().millisecondsSinceEpoch}';

    final start = widget.startSeconds ?? 0;
    final endParam =
        widget.endSeconds != null ? 'end:${widget.endSeconds},' : '';
    final htmlContent = '''<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
  <style>*{margin:0;padding:0}body,html{width:100%;height:100%;background:#000;overflow:hidden}#p{width:100%;height:100%}</style>
</head>
<body>
<div id="p"></div>
<script>
  var s=document.createElement('script');s.src='https://www.youtube.com/iframe_api';document.head.appendChild(s);
  var player,startSec=$start;
  function onYouTubeIframeAPIReady(){
    player=new YT.Player('p',{videoId:'${widget.videoId}',width:'100%',height:'100%',
      playerVars:{autoplay:0,controls:1,modestbranding:1,rel:0,playsinline:1,start:$start,$endParam},
      events:{
        onStateChange:function(e){if(e.data===YT.PlayerState.ENDED){player.seekTo(startSec,true);}}
      }
    });
  }
</script>
</body>
</html>''';

    ui_web.platformViewRegistry.registerViewFactory(_viewId!, (int id) {
      return html.IFrameElement()
        ..setAttribute('srcdoc', htmlContent)
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
    if (!_open) {
      return FilledButton.icon(
        icon: const Icon(Icons.play_circle_outline),
        label: const Text('Watch Video'),
        onPressed: () {
          _initPlayer();
          setState(() => _open = true);
        },
      );
    }

    final maxWidth = widget.isPortrait ? 640.0 : 1280.0;
    final ratio = widget.isPortrait ? 9.0 / 16.0 : 16.0 / 9.0;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Close'),
              onPressed: () => setState(() => _open = false),
            ),
          ),
          AspectRatio(
            aspectRatio: ratio,
            child: HtmlElementView(viewType: _viewId!),
          ),
        ],
      ),
    );
  }
}
