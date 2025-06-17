import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/product_crawl.dart';

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

      final List<int> imageCounts = []; // Track image counts for median calculation
      final Set<String> uniqueBrands = {}; // Track unique brands

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
            print('🏢 BRAND: ${result['brand'] ?? 'Not found'}');
            print('🌐 SITE: ${result['site'] ?? 'N/A'}');

            // Track unique brands (excluding null, empty, "No brand", "Not found")
            if (result['brand'] != null &&
                result['brand'].toString().isNotEmpty &&
                result['brand'].toString() != 'No brand' &&
                result['brand'].toString() != 'Not found') {
              uniqueBrands.add(result['brand'].toString().trim());
            }

            if (result['image'] != null) {
              final images = result['image'] as List;
              imageCounts.add(images.length); // Track for median calculation
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
              imageCounts.add(0); // No images found
              print('   ❌ Images field is null');
            }

            // Show gallery info (should be same as image)
            if (result['gallery'] != null) {
              final gallery = result['gallery'] as List;
              print('🎨 GALLERY: ${gallery.length} items (should match images)');
            }

            // Also show other extracted data
            print('💰 PRICE: ${result['price']} ${result['priceCurrency'] ?? 'N/A'}');
            final description = result['description']?.toString() ?? 'N/A';
            final shortDesc = description.length > 100
                ? '${description.substring(0, 100)}...'
                : description;
            print('📝 DESCRIPTION: $shortDesc');
          } else {
            imageCounts.add(0); // No images when parsing fails
            print('❌ PARSING FAILED - No data extracted');
          }
        } catch (e) {
          imageCounts.add(0); // No images when there's an error
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

      print('\n📊 Image Analysis Summary:');
      print('📁 Total files tested: ${files.length}');
      print('✅ Files with images: ${imageCounts.where((count) => count > 0).length}');
      print('❌ Files without images: ${imageCounts.where((count) => count == 0).length}');

      if (imageCounts.isNotEmpty) {
        imageCounts.sort();

        final totalImages = imageCounts.reduce((a, b) => a + b);
        final avgImages = totalImages / imageCounts.length;
        final maxImages = imageCounts.last;
        final minImages = imageCounts.first;

        // Calculate median
        double medianImages;
        final length = imageCounts.length;
        if (length % 2 == 0) {
          medianImages = (imageCounts[length ~/ 2 - 1] + imageCounts[length ~/ 2]) / 2.0;
        } else {
          medianImages = imageCounts[length ~/ 2].toDouble();
        }

        print('🖼️ Total images found: $totalImages');
        print('🖼️ Average per file: ${avgImages.toStringAsFixed(1)}');
        print('🖼️ Median per file: ${medianImages.toStringAsFixed(1)}');
        print('🖼️ Max per file: $maxImages');
        print('🖼️ Min per file: $minImages');
        print('🏷️ Brand tested: ${uniqueBrands.length}');
      }
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
