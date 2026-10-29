import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.status,
    this.icon,
    this.leadingWidget,
    this.avatarUrl = '',
    this.trailing,
    this.avatarImage,
    this.onAvatarTap,
    this.avatarEditing = false,
    this.onBack,
    // Retained so existing screens that pass this argument continue to compile.
    // The header now always has square corners at the bottom.
    this.squareBottom = false,
  });

  final String title;
  final String subtitle;
  final String status;
  final IconData? icon;
  final Widget? leadingWidget;
  final String avatarUrl;
  final Widget? trailing;
  final ImageProvider? avatarImage;
  final VoidCallback? onAvatarTap;
  final bool avatarEditing;
  final VoidCallback? onBack;

  /// Retained for compatibility with existing call sites.
  /// Bottom corners are now square for every AppHeader instance, regardless
  /// of this value.
  final bool squareBottom;

  static const double contentHeight = 140;
  static const double leadingSize = 64;

  // Original brand colors are preserved.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF064E3B),
      Color(0xFF0B6B4D),
      Color(0xFF1A9E6B),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 400;
        final horizontalPadding = compact ? 12.0 : 20.0;
        final leadingGap = compact ? 8.0 : 14.0;

        return Container(
          width: double.infinity,
          height: contentHeight + topInset,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(
            gradient: brandGradient,
            // Always square: no rounding along the bottom edge.
            borderRadius: BorderRadius.zero,
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                right: -45,
                top: -70,
                child: _orb(170),
              ),
              Positioned(
                right: 45,
                bottom: -70,
                child: _orb(125),
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    onBack != null
                        ? (compact ? 48 : 56)
                        : horizontalPadding,
                    topInset,
                    horizontalPadding,
                    0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _leading(compact: compact),
                      SizedBox(width: leadingGap),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: compact ? 21 : 26,
                                fontWeight: FontWeight.w900,
                                height: 1.15,
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: compact ? 4 : 6),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .86),
                                fontSize: compact ? 11 : 13,
                                height: 1.25,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: compact ? 6 : 10),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF86EFAC),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Flexible(
                                  child: Text(
                                    status,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: compact ? 9 : 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: compact ? .3 : .6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (trailing != null) ...[
                        SizedBox(width: compact ? 6 : 8),
                        trailing!,
                      ],
                    ],
                  ),
                ),
              ),
              if (onBack != null)
                Positioned(
                  left: 6,
                  top: topInset + 6,
                  child: IconButton(
                    tooltip: 'Back',
                    onPressed: onBack,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _leading({required bool compact}) {
    if (leadingWidget != null) return leadingWidget!;

    if (icon != null) {
      return Container(
        width: compact ? 48 : leadingSize,
        height: compact ? 48 : leadingSize,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: compact ? 26 : 32,
        ),
      );
    }

    final ImageProvider? image =
        avatarImage ?? (avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null);

    final size = compact ? 48.0 : leadingSize;

    final avatar = Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: .20),
      ),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: CircleAvatar(
          backgroundColor: const Color(0xFFE0F5E8),
          backgroundImage: image,
          child: image == null
              ? Icon(
                  Icons.person_rounded,
                  color: const Color(0xFF128058),
                  size: compact ? 25 : 31,
                )
              : null,
        ),
      ),
    );

    if (onAvatarTap == null && !avatarEditing) return avatar;

    return GestureDetector(
      onTap: onAvatarTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          if (avatarEditing)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: compact ? 20 : 24,
                height: compact ? 20 : 24,
                decoration: const BoxDecoration(
                  color: Color(0xFF16A34A),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: compact ? 11 : 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _orb(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: .07),
        ),
      );
}
