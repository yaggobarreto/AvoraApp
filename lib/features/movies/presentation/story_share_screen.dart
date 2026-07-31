import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gradient_button.dart';

/// Median is what the group asked to show (not the mean): with few ratings a
/// single outlier skews an average badly, while the median stays
/// representative of what the group actually thought.
double? medianRating(List<double> ratings) {
  if (ratings.isEmpty) return null;
  final sorted = [...ratings]..sort();
  final middle = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[middle];
  return (sorted[middle - 1] + sorted[middle]) / 2;
}

class StoryShareScreen extends StatefulWidget {
  final String movieTitle;
  final String? posterUrl;
  final double? myRating;
  final double? groupMedianRating;
  final String groupName;

  const StoryShareScreen({
    super.key,
    required this.movieTitle,
    required this.groupName,
    this.posterUrl,
    this.myRating,
    this.groupMedianRating,
  });

  @override
  State<StoryShareScreen> createState() => _StoryShareScreenState();
}

class _StoryShareScreenState extends State<StoryShareScreen> {
  final _cardKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _share() async {
    setState(() => _isSharing = true);
    try {
      final boundary =
          _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      // 1080x1920 is the Story canvas; the card renders smaller on screen, so
      // scale up on capture to avoid a blurry export.
      final pixelRatio = 1080 / boundary.size.width;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      await Share.shareXFiles(
        [
          XFile.fromData(
            Uint8List.fromList(bytes),
            mimeType: 'image/png',
            name: 'avora-story.png',
          ),
        ],
        fileNameOverrides: const ['avora-story.png'],
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não deu para compartilhar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compartilhar')),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: _StoryCard(
                      movieTitle: widget.movieTitle,
                      posterUrl: widget.posterUrl,
                      myRating: widget.myRating,
                      groupMedianRating: widget.groupMedianRating,
                      groupName: widget.groupName,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: GradientButton(
              onPressed: _isSharing ? null : _share,
              child: _isSharing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Compartilhar no Story'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  final String movieTitle;
  final String? posterUrl;
  final double? myRating;
  final double? groupMedianRating;
  final String groupName;

  const _StoryCard({
    required this.movieTitle,
    required this.groupName,
    this.posterUrl,
    this.myRating,
    this.groupMedianRating,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Everything scales off the card width so the exported 1080px image
        // matches the on-screen preview proportionally.
        final unit = constraints.maxWidth / 100;

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF150F2B), AppTheme.background],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: unit * 9, vertical: unit * 11),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(unit * 5),
                    child: posterUrl != null
                        ? CachedNetworkImage(
                            imageUrl: posterUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorWidget: (context, url, error) => const ColoredBox(
                              color: AppTheme.surfaceHigh,
                              child: Icon(Icons.movie, color: Colors.white24, size: 48),
                            ),
                          )
                        : const ColoredBox(
                            color: AppTheme.surfaceHigh,
                            child: Icon(Icons.movie, color: Colors.white24, size: 48),
                          ),
                  ),
                ),
                SizedBox(height: unit * 6),
                Text(
                  movieTitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: unit * 7.5,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: unit * 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (myRating != null)
                      _ScoreBlock(label: 'Minha nota', value: myRating!, unit: unit),
                    if (myRating != null && groupMedianRating != null)
                      Container(
                        width: 1,
                        height: unit * 13,
                        margin: EdgeInsets.symmetric(horizontal: unit * 7),
                        color: Colors.white24,
                      ),
                    if (groupMedianRating != null)
                      _ScoreBlock(
                        label: 'Mediana do grupo',
                        value: groupMedianRating!,
                        unit: unit,
                      ),
                  ],
                ),
                SizedBox(height: unit * 7),
                Text(
                  groupName.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: unit * 2.6,
                    letterSpacing: unit * 0.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: unit * 2),
                ShaderMask(
                  shaderCallback: (rect) => AppTheme.primaryGradient.createShader(rect),
                  child: Text(
                    'AVORA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: unit * 5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: unit * 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScoreBlock extends StatelessWidget {
  final String label;
  final double value;
  final double unit;

  const _ScoreBlock({required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '★ ${value.toStringAsFixed(1)}',
          style: TextStyle(
            color: Colors.white,
            fontSize: unit * 9,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: unit * 1),
        Text(
          label,
          style: TextStyle(color: Colors.white54, fontSize: unit * 3.2),
        ),
      ],
    );
  }
}
