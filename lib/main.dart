import 'dart:convert';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

class ProductData {
  String? name;
  String? description;
  List<String> images = [];
  String? price;
  String? priceCurrency;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'images': images,
      'price': price,
      'priceCurrency': priceCurrency,
    };
  }
}

/// Hàm chính để phân tích cú pháp HTML và trích xuất thông tin sản phẩm.
///
/// Trả về một Map chứa dữ liệu sản phẩm, hoặc null nếu không tìm thấy
/// các thông tin cần thiết (tên và hình ảnh).
Future<Map<String, dynamic>?> parseProduct(String htmlContent, String url) async {
  final product = ProductData();
  final baseUri = Uri.parse(url);

  // --- Lớp 0: Lối tắt Shopify ---
  final shopifyData = await _extractShopifyData(htmlContent, url);
  if (shopifyData!= null) {
    return shopifyData;
  }

  final document = html_parser.parse(htmlContent);

  // --- Lớp 1: Dữ liệu có cấu trúc ---
  _extractJsonLd(document, product, baseUri);
  _extractMetaTags(document, product, baseUri);

  // --- Lớp 2 & 3: Suy nghiệm & Dữ liệu nhúng ---
  // Chỉ chạy các phương pháp suy nghiệm nếu dữ liệu cốt lõi vẫn còn thiếu.
  if (product.name == null || product.name!.isEmpty) {
    product.name = _extractHeuristicName(document);
  }
  if (product.description == null || product.description!.isEmpty) {
    product.description = _extractHeuristicDescription(document);
  }
  if (product.price == null || product.price!.isEmpty) {
    _extractHeuristicPrice(document, product);
  }
  if (product.images.isEmpty) {
     product.images.addAll(_extractHeuristicImages(document, baseUri, product.name?? ''));
  }
  
  // Cố gắng tìm dữ liệu trong các script nhúng nếu vẫn thiếu
  if (product.name == null || product.price == null || product.images.isEmpty) {
      _extractEmbeddedJson(document, product, baseUri);
  }


  // --- Hoàn thiện và xác thực ---
  _finalizeData(product, baseUri);

  // Yêu cầu phải có tên và ít nhất một hình ảnh
  if (product.name!= null && product.name!.isNotEmpty && product.images.isNotEmpty) {
    return product.toJson();
  }

  return null;
}

/// Lớp 0: Cố gắng trích xuất dữ liệu từ điểm cuối.json của Shopify.
Future<Map<String, dynamic>?> _extractShopifyData(String htmlContent, String url) async {
  final uri = Uri.parse(url);
  if (uri.path.contains('/products/') && htmlContent.toLowerCase().contains('shopify')) {
    try {
      final jsonUrl = Uri.parse('${uri.scheme}://${uri.host}${uri.path}.json');
      final response = await http.get(jsonUrl);
      if (response.statusCode == 200) {
        final jsonBody = jsonDecode(response.body);
        if (jsonBody.containsKey('product')) {
          final productJson = jsonBody['product'];
          return {
            'name': productJson['title'],
            'description': productJson['body_html'],
            'images': (productJson['images'] as List).map<String>((img) => img['src'] as String).toList(),
            'price': productJson['variants']??['price'],
            'priceCurrency': null, // Shopify API không cung cấp tiền tệ ở đây
          };
        }
      }
    } catch (e) {
      // Bỏ qua lỗi và tiếp tục với các phương pháp khác
    }
  }
  return null;
}

/// Lớp 1: Trích xuất dữ liệu từ các thẻ script JSON-LD.
void _extractJsonLd(Document document, ProductData product, Uri baseUri) {
  final scripts = document.querySelectorAll('script[type="application/ld+json"]');
  for (final script in scripts) {
    try {
      final jsonContent = jsonDecode(script.text);
      _parseJsonLdObject(jsonContent, product);
    } catch (e) {
      // Bỏ qua JSON không hợp lệ
    }
  }
}

/// Hàm đệ quy để phân tích các đối tượng JSON-LD.
void _parseJsonLdObject(dynamic jsonObj, ProductData product) {
  if (jsonObj is Map) {
    final type = jsonObj['@type'];
    final isProduct = type is String && (type.contains('Product') || type.contains('Thing')) ||
                      type is List && type.any((t) => t.toString().contains('Product'));

    if (isProduct) {
      product.name??= jsonObj['name'] as String?;
      product.description??= jsonObj['description'] as String?;

      // Trích xuất giá từ offers
      if (jsonObj.containsKey('offers')) {
        final offers = jsonObj['offers'];
        if (offers is List && offers.isNotEmpty) {
          final offer = offers.first;
          if (offer is Map) {
            product.price??= offer['price']?.toString();
            product.priceCurrency??= offer['priceCurrency'] as String?;
          }
        } else if (offers is Map) {
          product.price??= offers['price']?.toString();
          product.priceCurrency??= offers['priceCurrency'] as String?;
        }
      }

      // Trích xuất hình ảnh
      if (jsonObj.containsKey('image')) {
        final imageField = jsonObj['image'];
        if (imageField is String) {
          product.images.add(imageField);
        } else if (imageField is List) {
          for (final item in imageField) {
            if (item is String) {
              product.images.add(item);
            } else if (item is Map && item.containsKey('url') && item['url'] is String) {
              product.images.add(item['url']);
            }
          }
        }
      }
    }
    // Tìm kiếm đệ quy trong các giá trị của map
    jsonObj.values.forEach((value) => _parseJsonLdObject(value, product));
  } else if (jsonObj is List) {
    // Tìm kiếm đệ quy trong các phần tử của list
    jsonObj.forEach((item) => _parseJsonLdObject(item, product));
  }
}


/// Lớp 1: Trích xuất dữ liệu từ các thẻ meta (Open Graph, Twitter, etc.).
void _extractMetaTags(Document document, ProductData product, Uri baseUri) {
  String? getMetaContent(String property) {
    return document.querySelector('meta[property="$property"]')?.attributes['content']??
           document.querySelector('meta[name="$property"]')?.attributes['content'];
  }

  product.name??= getMetaContent('og:title')?? getMetaContent('twitter:title');
  product.description??= getMetaContent('og:description')?? getMetaContent('twitter:description');
  
  final ogImage = getMetaContent('og:image');
  if (ogImage!= null) product.images.add(ogImage);
  
  final twitterImage = getMetaContent('twitter:image');
  if (twitterImage!= null) product.images.add(twitterImage);
}

/// Lớp 2: Suy nghiệm tên sản phẩm từ các thẻ HTML phổ biến.
String? _extractHeuristicName(Document document) {
  return document.querySelector('h1')?.text.trim()??
         document.querySelector('title')?.text.trim();
}

/// Lớp 2: Suy nghiệm mô tả sản phẩm.
String? _extractHeuristicDescription(Document document) {
  return document.querySelector('meta[name="description"]')?.attributes['content']??
         document.querySelector('[class*="description"]')?.text.trim()??
         document.querySelector('[id*="description"]')?.text.trim();
}

/// Lớp 2: Suy nghiệm giá sản phẩm.
void _extractHeuristicPrice(Document document, ProductData product) {
  final priceSelectors = [
    '[class*="price"]', '[id*="price"]',
    '[class*="amount"]', '[id*="amount"]',
    '.product-price', '.sale-price'
  ];

  for (final selector in priceSelectors) {
    final element = document.querySelector(selector);
    if (element!= null) {
      final priceText = element.text;
      final priceMatch = RegExp(r'[\d,.]+', unicode: true).firstMatch(priceText);
      if (priceMatch!= null) {
        product.price = priceMatch.group(0)?.replaceAll(RegExp(r'[^\d.]'), '');
        // Suy luận tiền tệ đơn giản
        if (priceText.contains('đ') || priceText.contains('VND')) product.priceCurrency = 'VND';
        if (priceText.contains('\$')) product.priceCurrency = 'USD';
        if (priceText.contains('€')) product.priceCurrency = 'EUR';
        return;
      }
    }
  }
}

/// Lớp 2: Trích xuất hình ảnh bằng phương pháp suy nghiệm.
List<String> _extractHeuristicImages(Document document, Uri baseUri, String productName) {
  final images = <String>{}; // Sử dụng Set để tránh trùng lặp

  final imageElements = document.querySelectorAll('img');
  final imageAttributePriority = ['data-srcset', 'data-src', 'srcset', 'src'];

  for (final img in imageElements) {
    for (final attr in imageAttributePriority) {
      final src = img.attributes[attr];
      if (src!= null && src.isNotEmpty) {
        // Nếu là srcset, lấy URL đầu tiên hoặc URL có độ phân giải cao nhất
        final urlToAdd = attr.contains('srcset')? _parseSrcset(src) : src;
        images.add(urlToAdd);
        break; // Đã tìm thấy nguồn ảnh cho thẻ img này, chuyển sang thẻ tiếp theo
      }
    }
  }
  
  return _filterAndRankImages(images.toList(), productName, baseUri);
}

/// Lớp 3: Cố gắng trích xuất dữ liệu từ JSON nhúng trong các thẻ script.
void _extractEmbeddedJson(Document document, ProductData product, Uri baseUri) {
    final scripts = document.querySelectorAll('script');
    final jsonRegex = RegExp(r'(\{[^{}]+\})'); // Regex đơn giản để tìm các khối JSON

    for (final script in scripts) {
        if (script.attributes.containsKey('src')) continue; // Bỏ qua script bên ngoài

        final text = script.text;
        if (text.contains('product') || text.contains('price')) {
            final matches = jsonRegex.allMatches(text);
            for (final match in matches) {
                try {
                    final jsonString = match.group(1);
                    if (jsonString!= null) {
                        final decodedJson = jsonDecode(jsonString);
                        _parseJsonLdObject(decodedJson, product); // Tái sử dụng logic phân tích JSON-LD
                    }
                } catch (e) {
                    // Bỏ qua lỗi phân tích
                }
            }
        }
    }
}


/// Phân tích srcset để lấy URL tốt nhất.
String _parseSrcset(String srcset) {
  // Lấy URL đầu tiên từ danh sách
  return srcset.split(',').first.trim().split(' ').first;
}

/// Lọc và xếp hạng hình ảnh để chọn ra những ảnh phù hợp nhất.
List<String> _filterAndRankImages(List<String> imageUrls, String productName, Uri baseUri) {
  final unwantedKeywords = ['logo', 'icon', 'sprite', 'avatar', 'placeholder', 'loading', 'spinner', 'payment', 'badge', 'star', '.svg'];
  final productKeywords = productName.toLowerCase().split(RegExp(r'\s+')).where((s) => s.length > 2).toList();

  final rankedImages = imageUrls
     .map((url) => _resolveUrl(url, baseUri)) // Chuyển đổi URL tương đối thành tuyệt đối
     .where((url) => url.isNotEmpty &&!unwantedKeywords.any((kw) => url.toLowerCase().contains(kw)))
     .toList();

  // Sắp xếp dựa trên sự hiện diện của từ khóa sản phẩm trong URL
  rankedImages.sort((a, b) {
    final scoreA = productKeywords.where((kw) => a.toLowerCase().contains(kw)).length;
    final scoreB = productKeywords.where((kw) => b.toLowerCase().contains(kw)).length;
    return scoreB.compareTo(scoreA); // Sắp xếp giảm dần
  });

  return rankedImages.toSet().toList(); // Trả về danh sách duy nhất
}

/// Chuyển đổi URL tương đối thành URL tuyệt đối.
String _resolveUrl(String relativeUrl, Uri baseUri) {
  if (relativeUrl.startsWith('//')) {
    return '${baseUri.scheme}:$relativeUrl';
  }
  if (relativeUrl.startsWith('http')) {
    return relativeUrl;
  }
  try {
    return baseUri.resolve(relativeUrl).toString();
  } catch (e) {
    return '';
  }
}

/// Dọn dẹp và hoàn thiện dữ liệu cuối cùng.
void _finalizeData(ProductData product, Uri baseUri) {
  // Dọn dẹp tên và mô tả
  product.name = product.name?.replaceAll(RegExp(r'\s+'), ' ').trim();
  product.description = product.description?.replaceAll(RegExp(r'\s+'), ' ').trim();

  // Đảm bảo tất cả các URL hình ảnh là tuyệt đối và duy nhất
  product.images = product.images
     .map((url) => _resolveUrl(url, baseUri))
     .where((url) => url.isNotEmpty)
     .toSet()
     .toList();
      
  // Dọn dẹp giá
  product.price = product.price?.replaceAll(RegExp(r'[^0-9.]'), '');
}

