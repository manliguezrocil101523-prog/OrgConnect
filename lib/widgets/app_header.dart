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
  });

  final String title;
  final String subtitle;
  final String status;
  final IconData? icon; // if set, shows an icon tile
  final Widget? leadingWidget;
  final String avatarUrl; // used when icon is null
  final Widget? trailing; // e.g. an Edit button
  final ImageProvider? avatarImage; // overrides avatarUrl (e.g. a picked photo)
  final VoidCallback? onAvatarTap; // makes the avatar tappable
  final bool avatarEditing; // shows the little camera badge
  final VoidCallback? onBack; // shows a back arrow when set

  // ONE height for every page (excluding status bar)
  static const double contentHeight = 140;
  static const double leadingSize = 64;
  // Shared brand gradient: use this everywhere so all screens match
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF064E3B), Color(0xFF0B6B4D), Color(0xFF1A9E6B)],
  );

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      height: contentHeight + topInset,
      clipBehavior:
          Clip.antiAlias, // clips the white shapes to the rounded corners
      decoration: const BoxDecoration(
        gradient: brandGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Stack(
        children: [
          Positioned(right: -45, top: -70, child: _orb(170)),
          Positioned(right: 45, bottom: -70, child: _orb(125)),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  onBack != null ? 56 : 20, topInset, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _leading(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .86),
                            fontSize: 13,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
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
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
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
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  Widget _leading() {
    if (leadingWidget != null) return leadingWidget!;
    if (icon != null) {
      return Container(
        width: leadingSize,
        height: leadingSize,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Icon(icon, color: Colors.white, size: 32),
      );
    }

    final ImageProvider? image =
        avatarImage ?? (avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null);

    final avatar = Container(
      width: leadingSize,
      height: leadingSize,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: .20),
      ),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration:
            const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
        child: CircleAvatar(
          backgroundColor: const Color(0xFFE0F5E8),
          backgroundImage: image,
          child: image == null
              ? const Icon(Icons.person_rounded,
                  color: Color(0xFF128058), size: 31)
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
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFF16A34A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: Colors.white, size: 13),
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
