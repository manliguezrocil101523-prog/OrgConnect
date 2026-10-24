import 'home_time_format.dart';
import 'dart:async';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter/material.dart' hide Notification;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/app_state.dart';
import '../../analytics/event_comments_sheet.dart';
import 'home_event_utils.dart';
import 'home_tokens.dart';

/// Shows event information and lets students manage interest and comments.
Future<void> showEventDetailsSheet(
  BuildContext context, {
  required Event event,
  int interestedCount = 0,
  VoidCallback? onInterestChanged,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return HomeLayout.capText(
        sheetContext,
        DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return _EventDetailsSheet(
              event: event,
              interestedCount: interestedCount,
              onInterestChanged: onInterestChanged,
              scrollController: scrollController,
            );
          },
        ),
      );
    },
  );
}

/// One reaction a student can pick for an event.
class _ReactionOption {
  const _ReactionOption({
    required this.key,
    required this.emoji,
    required this.label,
  });

  /// Value stored in event_reactions.reaction.
  final String key;
  final String emoji;
  final String label;
}

/// The six reactions your database allows, in display order.
const List<_ReactionOption> _reactionOptions = <_ReactionOption>[
  _ReactionOption(key: 'like', emoji: '👍', label: 'Like'),
  _ReactionOption(key: 'heart', emoji: '❤️', label: 'Love'),
  _ReactionOption(key: 'laugh', emoji: '😆', label: 'Haha'),
  _ReactionOption(key: 'wow', emoji: '😮', label: 'Wow'),
  _ReactionOption(key: 'sad', emoji: '😢', label: 'Sad'),
  _ReactionOption(key: 'angry', emoji: '😡', label: 'Angry'),
];

/// Blue used for an active like or reaction.
const Color _reactionBlue = Color(0xFF1877F2);
const Color _reactionBlueSoft = Color(0xFFE7F0FD);

/// Implements the scrollable event details and interaction controls.
class _EventDetailsSheet extends StatefulWidget {
  const _EventDetailsSheet({
    required this.event,
    required this.interestedCount,
    required this.scrollController,
    this.onInterestChanged,
  });

  final Event event;
  final int interestedCount;
  final VoidCallback? onInterestChanged;
  final ScrollController scrollController;

  @override
  State<_EventDetailsSheet> createState() => _EventDetailsSheetState();
}

class _EventDetailsSheetState extends State<_EventDetailsSheet> {
  final PageController _imageController = PageController();

  late List<String> _images;
  late int _interestedCount;

  int _currentImage = 0;
  bool _isInterested = false;
  bool _isCheckingInterest = true;
  bool _isWritingInterest = false;
  int _viewCount = 0;
  bool _isLoadingViews = true;
  String? _myReaction; // null = no reaction yet
  int _reactionCount = 0;
  bool _isLoadingReaction = true;
  bool _isWritingReaction = false;
  int _commentCount = 0;
  final LayerLink _reactionLink = LayerLink();
  OverlayEntry? _pickerEntry;
  Timer? _pickerHideTimer;
  bool _pickerModal = false; // true when opened by long press (touch)

  @override
  void initState() {
    super.initState();
    _images = _collectImages(widget.event);
    _interestedCount = widget.interestedCount.clamp(0, 1 << 30).toInt();
    _loadInterestStatus();
    _recordAndLoadViews();
    _loadReactionState();
    _loadCommentCount();
  }

  @override
  void didUpdateWidget(covariant _EventDetailsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.event.id != widget.event.id) {
      _images = _collectImages(widget.event);
      _currentImage = 0;
      _interestedCount = widget.interestedCount.clamp(0, 1 << 30).toInt();
      _isInterested = false;
      _isCheckingInterest = true;
      _isWritingInterest = false;

      _hideReactionPicker();
      _viewCount = 0;
      _isLoadingViews = true;
      _myReaction = null;
      _commentCount = 0;
      _reactionCount = 0;
      _isLoadingReaction = true;
      _isWritingReaction = false;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _imageController.hasClients) {
          _imageController.jumpToPage(0);
        }
      });

      _loadInterestStatus();
      _recordAndLoadViews();
      _loadReactionState();
      _loadCommentCount();
    } else if (oldWidget.interestedCount != widget.interestedCount &&
        !_isWritingInterest) {
      _interestedCount = widget.interestedCount.clamp(0, 1 << 30).toInt();
    }
  }

  List<String> _collectImages(Event event) {
    final images = event.imageUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList(growable: false);

    if (images.isNotEmpty) {
      return images;
    }

    final cover = event.imageUrl?.trim();
    if (cover != null && cover.isNotEmpty) {
      return <String>[cover];
    }

    return <String>[];
  }

  Future<void> _loadInterestStatus() async {
    final client = supabase.Supabase.instance.client;
    final eventId = widget.event.id;
    final userId = client.auth.currentUser?.id;

    if (userId == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isInterested = false;
        _isCheckingInterest = false;
      });
      return;
    }

    try {
      final row = await client
          .from('event_interests')
          .select('event_id')
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .maybeSingle();

      if (!mounted || widget.event.id != eventId) {
        return;
      }

      setState(() {
        _isInterested = row != null;
        _isCheckingInterest = false;
      });
    } catch (error, stackTrace) {
      if (!mounted || widget.event.id != eventId) {
        return;
      }

      setState(() {
        _isInterested = false;
        _isCheckingInterest = false;
      });
    }
  }

  /// Records one view for this event, then loads the total view count.
  Future<void> _recordAndLoadViews() async {
    final client = supabase.Supabase.instance.client;
    final eventId = widget.event.id;
    final userId = client.auth.currentUser?.id; // null for guests

    // 1) Record this view. A failure here must never break the screen.
    try {
      await client.from('event_views').insert(<String, dynamic>{
        'event_id': eventId,
        'user_id': userId,
      });
    } on supabase.PostgrestException catch (error, stackTrace) {
      // 23505 = unique violation: this account already viewed the event.
      if (error.code != '23505') {
        debugPrint('Unable to record event view: $error\n$stackTrace');
      }
    } catch (error, stackTrace) {
      debugPrint('Unable to record event view: $error\n$stackTrace');
    }

    // 2) Load the total through the safe count function.
    try {
      final result = await client.rpc(
        'get_event_view_count',
        params: <String, dynamic>{'p_event_id': eventId},
      );

      if (!mounted || widget.event.id != eventId) {
        return;
      }

      setState(() {
        _viewCount = int.tryParse('$result') ?? 0;
        _isLoadingViews = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Unable to load event view count: $error\n$stackTrace');

      if (!mounted || widget.event.id != eventId) {
        return;
      }

      setState(() {
        _isLoadingViews = false;
      });
    }
  }

  /// Loads this student's reaction (if any) and the total reaction count.
  Future<void> _loadReactionState() async {
    final client = supabase.Supabase.instance.client;
    final eventId = widget.event.id;
    final userId = client.auth.currentUser?.id; // null for guests

    try {
      final rows = await client
          .from('event_reactions')
          .select('user_id, reaction')
          .eq('event_id', eventId);

      if (!mounted || widget.event.id != eventId) {
        return;
      }

      String? mine;
      final list = rows as List;

      if (userId != null) {
        for (final row in list) {
          if (row['user_id']?.toString() == userId) {
            mine = row['reaction']?.toString();
            break;
          }
        }
      }

      setState(() {
        _reactionCount = list.length;
        _myReaction = mine;
        _isLoadingReaction = false;
      });

      debugPrint('Reactions loaded: total=$_reactionCount, mine=$_myReaction');
    } catch (error, stackTrace) {
      debugPrint('Unable to load event reactions: $error\n$stackTrace');

      if (!mounted || widget.event.id != eventId) {
        return;
      }

      setState(() {
        _isLoadingReaction = false;
      });
    }
  }

  /// Saves, changes, or removes this student's reaction.
  /// Pass null to remove the reaction.
  Future<void> _setReaction(String? newReaction) async {
    if (_isWritingReaction || _isLoadingReaction) {
      return;
    }

    final client = supabase.Supabase.instance.client;
    final eventId = widget.event.id;
    final userId = client.auth.currentUser?.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to react.'),
        ),
      );
      return;
    }

    final previousReaction = _myReaction;
    final previousCount = _reactionCount;

    if (previousReaction == newReaction) {
      return;
    }

    // Update the screen right away; roll back below if the save fails.
    setState(() {
      _isWritingReaction = true;
      _myReaction = newReaction;

      if (previousReaction == null && newReaction != null) {
        _reactionCount++;
      } else if (previousReaction != null && newReaction == null) {
        if (_reactionCount > 0) {
          _reactionCount--;
        }
      }
    });

    try {
      if (newReaction == null) {
        await client
            .from('event_reactions')
            .delete()
            .eq('event_id', eventId)
            .eq('user_id', userId);
      } else {
        await client.from('event_reactions').upsert(
          <String, dynamic>{
            'event_id': eventId,
            'user_id': userId,
            'reaction': newReaction,
          },
          onConflict: 'event_id,user_id',
        );
      }

      if (!mounted || widget.event.id != eventId) {
        return;
      }

      setState(() {
        _isWritingReaction = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Unable to update event reaction: $error\n$stackTrace');

      if (!mounted || widget.event.id != eventId) {
        return;
      }

      setState(() {
        _myReaction = previousReaction;
        _reactionCount = previousCount;
        _isWritingReaction = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update reaction. Please try again.'),
        ),
      );
    }
  }

  /// Simple tap: adds a Like, or removes whatever reaction is already set.
  void _handleReactionTap() {
    if (_myReaction == null) {
      _setReaction('like');
    } else {
      _setReaction(null);
    }
  }

  /// Loads how many comments this event has.
  Future<void> _loadCommentCount() async {
    final client = supabase.Supabase.instance.client;
    final eventId = widget.event.id;

    try {
      final rows = await client
          .from('event_comments')
          .select('id')
          .eq('event_id', eventId);

      if (!mounted || widget.event.id != eventId) {
        return;
      }

      setState(() {
        _commentCount = (rows as List).length;
      });
    } catch (error, stackTrace) {
      debugPrint('Unable to load comment count: $error\n$stackTrace');
    }
  }

  Future<void> _toggleInterest() async {
    if (_isWritingInterest || _isCheckingInterest) {
      return;
    }

    final client = supabase.Supabase.instance.client;
    final eventId = widget.event.id;
    final userId = client.auth.currentUser?.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to mark interest.'),
        ),
      );
      return;
    }

    final wasInterested = _isInterested;
    final previousCount = _interestedCount;

    setState(() {
      _isWritingInterest = true;
      _isInterested = !wasInterested;

      if (wasInterested) {
        if (_interestedCount > 0) {
          _interestedCount--;
        }
      } else {
        _interestedCount++;
      }
    });

    try {
      if (wasInterested) {
        await client
            .from('event_interests')
            .delete()
            .eq('event_id', eventId)
            .eq('user_id', userId);
      } else {
        await client.from('event_interests').upsert(
          <String, dynamic>{
            'event_id': eventId,
            'user_id': userId,
          },
          onConflict: 'event_id,user_id',
          ignoreDuplicates: true,
        );
      }

      if (!mounted || widget.event.id != eventId) {
        return;
      }

      setState(() {
        _isWritingInterest = false;
      });

      widget.onInterestChanged?.call();
    } catch (error, stackTrace) {
      debugPrint('Unable to update event interest: $error\n$stackTrace');

      if (!mounted || widget.event.id != eventId) {
        return;
      }

      setState(() {
        _isInterested = wasInterested;
        _interestedCount = previousCount;
        _isWritingInterest = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update interest. Please try again.'),
        ),
      );
    }
  }

  void _openImage(int index) {
    if (_images.isEmpty) {
      return;
    }

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _FullScreenImageGallery(
          images: _images,
          initialPage: index,
        ),
      ),
    );
  }

  Widget _buildCenteredContent(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: child,
      ),
    );
  }

  Widget _buildImageArea(double height) {
    if (_images.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: eventGradientFallback(iconSize: 46),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            PageView.builder(
              controller: _imageController,
              itemCount: _images.length,
              onPageChanged: (index) {
                if (!mounted) {
                  return;
                }

                setState(() {
                  _currentImage = index;
                });
              },
              itemBuilder: (context, index) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openImage(index),
                  child: EventImage(
                    url: _images[index],
                    fit: BoxFit.cover,
                  ),
                );
              },
            ),
            if (_images.length > 1)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: HC.dark.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentImage + 1} / ${_images.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (_images.length > 1)
              Positioned(
                bottom: 10,
                left: 12,
                right: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List<Widget>.generate(_images.length, (index) {
                    final isActive = index == _currentImage;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: isActive ? 17 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Presents date, time, and venue in a responsive metadata card.
  Widget _buildEventMetaCard() {
    final event = widget.event;
    final date = formatDateFull(event.date).trim();
    final venue = event.venue.trim();
    final time = formatTimeLabel12h(event.timeLabel);

    Widget iconBadge(IconData icon, {double size = 36}) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4F3),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: HC.ink, size: 20),
      );
    }

    Widget wideItem({
      required IconData icon,
      required String label,
      required String value,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          iconBadge(icon),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              color: HC.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: HC.ink,
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    Widget compactItem({
      required IconData icon,
      required String label,
      required String value,
    }) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          iconBadge(icon, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(
                    color: HC.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HC.ink,
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 560;
        final hasVenue = venue.isNotEmpty;
        final hasTime = time.isNotEmpty;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFBFCFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE0E7E8)),
          ),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: wideItem(
                        icon: Icons.calendar_month_outlined,
                        label: 'Date',
                        value: date,
                      ),
                    ),
                    if (hasTime) ...<Widget>[
                      Container(
                        width: 1,
                        height: 112,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        color: const Color(0xFFE0E7E8),
                      ),
                      Expanded(
                        child: wideItem(
                          icon: Icons.schedule_rounded,
                          label: 'Time',
                          value: time,
                        ),
                      ),
                    ],
                    if (hasVenue) ...<Widget>[
                      Container(
                        width: 1,
                        height: 112,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        color: const Color(0xFFE0E7E8),
                      ),
                      Expanded(
                        child: wideItem(
                          icon: Icons.location_on_outlined,
                          label: 'Venue',
                          value: venue,
                        ),
                      ),
                    ],
                  ],
                )
              : Column(
                  children: <Widget>[
                    compactItem(
                      icon: Icons.calendar_month_outlined,
                      label: 'Date',
                      value: date,
                    ),
                    if (hasVenue || hasTime) ...<Widget>[
                      const SizedBox(height: 14),
                      const Divider(
                        height: 1,
                        color: Color(0xFFE0E7E8),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          if (hasVenue)
                            Expanded(
                              child: compactItem(
                                icon: Icons.location_on_outlined,
                                label: 'Venue',
                                value: venue,
                              ),
                            ),
                          if (hasVenue && hasTime) ...<Widget>[
                            const SizedBox(width: 12),
                            Container(
                              width: 1,
                              height: 48,
                              color: const Color(0xFFE0E7E8),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (hasTime)
                            Expanded(
                              child: compactItem(
                                icon: Icons.schedule_rounded,
                                label: 'Time',
                                value: time,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }

  /// Opens the floating emoji bar above the reaction button.
  /// [modal] is true for long press: the bar stays open until the student
  /// picks an emoji or taps outside it. Hover opens it non-modally.
  void _showReactionPicker({bool modal = false}) {
    _pickerHideTimer?.cancel();

    if (_pickerEntry != null) {
      if (modal && !_pickerModal) {
        _pickerModal = true;
        _pickerEntry!.markNeedsBuild();
      }
      return;
    }

    _pickerModal = modal;
    _pickerEntry = OverlayEntry(builder: (_) => _buildReactionPicker());
    Overlay.of(context).insert(_pickerEntry!);
  }

  /// Hides the bar shortly after the mouse leaves (desktop hover only).
  void _scheduleHideReactionPicker() {
    if (_pickerModal) {
      return;
    }

    _pickerHideTimer?.cancel();
    _pickerHideTimer = Timer(
      const Duration(milliseconds: 350),
      _hideReactionPicker,
    );
  }

  void _hideReactionPicker() {
    _pickerHideTimer?.cancel();
    _pickerEntry?.remove();
    _pickerEntry = null;
    _pickerModal = false;
  }

  void _pickReaction(String reaction) {
    _hideReactionPicker();
    _setReaction(reaction);
  }

  Widget _buildReactionPickerItem(_ReactionOption option) {
    final isSelected = option.key == _myReaction;

    return Semantics(
      button: true,
      label: option.label,
      child: InkWell(
        onTap: () => _pickReaction(option.key),
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? _reactionBlueSoft : Colors.transparent,
          ),
          child: Text(
            option.emoji,
            style: const TextStyle(fontSize: 26),
          ),
        ),
      ),
    );
  }

  /// The floating bar with the six emojis, anchored above the button.
  Widget _buildReactionPicker() {
    return Stack(
      children: <Widget>[
        if (_pickerModal)
          Positioned.fill(
            key: const ValueKey<String>('reaction-picker-barrier'),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _hideReactionPicker,
            ),
          ),
        Positioned(
          key: const ValueKey<String>('reaction-picker-bar'),
          left: 0,
          top: 0,
          child: CompositedTransformFollower(
            link: _reactionLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.topLeft,
            followerAnchor: Alignment.bottomLeft,
            offset: const Offset(0, -6),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) {
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, 10 * (1 - t)),
                    child: Transform.scale(
                      scale: 0.85 + 0.15 * t,
                      alignment: Alignment.bottomLeft,
                      child: child,
                    ),
                  ),
                );
              },
              child: MouseRegion(
                onEnter: (_) => _pickerHideTimer?.cancel(),
                onExit: (_) => _scheduleHideReactionPicker(),
                child: Material(
                  color: Colors.white,
                  elevation: 8,
                  shadowColor: Colors.black38,
                  borderRadius: BorderRadius.circular(32),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (final option in _reactionOptions)
                          _buildReactionPickerItem(option),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Reaction button: tap = Like, long press / hover = emoji bar.
  /// Layout: [icon] [count] Like. The word always stays "Like".
  Widget _buildReactionButton() {
    final mine = _myReaction;
    final isActive = mine != null;
    final color = HC.muted;
    final Widget icon;

    if (mine == null) {
      icon = const Icon(
        Icons.thumb_up_alt_outlined,
        size: 21,
        color: HC.muted,
      );
    } else if (mine == 'like') {
      icon = const Icon(
        Icons.thumb_up_alt_rounded,
        size: 21,
        color: _reactionBlue,
      );
    } else {
      final option = _reactionOptions.firstWhere(
        (o) => o.key == mine,
        orElse: () => _reactionOptions.first,
      );
      icon = Text(option.emoji, style: const TextStyle(fontSize: 20));
    }

    return Expanded(
      child: CompositedTransformTarget(
        link: _reactionLink,
        child: MouseRegion(
          onEnter: (_) => _showReactionPicker(),
          onExit: (_) => _scheduleHideReactionPicker(),
          child: Semantics(
            button: true,
            label: 'React',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _hideReactionPicker();
                  _handleReactionTap();
                },
                onLongPress: () {
                  HapticFeedback.selectionClick();
                  _showReactionPicker(modal: true);
                },
                borderRadius: BorderRadius.circular(12),
                splashColor: HC.muted.withValues(alpha: 0.10),
                highlightColor: HC.muted.withValues(alpha: 0.05),
                hoverColor: HC.muted.withValues(alpha: 0.05),
                child: SizedBox(
                  height: 48,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        icon,
                        if (_reactionCount > 0) ...<Widget>[
                          const SizedBox(width: 5),
                          Text(
                            '$_reactionCount',
                            style: TextStyle(
                              color: color,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'Like',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Comment button. Layout: [icon] [count] Comment.
  Widget _buildCommentButton() {
    return Expanded(
      child: Semantics(
        button: true,
        label: 'Comment',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              _hideReactionPicker();

              await Future<void>.sync(
                () => showEventComments(
                  context,
                  eventId: widget.event.id,
                  eventTitle: widget.event.title,
                ),
              );

              // Refresh the number after the comments sheet is closed.
              if (mounted) {
                _loadCommentCount();
              }
            },
            borderRadius: BorderRadius.circular(12),
            splashColor: HC.muted.withValues(alpha: 0.10),
            highlightColor: HC.muted.withValues(alpha: 0.05),
            hoverColor: HC.muted.withValues(alpha: 0.05),
            child: SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 20,
                      color: HC.muted,
                    ),
                    if (_commentCount > 0) ...<Widget>[
                      const SizedBox(width: 5),
                      Text(
                        '$_commentCount',
                        style: const TextStyle(
                          color: HC.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(width: 5),
                    const Flexible(
                      child: Text(
                        'Comment',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: HC.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: (_isCheckingInterest || _isWritingInterest)
                ? null
                : _toggleInterest,
            style: FilledButton.styleFrom(
              backgroundColor: HC.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: HC.primary.withValues(alpha: 0.45),
              disabledForegroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 17,
              ),
              minimumSize: const Size(44, 58),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            icon: _isWritingInterest
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    _isInterested
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 21,
                  ),
            label: const Text(
              'Interested',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // TODO: connect view tracking
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            const Icon(
              Icons.visibility_outlined,
              size: 17,
              color: HC.muted,
            ),
            const SizedBox(width: 6),
            Text(
              _isLoadingViews
                  ? '-- views'
                  : '$_viewCount ${_viewCount == 1 ? 'view' : 'views'}',
              style: const TextStyle(
                color: HC.muted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: HC.line),
        Row(
          children: <Widget>[
            _buildReactionButton(),
            _buildCommentButton(),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _pickerHideTimer?.cancel();
    _pickerEntry?.remove();
    _pickerEntry = null;
    _imageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final orgName = event.orgName.trim();
    final description = event.description.trim();
    final imageHeight = (MediaQuery.sizeOf(context).width * 0.49)
        .clamp(180.0, 270.0)
        .toDouble();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
        child: Column(
          children: <Widget>[
            Expanded(
              child: _buildCenteredContent(
                SingleChildScrollView(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: HC.line,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          IconButton(
                            tooltip: 'Back to events',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                            color: Colors.black,
                          ),
                          const SizedBox(width: 2),
                          const Expanded(
                            child: Text(
                              'Events',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildImageArea(imageHeight),
                      const SizedBox(height: 20),
                      if (orgName.isNotEmpty) ...<Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9F8F0),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: HC.line),
                          ),
                          child: Text(
                            orgName.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: HC.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Text(
                        event.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        style: const TextStyle(
                          color: HC.ink,
                          fontSize: 29,
                          height: 1.15,
                          letterSpacing: -0.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildEventMetaCard(),
                      const SizedBox(height: 28),
                      const Text(
                        'About this event',
                        style: TextStyle(
                          color: HC.ink,
                          fontSize: 21,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description.isEmpty
                            ? 'No description provided yet.'
                            : description,
                        style: TextStyle(
                          color: description.isEmpty ? HC.muted : HC.ink,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                12 + MediaQuery.paddingOf(context).bottom,
              ),
              child: _buildCenteredContent(
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Divider(height: 1, color: HC.line),
                    const SizedBox(height: 18),
                    _buildActionRow(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Displays event images on a black route with pinch-to-zoom support.
class _FullScreenImageGallery extends StatefulWidget {
  const _FullScreenImageGallery({
    required this.images,
    required this.initialPage,
  });

  final List<String> images;
  final int initialPage;

  @override
  State<_FullScreenImageGallery> createState() =>
      _FullScreenImageGalleryState();
}

class _FullScreenImageGalleryState extends State<_FullScreenImageGallery> {
  late final PageController _controller;
  late int _currentPage;

  @override
  void initState() {
    super.initState();

    _currentPage =
        widget.initialPage.clamp(0, widget.images.length - 1).toInt();
    _controller = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: widget.images.length > 1
            ? Text(
                '${_currentPage + 1} / ${widget.images.length}',
                style: const TextStyle(fontSize: 14),
              )
            : const SizedBox.shrink(),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (index) {
          if (!mounted) {
            return;
          }

          setState(() {
            _currentPage = index;
          });
        },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: SizedBox.expand(
              child: EventImage(
                url: widget.images[index],
                fit: BoxFit.contain,
                fallback: const SizedBox.expand(),
              ),
            ),
          );
        },
      ),
    );
  }
}
