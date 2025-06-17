import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/product_crawl.dart';

void main() {
  group('Performance Tests', () {
    // Test performance của parser
    test('Performance Benchmark', () async {
      final assetsDir = Directory('assets');
      if (!await assetsDir.exists()) {
        print('⚠️ Assets folder not found. Skipping performance test.');
        return;
      }

      final files = await assetsDir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.txt'))
          .cast<File>()
          .toList();

      if (files.isEmpty) {
        print('⚠️ No test files found. Skipping performance test.');
        return;
      }

      print('🚀 Running performance benchmark...');

      final stopwatch = Stopwatch();
      int totalTests = 0;
      int successfulTests = 0;

      for (final file in files) {
        final content = await file.readAsString();
        final lines = content.split('\n');

        if (lines.isNotEmpty) {
          final url = lines[0].trim();
          final html = lines.skip(1).join('\n');

          stopwatch.start();
          final result = await parseProduct(html, url);
          stopwatch.stop();

          totalTests++;
          if (result != null &&
              result['name'] != null &&
              result['image'] != null &&
              (result['image'] as List).isNotEmpty &&
              result['gallery'] != null &&
              (result['gallery'] as List).isNotEmpty) {
            successfulTests++;
          }

          final fileName = file.path.split('\\').last;
          print(
            '   ${fileName}: ${stopwatch.elapsedMilliseconds}ms - ${result != null ? "✅" : "❌"}',
          );
          stopwatch.reset();
        }
      }

      print('\n📊 Performance Summary:');
      print('   Total tests: $totalTests');
      print('   Successful: $successfulTests');
      print('   Success rate: ${((successfulTests / totalTests) * 100).toStringAsFixed(1)}%');

      // Đảm bảo success rate >= 50%
      expect(
        successfulTests / totalTests,
        greaterThanOrEqualTo(0.5),
        reason: 'Success rate should be at least 50%',
      );
    });

    // Test với file lớn (nếu có)
    test('Large File Performance', () async {
      // Tạo một HTML lớn để test
      final largeHtml =
          '''
      <!DOCTYPE html>
      <html>
      <head>
          <title>Large Product Page</title>
          <meta property="og:title" content="Large Product">
          <meta property="og:description" content="A product with lots of content">
          <meta property="og:image" content="https://example.com/large-product.jpg">
          
          <script type="application/ld+json">
          {
              "@context": "https://schema.org/",
              "@type": "Product",
              "name": "Large Product",
              "description": "${"Lorem ipsum " * 100}",
              "image": "https://example.com/large-product.jpg",
              "offers": {
                  "@type": "Offer",
                  "price": "199.99",
                  "priceCurrency": "USD"
              }
          }
          </script>
      </head>
      <body>
          <h1>Large Product</h1>
          <div class="content">
              ${"<p>This is a lot of content. " * 1000}</p>
          </div>
          <div class="price">\$199.99</div>
          <img src="https://example.com/large-product.jpg" alt="Large Product">
      </body>
      </html>
      ''';

      const url = 'https://example.com/large-product';

      final stopwatch = Stopwatch();
      stopwatch.start();

      final result = await parseProduct(largeHtml, url);

      stopwatch.stop();

      print('🐘 Large file test: ${stopwatch.elapsedMilliseconds}ms');

      expect(result, isNotNull, reason: 'Should parse large file successfully');
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(5000),
        reason: 'Should complete within 5 seconds',
      );
    });

    // Test memory usage (basic)
    test('Memory Usage Test', () async {
      // Chạy parser nhiều lần để kiểm tra memory leak
      const testHtml = '''
      <!DOCTYPE html>
      <html>
      <head>
          <title>Memory Test Product</title>
          <script type="application/ld+json">
          {
              "@type": "Product",
              "name": "Memory Test Product",
              "description": "Testing memory usage",
              "image": "https://example.com/test.jpg",
              "offers": {
                  "price": "99.99",
                  "priceCurrency": "USD"
              }
          }
          </script>
      </head>
      <body>
          <h1>Memory Test Product</h1>
      </body>
      </html>
      ''';

      const url = 'https://example.com/memory-test';
      const iterations = 100;

      print('🧠 Running memory test with $iterations iterations...');

      final stopwatch = Stopwatch();
      stopwatch.start();

      for (int i = 0; i < iterations; i++) {
        final result = await parseProduct(testHtml, url);
        expect(result, isNotNull, reason: 'Should parse successfully on iteration $i');
      }

      stopwatch.stop();

      final avgTime = stopwatch.elapsedMilliseconds / iterations;
      print('   Average time per parse: ${avgTime.toStringAsFixed(2)}ms');
      print('   Total time: ${stopwatch.elapsedMilliseconds}ms');

      expect(avgTime, lessThan(100), reason: 'Average parse time should be less than 100ms');
    });
  });
}
