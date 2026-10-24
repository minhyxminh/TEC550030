import 'package:material_ui/material_ui.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/machine_guide.dart';
import '../../services/video_service.dart';
import '../../widgets/machine_guide_card.dart';

/// Plays a guide's YouTube Short inside the app.
class GuideVideoScreen extends StatefulWidget {
  /// Widget tests have no WebView, so they swap the player out.
  static Widget Function(MachineGuide guide)? playerOverride;

  final MachineGuide guide;
  const GuideVideoScreen({super.key, required this.guide});
  @override
  State<GuideVideoScreen> createState() => _GuideVideoScreenState();
}

class _GuideVideoScreenState extends State<GuideVideoScreen> {
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    final id = widget.guide.youtubeId;
    if (id != null && GuideVideoScreen.playerOverride == null) {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: id,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showFullscreenButton: true,
          strictRelatedVideos: true,
          playsInline: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  Future<void> _openExternally() async {
    final url = widget.guide.videoUrl;
    if (url != null && await VideoService.open(url)) return;
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Không mở được YouTube.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final guide = widget.guide;
    final controller = _controller;
    final player =
        GuideVideoScreen.playerOverride?.call(guide) ??
        (controller == null
            ? const Center(
                child: Text(
                  'Video chưa sẵn sàng.',
                  style: TextStyle(color: Colors.white),
                ),
              )
            : YoutubePlayer(
                controller: controller,
                aspectRatio: 9 / 16,
                autoFullScreen: false,
                backgroundColor: Colors.black,
              ));
    return Scaffold(
      backgroundColor: const Color(0xFF1C120C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C120C),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: AppTextStyles.heading2.copyWith(color: Colors.white),
        title: Text(guide.name),
        actions: [
          if (guide.videoUrl != null)
            IconButton(
              tooltip: 'Mở trong YouTube',
              onPressed: _openExternally,
              icon: const Icon(Icons.open_in_new_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: AspectRatio(aspectRatio: 9 / 16, child: player),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guide.subtitle,
                    style: AppTextStyles.title.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.repeat_rounded,
                        size: 16,
                        color: AppColors.sunOrange,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          guide.prescription,
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  MuscleTags(guide.muscles),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
