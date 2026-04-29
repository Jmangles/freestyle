import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

  static bool get supported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows;

  @override
  State<YoutubeLoopPlayer> createState() => _YoutubeLoopPlayerState();
}

class _YoutubeLoopPlayerState extends State<YoutubeLoopPlayer> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
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
      playerVars:{autoplay:1,controls:1,modestbranding:1,rel:0,playsinline:1,start:$start,$endParam},
      events:{
        onReady:function(e){e.target.playVideo();},
        onStateChange:function(e){if(e.data===YT.PlayerState.ENDED){player.seekTo(startSec,true);player.playVideo();}}
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
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: WebViewWidget(controller: _controller),
    );
  }
}
