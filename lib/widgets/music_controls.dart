import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:days_together/providers/music_provider.dart';

class MusicControls extends StatelessWidget {
  const MusicControls({super.key});

  @override
  Widget build(BuildContext context) {
    final musicProvider = context.watch<MusicProvider>();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(25),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              musicProvider.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 28,
            ),
            onPressed: () {
              // Surface errors to the user instead of silently failing.
              musicProvider.toggleMusic().catchError((Object e) {
                if (!context.mounted) return null;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Music toggle failed: $e')),
                );
                return null;
              });
            },
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Slider(
              value: musicProvider.volume.clamp(0.0, 1.0).toDouble(),
              onChanged: musicProvider.setVolume,
              min: 0,
              max: 1,
              activeColor: Colors.white,
              inactiveColor: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}
