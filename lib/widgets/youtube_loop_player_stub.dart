import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:freestyle_highline/l10n/app_localizations_extension.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

  static bool get supported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows;

  @override
  State<YoutubeLoopPlayer> createState() => _YoutubeLoopPlayerState();
}

class _YoutubeLoopPlayerState extends State<YoutubeLoopPlayer> {
  bool _open = false;
  WebViewController? _controller;

  void _initPlayer() {
    if (_controller != null) return;
    final start = widget.startSeconds ?? 0;
    final endParam =
        widget.endSeconds != null ? 'end:${widget.endSeconds},' : '';
    final html = '''<!DOCTYPE html>
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

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (req) =>
            req.isMainFrame && req.url != 'about:blank'
                ? NavigationDecision.prevent
                : NavigationDecision.navigate,
      ))
      ..loadHtmlString(html, baseUrl: 'https://www.youtube.com');
  }

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return FilledButton.icon(
        icon: const Icon(Icons.play_circle_outline),
        label: Text(context.l10n.watchVideoButton),
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
              label: Text(context.l10n.closeButton),
              onPressed: () => setState(() => _open = false),
            ),
          ),
          AspectRatio(
            aspectRatio: ratio,
            child: WebViewWidget(controller: _controller!),
          ),
        ],
      ),
    );
  }
}
