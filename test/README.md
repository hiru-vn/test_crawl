# Product Parser Test Suite

Đây là bộ test để kiểm tra chức năng của hàm `parseProduct` trong `main.dart`.

## 📁 Cấu trúc Test

```
test/
├── product_parser_test.dart   # Test cơ bản cho từng file
├── performance_test.dart      # Test hiệu suất và benchmark
├── test_runner.dart          # Test runner tổng hợp
└── README.md                # Hướng dẫn này
```

## 🚀 Cách chạy Test

### 1. Chuẩn bị dữ liệu test

Tạo các file `.txt` trong folder `assets/` với format:

```
https://example.com/product-url
<!DOCTYPE html>
<html>
<head>
    <title>Product Name</title>
    <!-- HTML content ở đây -->
</head>
<body>
    <!-- Nội dung sản phẩm -->
</body>
</html>
```

**Dòng đầu tiên**: URL của sản phẩm
**Các dòng tiếp theo**: Nội dung HTML

### 2. Chạy từng loại test

```bash
# Test cơ bản
flutter test test/product_parser_test.dart

# Test hiệu suất
flutter test test/performance_test.dart

# Test tổng hợp (khuyến nghị)
flutter test test/test_runner.dart
```

### 3. Chạy tất cả tests

```bash
flutter test
```

## ✅ Tiêu chí Pass/Fail

Một test được coi là **thành công** khi kết quả trả về có đầy đủ:

- ✅ `name` - Tên sản phẩm (không null, không rỗng)
- ✅ `description` - Mô tả sản phẩm (không null, không rỗng)  
- ✅ `images` - Danh sách hình ảnh (không null, có ít nhất 1 ảnh)
- ✅ `price` - Giá sản phẩm (không null, không rỗng)
- ✅ `priceCurrency` - Đơn vị tiền tệ (không null, không rỗng)

## 📊 Loại Test

### 1. Product Parser Test (`product_parser_test.dart`)
- Test từng file HTML riêng lẻ
- Validation chi tiết cho từng trường dữ liệu
- Test với dữ liệu không hợp lệ

### 2. Performance Test (`performance_test.dart`)
- Đo thời gian parse cho mỗi file
- Test với file HTML lớn
- Kiểm tra memory usage
- Benchmark tổng thể

### 3. Test Runner (`test_runner.dart`)
- Chạy tất cả tests trong assets/
- Báo cáo chi tiết và thống kê
- Edge case testing
- Summary và recommendations

## 📈 Kết quả mong đợi

```
============================================================
  PRODUCT PARSER TEST SUITE                                
============================================================

🔍 Checking test environment...
✅ Assets Folder
   Found 5 test files
✅ Test Files
   Found 5 test files

============================================================
  BASIC VALIDATION TESTS                                   
============================================================
✅ ProductData Class
   toJson() method works correctly

============================================================
  FILE-BASED TESTS                                         
============================================================
✅ shopify_product.txt
   Name: Test Product, Images: 2, Price: 29.99 USD, Time: 45ms
✅ basic_product.txt
   Name: Basic Item, Images: 2, Price: 15.50 USD, Time: 32ms

============================================================
  PERFORMANCE SUMMARY                                      
============================================================
⏱️  Average parse time: 38.50ms
⏱️  Fastest parse: 32ms
⏱️  Slowest parse: 45ms
✅ Performance Check
   Average: 38.50ms

============================================================
  FINAL SUMMARY                                            
============================================================
📊 Test Files: 5
✅ Successful: 5
❌ Failed: 0
📈 Success Rate: 100.0%

🎉 TEST SUITE PASSED! Your parser is working well.
```

## 🐛 Troubleshooting

### Lỗi thường gặp:

1. **"Assets folder not found"**
   - Tạo folder `assets/` trong root project
   - Thêm ít nhất 1 file `.txt` theo format đúng

2. **"Missing: name, images"**
   - HTML test thiếu dữ liệu sản phẩm
   - Kiểm tra HTML có đúng cấu trúc không
   - Thêm meta tags hoặc JSON-LD

3. **"Performance too slow"**
   - File HTML quá lớn
   - Tối ưu logic parser
   - Kiểm tra regex complexity

### Tips để có test tốt:

- ✅ **Đa dạng nguồn**: Shopify, WooCommerce, custom sites
- ✅ **Nhiều format**: JSON-LD, meta tags, heuristic parsing  
- ✅ **Edge cases**: HTML malformed, missing data
- ✅ **Real data**: Copy HTML từ trang thật
- ✅ **Different languages**: Vietnamese, English, etc.

## 🔧 Tùy chỉnh Tests

### Thay đổi tiêu chí pass/fail:

Sửa trong `product_parser_test.dart`:

```dart
void validateProductData(Map<String, dynamic>? result, String testName) {
  // Thêm/bớt validation rules ở đây
}
```

### Thay đổi performance thresholds:

Sửa trong `performance_test.dart`:

```dart
expect(avgTime, lessThan(100), // Thay đổi 100ms thành giá trị khác
    reason: 'Average parse time should be less than 100ms');
```

---

**Lưu ý**: Vì bạn có background Flutter mạnh, các test này được thiết kế giống như widget tests trong Flutter - có validation, matchers, và báo cáo chi tiết. Logic test tương tự như việc test API responses trong Flutter apps. 