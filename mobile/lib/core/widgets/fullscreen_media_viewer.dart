import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

class FullscreenMediaViewer extends StatefulWidget {
  final String? imageUrl;
  final Uint8List? imageBytes;
  final VideoPlayerController? videoController;

  const FullscreenMediaViewer({
    super.key,
    this.imageUrl,
    this.imageBytes,
    this.videoController,
  });

  static void showImage(BuildContext context, {String? url, Uint8List? bytes}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, __, ___) => FullscreenMediaViewer(imageUrl: url, imageBytes: bytes),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  static void showVideo(BuildContext context, VideoPlayerController controller) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, __, ___) => FullscreenMediaViewer(videoController: controller),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<FullscreenMediaViewer> createState() => _FullscreenMediaViewerState();
}

class _FullscreenMediaViewerState extends State<FullscreenMediaViewer>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  double _dragScale = 1.0;
  double _opacity = 1.0;
  bool _isDragging = false;

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _isDragging = true;
      _dragOffset += details.delta.dy;
      final progress = (_dragOffset.abs() / 300).clamp(0.0, 1.0);
      _dragScale = 1.0 - progress * 0.3;
      _opacity = 1.0 - progress;
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_dragOffset.abs() > 100 || details.velocity.pixelsPerSecond.dy.abs() > 500) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _dragOffset = 0;
        _dragScale = 1.0;
        _opacity = 1.0;
        _isDragging = false;
      });
    }
  }

  Widget _buildMedia() {
    if (widget.videoController != null) {
      return AspectRatio(
        aspectRatio: widget.videoController!.value.aspectRatio,
        child: VideoPlayer(widget.videoController!),
      );
    }

    if (widget.imageBytes != null) {
      return InteractiveViewer(
        child: Image.memory(widget.imageBytes!, fit: BoxFit.contain),
      );
    }

    if (widget.imageUrl != null) {
      return InteractiveViewer(
        child: CachedNetworkImage(
          imageUrl: widget.imageUrl!,
          fit: BoxFit.contain,
          placeholder: (_, _) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          errorWidget: (_, _, _) => const Center(
            child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: _opacity.clamp(0.3, 1.0)),
      body: Stack(
        children: [
          GestureDetector(
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: _onVerticalDragEnd,
            onTap: () => Navigator.of(context).pop(),
            child: Center(
              child: Transform.translate(
                offset: Offset(0, _dragOffset),
                child: Transform.scale(
                  scale: _dragScale,
                  child: Opacity(
                    opacity: _opacity.clamp(0.2, 1.0),
                    child: _buildMedia(),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: AnimatedOpacity(
              opacity: _isDragging ? 0 : 1,
              duration: const Duration(milliseconds: 150),
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
