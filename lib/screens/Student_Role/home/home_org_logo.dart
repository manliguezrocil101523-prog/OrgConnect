import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'home_tokens.dart';

/// Displays an organization logo with reliable fallbacks for every source type.
class OrgLogoAvatar extends StatefulWidget {
  final String logoAsset;
  final double size;
  final double radius;

  const OrgLogoAvatar({
    super.key,
    required this.logoAsset,
    required this.size,
    this.radius = 14,
  });

  @override
  State<OrgLogoAvatar> createState() => _OrgLogoAvatarState();
}

/// Holds decoded image data so data URIs are not decoded on every rebuild.
class _OrgLogoAvatarState extends State<OrgLogoAvatar> {
  Uint8List? _dataBytes;

  @override
  void initState() {
    super.initState();
    _decodeDataUri();
  }

  @override
  void didUpdateWidget(covariant OrgLogoAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.logoAsset != widget.logoAsset) {
      _decodeDataUri();
    }
  }

  void _decodeDataUri() {
    _dataBytes = null;

    final source = widget.logoAsset;
    if (!source.startsWith('data:')) {
      return;
    }

    try {
      final commaIndex = source.indexOf(',');
      if (commaIndex < 0) {
        throw const FormatException('Invalid data URI.');
      }

      final metadata = source.substring(0, commaIndex).toLowerCase();
      if (!metadata.contains(';base64')) {
        throw const FormatException('Expected a base64 data URI.');
      }

      final encodedData = source.substring(commaIndex + 1);
      _dataBytes = Uint8List.fromList(base64.decode(encodedData));
    } catch (error) {
      debugPrint('Unable to decode organization logo: $error');
      _dataBytes = null;
    }
  }

  Widget _fallback() {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Center(
        child: Icon(
          Icons.groups_rounded,
          size: widget.size * 0.48,
          color: HC.primary,
        ),
      ),
    );
  }

  String _preferredAssetPath(String path) {
    return path.replaceFirst(
      RegExp(r'\.(jpe?g)$', caseSensitive: false),
      '.png',
    );
  }

  Widget _localAssetImage() {
    final originalPath = widget.logoAsset;
    final preferredPath = _preferredAssetPath(originalPath);

    return Image.asset(
      preferredPath,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        if (preferredPath == originalPath) {
          return _fallback();
        }

        return Image.asset(
          originalPath,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _fallback(),
        );
      },
    );
  }

  Widget _logoContent() {
    final source = widget.logoAsset.trim();

    if (source.isEmpty) {
      return _fallback();
    }

    if (source.startsWith('data:')) {
      final bytes = _dataBytes;

      if (bytes == null) {
        return _fallback();
      }

      return Image.memory(
        bytes,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _fallback(),
      );
    }

    if (source.startsWith('http://') || source.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: source,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        placeholder: (context, url) => _fallback(),
        errorWidget: (context, url, error) => _fallback(),
      );
    }

    return _localAssetImage();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: HC.mint,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: HC.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          (widget.radius - 1).clamp(0, widget.radius).toDouble(),
        ),
        child: Center(child: _logoContent()),
      ),
    );
  }
}
