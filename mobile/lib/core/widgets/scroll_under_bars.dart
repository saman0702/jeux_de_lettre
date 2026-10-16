import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Liste qui occupe toute la hauteur et passe sous un en-tête et un pied de
/// page transparents : rien ne trahit le bord de la zone de défilement. La
/// liste reçoit en marges la hauteur mesurée de l'en-tête et du pied, pour que
/// le premier et le dernier élément restent visibles.
class ScrollUnderBars extends StatefulWidget {
  const ScrollUnderBars({
    super.key,
    required this.header,
    required this.builder,
    this.footer,
    this.gap = 8,
  });

  final Widget header;
  final Widget? footer;

  /// Construit la liste avec les marges [padding] à appliquer.
  final Widget Function(BuildContext context, EdgeInsets padding) builder;

  /// Espace entre l'en-tête (ou le pied) et le contenu au repos.
  final double gap;

  @override
  State<ScrollUnderBars> createState() => _ScrollUnderBarsState();
}

class _ScrollUnderBarsState extends State<ScrollUnderBars> {
  double _top = 0;
  double _bottom = 0;

  void _setTop(Size size) {
    if (size.height != _top) setState(() => _top = size.height);
  }

  void _setBottom(Size size) {
    if (size.height != _bottom) setState(() => _bottom = size.height);
  }

  @override
  Widget build(BuildContext context) {
    final footer = widget.footer;
    return Stack(
      children: [
        Positioned.fill(
          child: widget.builder(
            context,
            EdgeInsets.only(
              top: _top + widget.gap,
              bottom: _bottom + widget.gap,
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _SizeReporter(onSize: _setTop, child: widget.header),
        ),
        if (footer != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _SizeReporter(onSize: _setBottom, child: footer),
          ),
      ],
    );
  }
}

/// Signale la taille de son enfant après chaque mise en page.
class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({required this.onSize, required super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSizeReporter renderObject,
  ) => renderObject.onSize = onSize;
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onSize);

  ValueChanged<Size> onSize;
  Size? _reported;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _reported) return;
    _reported = size;
    final measured = size;
    // Pas de setState pendant la mise en page : on attend la fin de l'image.
    SchedulerBinding.instance.addPostFrameCallback((_) => onSize(measured));
  }
}
