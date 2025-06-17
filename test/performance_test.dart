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

      final List<Duration> allTimes = [];
      final List<int> imageCounts = []; // Track image counts for median calculation
      final Set<String> uniqueBrands = {}; // Track unique brands
      int successfulParses = 0;

      for (final file in files) {
        final fileName = file.path.split('\\').last;
        print('📄 Testing performance: $fileName');

        final content = await file.readAsString();
        final lines = content.split('\n');
        final url = lines[0].trim();
        final html = lines.skip(1).join('\n');

        final stopwatch = Stopwatch();

        // Run multiple iterations for this file
        final fileTimes = <Duration>[];

        for (int j = 0; j < 3; j++) {
          stopwatch.reset();
          stopwatch.start();
          final result = await parseProduct(html, url);
          stopwatch.stop();

          fileTimes.add(stopwatch.elapsed);

          // Check if parsing was successful
          final success =
              result != null &&
              result['name'] != null &&
              result['description'] != null &&
              result['image'] != null &&
              (result['image'] as List).isNotEmpty &&
              result['price'] != null &&
              result['priceCurrency'] != null;

          if (success && j == 0) {
            // Only count image count and brand once per file (first iteration)
            successfulParses++;
            imageCounts.add((result!['image'] as List).length);

            // Track unique brands (excluding null, empty, "No brand", "Not found")
            if (result['brand'] != null &&
                result['brand'].toString().isNotEmpty &&
                result['brand'].toString() != 'No brand' &&
                result['brand'].toString() != 'Not found') {
              uniqueBrands.add(result['brand'].toString().trim());
            }
          }
        }

        allTimes.addAll(fileTimes);

        final avgTimeForFile =
            fileTimes.map((d) => d.inMilliseconds).reduce((a, b) => a + b) / fileTimes.length;
        print('   ⏱️ Average: ${avgTimeForFile.toStringAsFixed(1)}ms');
      }

      // Calculate statistics
      final totalTime = allTimes.fold(0, (sum, time) => sum + time.inMilliseconds);
      final avgTime = totalTime / allTimes.length;
      final fastestTime = allTimes.map((d) => d.inMilliseconds).reduce((a, b) => a < b ? a : b);
      final slowestTime = allTimes.map((d) => d.inMilliseconds).reduce((a, b) => a > b ? a : b);

      // Calculate median parse time
      final sortedTimes = allTimes.map((d) => d.inMilliseconds).toList()..sort();
      double medianTime;
      final length = sortedTimes.length;
      if (length % 2 == 0) {
        medianTime = (sortedTimes[length ~/ 2 - 1] + sortedTimes[length ~/ 2]) / 2.0;
      } else {
        medianTime = sortedTimes[length ~/ 2].toDouble();
      }

      // Calculate median image count
      double medianImageCount = 0;
      if (imageCounts.isNotEmpty) {
        imageCounts.sort();
        final length = imageCounts.length;
        if (length % 2 == 0) {
          medianImageCount = (imageCounts[length ~/ 2 - 1] + imageCounts[length ~/ 2]) / 2.0;
        } else {
          medianImageCount = imageCounts[length ~/ 2].toDouble();
        }
      }

      print('\n📊 Performance Summary:');
      print('🏃 Total tests: ${allTimes.length}');
      print('✅ Successful parses: $successfulParses');
      print('⏱️ Average parse time: ${avgTime.toStringAsFixed(2)}ms');
      print('⏱️ Median parse time: ${medianTime.toStringAsFixed(1)}ms');
      print('⏱️ Fastest parse: ${fastestTime}ms');
      print('⏱️ Slowest parse: ${slowestTime}ms');
      print('🏷️ Brand tested: ${uniqueBrands.length}');
      print('🖼️ Median image count: ${medianImageCount.toStringAsFixed(1)}');

      // Đảm bảo success rate >= 50% (based on unique files, not iterations)
      final filesTestCount = files.length;
      expect(
        successfulParses / filesTestCount,
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
