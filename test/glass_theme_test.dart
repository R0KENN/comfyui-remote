import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:comfyui_remote/glass_theme.dart';

void main() {
  group('GlassTheme widgets', () {
    testWidgets('chip рендерится с текстом', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassTheme.chip('Test', Colors.blue),
          ),
        ),
      );
      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('chip рендерится с иконкой', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassTheme.chip('Tag', Colors.red, icon: Icons.star),
          ),
        ),
      );
      expect(find.text('Tag'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('statusBadge показывает текст', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassTheme.statusBadge('Online', Colors.green),
          ),
        ),
      );
      expect(find.text('Online'), findsOneWidget);
    });

    testWidgets('statusBadge без точки', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassTheme.statusBadge('Status', Colors.red, dot: false),
          ),
        ),
      );
      expect(find.text('Status'), findsOneWidget);
    });

    testWidgets('card рендерит child', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassTheme.card(
              child: const Text('Card Content'),
            ),
          ),
        ),
      );
      expect(find.text('Card Content'), findsOneWidget);
    });

    testWidgets('miniCard рендерит child', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassTheme.miniCard(
              child: const Text('Mini'),
            ),
          ),
        ),
      );
      expect(find.text('Mini'), findsOneWidget);
    });

    testWidgets('glassButton enabled показывает текст и реагирует',
            (tester) async {
          bool tapped = false;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: GlassTheme.glassButton(
                  text: 'Click Me',
                  onTap: () => tapped = true,
                  icon: Icons.play_arrow,
                ),
              ),
            ),
          );
          expect(find.text('Click Me'), findsOneWidget);
          expect(find.byIcon(Icons.play_arrow), findsOneWidget);
          await tester.tap(find.text('Click Me'));
          expect(tapped, true);
        });

    testWidgets('glassButton disabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassTheme.glassButton(
              text: 'Disabled',
              onTap: null,
            ),
          ),
        ),
      );
      expect(find.text('Disabled'), findsOneWidget);
    });

    testWidgets('sectionTitle показывает иконку и текст', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassTheme.sectionTitle(
              Icons.memory,
              Colors.green,
              'GPU Info',
            ),
          ),
        ),
      );
      expect(find.text('GPU Info'), findsOneWidget);
      expect(find.byIcon(Icons.memory), findsOneWidget);
    });

    testWidgets('sectionTitle с trailing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassTheme.sectionTitle(
              Icons.queue,
              Colors.blue,
              'Queue',
              trailing: const Text('3'),
            ),
          ),
        ),
      );
      expect(find.text('Queue'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('progressBar рендерится', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: GlassTheme.progressBar(75.5),
            ),
          ),
        ),
      );
      expect(find.text('75.5%'), findsOneWidget);
    });
  });

  group('GlassTheme constants', () {
    test('bgDark чёрный AMOLED', () {
      expect(GlassTheme.bgDark, const Color(0xFF000000));
    });

    test('textPrimary светлый', () {
      expect((GlassTheme.textPrimary.a * 255.0).round().clamp(0, 255), 255);
      expect((GlassTheme.textPrimary.r * 255.0).round().clamp(0, 255), greaterThan(200));
    });
  });
}
