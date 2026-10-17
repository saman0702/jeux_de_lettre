import 'package:flutter/material.dart';

/// Contenu défilant qui passe sous un en-tête et un pied de page entièrement
/// transparents (pas de fondu ni de bandeau), comme les menus des jeux.
class FloatingBarsLayout extends StatelessWidget {
  const FloatingBarsLayout({
    super.key,
    required this.header,
    required this.children,
    this.footer,
    this.headerHeight = 66,
    this.footerHeight = 92,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final Widget header;
  final Widget? footer;
  final List<Widget> children;
  final double headerHeight;
  final double footerHeight;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final bottom = footer == null ? 16.0 : footerHeight;
    return Stack(
      children: [
        Positioned.fill(
          child: ListView(
            padding: padding.copyWith(top: headerHeight, bottom: bottom + 8),
            children: children,
          ),
        ),
        Positioned(top: 0, left: 0, right: 0, child: header),
        if (footer != null)
          Positioned(left: 0, right: 0, bottom: 0, child: footer!),
      ],
    );
  }
}
