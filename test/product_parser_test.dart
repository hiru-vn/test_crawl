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

        expect(result['images'], isNotNull, reason: 'Images should not be null for $testName');
        expect(result['images'], isA<List>(), reason: 'Images should be a List for $testName');
        expect(
          (result['images'] as List).isNotEmpty,
          true,
          reason: 'Images should not be empty for $testName',
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

        print('✅ $testName - All fields validated successfully');
        print('   Name: ${result['name']}');
        print('   Description: ${result['description']?.toString().substring(0, 50)}...');
        print('   Images count: ${(result['images'] as List).length}');
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

    test('Test Shopify Product Parsing', () async {
      await runTestFromFile('shopify_product.txt');
    });

    test('Test Basic Product Parsing', () async {
      await runTestFromFile('basic_product.txt');
    });

    test('Test Vietnamese Product Parsing', () async {
      await runTestFromFile('vietnamese_product.txt');
    });

    test('Test Complex eCommerce Product', () async {
      await runTestFromFile('complex_product.txt');
    });

    test('Test Product with Embedded JSON', () async {
      await runTestFromFile('embedded_json_product.txt');
    });

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

      print('🧪 Testing ${files.length} files from assets folder...');

      int successCount = 0;
      int failCount = 0;

      for (final file in files) {
        final fileName = file.path.split('\\').last; // Windows path separator
        try {
          print('\n🔍 Testing: $fileName');
          await runTestFromFile(fileName);
          successCount++;
        } catch (e) {
          print('❌ Failed: $fileName - $e');
          failCount++;
        }
      }

      print('\n📊 Test Summary:');
      print('   ✅ Successful: $successCount');
      print('   ❌ Failed: $failCount');
      print('   📁 Total files: ${files.length}');

      // Test sẽ pass nếu có ít nhất 1 file thành công
      expect(successCount, greaterThan(0), reason: 'At least one test file should pass');
    });
  });

  group('Product Data Validation Tests', () {
    test('Test ProductData.toJson()', () {
      final product = ProductData();
      product.name = 'Test Product';
      product.description = 'Test Description';
      product.images = ['image1.jpg', 'image2.jpg'];
      product.price = '99.99';
      product.priceCurrency = 'USD';

      final json = product.toJson();

      expect(json['name'], equals('Test Product'));
      expect(json['description'], equals('Test Description'));
      expect(json['images'], equals(['image1.jpg', 'image2.jpg']));
      expect(json['price'], equals('99.99'));
      expect(json['priceCurrency'], equals('USD'));
    });

    test('Test ProductData with null values', () {
      final product = ProductData();

      final json = product.toJson();

      expect(json['name'], isNull);
      expect(json['description'], isNull);
      expect(json['images'], isEmpty);
      expect(json['price'], isNull);
      expect(json['priceCurrency'], isNull);
    });
  });
}
