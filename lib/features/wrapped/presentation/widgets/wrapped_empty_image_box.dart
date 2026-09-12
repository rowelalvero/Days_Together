import 'package:flutter/material.dart';

/// Placeholder shown when a featured memory has no resolvable image.
/// Extracted from [WrappedPageMemories]'s `_emptyImageBox` method
/// (Migration audit item 6).
class WrappedEmptyImageBox extends StatelessWidget {
  const WrappedEmptyImageBox({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white10,
      child: const Center(
        child: Icon(Icons.image_rounded, color: Colors.white24, size: 40),
      ),
    );
  }
}
