import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class AppLoading extends StatelessWidget {
  final bool _isSkeleton;
  final double? height;
  final double? width;

  const AppLoading.spinner({super.key})
      : _isSkeleton = false,
        height = null,
        width = null;

  const AppLoading.skeleton({
    super.key,
    required double this.height,
    this.width,
  }) : _isSkeleton = true;

  @override
  Widget build(BuildContext context) {
    if (!_isSkeleton) {
      return Semantics(
        label: 'Carregando...',
        liveRegion: true,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final cs = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.topCenter,
      child: Shimmer.fromColors(
        baseColor: cs.surfaceContainerHighest,
        highlightColor: cs.surface,
        child: Container(
          height: height,
          width: width ?? double.infinity,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
