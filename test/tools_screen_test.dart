import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_downloader/features/tools/models/infyn_tool.dart';
import 'package:media_downloader/features/tools/screens/tools_screen.dart';
import 'package:media_downloader/features/tools/widgets/tool_card.dart';

void main() {
  group('InfynTool Catalog Tests', () {
    test('Catalog contains expected tool counts and categories', () {
      final tools = InfynTool.allTools;
      expect(tools.length, equals(12));

      final pdfTools =
          tools.where((t) => t.category == ToolCategory.pdf).toList();
      final imgTools =
          tools.where((t) => t.category == ToolCategory.image).toList();

      expect(pdfTools.length, equals(6));
      expect(imgTools.length, equals(6));
    });

    test('All tools have secure https://infyn.software URLs', () {
      for (final tool in InfynTool.allTools) {
        expect(tool.url.startsWith('https://infyn.software/'), isTrue);
        expect(tool.title.isNotEmpty, isTrue);
        expect(tool.description.isNotEmpty, isTrue);
        expect(tool.badge.isNotEmpty, isTrue);
      }
    });
  });

  group('ToolsScreen Widget Tests', () {
    testWidgets('Renders header, hero banner, search bar, and tool cards',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolsScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Infyn Tools'), findsOneWidget);
      expect(find.text('ZERO SERVER UPLOADS'), findsOneWidget);
      expect(find.text('All Tools (12)'), findsOneWidget);
      expect(find.text('PDF Suite (6)'), findsOneWidget);
      expect(find.text('Image Suite (6)'), findsOneWidget);

      // Verify tool cards render
      expect(find.byType(ToolCard), findsWidgets);
      expect(find.text('PDF to Image'), findsOneWidget);
      expect(find.text('Image to PDF'), findsOneWidget);
    });

    testWidgets('Filters tools when category chips are tapped', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolsScreen(),
        ),
      );
      await tester.pump();

      // Tap PDF Suite chip
      await tester.tap(find.text('PDF Suite (6)'));
      await tester.pumpAndSettle();

      expect(find.text('PDF to Image'), findsOneWidget);
      expect(find.text('Image to PDF'), findsOneWidget);
      expect(find.text('AI Background Remover'), findsNothing);

      // Tap Image Suite chip
      await tester.tap(find.text('Image Suite (6)'));
      await tester.pumpAndSettle();

      expect(find.text('AI Background Remover'), findsOneWidget);
      expect(find.text('Batch Image Compressor'), findsOneWidget);
      expect(find.text('PDF to Image'), findsNothing);
    });

    testWidgets('Filters tools via live search query', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolsScreen(),
        ),
      );
      await tester.pump();

      // Enter search term
      await tester.enterText(find.byType(TextField), 'compress');
      await tester.pumpAndSettle();

      expect(find.text('Batch Image Compressor'), findsOneWidget);
      expect(find.text('PDF to Image'), findsNothing);

      // Search with no matches
      await tester.enterText(find.byType(TextField), 'nonexistenttool123');
      await tester.pumpAndSettle();

      expect(find.textContaining('No tools found matching'), findsOneWidget);
    });
  });
}
