import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design_system/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/money.dart';
import '../domain/dashboard_summary.dart';

/// Daily money received: counter sales stacked with invoice payments.
///
/// Drawn with a [CustomPainter] so the app carries no charting dependency.
/// Hovering or touching a day shows its figures above the plot.
class RevenueChart extends StatefulWidget {
  const RevenueChart({super.key, required this.points, required this.currencyCode});

  final List<DailyPoint> points;
  final String currencyCode;

  @override
  State<RevenueChart> createState() => _RevenueChartState();
}

class _RevenueChartState extends State<RevenueChart> {
  int? _active;

  void _select(Offset position, double width) {
    final count = widget.points.length;
    if (count == 0 || width <= _RevenuePainter.axisWidth) return;
    final slot = (width - _RevenuePainter.axisWidth) / count;
    final index = ((position.dx - _RevenuePainter.axisWidth) / slot).floor();
    final next = index < 0 || index >= count ? null : index;
    if (next != _active) setState(() => _active = next);
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final currency = widget.currencyCode;
    final active = _active != null && _active! < points.length ? points[_active!] : null;
    final total = points.fold<int>(0, (sum, point) => sum + point.totalMinor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: NobSpace.lg,
          runSpacing: NobSpace.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const _Legend(color: NobColors.cyan, label: 'Sales'),
            const _Legend(color: NobColors.violet, label: 'Invoice payments'),
            Text(
              active == null
                  ? 'Touch or hover a day for its figures'
                  : '${formatShortDay(active.day)}: '
                        '${Money.format(active.salesMinor, currency)} sales, '
                        '${Money.format(active.paymentsMinor, currency)} payments',
              style: NobText.bodySmall.copyWith(
                color: active == null ? NobColors.textMuted : NobColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: NobSpace.md),
        SizedBox(
          height: 220,
          child: LayoutBuilder(
            builder: (context, constraints) => Semantics(
              image: true,
              label:
                  'Bar chart of money received per day over ${points.length} days, '
                  '${Money.format(total, currency)} in total.',
              child: MouseRegion(
                onHover: (event) => _select(event.localPosition, constraints.maxWidth),
                onExit: (_) => setState(() => _active = null),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) => _select(details.localPosition, constraints.maxWidth),
                  onHorizontalDragUpdate: (details) =>
                      _select(details.localPosition, constraints.maxWidth),
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, 220),
                    painter: _RevenuePainter(
                      points: points,
                      currencyCode: currency,
                      active: _active,
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
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: NobSpace.xs),
        Text(label, style: NobText.bodySmall.copyWith(color: NobColors.textSecondary)),
      ],
    );
  }
}

class _RevenuePainter extends CustomPainter {
  _RevenuePainter({required this.points, required this.currencyCode, required this.active});

  static const double axisWidth = 56;
  static const double _labelHeight = 22;

  final List<DailyPoint> points;
  final String currencyCode;
  final int? active;

  /// Rounds the largest value up to a tidy axis maximum (1, 2 or 5 × 10ⁿ).
  static int niceCeiling(int value) {
    if (value <= 0) return 100;
    final magnitude = math.pow(10, (math.log(value) / math.ln10).floor()).toDouble();
    for (final step in const [1, 2, 5, 10]) {
      if (step * magnitude >= value) return (step * magnitude).round();
    }
    return (10 * magnitude).round();
  }

  void _text(
    Canvas canvas,
    String text,
    Offset anchor, {
    TextAlign align = TextAlign.left,
    Color color = NobColors.textMuted,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: NobText.label.copyWith(color: color, fontSize: 10.5),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final dx = switch (align) {
      TextAlign.right => anchor.dx - painter.width,
      TextAlign.center => anchor.dx - painter.width / 2,
      _ => anchor.dx,
    };
    painter.paint(canvas, Offset(dx, anchor.dy - painter.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(axisWidth, 6, size.width, size.height - _labelHeight);
    if (plot.width <= 0 || plot.height <= 0) return;

    final peak = points.fold<int>(0, (best, point) => math.max(best, point.totalMinor));
    final ceiling = niceCeiling(peak);

    final grid = Paint()
      ..color = NobColors.border
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = plot.bottom - plot.height * i / 4;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      _text(
        canvas,
        Money.compact((ceiling * i / 4).round(), currencyCode),
        Offset(axisWidth - 8, y),
        align: TextAlign.right,
      );
    }
    if (points.isEmpty) return;

    final slot = plot.width / points.length;
    final barWidth = math.max(2.0, math.min(22.0, slot * 0.62));
    final sales = Paint()..color = NobColors.cyan;
    final payments = Paint()..color = NobColors.violet;
    final highlight = Paint()..color = NobColors.textPrimary.withValues(alpha: 0.06);
    const radius = Radius.circular(3);

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final centre = plot.left + slot * (i + 0.5);
      if (i == active) {
        canvas.drawRect(
          Rect.fromLTRB(centre - slot / 2, plot.top, centre + slot / 2, plot.bottom),
          highlight,
        );
      }
      final salesHeight = plot.height * point.salesMinor / ceiling;
      final paymentsHeight = plot.height * point.paymentsMinor / ceiling;
      final left = centre - barWidth / 2;
      if (salesHeight > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(left, plot.bottom - salesHeight, barWidth, salesHeight),
            topLeft: paymentsHeight > 0 ? Radius.zero : radius,
            topRight: paymentsHeight > 0 ? Radius.zero : radius,
          ),
          sales,
        );
      }
      if (paymentsHeight > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(
              left,
              plot.bottom - salesHeight - paymentsHeight,
              barWidth,
              paymentsHeight,
            ),
            topLeft: radius,
            topRight: radius,
          ),
          payments,
        );
      }
    }

    // A handful of evenly spaced date labels; every day would not fit.
    final labelCount = math.min(points.length, math.max(2, (plot.width / 90).floor()));
    final labelled = <int>{
      for (var i = 0; i < labelCount; i++)
        labelCount == 1 ? 0 : (i * (points.length - 1) / (labelCount - 1)).round(),
    };
    for (final index in labelled) {
      final centre = plot.left + slot * (index + 0.5);
      final align = index == 0
          ? TextAlign.left
          : index == points.length - 1
          ? TextAlign.right
          : TextAlign.center;
      final anchorX = switch (align) {
        TextAlign.left => centre - slot / 2,
        TextAlign.right => centre + slot / 2,
        _ => centre,
      };
      _text(
        canvas,
        formatShortDay(points[index].day),
        Offset(anchorX, size.height - _labelHeight / 2 + 2),
        align: align,
        color: index == active ? NobColors.textPrimary : NobColors.textMuted,
      );
    }
  }

  @override
  bool shouldRepaint(_RevenuePainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.active != active ||
      oldDelegate.currencyCode != currencyCode;
}

/// Horizontal share bars, used for payment methods and top products.
class ShareBars extends StatelessWidget {
  const ShareBars({super.key, required this.rows, this.color = NobColors.cobalt});

  /// Label, formatted value and the raw amount that sets the bar length.
  final List<({String label, String value, int amount})> rows;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final peak = rows.fold<int>(0, (best, row) => math.max(best, row.amount));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: NobSpace.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.label,
                        style: NobText.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: NobSpace.md),
                    Text(row.value, style: NobText.numeric),
                  ],
                ),
                const SizedBox(height: NobSpace.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(NobRadius.pill),
                  child: LinearProgressIndicator(
                    value: peak <= 0 ? 0 : row.amount / peak,
                    minHeight: 6,
                    backgroundColor: NobColors.surfaceHigh,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
