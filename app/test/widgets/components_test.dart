import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_business/core/design_system/components/list_panel.dart';
import 'package:no_business/core/design_system/components/metric_tile.dart';
import 'package:no_business/core/design_system/components/page_scaffold.dart';
import 'package:no_business/core/design_system/components/state_views.dart';
import 'package:no_business/core/design_system/components/status_badge.dart';
import 'package:no_business/core/design_system/theme.dart';
import 'package:no_business/features/dashboard/domain/dashboard_summary.dart';
import 'package:no_business/features/dashboard/presentation/revenue_chart.dart';

Future<void> pump(WidgetTester tester, Widget child, {Size size = const Size(1200, 800)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: buildNobTheme(), home: Scaffold(body: child)));
  await tester.pump();
}

void main() {
  testWidgets('MetricTile shows its figures and reacts to taps', (tester) async {
    var taps = 0;
    await pump(
      tester,
      Center(
        child: SizedBox(
          width: 260,
          child: MetricTile(
            label: 'Owed to you',
            value: '₦1,250,000.00',
            caption: '3 open invoices',
            icon: Icons.hourglass_bottom_rounded,
            onTap: () => taps++,
          ),
        ),
      ),
    );
    expect(find.text('Owed to you'), findsOneWidget);
    expect(find.text('₦1,250,000.00'), findsOneWidget);
    expect(find.text('3 open invoices'), findsOneWidget);
    await tester.tap(find.byType(MetricTile));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MetricTile keeps a long value inside a narrow card', (tester) async {
    await pump(
      tester,
      const Center(
        child: SizedBox(
          width: 150,
          child: MetricTile(
            label: 'Money received in the selected period',
            value: '₦999,999,999,999.99',
            icon: Icons.account_balance_wallet_outlined,
          ),
        ),
      ),
      size: const Size(360, 640),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('EmptyState offers its action', (tester) async {
    var pressed = false;
    await pump(
      tester,
      EmptyState(
        icon: Icons.groups_2_outlined,
        title: 'No customers yet',
        message: 'Add the people and companies you sell to.',
        action: FilledButton(onPressed: () => pressed = true, child: const Text('Add customer')),
      ),
    );
    expect(find.text('No customers yet'), findsOneWidget);
    await tester.tap(find.text('Add customer'));
    expect(pressed, isTrue);
  });

  testWidgets('ErrorState retries', (tester) async {
    var retries = 0;
    await pump(tester, ErrorState(message: 'Cannot reach the server.', onRetry: () => retries++));
    expect(find.text('Cannot reach the server.'), findsOneWidget);
    await tester.tap(find.byType(FilledButton).hitTestable().first);
    expect(retries, 1);
  });

  testWidgets('StatusBadge renders every tone', (tester) async {
    await pump(
      tester,
      Wrap(
        children: [for (final tone in BadgeTone.values) StatusBadge(label: tone.name, tone: tone)],
      ),
    );
    for (final tone in BadgeTone.values) {
      expect(find.text(tone.name), findsOneWidget);
    }
  });

  testWidgets('ListRow truncates long text on a phone-width screen', (tester) async {
    await pump(
      tester,
      ListRow(
        leading: const RowIcon(Icons.receipt_long_outlined),
        title: 'A very long customer name that would never fit on a narrow phone display at all',
        subtitle: 'INV-000001 · due 12 Nov 2026 · a similarly long secondary line of supporting text',
        trailing: const TrailingAmount(amount: '₦12,345,678.00', below: Text('Overdue')),
        onTap: () {},
      ),
      size: const Size(320, 600),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ResponsiveGrid collapses to one column when narrow', (tester) async {
    Widget grid() => const SingleChildScrollView(
          child: ResponsiveGrid(
            minItemWidth: 240,
            children: [
              SizedBox(key: Key('a'), height: 40),
              SizedBox(key: Key('b'), height: 40),
              SizedBox(key: Key('c'), height: 40),
            ],
          ),
        );

    await pump(tester, grid());
    expect(tester.getTopLeft(find.byKey(const Key('a'))).dy, tester.getTopLeft(find.byKey(const Key('c'))).dy);

    await pump(tester, grid(), size: const Size(320, 600));
    expect(tester.getTopLeft(find.byKey(const Key('b'))).dy,
        greaterThan(tester.getTopLeft(find.byKey(const Key('a'))).dy));
    expect(tester.getSize(find.byKey(const Key('a'))).width, 320);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RevenueChart draws and reports the touched day', (tester) async {
    final points = [
      for (var day = 1; day <= 7; day++)
        DailyPoint(day: DateTime(2026, 11, day), salesMinor: day * 100000, paymentsMinor: day.isEven ? 50000 : 0),
    ];
    await pump(
      tester,
      Padding(
        padding: const EdgeInsets.all(24),
        child: RevenueChart(points: points, currencyCode: 'NGN'),
      ),
    );
    expect(find.text('Sales'), findsOneWidget);
    expect(find.text('Invoice payments'), findsOneWidget);
    expect(find.textContaining('Touch or hover'), findsOneWidget);

    final chart = tester.getRect(find.byType(CustomPaint).last);
    await tester.tapAt(Offset(chart.right - 20, chart.center.dy));
    await tester.pump();
    expect(find.textContaining('7 Nov'), findsOneWidget);
    expect(find.textContaining('Touch or hover'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RevenueChart tolerates an empty period', (tester) async {
    await pump(tester, const RevenueChart(points: [], currencyCode: 'USD'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ShareBars lists every row', (tester) async {
    await pump(
      tester,
      const ShareBars(
        rows: [
          (label: 'Cash', value: '₦500.00', amount: 50000),
          (label: 'Card', value: '₦0.00', amount: 0),
        ],
      ),
    );
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Card'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
