import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import '../lib/main.dart';

void main() {
  test('Debug 19.txt Description Issue', () async {
    final file = File('assets/19.txt');
    if (!await file.exists()) {
      print('❌ File 19.txt not found');
      return;
    }

    final content = await file.readAsString();
    final lines = content.split('\n');
    final url = lines[0].trim();
    final html = lines.skip(1).join('\n');

    print('🔍 Testing file 19.txt');
    print('URL: $url');

    // Check if the meta tag exists in HTML
    final twitterDescMatch = RegExp(
      r'name="twitter:description"[^>]*content="([^"]*)"',
    ).firstMatch(html);
    print('Raw twitter:description found: ${twitterDescMatch?.group(1)}');

    // Also check the other way around
    final twitterDescMatch2 = RegExp(
      r'content="([^"]*)"[^>]*name="twitter:description"',
    ).firstMatch(html);
    print('Raw twitter:description (reverse) found: ${twitterDescMatch2?.group(1)}');

    // Test the getMetaContent function directly
    final document = html_parser.parse(html);
    final metaTwitterDesc = document
        .querySelector('meta[name="twitter:description"]')
        ?.attributes['content'];
    print('Direct meta query result: "$metaTwitterDesc"');

    final result = await parseProduct(html, url);

    if (result != null) {
      print('Final Result:');
      print('  Name: ${result['name']}');
      print('  Description: "${result['description']}"');
      print('  Price: ${result['price']}');
      print('  Currency: ${result['priceCurrency']}');
      print('  Images: ${result['images']?.length ?? 0}');
    } else {
      print('❌ Parsing failed completely');
    }
  });
}
