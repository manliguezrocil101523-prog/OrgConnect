import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide Notification;

import '../../../core/app_state.dart';
import 'home_tokens.dart';

/// Returns the first usable image URL for an event.
String? eventCoverImage(Event event) {
  for (final url in event.imageUrls) {
    if (url.trim().isNotEmpty) {
      return url.trim();
    }
  }

  final singleImage = event.imageUrl;
  if (singleImage != null && singleImage.trim().isNotEmpty) {
    return singleImage.trim();
  }

  return null;
}

/// Displays a network image, an embedded base64 image, or a fallback.
class EventImage extends StatefulWidget {
  const EventImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.fallback,
  });

  final String url;
  final BoxFit fit;
  final Widget? fallback;

  @override
  State<EventImage> createState() => _EventImageState();
}

class _EventImageState extends State<EventImage> {
  Uint8List? _dataBytes;
  bool _isDataUrl = false;

  @override
  void initState() {
    super.initState();
    _decodeCurrentUrl();
  }

  @override
  void didUpdateWidget(covariant EventImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.url != widget.url) {
      _decodeCurrentUrl();
    }
  }

  void _decodeCurrentUrl() {
    _isDataUrl = widget.url.toLowerCase().startsWith('data:');
    _dataBytes = null;

    if (!_isDataUrl) {
      return;
    }

    try {
      final commaIndex = widget.url.indexOf(',');
      if (commaIndex < 0) {
        throw const FormatException('Invalid data URL.');
      }

      final metadata = widget.url.substring(0, commaIndex);
      if (!metadata.toLowerCase().contains(';base64')) {
        throw const FormatException('Expected a base64 data URL.');
      }

      final encoded = widget.url.substring(commaIndex + 1);
      _dataBytes = base64Decode(encoded);
    } catch (error) {
      debugPrint('EventImage: unable to decode embedded image: $error');
      _dataBytes = null;
    }
  }

  Widget _fallback() {
    return widget.fallback ?? eventGradientFallback();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDataUrl) {
      final bytes = _dataBytes;
      if (bytes == null) {
        return _fallback();
      }

      return Image.memory(
        bytes,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _fallback(),
      );
    }

    final normalizedUrl = widget.url.trim().toLowerCase();
    if (normalizedUrl.startsWith('https://') ||
        normalizedUrl.startsWith('http://')) {
      return CachedNetworkImage(
        imageUrl: widget.url.trim(),
        fit: widget.fit,
        placeholder: (context, url) => const ColoredBox(
          color: HC.mint,
          child: Center(
            child: Icon(
              Icons.image_outlined,
              color: HC.primary,
              size: 30,
            ),
          ),
        ),
        errorWidget: (context, url, error) => _fallback(),
      );
    }

    return _fallback();
  }
}

/// Provides a green gradient image placeholder without requiring an asset.
Widget eventGradientFallback({double iconSize = 34}) {
  return Container(
    decoration: const BoxDecoration(gradient: HC.heroGradient),
    alignment: Alignment.center,
    child: Icon(
      Icons.auto_awesome_rounded,
      color: Colors.white,
      size: iconSize,
    ),
  );
}

const List<String> _monthShort = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const List<String> _monthFull = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const List<String> _weekdayFull = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Returns a three-letter uppercase month, such as OCT.
String monthShortUpper(int month) {
  if (month < 1 || month > _monthShort.length) {
    return '';
  }

  return _monthShort[month - 1].toUpperCase();
}

/// Formats a date as "Oct 22, 2026".
String formatDateShort(DateTime date) {
  final month = _monthShort[date.month - 1];
  return '$month ${date.day}, ${date.year}';
}

/// Formats a date as "Thursday, October 22, 2026".
String formatDateFull(DateTime date) {
  final weekday = _weekdayFull[date.weekday - 1];
  final month = _monthFull[date.month - 1];
  return '$weekday, $month ${date.day}, ${date.year}';
}
