import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import '../lib/product_crawl.dart';

/// Test Runner để chạy tất cả tests và tạo báo cáo chi tiết
void main() {
  group('Complete Test Suite', () {
    // Utility function để in header đẹp
    void printHeader(String title) {
      final border = '=' * 60;
      print('\n$border');
      print('  $title'.padRight(58) + '  ');
      print(border);
    }

    // Utility function để in kết quả test
    void printTestResult(String testName, bool success, String details) {
      final icon = success ? '✅' : '❌';
      print('$icon $testName');
      if (details.isNotEmpty) {
        print('   $details');
      }
    }

    test('Complete Product Parser Test Suite', () async {
      printHeader('PRODUCT PARSER TEST SUITE');

      final testResults = <String, bool>{};
      final testDetails = <String, String>{};

      // Test 1: Kiểm tra assets folder
      print('\n🔍 Checking test environment...');
      final assetsDir = Directory('assets');
      final assetsExist = await assetsDir.exists();
      testResults['Assets Folder'] = assetsExist;

      if (!assetsExist) {
        testDetails['Assets Folder'] = 'Please create assets/ folder and add .txt test files';
        printTestResult('Assets Folder', false, testDetails['Assets Folder']!);
        return;
      }

      final files = await assetsDir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.txt'))
          .cast<File>()
          .toList();

      // Sort files numerically (1.txt, 2.txt, ..., 10.txt, 11.txt) instead of alphabetically
      files.sort((a, b) {
        final fileNameA = a.path.split('\\').last;
        final fileNameB = b.path.split('\\').last;

        // Extract the number from filename (e.g., "1.txt" -> 1)
        final numA = int.tryParse(fileNameA.replaceAll('.txt', '')) ?? 0;
        final numB = int.tryParse(fileNameB.replaceAll('.txt', '')) ?? 0;

        return numA.compareTo(numB);
      });

      testResults['Test Files'] = files.isNotEmpty;
      testDetails['Test Files'] = 'Found ${files.length} test files';
      printTestResult('Test Files', files.isNotEmpty, testDetails['Test Files']!);

      if (files.isEmpty) {
        print('\n💡 To run tests, add .txt files to assets/ folder with format:');
        print('   Line 1: URL');
        print('   Line 2+: HTML content');
        return;
      }

      // Test 2: Chạy basic validation tests
      printHeader('BASIC VALIDATION TESTS');

      // Test ProductData class
      try {
        const testUrl = 'https://example.com/test';
        final product = ProductData(testUrl);
        product.name = 'Test';
        product.brand = 'Test Brand';
        product.description = 'Test Description';
        product.images = ['test.jpg'];
        product.price = '99.99';
        product.priceCurrency = 'USD';

        final json = product.toJson();
        final validJson =
            json['name'] == 'Test' &&
            json['brand'] == 'Test Brand' &&
            json['url'] == testUrl &&
            json['site'] == 'https://example.com' &&
            json['image'] is List &&
            (json['image'] as List).isNotEmpty &&
            json['gallery'] is List &&
            (json['gallery'] as List).isNotEmpty;

        testResults['ProductData Class'] = validJson;
        printTestResult(
          'ProductData Class',
          validJson,
          'toJson() method works correctly with new format',
        );
      } catch (e) {
        testResults['ProductData Class'] = false;
        testDetails['ProductData Class'] = 'Error: $e';
        printTestResult('ProductData Class', false, testDetails['ProductData Class']!);
      }

      // Test 3: Chạy tests với từng file
      printHeader('FILE-BASED TESTS');

      int successCount = 0;
      int totalCount = 0;
      final List<Duration> parseTimes = [];
      final List<int> imageCounts = []; // Track image counts for median calculation
      final Set<String> uniqueBrands = {}; // Track unique brands

      for (final file in files) {
        final fileName = file.path.split('\\').last;
        totalCount++;

        try {
          final content = await file.readAsString();
          final lines = content.split('\n');

          if (lines.isEmpty) {
            testResults[fileName] = false;
            testDetails[fileName] = 'Empty file';
            printTestResult(fileName, false, testDetails[fileName]!);
            continue;
          }

          final url = lines[0].trim();
          final html = lines.skip(1).join('\n');

          if (url.isEmpty || html.isEmpty) {
            testResults[fileName] = false;
            testDetails[fileName] = 'Invalid format: URL or HTML missing';
            printTestResult(fileName, false, testDetails[fileName]!);
            continue;
          }

          // Đo thời gian parse
          final stopwatch = Stopwatch()..start();
          final result = await parseProduct(html, url);
          stopwatch.stop();
          parseTimes.add(stopwatch.elapsed);

          // Kiểm tra kết quả
          final success =
              result != null &&
              result['name'] != null &&
              result['name'].toString().isNotEmpty &&
              result['description'] != null &&
              result['description'].toString().isNotEmpty &&
              result['image'] != null &&
              (result['image'] as List).isNotEmpty &&
              result['price'] != null &&
              result['price'].toString().isNotEmpty &&
              result['priceCurrency'] != null &&
              result['priceCurrency'].toString().isNotEmpty;

          testResults[fileName] = success;

          if (success) {
            successCount++;
            final imageCount = (result!['image'] as List).length;
            imageCounts.add(imageCount); // Add to median calculation
            final galleryCount = (result['gallery'] as List).length;
            final brandInfo = result['brand'] != null ? result['brand'] : 'No brand';

            // Track unique brands (excluding null, empty, "No brand", "Not found")
            if (result['brand'] != null &&
                result['brand'].toString().isNotEmpty &&
                result['brand'].toString() != 'No brand' &&
                result['brand'].toString() != 'Not found') {
              uniqueBrands.add(result['brand'].toString().trim());
            }

            testDetails[fileName] =
                'Name: ${result['name']}, Brand: $brandInfo, Images: $imageCount, Gallery: $galleryCount, ' +
                'Price: ${result['price']} ${result['priceCurrency']}, ' +
                'Time: ${stopwatch.elapsedMilliseconds}ms';
          } else {
            final missingFields = <String>[];
            if (result == null) {
              missingFields.add('all fields (null result)');
            } else {
              if (result['name'] == null || result['name'].toString().isEmpty)
                missingFields.add('name');
              if (result['description'] == null || result['description'].toString().isEmpty)
                missingFields.add('description');
              if (result['image'] == null || (result['image'] as List).isEmpty)
                missingFields.add('image');
              if (result['price'] == null || result['price'].toString().isEmpty)
                missingFields.add('price');
              if (result['priceCurrency'] == null || result['priceCurrency'].toString().isEmpty)
                missingFields.add('priceCurrency');
            }

            testDetails[fileName] = 'Missing: ${missingFields.join(', ')}';
          }

          printTestResult(fileName, success, testDetails[fileName]!);
        } catch (e) {
          testResults[fileName] = false;
          testDetails[fileName] = 'Exception: $e';
          printTestResult(fileName, false, testDetails[fileName]!);
        }
      }

      // Test 4: Performance summary
      printHeader('PERFORMANCE SUMMARY');

      // Declare performance variables with default values
      double avgTime = 0.0;
      double medianTime = 0.0;
      int maxTime = 0;
      int minTime = 0;

      if (parseTimes.isNotEmpty) {
        avgTime =
            parseTimes.map((d) => d.inMilliseconds).reduce((a, b) => a + b) / parseTimes.length;
        maxTime = parseTimes.map((d) => d.inMilliseconds).reduce((a, b) => a > b ? a : b);
        minTime = parseTimes.map((d) => d.inMilliseconds).reduce((a, b) => a < b ? a : b);

        // Calculate median parse time
        final sortedTimes = parseTimes.map((d) => d.inMilliseconds).toList()..sort();
        final length = sortedTimes.length;
        if (length % 2 == 0) {
          medianTime = (sortedTimes[length ~/ 2 - 1] + sortedTimes[length ~/ 2]) / 2.0;
        } else {
          medianTime = sortedTimes[length ~/ 2].toDouble();
        }

        print('⏱️  Average parse time: ${avgTime.toStringAsFixed(2)}ms');
        print('⏱️  Median parse time: ${medianTime.toStringAsFixed(1)}ms');
        print('⏱️  Fastest parse: ${minTime}ms');
        print('⏱️  Slowest parse: ${maxTime}ms');

        testResults['Performance'] = avgTime < 1000; // Dưới 1 giây
        testDetails['Performance'] = 'Average: ${avgTime.toStringAsFixed(2)}ms';
        printTestResult(
          'Performance Check',
          testResults['Performance']!,
          testDetails['Performance']!,
        );
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
        print('🖼️  Median image count: ${medianImageCount.toStringAsFixed(1)}');
      }

      // Test 5: Final summary
      printHeader('FINAL SUMMARY');

      final successRate = totalCount > 0 ? (successCount / totalCount) * 100 : 0;
      print('📊 Test Files: $totalCount');
      print('✅ Successful: $successCount');
      print('❌ Failed: ${totalCount - successCount}');
      print('📈 Success Rate: ${successRate.toStringAsFixed(1)}%');
      print('🏷️ Brand tested: ${uniqueBrands.length}');
      if (imageCounts.isNotEmpty) {
        print('🖼️ Median Image Count: ${medianImageCount.toStringAsFixed(1)}');
      }

      // Export results to JSON with historical tracking (summary only)
      await TestResultExporter.exportResults(
        totalFiles: totalCount,
        successCount: successCount,
        successRate: successRate.toDouble(),
        avgTime: avgTime,
        medianTime: medianTime,
        fastestTime: minTime,
        slowestTime: maxTime,
        uniqueBrands: uniqueBrands.length,
        medianImageCount: medianImageCount,
      );

      // Overall test result
      final overallSuccess = successRate >= 50.0; // Ít nhất 50% thành công
      testResults['Overall'] = overallSuccess;

      if (overallSuccess) {
        print('\n🎉 TEST SUITE PASSED! Your parser is working well.');
      } else {
        print('\n⚠️  TEST SUITE NEEDS IMPROVEMENT. Consider:');
        print('   - Adding more diverse test files');
        print('   - Improving parser logic for failed cases');
        print('   - Checking HTML structure of failed files');
      }

      // Assert final result
      expect(overallSuccess, true, reason: 'Overall test success rate should be >= 50%');

      print('\n' + '=' * 60);
    });

    // Test edge cases
    test('Edge Cases', () async {
      printHeader('EDGE CASE TESTS');

      final edgeCases = [
        {'name': 'Empty HTML', 'html': '', 'url': 'https://example.com/empty', 'shouldPass': false},
        {
          'name': 'HTML without product data',
          'html': '<html><body><h1>Not a product page</h1></body></html>',
          'url': 'https://example.com/not-product',
          'shouldPass': false,
        },
        {
          'name': 'HTML with only title',
          'html':
              '<html><head><title>Just Title</title></head><body><h1>Just Title</h1></body></html>',
          'url': 'https://example.com/just-title',
          'shouldPass': false,
        },
        {
          'name': 'Malformed JSON-LD',
          'html': '''
          <html>
          <head>
            <script type="application/ld+json">{ invalid json }</script>
          </head>
          <body><h1>Product</h1></body>
          </html>
          ''',
          'url': 'https://example.com/malformed',
          'shouldPass': false,
        },
      ];

      for (final testCase in edgeCases) {
        try {
          final result = await parseProduct(testCase['html'] as String, testCase['url'] as String);
          final actualPass = result != null;
          final expectedPass = testCase['shouldPass'] as bool;
          final success = actualPass == expectedPass;

          printTestResult(
            testCase['name'] as String,
            success,
            'Expected: ${expectedPass ? "pass" : "fail"}, Got: ${actualPass ? "pass" : "fail"}',
          );
        } catch (e) {
          printTestResult(testCase['name'] as String, false, 'Exception: $e');
        }
      }
    });
  });
}

// Test result export functionality
class TestResultExporter {
  static const String historyFileName = 'test_history.json';

  static Future<void> exportResults({
    required int totalFiles,
    required int successCount,
    required double successRate,
    required double avgTime,
    required double medianTime,
    required int fastestTime,
    required int slowestTime,
    required int uniqueBrands,
    required double medianImageCount,
  }) async {
    final now = DateTime.now();

    // Create current test result (summary only for efficient storage)
    final currentResult = {
      'timestamp': now.toIso8601String(),
      'date':
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      'time':
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
      'summary': {
        'totalFiles': totalFiles,
        'successCount': successCount,
        'failedCount': totalFiles - successCount,
        'successRate': double.parse(successRate.toStringAsFixed(1)),
        'avgParseTime': double.parse(avgTime.toStringAsFixed(2)),
        'medianParseTime': double.parse(medianTime.toStringAsFixed(1)),
        'fastestParse': fastestTime,
        'slowestParse': slowestTime,
        'uniqueBrands': uniqueBrands,
        'medianImageCount': double.parse(medianImageCount.toStringAsFixed(1)),
      },
    };

    // Load existing history
    final historyFile = File(historyFileName);
    List<dynamic> history = [];

    if (await historyFile.exists()) {
      try {
        final content = await historyFile.readAsString();
        history = jsonDecode(content);
      } catch (e) {
        print('⚠️  Warning: Could not read existing history file: $e');
      }
    }

    // Add current result to history
    history.add(currentResult);

    // Keep only last 50 results to avoid huge files
    if (history.length > 50) {
      history = history.skip(history.length - 50).toList();
    }

    // Save updated history
    try {
      await historyFile.writeAsString(const JsonEncoder.withIndent('  ').convert(history));
      print('📊 Test results exported to: $historyFileName');
    } catch (e) {
      print('❌ Failed to export results: $e');
      return;
    }

    // Print comparison with history
    _printComparison(currentResult, history);
  }

  static void _printComparison(Map<String, dynamic> current, List<dynamic> history) {
    if (history.length < 2) {
      print('📈 No previous results to compare with.');
      return;
    }

    final currentSummary = current['summary'] as Map<String, dynamic>;
    final currentAvgTime = currentSummary['avgParseTime'] as double;
    final currentMedianTime = currentSummary['medianParseTime'] as double;
    final currentSuccessRate = currentSummary['successRate'] as double;

    // Compare with previous run (last item before current)
    final previousRun = history[history.length - 2] as Map<String, dynamic>;
    final prevSummary = previousRun['summary'] as Map<String, dynamic>;
    final prevAvgTime = prevSummary['avgParseTime'] as double;
    final prevMedianTime = prevSummary['medianParseTime'] as double;
    final prevSuccessRate = prevSummary['successRate'] as double;

    // Calculate historical averages (excluding current run)
    final historicalRuns = history.take(history.length - 1).toList();
    if (historicalRuns.isNotEmpty) {
      final avgOfAvgTimes =
          historicalRuns
              .map((r) => (r['summary'] as Map)['avgParseTime'] as double)
              .reduce((a, b) => a + b) /
          historicalRuns.length;

      final avgOfMedianTimes =
          historicalRuns
              .map((r) => (r['summary'] as Map)['medianParseTime'] as double)
              .reduce((a, b) => a + b) /
          historicalRuns.length;

      final avgSuccessRate =
          historicalRuns
              .map((r) => (r['summary'] as Map)['successRate'] as double)
              .reduce((a, b) => a + b) /
          historicalRuns.length;

      print('');
      print('=' * 60);
      print('  PERFORMANCE COMPARISON');
      print('=' * 60);

      // Compare with previous run
      final avgTimeDiffPrev = ((prevAvgTime - currentAvgTime) / prevAvgTime * 100);
      final medianTimeDiffPrev = ((prevMedianTime - currentMedianTime) / prevMedianTime * 100);
      final successRateDiffPrev = currentSuccessRate - prevSuccessRate;

      print('📊 vs Previous Run:');
      _printTimeDifference('   Avg time', avgTimeDiffPrev);
      _printTimeDifference('   Median time', medianTimeDiffPrev);
      _printSuccessRateDifference('   Success rate', successRateDiffPrev);

      // Compare with historical average
      final avgTimeDiffHist = ((avgOfAvgTimes - currentAvgTime) / avgOfAvgTimes * 100);
      final medianTimeDiffHist = ((avgOfMedianTimes - currentMedianTime) / avgOfMedianTimes * 100);
      final successRateDiffHist = currentSuccessRate - avgSuccessRate;

      print('');
      print('📈 vs Historical Average (${historicalRuns.length} runs):');
      _printTimeDifference('   Avg time', avgTimeDiffHist);
      _printTimeDifference('   Median time', medianTimeDiffHist);
      _printSuccessRateDifference('   Success rate', successRateDiffHist);

      print('');
    }
  }

  static void _printTimeDifference(String label, double percentDiff) {
    if (percentDiff > 1) {
      print('$label: 🚀 ${percentDiff.toStringAsFixed(1)}% faster');
    } else if (percentDiff < -1) {
      print('$label: 🐌 ${(-percentDiff).toStringAsFixed(1)}% slower');
    } else {
      print('$label: ≈ Similar performance');
    }
  }

  static void _printSuccessRateDifference(String label, double diff) {
    if (diff > 0.5) {
      print('$label: ✅ +${diff.toStringAsFixed(1)}% better');
    } else if (diff < -0.5) {
      print('$label: ❌ ${diff.toStringAsFixed(1)}% worse');
    } else {
      print('$label: ≈ Similar success rate');
    }
  }
}
