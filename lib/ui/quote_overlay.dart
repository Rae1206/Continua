import 'dart:ui';
import 'package:flutter/material.dart';

class QuoteOverlay extends StatefulWidget {
  final String text;
  final String author;

  const QuoteOverlay({Key? key, required this.text, required this.author}) : super(key: key);

  static Future<void> showInApp(BuildContext context, String text, String author) async {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'quote',
      barrierColor: Colors.black38,
      pageBuilder: (_, __, ___) => Align(
        alignment: Alignment.topCenter,
        child: SafeArea(
          child: QuoteOverlay(text: text, author: author),
        ),
      ),
      transitionBuilder: (context, anim, secAnim, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: Tween<double>(begin: 0.9, end: 1).animate(anim), child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }

  @override
  State<QuoteOverlay> createState() => _QuoteOverlayState();
}

class _QuoteOverlayState extends State<QuoteOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _controller.forward();
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      _controller.reverse().then((_) {
        if (mounted) Navigator.of(context).pop();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _controller.value,
            child: Transform.translate(
              offset: Offset(0, -30 * (1 - _controller.value)),
              child: child,
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.text, style: const TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('- ${widget.author}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
