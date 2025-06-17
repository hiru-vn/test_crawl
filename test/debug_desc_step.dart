import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import '../lib/main.dart';

void main() {
  test('Debug Description Step by Step', () async {
    final file = File('assets/19.txt');
    final content = await file.readAsString();
    final lines = content.split('\n');
    final url = lines[0].trim();
    final html = lines.skip(1).join('\n');

    print('🔍 Step-by-step description tracing for 19.txt');

    // Test direct meta extraction
    final document = html_parser.parse(html);

    // Test getMetaContent function
    String? getMetaContent(String property) {
      return document.querySelector('meta[property="$property"]')?.attributes['content'] ??
          document.querySelector('meta[name="$property"]')?.attributes['content'];
    }

    final ogDesc = getMetaContent('og:description');
    final twitterDesc = getMetaContent('twitter:description');
    final regularDesc = getMetaContent('description');

    print('og:description: "$ogDesc"');
    print('twitter:description: "$twitterDesc"');
    print('description: "$regularDesc"');

    // Test what the extraction logic would choose
    final finalDesc = ogDesc ?? twitterDesc ?? regularDesc;
    print('Final chosen: "$finalDesc"');

    // Test cleaning logic
    if (finalDesc != null) {
      final step1 = finalDesc.replaceAll(RegExp(r'\s+'), ' ');
      print('After whitespace normalize: "$step1"');

      final step2 = step1.trim();
      print('After trim: "$step2"');

      final step3 = step2.replaceAll(RegExp(r'^[\s]*[\.\,\-][\s]+(?=\w)'), '');
      print('After punctuation removal: "$step3"');

      final final_result = step3.trim();
      print('Final result: "$final_result"');
    }

    // Compare with actual parsing
    final result = await parseProduct(html, url);
    print('Actual parser result: "${result?['description']}"');
  });
}
