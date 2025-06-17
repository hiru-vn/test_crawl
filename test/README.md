# 🛒 Product Parser Test Suite

A comprehensive testing framework for the `parseProduct` function that extracts product data from e-commerce websites.

## 🎯 Overview

This test suite validates product parsing across **40 real-world e-commerce sites** with a **97.5% success rate**. It tests extraction of product names, descriptions, images, prices, and currencies from various website formats.

## 📁 Project Structure

```
test/
├── 📊 test_runner.dart           # Main comprehensive test suite
├── 🔧 product_parser_test.dart   # Basic validation tests  
├── ⚡ performance_test.dart      # Performance benchmarks
├── 🏷️ image_debug_test.dart      # Image extraction debugging
└── 📖 README.md                 # This documentation

lib/
├── 🎯 main.dart                 # Core parsing logic (530 lines)
└── 🔧 fallback_extractors.dart  # Specialized fallback methods (420+ lines)

assets/
├── 1.txt, 2.txt, ... 40.txt    # Real HTML test data from e-commerce sites
```

## 🚀 Quick Start

### 1. Run the Complete Test Suite

```bash
# 🎯 Recommended: Run all tests with detailed reporting
flutter test test/test_runner.dart

# ⚡ Quick performance check
flutter test test/performance_test.dart

# 🔧 Basic validation only
flutter test test/product_parser_test.dart

# 🏷️ Image extraction debugging
flutter test test/image_debug_test.dart
```

### 2. Run All Tests

```bash
# Run everything
flutter test
```

## 📋 Test Data Format

Test files in `assets/` follow this format:

```
https://example.com/product-url
<!DOCTYPE html>
<html>
<head>
    <title>Product Name</title>
    <meta property="og:title" content="Amazing Product">
    <meta property="og:price:amount" content="29.99">
    <meta property="og:price:currency" content="USD">
</head>
<body>
    <h1>Product Title</h1>
    <div class="price">$29.99</div>
    <img src="product-image.jpg" alt="Product">
</body>
</html>
```

**Line 1**: Product URL  
**Line 2+**: Complete HTML content

## ✅ Success Criteria

A test **passes** when all 5 required fields are extracted:

| Field | Requirement | Example |
|-------|-------------|---------|
| 🏷️ **name** | Non-null, non-empty | `"Leather Handbag"` |
| 📝 **description** | Non-null, non-empty | `"Premium leather handbag..."` |
| 🖼️ **images** | Array with ≥1 image | `["https://shop.com/img1.jpg"]` |
| 💰 **price** | Non-null, non-empty | `"129.99"` |
| 💱 **priceCurrency** | Non-null, non-empty | `"USD"` |

## 📊 Current Performance

```
📈 Success Rate: 97.5% (39/40 files)
⚡ Average Speed: ~120ms per page
🎯 Fastest Parse: 6ms
🐌 Slowest Parse: 708ms
```

## 🧪 Test Types

### 🎯 Complete Test Suite (`test_runner.dart`)
- **File-based tests**: All 40 real HTML files
- **Performance metrics**: Speed and efficiency tracking  
- **Success rate analysis**: Detailed pass/fail breakdown
- **Edge case validation**: Empty HTML, malformed JSON, etc.

### 🔧 Basic Validation (`product_parser_test.dart`)
- **Individual field testing**: Each data field validated separately
- **Data type checking**: Ensures correct data types
- **Null safety**: Tests null and empty value handling

### ⚡ Performance Testing (`performance_test.dart`)
- **Speed benchmarks**: Parse time measurements
- **Memory usage**: Resource consumption tracking
- **Scalability**: Performance with large HTML files

### 🏷️ Image Debugging (`image_debug_test.dart`)
- **Image extraction**: Detailed image URL extraction
- **Format validation**: Image URL format checking
- **Priority ranking**: Image selection algorithm testing

## 🏗️ Architecture

The parser uses a **layered fallback approach**:

### 🎯 Core Logic (`main.dart`)
1. **Shopify shortcuts**: Direct API access for Shopify sites
2. **JSON-LD extraction**: Structured data parsing
3. **Meta tags**: OpenGraph, Twitter cards
4. **Heuristic methods**: Standard HTML patterns

### 🔧 Fallback Extractors (`fallback_extractors.dart`)
1. **Microdata extraction**: `itemprop` attributes
2. **Data-test attributes**: Modern test identifiers
3. **Currency detection**: URL-based currency mapping
4. **Country mapping**: 150+ country-to-currency mappings

## 📈 Expected Output

```
============================================================
  PRODUCT PARSER TEST SUITE
============================================================

🔍 Checking test environment...
✅ Test Files
   Found 40 test files

============================================================
  FILE-BASED TESTS
============================================================
✅ 1.txt
   Name: Meandering Convertible-Collar Cotton-Lace Shirt, Images: 4, Price: 60040 USD, Time: 132ms
✅ 2.txt
   Name: Nike LD-1000 Women's Shoes, Images: 2, Price: 89.97 USD, Time: 45ms
...
❌ 13.txt
   Missing: price, priceCurrency

============================================================
  FINAL SUMMARY
============================================================
📊 Test Files: 40
✅ Successful: 39
❌ Failed: 1
📈 Success Rate: 97.5%

🎉 TEST SUITE PASSED! Your parser is working well.
```

## 🛠️ Customization

### Adding New Test Files

1. **Create HTML file**: Save as `assets/41.txt` (next number)
2. **Format correctly**: URL on line 1, HTML on line 2+
3. **Run tests**: `flutter test test/test_runner.dart`

### Modifying Success Criteria

Edit validation logic in `product_parser_test.dart`:

```dart
void validateProductData(Map<String, dynamic>? result, String testName) {
  expect(result, isNotNull, reason: 'Parser should return valid data for $testName');
  expect(result!['name'], isNotNull, reason: 'Name is required');
  expect(result['name'], isNotEmpty, reason: 'Name cannot be empty');
  // Add your custom validation rules here
}
```

### Performance Thresholds

Adjust performance expectations in `performance_test.dart`:

```dart
expect(avgTime, lessThan(150), // Change 150ms to your desired threshold
    reason: 'Average parse time should be under 150ms');
```

## 🔍 Troubleshooting

### Common Issues

| Problem | Cause | Solution |
|---------|-------|----------|
| 🚫 "Assets folder not found" | Missing test files | Create `assets/` folder with `.txt` files |
| 🚫 "Missing: name, images" | Incomplete HTML | Add proper meta tags or JSON-LD |
| 🐌 "Performance too slow" | Large HTML files | Optimize HTML or review parser logic |
| 🚫 "Import error" | Missing dependencies | Run `flutter pub get` |

### Best Practices

- ✅ **Use real HTML**: Copy from actual e-commerce sites
- ✅ **Test edge cases**: Malformed HTML, missing data
- ✅ **Multiple formats**: JSON-LD, meta tags, heuristic parsing
- ✅ **Various sites**: Shopify, WooCommerce, custom platforms
- ✅ **Different languages**: English, Vietnamese, etc.

## 📚 Technical Notes

### Parsing Strategy
The parser follows web standards and common e-commerce patterns:
1. **Standards-first**: JSON-LD and meta tags
2. **Fallback layers**: Multiple extraction methods
3. **Performance-optimized**: Early returns for known patterns
4. **Error-tolerant**: Graceful handling of malformed data

### Supported Formats
- 🌐 **JSON-LD**: Structured data standard
- 📱 **OpenGraph**: Social media meta tags
- 🐦 **Twitter Cards**: Twitter-specific meta tags
- 🏪 **Shopify**: Direct API integration
- 🏷️ **Microdata**: Schema.org attributes
- 🧪 **Data-test**: Modern testing attributes

---

*This test suite was designed with Flutter/Dart best practices, similar to widget testing patterns you're familiar with. The validation, matchers, and reporting structure follows Flutter testing conventions.* 