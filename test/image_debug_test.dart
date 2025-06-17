import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/main.dart';

void main() {
  group('Image Extraction Debug', () {
    test('Show All Extracted Images', () async {
      final assetsDir = Directory('assets');

      if (!await assetsDir.exists()) {
        print('⚠️ Assets folder not found');
        return;
      }

      final files = await assetsDir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.txt'))
          .cast<File>()
          .toList();

      // Sort files by name
      files.sort((a, b) => a.path.compareTo(b.path));

      print('🖼️  IMAGE EXTRACTION RESULTS');
      print('=' * 80);

      for (final file in files) {
        final fileName = file.path.split('\\').last;

        try {
          final content = await file.readAsString();
          final lines = content.split('\n');

          if (lines.isEmpty) continue;

          final url = lines[0].trim();
          final html = lines.skip(1).join('\n');

          print('\n📁 FILE: $fileName');
          print('🔗 URL: $url');
          print('-' * 60);

          final result = await parseProduct(html, url);

          if (result != null) {
            print('✅ PRODUCT: ${result['name']}');

            if (result['images'] != null) {
              final images = result['images'] as List;
              print('🖼️  IMAGES FOUND: ${images.length}');

              if (images.isNotEmpty) {
                for (int i = 0; i < images.length; i++) {
                  final imageUrl = images[i];
                  print('   ${i + 1}. $imageUrl');
                }
              } else {
                print('   ❌ No images extracted');
              }
            } else {
              print('   ❌ Images field is null');
            }

            // Also show other extracted data
            print('💰 PRICE: ${result['price']} ${result['priceCurrency'] ?? 'N/A'}');
            final description = result['description']?.toString() ?? 'N/A';
            final shortDesc = description.length > 100
                ? '${description.substring(0, 100)}...'
                : description;
            print('📝 DESCRIPTION: $shortDesc');
          } else {
            print('❌ PARSING FAILED - No data extracted');
          }
        } catch (e) {
          print('❌ ERROR processing $fileName: $e');
        }

        print('=' * 80);
      }

      // Summary
      print('\n📊 SUMMARY');
      print('Total files processed: ${files.length}');
      print(
        '\n💡 TIP: You can copy these image URLs and paste them in your browser to see the actual images!',
      );
    });

    // Test to show image extraction methods used
    test('Show Image Extraction Methods', () async {
      print('\n🔍 IMAGE EXTRACTION METHODS USED BY THE PARSER:');
      print('=' * 60);
      print('1. 📋 JSON-LD structured data (schema.org)');
      print('   - Looks for: "image" field in JSON-LD scripts');
      print('   - Priority: HIGHEST');
      print('');
      print('2. 🏷️  Meta tags (Open Graph, Twitter)');
      print('   - Looks for: og:image, twitter:image');
      print('   - Priority: HIGH');
      print('');
      print('3. 🔍 Heuristic image discovery');
      print('   - Looks for: <img> tags with various attributes');
      print('   - Attributes checked: data-srcset, data-src, srcset, src');
      print('   - Priority: MEDIUM');
      print('');
      print('4. 🧹 Image filtering & ranking');
      print('   - Removes: logos, icons, sprites, avatars, placeholders');
      print('   - Ranks by: product name keywords in URL');
      print('   - Converts: relative URLs to absolute URLs');
      print('');
      print('📌 The parser tries all methods and combines results for best coverage!');
    });
  });
}
