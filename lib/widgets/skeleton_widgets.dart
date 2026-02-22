import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../services/theme_service.dart';

/// A shimmer box used as a placeholder while content loads.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Wraps children in a shimmer effect. Adapts colors to dark/light mode.
class SkeletonShimmer extends StatelessWidget {
  final Widget child;
  final bool isDarkMode;

  const SkeletonShimmer({
    super.key,
    required this.child,
    this.isDarkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDarkMode ? Colors.grey[700]! : Colors.grey[100]!,
      child: child,
    );
  }
}

/// Skeleton for a representative card (used in home page horizontal PageView).
class RepresentativeCardSkeleton extends StatelessWidget {
  final bool isDarkMode;

  const RepresentativeCardSkeleton({super.key, this.isDarkMode = false});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      isDarkMode: isDarkMode,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDarkMode ? ThemeService.bgElev : Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(radius: 32, backgroundColor: Colors.white),
            const SizedBox(height: 10),
            const SkeletonBox(width: 100, height: 14),
            const SizedBox(height: 6),
            const SkeletonBox(width: 70, height: 12),
            const SizedBox(height: 6),
            const SkeletonBox(width: 50, height: 10),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for the representative cards loading row on home page.
class RepresentativeListSkeleton extends StatelessWidget {
  final bool isDarkMode;

  const RepresentativeListSkeleton({super.key, this.isDarkMode = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: 4,
        itemBuilder: (context, index) {
          return RepresentativeCardSkeleton(isDarkMode: isDarkMode);
        },
      ),
    );
  }
}

/// Skeleton for a news article card in the home page list.
class NewsArticleSkeleton extends StatelessWidget {
  final bool isDarkMode;

  const NewsArticleSkeleton({super.key, this.isDarkMode = false});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      isDarkMode: isDarkMode,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(width: 14),
            // Text lines
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(height: 14),
                  SizedBox(height: 8),
                  SkeletonBox(height: 14, width: 200),
                  SizedBox(height: 8),
                  SkeletonBox(height: 12, width: 120),
                  SizedBox(height: 8),
                  SkeletonBox(height: 10, width: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for the news list on home page.
class NewsListSkeleton extends StatelessWidget {
  final bool isDarkMode;
  final int itemCount;

  const NewsListSkeleton({
    super.key,
    this.isDarkMode = false,
    this.itemCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => NewsArticleSkeleton(isDarkMode: isDarkMode),
      ),
    );
  }
}

/// Skeleton for a full-screen news card (news page PageView).
class NewsPageSkeleton extends StatelessWidget {
  final bool isDarkMode;

  const NewsPageSkeleton({super.key, this.isDarkMode = false});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      isDarkMode: isDarkMode,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder  
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Title
            const SkeletonBox(height: 20),
            const SizedBox(height: 10),
            const SkeletonBox(height: 20, width: 250),
            const SizedBox(height: 16),
            // Source & date
            const SkeletonBox(height: 14, width: 150),
            const SizedBox(height: 12),
            // Description lines
            const SkeletonBox(height: 14),
            const SizedBox(height: 8),
            const SkeletonBox(height: 14),
            const SizedBox(height: 8),
            const SkeletonBox(height: 14, width: 200),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for the representative detail page.
class RepresentativeDetailSkeleton extends StatelessWidget {
  final bool isDarkMode;

  const RepresentativeDetailSkeleton({super.key, this.isDarkMode = false});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      isDarkMode: isDarkMode,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 40),
            // Avatar
            const CircleAvatar(radius: 60, backgroundColor: Colors.white),
            const SizedBox(height: 20),
            // Name
            const SkeletonBox(width: 200, height: 22),
            const SizedBox(height: 10),
            // Party / Role
            const SkeletonBox(width: 150, height: 16),
            const SizedBox(height: 6),
            const SkeletonBox(width: 180, height: 16),
            const SizedBox(height: 30),
            // Stats cards row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                SkeletonBox(width: 100, height: 80, borderRadius: 14),
                SkeletonBox(width: 100, height: 80, borderRadius: 14),
                SkeletonBox(width: 100, height: 80, borderRadius: 14),
              ],
            ),
            const SizedBox(height: 30),
            // Info sections
            const SkeletonBox(height: 120, borderRadius: 14),
            const SizedBox(height: 16),
            const SkeletonBox(height: 120, borderRadius: 14),
            const SizedBox(height: 16),
            const SkeletonBox(height: 80, borderRadius: 14),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for a search result item.
class SearchResultSkeleton extends StatelessWidget {
  final bool isDarkMode;

  const SearchResultSkeleton({super.key, this.isDarkMode = false});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      isDarkMode: isDarkMode,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Row(
          children: [
            const CircleAvatar(radius: 28, backgroundColor: Colors.white),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(height: 16, width: 160),
                  SizedBox(height: 8),
                  SkeletonBox(height: 12, width: 120),
                  SizedBox(height: 6),
                  SkeletonBox(height: 12, width: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for the map bottom sheet representative list.
class MapRepListSkeleton extends StatelessWidget {
  final bool isDarkMode;

  const MapRepListSkeleton({super.key, this.isDarkMode = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SkeletonShimmer(
            isDarkMode: isDarkMode,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: const [
                  CircleAvatar(radius: 26, backgroundColor: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(height: 14, width: 140),
                        SizedBox(height: 6),
                        SkeletonBox(height: 12, width: 100),
                        SizedBox(height: 4),
                        SkeletonBox(height: 10, width: 80),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
