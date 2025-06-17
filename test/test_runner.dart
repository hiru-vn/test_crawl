import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
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
        final product = ProductData();
        product.name = 'Test';
        product.description = 'Test Description';
        product.images = ['test.jpg'];
        product.price = '99.99';
        product.priceCurrency = 'USD';

        final json = product.toJson();
        final validJson =
            json['name'] == 'Test' && json['images'] is List && (json['images'] as List).isNotEmpty;

        testResults['ProductData Class'] = validJson;
        printTestResult('ProductData Class', validJson, 'toJson() method works correctly');
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
              result['images'] != null &&
              (result['images'] as List).isNotEmpty &&
              result['price'] != null &&
              result['price'].toString().isNotEmpty &&
              result['priceCurrency'] != null &&
              result['priceCurrency'].toString().isNotEmpty;

          testResults[fileName] = success;

          if (success) {
            successCount++;
            final imageCount = (result!['images'] as List).length;
            testDetails[fileName] =
                'Name: ${result['name']}, Images: $imageCount, ' +
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
              if (result['images'] == null || (result['images'] as List).isEmpty)
                missingFields.add('images');
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

      if (parseTimes.isNotEmpty) {
        final avgTime =
            parseTimes.map((d) => d.inMilliseconds).reduce((a, b) => a + b) / parseTimes.length;
        final maxTime = parseTimes.map((d) => d.inMilliseconds).reduce((a, b) => a > b ? a : b);
        final minTime = parseTimes.map((d) => d.inMilliseconds).reduce((a, b) => a < b ? a : b);

        print('⏱️  Average parse time: ${avgTime.toStringAsFixed(2)}ms');
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

      // Test 5: Final summary
      printHeader('FINAL SUMMARY');

      final successRate = totalCount > 0 ? (successCount / totalCount) * 100 : 0;
      print('📊 Test Files: $totalCount');
      print('✅ Successful: $successCount');
      print('❌ Failed: ${totalCount - successCount}');
      print('📈 Success Rate: ${successRate.toStringAsFixed(1)}%');

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
