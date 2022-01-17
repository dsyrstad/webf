/*
 * Copyright (C) 2019-present Alibaba Inc. All rights reserved.
 * Author: Kraken Team.
 */

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:kraken/css.dart';
import 'package:kraken/rendering.dart';

enum BackgroundBoundary {
  borderBox,
  paddingBox,
  contentBox,
}

mixin RenderBoxDecorationMixin on RenderBoxModelBase {
  BoxDecorationPainter? _painter;

  BoxDecorationPainter? get boxPainter => _painter;

  set boxPainter(BoxDecorationPainter? painter) {
    _painter = painter;
  }

  void disposePainter() {
    _painter?.dispose();
    _painter = null;
  }

  void paintBackground(
      PaintingContext context, Offset offset, EdgeInsets? padding) {
    CSSBoxDecoration? decoration = renderStyle.decoration;
    DecorationPosition decorationPosition = renderStyle.decorationPosition;
    ImageConfiguration imageConfiguration = renderStyle.imageConfiguration;

    if (decoration == null) return;
    _painter ??= BoxDecorationPainter(
          padding, renderStyle, markNeedsPaint);

    final ImageConfiguration filledConfiguration =
        imageConfiguration.copyWith(size: size);
    if (decorationPosition == DecorationPosition.background) {
      int? debugSaveCount;
      assert(() {
        debugSaveCount = context.canvas.getSaveCount();
        return true;
      }());
      _painter!.paintBackground(context.canvas, offset, filledConfiguration);
      assert(() {
        if (debugSaveCount != context.canvas.getSaveCount()) {
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary(
                '${decoration.runtimeType} painter had mismatching save and restore calls.'),
            ErrorDescription(
                'Before painting the decoration, the canvas save count was $debugSaveCount. '
                'After painting it, the canvas save count was ${context.canvas.getSaveCount()}. '
                'Every call to save() or saveLayer() must be matched by a call to restore().'),
            DiagnosticsProperty<Decoration>('The decoration was', decoration,
                style: DiagnosticsTreeStyle.errorProperty),
            DiagnosticsProperty<BoxPainter>('The painter was', _painter,
                style: DiagnosticsTreeStyle.errorProperty),
          ]);
        }
        return true;
      }());
      if (decoration.isComplex) context.setIsComplexHint();
    }

    if (decorationPosition == DecorationPosition.foreground) {
      _painter!.paint(context.canvas, offset, filledConfiguration);
      if (decoration.isComplex) context.setIsComplexHint();
    }
  }

  void paintDecoration(
      PaintingContext context, Offset offset, PaintingContextCallback callback) {
    CSSBoxDecoration? decoration = renderStyle.decoration;
    DecorationPosition decorationPosition = renderStyle.decorationPosition;
    ImageConfiguration imageConfiguration = renderStyle.imageConfiguration;

    if (decoration == null) return callback(context, offset);

    EdgeInsets? padding = renderStyle.padding.resolve(TextDirection.ltr);
    _painter ??=
        BoxDecorationPainter(padding, renderStyle, markNeedsPaint);

    final ImageConfiguration filledConfiguration =
        imageConfiguration.copyWith(size: size);
    if (decorationPosition == DecorationPosition.background) {
      int? debugSaveCount;
      assert(() {
        debugSaveCount = context.canvas.getSaveCount();
        return true;
      }());

      _painter!.paint(context.canvas, offset, filledConfiguration);
      assert(() {
        if (debugSaveCount != context.canvas.getSaveCount()) {
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary(
                '${decoration.runtimeType} painter had mismatching save and restore calls.'),
            ErrorDescription(
                'Before painting the decoration, the canvas save count was $debugSaveCount. '
                'After painting it, the canvas save count was ${context.canvas.getSaveCount()}. '
                'Every call to save() or saveLayer() must be matched by a call to restore().'),
            DiagnosticsProperty<Decoration>('The decoration was', decoration,
                style: DiagnosticsTreeStyle.errorProperty),
            DiagnosticsProperty<BoxPainter>('The painter was', _painter,
                style: DiagnosticsTreeStyle.errorProperty),
          ]);
        }
        return true;
      }());
      if (decoration.isComplex) context.setIsComplexHint();
    }
    Offset contentOffset;
    EdgeInsets borderEdge = renderStyle.border;
    contentOffset = offset.translate(borderEdge.left, borderEdge.top);
    super.paint(context, contentOffset);
    if (decorationPosition == DecorationPosition.foreground) {
      _painter!.paint(context.canvas, offset, filledConfiguration);
      if (decoration.isComplex) context.setIsComplexHint();
    }

    // Content of renderBox are effected by border-radius in the following cases:
    // https://www.w3.org/TR/css-backgrounds-3/#corner-clipping
    bool isClipOverflowContent = renderStyle.borderRadius != null
      && (renderStyle.effectiveOverflowX != CSSOverflowType.visible
      || renderStyle.effectiveOverflowY != CSSOverflowType.visible);

    bool isClipRenderIntrinsic = renderStyle.borderRadius != null
      && this is RenderIntrinsic
      && renderStyle.intrinsicRatio != null;

    bool isClipContent = isClipOverflowContent || isClipRenderIntrinsic;

    if (isClipContent) {
      context.canvas.save();

      RRect rRect;
      Rect rect = offset & size;
      BorderRadius borderRadius = renderStyle.decoration!.borderRadius as BorderRadius;
      RRect borderRRect = borderRadius.toRRect(rect);
      // A borderRadius can only be given for a uniform Border in Flutter.
      double? borderTop = renderStyle.borderTopWidth?.computedValue;
      RRect paddingRRect = borderTop != null
        ? borderRRect.deflate(borderTop)
        : borderRRect;

      // The content of box with overflow values other than visible is trimmed to the padding edge curve.
      if (isClipOverflowContent) {
        rRect = paddingRRect;

      // The content of replaced elements is always trimmed to the content edge curve.
      } else {
        // @TODO: Currently only support clip uniform padding for replaced element.
        double paddingTop = renderStyle.paddingTop.computedValue;
        RRect contentRRect = paddingRRect.deflate(paddingTop);
        rRect = contentRRect;
      }

      context.canvas.clipRRect(rRect);
    }

    callback(context, offset);

    if (isClipContent) {
      context.canvas.restore();
    }
  }

  void debugBoxDecorationProperties(DiagnosticPropertiesBuilder properties) {
    properties
        .add(DiagnosticsProperty('borderEdge', renderStyle.border));
    if (renderStyle.backgroundClip != null)
      properties.add(
          DiagnosticsProperty('backgroundClip', renderStyle.backgroundClip));
    if (renderStyle.backgroundOrigin != null)
      properties.add(DiagnosticsProperty(
          'backgroundOrigin', renderStyle.backgroundOrigin));
    BoxDecoration? _decoration = renderStyle.decoration;
    if (_decoration != null && _decoration.borderRadius != null)
      properties
          .add(DiagnosticsProperty('borderRadius', _decoration.borderRadius));
    if (_decoration != null && _decoration.image != null)
      properties.add(DiagnosticsProperty('backgroundImage', _decoration.image));
    if (_decoration != null && _decoration.boxShadow != null)
      properties.add(DiagnosticsProperty('boxShadow', _decoration.boxShadow));
    if (_decoration != null && _decoration.gradient != null)
      properties.add(DiagnosticsProperty('gradient', _decoration.gradient));
  }
}

