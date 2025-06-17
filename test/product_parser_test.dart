import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/product_crawl.dart';

void main() {
  group('Product Parser Tests', () {
    // Helper function để đọc file test từ assets
    Future<String> loadTestFile(String fileName) async {
      final file = File('assets/$fileName');
      if (!await file.exists()) {
        throw Exception('Test file not found: assets/$fileName');
      }
      return await file.readAsString();
    }

    // Helper function để parse file test (dòng đầu là URL, phần còn lại là HTML)
    Map<String, String> parseTestFile(String content) {
      final lines = content.split('\n');
      if (lines.isEmpty) {
        throw Exception('Empty test file');
      }

      final url = lines[0].trim();
      final html = lines.skip(1).join('\n');

      return {'url': url, 'html': html};
    }

    // Test helper để kiểm tra kết quả có đầy đủ thông tin không
    void validateProductData(Map<String, dynamic>? result, String testName) {
      expect(result, isNotNull, reason: 'Result should not be null for $testName');

      if (result != null) {
        // Validate core fields
        expect(result['name'], isNotNull, reason: 'Name should not be null for $testName');
        expect(result['name'], isNotEmpty, reason: 'Name should not be empty for $testName');

        expect(
          result['description'],
          isNotNull,
          reason: 'Description should not be null for $testName',
        );
        expect(
          result['description'],
          isNotEmpty,
          reason: 'Description should not be empty for $testName',
        );

        // Validate new image field (renamed from images)
        expect(result['image'], isNotNull, reason: 'Image should not be null for $testName');
        expect(result['image'], isA<List>(), reason: 'Image should be a List for $testName');
        expect(
          (result['image'] as List).isNotEmpty,
          true,
          reason: 'Image should not be empty for $testName',
        );

        // Validate gallery field (should be same as image)
        expect(result['gallery'], isNotNull, reason: 'Gallery should not be null for $testName');
        expect(result['gallery'], isA<List>(), reason: 'Gallery should be a List for $testName');
        expect(
          (result['gallery'] as List).isNotEmpty,
          true,
          reason: 'Gallery should not be empty for $testName',
        );

        expect(result['price'], isNotNull, reason: 'Price should not be null for $testName');
        expect(result['price'], isNotEmpty, reason: 'Price should not be empty for $testName');

        expect(
          result['priceCurrency'],
          isNotNull,
          reason: 'PriceCurrency should not be null for $testName',
        );
        expect(
          result['priceCurrency'],
          isNotEmpty,
          reason: 'PriceCurrency should not be empty for $testName',
        );

        // Validate new fields
        expect(result['url'], isNotNull, reason: 'URL should not be null for $testName');
        expect(result['url'], isNotEmpty, reason: 'URL should not be empty for $testName');

        expect(result['site'], isNotNull, reason: 'Site should not be null for $testName');
        expect(result['site'], isNotEmpty, reason: 'Site should not be empty for $testName');

        // Brand is optional but should be present in the structure
        expect(result.containsKey('brand'), true, reason: 'Brand field should exist for $testName');

        print('✅ $testName - All fields validated successfully');
        print('   Name: ${result['name']}');
        print('   Brand: ${result['brand'] ?? 'Not found'}');
        print('   Site: ${result['site']}');
        final description = result['description']?.toString() ?? '';
        final shortDesc = description.length > 50
            ? '${description.substring(0, 50)}...'
            : description;
        print('   Description: $shortDesc');
        print('   Images count: ${(result['image'] as List).length}');
        print('   Gallery count: ${(result['gallery'] as List).length}');
        print('   Price: ${result['price']} ${result['priceCurrency']}');
      }
    }

    // Test function để chạy test từ file
    Future<void> runTestFromFile(String fileName) async {
      try {
        final content = await loadTestFile(fileName);
        final testData = parseTestFile(content);

        final result = await parseProduct(testData['html']!, testData['url']!);
        validateProductData(result, fileName);
      } catch (e) {
        fail('Failed to run test for $fileName: $e');
      }
    }

    // Test với dữ liệu không hợp lệ
    test('Test Invalid HTML', () async {
      const invalidHtml = '<html><body><p>No product data here</p></body></html>';
      const url = 'https://example.com/invalid';

      final result = await parseProduct(invalidHtml, url);
      expect(result, isNull, reason: 'Should return null for invalid HTML without product data');
    });

    // Test với HTML rỗng
    test('Test Empty HTML', () async {
      const emptyHtml = '';
      const url = 'https://example.com/empty';

      final result = await parseProduct(emptyHtml, url);
      expect(result, isNull, reason: 'Should return null for empty HTML');
    });

    // Test tất cả các file trong assets folder
    test('Test All Files in Assets Folder', () async {
      final assetsDir = Directory('assets');
      if (!await assetsDir.exists()) {
        print('⚠️ Assets folder not found. Please create it and add test files.');
        return;
      }

      final files = await assetsDir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.txt'))
          .cast<File>()
          .toList();

      if (files.isEmpty) {
        print('⚠️ No .txt files found in assets folder. Please add test files.');
        return;
      }

      // Sort files numerically
      files.sort((a, b) {
        final fileNameA = a.path.split(Platform.pathSeparator).last;
        final fileNameB = b.path.split(Platform.pathSeparator).last;

        final numA = int.tryParse(fileNameA.replaceAll('.txt', '')) ?? 0;
        final numB = int.tryParse(fileNameB.replaceAll('.txt', '')) ?? 0;

        return numA.compareTo(numB);
      });

      print('🧪 Testing ${files.length} files from assets folder...');

      int successCount = 0;
      int failCount = 0;
      List<int> imageCounts = []; // Track image counts for median calculation
      final Set<String> uniqueBrands = {}; // Track unique brands

      for (final file in files) {
        final fileName = file.path.split(Platform.pathSeparator).last;
        try {
          print('\n🔍 Testing: $fileName');
          await runTestFromFile(fileName);
          successCount++;

          // Get image count and brand for tracking
          final content = await file.readAsString();
          final lines = content.split('\n');
          if (lines.isNotEmpty) {
            final url = lines[0].trim();
            final html = lines.skip(1).join('\n');
            final result = await parseProduct(html, url);
            if (result != null && result['image'] != null) {
              imageCounts.add((result['image'] as List).length);

              // Track unique brands (excluding null, empty, "No brand", "Not found")
              if (result['brand'] != null &&
                  result['brand'].toString().isNotEmpty &&
                  result['brand'].toString() != 'No brand' &&
                  result['brand'].toString() != 'Not found') {
                uniqueBrands.add(result['brand'].toString().trim());
              }
            }
          }
        } catch (e) {
          print('❌ Failed: $fileName - $e');
          failCount++;
        }
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

      print('\n📊 Test Summary:');
      print('   ✅ Successful: $successCount');
      print('   ❌ Failed: $failCount');
      print('   📁 Total files: ${files.length}');
      print('   📈 Success Rate: ${(successCount / files.length * 100).toStringAsFixed(1)}%');
      print('   🏷️ Brand tested: ${uniqueBrands.length}');
      print('   🖼️ Median Image Count: ${medianImageCount.toStringAsFixed(1)}');

      // Test sẽ pass nếu có ít nhất 1 file thành công
      expect(successCount, greaterThan(0), reason: 'At least one test file should pass');
    });
  });

  group('Product Data Validation Tests', () {
    test('Test ProductData.toJson() with new format', () {
      const testUrl = 'https://example.com/product';
      final product = ProductData(testUrl);
      product.name = 'Test Product';
      product.brand = 'Test Brand';
      product.description = 'Test Description';
      product.images = ['image1.jpg', 'image2.jpg'];
      product.price = '99.99';
      product.priceCurrency = 'USD';

      final json = product.toJson();

      expect(json['name'], equals('Test Product'));
      expect(json['brand'], equals('Test Brand'));
      expect(json['url'], equals(testUrl));
      expect(json['site'], equals('https://example.com'));
      expect(json['description'], equals('Test Description'));
      expect(json['image'], equals(['image1.jpg', 'image2.jpg']));
      expect(json['gallery'], equals(['image1.jpg', 'image2.jpg']));
      expect(json['price'], equals('99.99'));
      expect(json['priceCurrency'], equals('USD'));
    });

    test('Test ProductData with null values', () {
      const testUrl = 'https://example.com/product';
      final product = ProductData(testUrl);

      final json = product.toJson();

      expect(json['name'], isNull);
      expect(json['brand'], isNull);
      expect(json['url'], equals(testUrl));
      expect(json['site'], equals('https://example.com'));
      expect(json['description'], isNull);
      expect(json['image'], isEmpty);
      expect(json['gallery'], isEmpty);
      expect(json['price'], isNull);
      expect(json['priceCurrency'], isNull);
    });

    test('Test site extraction', () {
      final testCases = [
        ['https://example.com/product', 'https://example.com'],
        ['http://test.com:8080/item', 'http://test.com:8080'],
        ['https://shop.example.com/products/123', 'https://shop.example.com'],
        ['https://www.amazon.com/dp/B123', 'https://www.amazon.com'],
      ];

      for (final testCase in testCases) {
        final product = ProductData(testCase[0]);
        final json = product.toJson();
        expect(
          json['site'],
          equals(testCase[1]),
          reason: 'Site extraction failed for ${testCase[0]}',
        );
      }
    });
  });
}
