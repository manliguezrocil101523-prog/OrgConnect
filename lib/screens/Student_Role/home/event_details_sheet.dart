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

  @override
  void initState() {
    super.initState();
    _images = _collectImages(widget.event);
    _interestedCount = widget.interestedCount.clamp(0, 1 << 30).toInt();
    _loadInterestStatus();
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

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _imageController.hasClients) {
          _imageController.jumpToPage(0);
        }
      });

      _loadInterestStatus();
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
          .from('event_reactions')
          .select('reaction')
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .maybeSingle();

      if (!mounted || widget.event.id != eventId) {
        return;
      }

      setState(() {
        _isInterested = row != null && row['reaction'] == 'heart';
        _isCheckingInterest = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Unable to load event interest status: $error\n$stackTrace');

      if (!mounted || widget.event.id != eventId) {
        return;
      }

      setState(() {
        _isInterested = false;
        _isCheckingInterest = false;
      });
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
            .from('event_reactions')
            .delete()
            .eq('event_id', eventId)
            .eq('user_id', userId);
      } else {
        await client.from('event_reactions').upsert(
          <String, dynamic>{
            'event_id': eventId,
            'user_id': userId,
            'reaction': 'heart',
          },
          onConflict: 'event_id,user_id',
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

  Widget _buildInfoRows() {
    return _EventInfoRow(
      icon: Icons.calendar_month_outlined,
      label: formatDateFull(widget.event.date),
    );
  }

  Widget _buildVenueTimeCard() {
    final event = widget.event;
    final venue = event.venue.trim();
    final time = event.timeLabel.trim();

    if (venue.isEmpty && time.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget item({
      required IconData icon,
      required String label,
      required String value,
    }) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE3F5EC),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: HC.primary, size: 21),
          ),
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
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
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
        final stackItems =
            constraints.maxWidth < 340 && venue.isNotEmpty && time.isNotEmpty;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF2FBF6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: HC.line),
          ),
          child: stackItems
              ? Column(
                  children: <Widget>[
                    item(
                      icon: Icons.location_on_outlined,
                      label: 'Venue',
                      value: venue,
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: HC.line),
                    const SizedBox(height: 14),
                    item(
                      icon: Icons.schedule_rounded,
                      label: 'Time',
                      value: time,
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    if (venue.isNotEmpty)
                      Expanded(
                        child: item(
                          icon: Icons.location_on_outlined,
                          label: 'Venue',
                          value: venue,
                        ),
                      ),
                    if (venue.isNotEmpty && time.isNotEmpty) ...<Widget>[
                      const SizedBox(width: 12),
                      Container(
                        height: 52,
                        width: 1,
                        color: HC.line,
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (time.isNotEmpty)
                      Expanded(
                        child: item(
                          icon: Icons.schedule_rounded,
                          label: 'Time',
                          value: time,
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildActionRow() {
    final event = widget.event;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            FilledButton.icon(
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
                  vertical: 14,
                ),
                minimumSize: const Size(44, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _isWritingInterest
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _isInterested
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 19,
                    ),
              label: const Text(
                'Interested',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (_interestedCount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  '$_interestedCount interested',
                  style: const TextStyle(
                    color: HC.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              showEventComments(
                context,
                eventId: event.id,
                eventTitle: event.title,
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: HC.primary,
              side: const BorderSide(color: HC.primary),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
              minimumSize: const Size(44, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.forum_outlined, size: 19),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                EventCommentCountLabel(
                  eventId: event.id,
                  style: const TextStyle(
                    color: HC.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const Text(
                  '  ·  Reactions',
                  style: TextStyle(
                    color: HC.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
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
        child: SingleChildScrollView(
          controller: widget.scrollController,
          padding: EdgeInsets.fromLTRB(
            20,
            10,
            20,
            28 + MediaQuery.paddingOf(context).bottom,
          ),
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
                    color: HC.primary,
                  ),
                  const SizedBox(width: 2),
                  const Expanded(
                    child: Text(
                      'Events',
                      style: TextStyle(
                        color: HC.primary,
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
                style: const TextStyle(
                  color: HC.ink,
                  fontSize: 29,
                  height: 1.15,
                  letterSpacing: -0.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              _buildInfoRows(),
              if (event.venue.trim().isNotEmpty ||
                  event.timeLabel.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                _buildVenueTimeCard(),
              ],
              const SizedBox(height: 22),
              const Divider(height: 1, color: HC.line),
              const SizedBox(height: 20),
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
              const SizedBox(height: 24),
              _buildActionRow(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Displays one event detail item with its matching icon.
class _EventInfoRow extends StatelessWidget {
  const _EventInfoRow({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFE9F8F0),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            size: 21,
            color: HC.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: HC.ink,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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
