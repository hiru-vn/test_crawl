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
  if (shopifyData != null) {
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
    product.images.addAll(_extractHeuristicImages(document, baseUri, product.name ?? ''));
  }

  // Cố gắng tìm dữ liệu trong các script nhúng nếu vẫn thiếu
  if (product.name == null || product.price == null || product.images.isEmpty) {
    _extractEmbeddedJson(document, product, baseUri);
  }

  // --- Lớp bổ sung: Fallback cho price/currency từ itemprop meta tags ---
  if (product.price == null ||
      product.price!.isEmpty ||
      product.priceCurrency == null ||
      product.priceCurrency!.isEmpty) {
    _extractMicrodataPrice(document, product);
  }

  // --- Hoàn thiện và xác thực ---
  _finalizeData(product, baseUri);

  // Yêu cầu phải có tên và ít nhất một hình ảnh
  if (product.name != null && product.name!.isNotEmpty && product.images.isNotEmpty) {
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
          // Extract currency from variants
          String? currency;
          String? price;
          if (productJson.containsKey('variants')) {
            final variants = productJson['variants'];
            if (variants is List && variants.isNotEmpty) {
              final firstVariant = variants.first;
              if (firstVariant is Map) {
                price = firstVariant['price']?.toString();
                currency = firstVariant['price_currency'] as String?;
              }
            }
          }

          return {
            'name': productJson['title'],
            'description': productJson['body_html'],
            'images': (productJson['images'] as List)
                .map<String>((img) => img['src'] as String)
                .toList(),
            'price': price ?? productJson['variants']?.toString(),
            'priceCurrency': currency,
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
    final isProduct =
        type is String && (type.contains('Product') || type.contains('Thing')) ||
        type is List && type.any((t) => t.toString().contains('Product'));

    if (isProduct) {
      product.name ??= jsonObj['name'] as String?;
      // Only set description if it's not null and not just whitespace
      final jsonDesc = jsonObj['description'] as String?;
      if (product.description == null && jsonDesc != null && jsonDesc.trim().isNotEmpty) {
        product.description = jsonDesc;
      }

      // Trích xuất giá từ offers
      if (jsonObj.containsKey('offers')) {
        final offers = jsonObj['offers'];
        if (offers is List && offers.isNotEmpty) {
          final offer = offers.first;
          if (offer is Map) {
            product.price ??= offer['price']?.toString();
            product.priceCurrency ??= offer['priceCurrency'] as String?;
          }
        } else if (offers is Map) {
          product.price ??= offers['price']?.toString();
          product.priceCurrency ??= offers['priceCurrency'] as String?;
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
    return document.querySelector('meta[property="$property"]')?.attributes['content'] ??
        document.querySelector('meta[name="$property"]')?.attributes['content'];
  }

  product.name ??= getMetaContent('og:title') ?? getMetaContent('twitter:title');
  product.description ??=
      getMetaContent('og:description') ??
      getMetaContent('twitter:description') ??
      getMetaContent('description');

  final ogImage = getMetaContent('og:image');
  if (ogImage != null) product.images.add(ogImage);

  final twitterImage = getMetaContent('twitter:image');
  if (twitterImage != null) product.images.add(twitterImage);
}

/// Lớp 2: Suy nghiệm tên sản phẩm từ các thẻ HTML phổ biến.
String? _extractHeuristicName(Document document) {
  return document.querySelector('h1')?.text.trim() ?? document.querySelector('title')?.text.trim();
}

/// Lớp 2: Suy nghiệm mô tả sản phẩm.
String? _extractHeuristicDescription(Document document) {
  return document.querySelector('meta[name="description"]')?.attributes['content'] ??
      document.querySelector('[class*="description"]')?.text.trim() ??
      document.querySelector('[id*="description"]')?.text.trim();
}

/// Lớp 2: Suy nghiệm giá sản phẩm.
void _extractHeuristicPrice(Document document, ProductData product) {
  final priceSelectors = [
    '[class*="price"]',
    '[id*="price"]',
    '[class*="amount"]',
    '[id*="amount"]',
    '.product-price',
    '.sale-price',
  ];

  for (final selector in priceSelectors) {
    final element = document.querySelector(selector);
    if (element != null) {
      final priceText = element.text;
      final priceMatch = RegExp(r'[\d,.]+', unicode: true).firstMatch(priceText);
      if (priceMatch != null) {
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

/// Lớp bổ sung: Trích xuất giá và tiền tệ từ microdata (itemprop) meta tags
void _extractMicrodataPrice(Document document, ProductData product) {
  // Common itemprop attributes for price and currency
  final priceProps = ['price', 'lowPrice', 'highPrice', 'priceValue'];
  final currencyProps = ['priceCurrency', 'currency'];

  // Try to extract price from itemprop meta tags
  if (product.price == null || product.price!.isEmpty) {
    for (final prop in priceProps) {
      final priceElement = document.querySelector('meta[itemprop="$prop"]');
      if (priceElement != null) {
        final priceContent = priceElement.attributes['content'];
        if (priceContent != null && priceContent.isNotEmpty) {
          // Clean price: remove currency symbols and keep only numbers and dots
          final cleanPrice = priceContent.replaceAll(RegExp(r'[^\d\.]'), '');
          if (cleanPrice.isNotEmpty) {
            product.price = cleanPrice;
            break;
          }
        }
      }
    }
  }

  // Try to extract currency from itemprop meta tags
  if (product.priceCurrency == null || product.priceCurrency!.isEmpty) {
    for (final prop in currencyProps) {
      final currencyElement = document.querySelector('meta[itemprop="$prop"]');
      if (currencyElement != null) {
        final currencyContent = currencyElement.attributes['content'];
        if (currencyContent != null && currencyContent.isNotEmpty) {
          product.priceCurrency = currencyContent;
          break;
        }
      }
    }
  }

  // Also check for property-based microdata (alternative format)
  if (product.price == null || product.price!.isEmpty) {
    for (final prop in priceProps) {
      final priceElement = document.querySelector('meta[property="$prop"]');
      if (priceElement != null) {
        final priceContent = priceElement.attributes['content'];
        if (priceContent != null && priceContent.isNotEmpty) {
          final cleanPrice = priceContent.replaceAll(RegExp(r'[^\d\.]'), '');
          if (cleanPrice.isNotEmpty) {
            product.price = cleanPrice;
            break;
          }
        }
      }
    }
  }

  if (product.priceCurrency == null || product.priceCurrency!.isEmpty) {
    for (final prop in currencyProps) {
      final currencyElement = document.querySelector('meta[property="$prop"]');
      if (currencyElement != null) {
        final currencyContent = currencyElement.attributes['content'];
        if (currencyContent != null && currencyContent.isNotEmpty) {
          product.priceCurrency = currencyContent;
          break;
        }
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
      if (src != null && src.isNotEmpty) {
        // Nếu là srcset, lấy URL đầu tiên hoặc URL có độ phân giải cao nhất
        final urlToAdd = attr.contains('srcset') ? _parseSrcset(src) : src;
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

  for (final script in scripts) {
    if (script.attributes.containsKey('src')) continue; // Bỏ qua script bên ngoài

    final text = script.text;

    // Tìm kiếm Shopify product data specifically
    if (text.contains('product') && text.contains('variants')) {
      _extractShopifyScriptData(text, product);
    }

    // Tìm kiếm JSON objects khác
    if (text.contains('product') || text.contains('price')) {
      // Improved regex for nested JSON
      final jsonRegex = RegExp(r'(\{(?:[^{}]|{[^{}]*})*\})');
      final matches = jsonRegex.allMatches(text);

      for (final match in matches) {
        try {
          final jsonString = match.group(1);
          if (jsonString != null) {
            final decodedJson = jsonDecode(jsonString);
            _parseJsonLdObject(decodedJson, product);
          }
        } catch (e) {
          // Bỏ qua lỗi phân tích
        }
      }
    }
  }
}

/// Trích xuất dữ liệu Shopify từ script tags
void _extractShopifyScriptData(String scriptText, ProductData product) {
  // Look for Shopify product data patterns
  final patterns = [
    RegExp(r'window\.ShopifyAnalytics\s*=\s*\{[^}]*"product":\s*(\{[^}]+\})', multiLine: true),
    RegExp(r'"product":\s*(\{[^}]+variants[^}]+\})', multiLine: true),
    RegExp(r'product:\s*(\{[^}]+variants[^}]+\})', multiLine: true),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(scriptText);
    if (match != null) {
      try {
        final productJson = jsonDecode(match.group(1)!);
        if (productJson is Map<String, dynamic>) {
          _parseShopifyProductData(productJson, product);
        }
      } catch (e) {
        // Continue to next pattern
      }
    }
  }

  // Also look for variants array specifically with better regex
  final variantsMatches = [
    RegExp(r'variants"?\s*:\s*(\[[\s\S]*?\])', multiLine: true),
    RegExp(r'"variants"\s*:\s*(\[[\s\S]*?\])', multiLine: true),
    RegExp(r'window\.product\s*=\s*\{[^}]*variants[^}]*:\s*(\[[\s\S]*?\])', multiLine: true),
  ];

  for (final regex in variantsMatches) {
    final match = regex.firstMatch(scriptText);
    if (match != null) {
      try {
        final variantsString = match.group(1)!;
        // Fix any JSON formatting issues
        final cleanedVariants = variantsString
            .replaceAll(RegExp(r',\s*\}'), '}')
            .replaceAll(RegExp(r',\s*\]'), ']');

        final variantsJson = jsonDecode(cleanedVariants);
        if (variantsJson is List && variantsJson.isNotEmpty) {
          final firstVariant = variantsJson.first;
          if (firstVariant is Map) {
            if (product.price == null && firstVariant.containsKey('price')) {
              product.price = firstVariant['price']?.toString();
            }
            if (product.priceCurrency == null && firstVariant.containsKey('price_currency')) {
              product.priceCurrency = firstVariant['price_currency'] as String?;
            }
          }
        }
        break; // Successfully parsed, stop trying other patterns
      } catch (e) {
        // Continue to next pattern
      }
    }
  }
}

/// Parse Shopify specific product data
void _parseShopifyProductData(Map<String, dynamic> productData, ProductData product) {
  // Extract basic info
  product.name ??= productData['title'] as String?;

  // Extract variants for price and currency
  if (productData.containsKey('variants')) {
    final variants = productData['variants'];
    if (variants is List && variants.isNotEmpty) {
      final firstVariant = variants.first;
      if (firstVariant is Map) {
        product.price ??= firstVariant['price']?.toString();
        product.priceCurrency ??= firstVariant['price_currency'] as String?;
      }
    }
  }

  // Extract images
  if (productData.containsKey('images')) {
    final images = productData['images'];
    if (images is List) {
      for (final img in images) {
        if (img is String) {
          product.images.add(img);
        } else if (img is Map && img.containsKey('src')) {
          product.images.add(img['src'] as String);
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
  final unwantedKeywords = [
    'logo',
    'icon',
    'sprite',
    'avatar',
    'placeholder',
    'loading',
    'spinner',
    'payment',
    'badge',
    'star',
    '.svg',
  ];
  final productKeywords = productName
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((s) => s.length > 2)
      .toList();

  final rankedImages = imageUrls
      .map((url) => _resolveUrl(url, baseUri)) // Chuyển đổi URL tương đối thành tuyệt đối
      .where(
        (url) => url.isNotEmpty && !unwantedKeywords.any((kw) => url.toLowerCase().contains(kw)),
      )
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
  product.description = product.description
      ?.replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
      .trim()
      .replaceAll(
        RegExp(r'^[\s]*[\.\,\-][\s]+(?=\w)'),
        '',
      ) // Remove leading punctuation followed by space before words
      .trim(); // Trim again after removing leading punctuation

  // Đảm bảo tất cả các URL hình ảnh là tuyệt đối và duy nhất
  product.images = product.images
      .map((url) => _resolveUrl(url, baseUri))
      .where((url) => url.isNotEmpty)
      .toSet()
      .toList();

  // Fallback để parse currency từ price field nếu nó chứa JSON (TRƯỚC khi dọn dẹp)
  if (product.price != null &&
      product.price!.contains('price_currency') &&
      product.priceCurrency == null) {
    // More aggressive currency extraction patterns
    final currencyPatterns = [
      RegExp(r'price_currency:\s*([A-Z]{3})', caseSensitive: false), // No quotes case
      RegExp(r'"price_currency":\s*"([A-Z]{3})"', caseSensitive: false), // Full quotes case
      RegExp(r'price_currency["\s]*:\s*["\s]*([A-Z]{3})', caseSensitive: false),
      RegExp(r'price_currency["\047]?\s*:\s*["\047]?([A-Z]{3})', caseSensitive: false),
    ];

    for (final pattern in currencyPatterns) {
      final match = pattern.firstMatch(product.price!);
      if (match != null) {
        product.priceCurrency = match.group(1);
        break;
      }
    }

    // Extract clean price from the JSON if currency was found
    if (product.priceCurrency != null) {
      final pricePatterns = [
        RegExp(r'price:\s*([0-9.]+)', caseSensitive: false), // No quotes case
        RegExp(r'"price":\s*([0-9.]+)', caseSensitive: false), // Full quotes case
        RegExp(r'price["\047]?\s*:\s*([0-9.]+)', caseSensitive: false),
      ];

      for (final pattern in pricePatterns) {
        final match = pattern.firstMatch(product.price!);
        if (match != null) {
          product.price = match.group(1);
          break;
        }
      }
    }
  }

  // Dọn dẹp giá (SAU khi extract currency)
  product.price = product.price?.replaceAll(RegExp(r'[^0-9.]'), '');

  // Fallback currency detection nếu priceCurrency vẫn null
  if (product.price != null && product.price!.isNotEmpty && product.priceCurrency == null) {
    product.priceCurrency = _detectCurrencyFromUrl(baseUri);
  }
}

// /// Phát hiện currency từ URL domain và language codes
String? _detectCurrencyFromUrl(Uri baseUri) {
  final host = baseUri.host.toLowerCase();

  // 1. Kiểm tra country code từ domain
  final countryCurrency = _getCountryCurrencyFromDomain(host);
  if (countryCurrency != null) return countryCurrency;

  // 2. Kiểm tra language code từ URL path
  final languageCurrency = _getLanguageCurrencyFromPath(baseUri.path);
  if (languageCurrency != null) return languageCurrency;

  // 3. Default fallback based on common TLDs
  if (host.endsWith('.com') || host.endsWith('.org') || host.endsWith('.net')) return 'USD';
  if (host.endsWith('.eu')) return 'EUR';
  if (host.endsWith('.co.uk') || host.endsWith('.uk')) return 'GBP';
  if (host.endsWith('.ca')) return 'CAD';
  if (host.endsWith('.au')) return 'AUD';
  if (host.endsWith('.jp')) return 'JPY';
  if (host.endsWith('.vn')) return 'VND';

  return null;
}

/// Mapping country codes to currencies
String? _getCountryCurrencyFromDomain(String host) {
  // Country code to currency mapping
  final countryCurrencyMap = <String, String>{
    "nz": "NZD",
    "ck": "NZD",
    "nu": "NZD",
    "pn": "NZD",
    "tk": "NZD",
    "au": "AUD",
    "cx": "AUD",
    "cc": "AUD",
    "hm": "AUD",
    "ki": "AUD",
    "nr": "AUD",
    "nf": "AUD",
    "tv": "AUD",
    "as": "EUR",
    "ad": "EUR",
    "at": "EUR",
    "be": "EUR",
    "fi": "EUR",
    "fr": "EUR",
    "gf": "EUR",
    "tf": "EUR",
    "de": "EUR",
    "gr": "EUR",
    "gp": "EUR",
    "ie": "EUR",
    "it": "EUR",
    "lu": "EUR",
    "mq": "EUR",
    "yt": "EUR",
    "mc": "EUR",
    "nl": "EUR",
    "pt": "EUR",
    "re": "EUR",
    "ws": "EUR",
    "sm": "EUR",
    "si": "EUR",
    "es": "EUR",
    "va": "EUR",
    "ax": "EUR",
    "me": "EUR",
    "bl": "EUR",
    "pm": "EUR",
    "gs": "GBP",
    "gb": "GBP",
    "je": "GBP",
    "sh": "GBP",
    "im": "GBP",
    "io": "USD",
    "gu": "USD",
    "mh": "USD",
    "fm": "USD",
    "mp": "USD",
    "pw": "USD",
    "pr": "USD",
    "tc": "USD",
    "us": "USD",
    "um": "USD",
    "vg": "USD",
    "vi": "USD",
    "hk": "HKD",
    "ca": "CAD",
    "jp": "JPY",
    "af": "AFN",
    "al": "ALL",
    "dz": "DZD",
    "ai": "XCD",
    "ag": "XCD",
    "dm": "XCD",
    "gd": "XCD",
    "ms": "XCD",
    "kn": "XCD",
    "lc": "XCD",
    "vc": "XCD",
    "ar": "ARS",
    "am": "AMD",
    "aw": "ANG",
    "an": "ANG",
    "az": "AZN",
    "bs": "BSD",
    "bh": "BHD",
    "bd": "BDT",
    "bb": "BBD",
    "by": "BYR",
    "bz": "BZD",
    "bj": "XOF",
    "bf": "XOF",
    "gw": "XOF",
    "ci": "XOF",
    "ml": "XOF",
    "ne": "XOF",
    "sn": "XOF",
    "tg": "XOF",
    "bm": "BMD",
    "bt": "INR",
    "in": "INR",
    "bo": "BOB",
    "bw": "BWP",
    "bv": "NOK",
    "no": "NOK",
    "sj": "NOK",
    "br": "BRL",
    "bn": "BND",
    "bg": "BGN",
    "bi": "BIF",
    "kh": "KHR",
    "cm": "XAF",
    "cf": "XAF",
    "td": "XAF",
    "cg": "XAF",
    "gq": "XAF",
    "ga": "XAF",
    "cv": "CVE",
    "ky": "KYD",
    "cl": "CLP",
    "cn": "CNY",
    "co": "COP",
    "km": "KMF",
    "cd": "CDF",
    "cr": "CRC",
    "hr": "HRK",
    "cu": "CUP",
    "cy": "CYP",
    "cz": "CZK",
    "dk": "DKK",
    "fo": "DKK",
    "gl": "DKK",
    "dj": "DJF",
    "do": "DOP",
    "tp": "IDR",
    "id": "IDR",
    "ec": "ECS",
    "eg": "EGP",
    "sv": "SVC",
    "er": "ETB",
    "et": "ETB",
    "ee": "EEK",
    "fk": "FKP",
    "fj": "FJD",
    "pf": "XPF",
    "nc": "XPF",
    "wf": "XPF",
    "gm": "GMD",
    "ge": "GEL",
    "gi": "GIP",
    "gt": "GTQ",
    "gn": "GNF",
    "gy": "GYD",
    "ht": "HTG",
    "hn": "HNL",
    "hu": "HUF",
    "is": "ISK",
    "ir": "IRR",
    "iq": "IQD",
    "il": "ILS",
    "jm": "JMD",
    "jo": "JOD",
    "kz": "KZT",
    "ke": "KES",
    "kp": "KPW",
    "kr": "KRW",
    "kw": "KWD",
    "kg": "KGS",
    "la": "LAK",
    "lv": "LVL",
    "lb": "LBP",
    "ls": "LSL",
    "lr": "LRD",
    "ly": "LYD",
    "li": "CHF",
    "ch": "CHF",
    "lt": "LTL",
    "mo": "MOP",
    "mk": "MKD",
    "mg": "MGA",
    "mw": "MWK",
    "my": "MYR",
    "mv": "MVR",
    "mt": "MTL",
    "mr": "MRO",
    "mu": "MUR",
    "mx": "MXN",
    "md": "MDL",
    "mn": "MNT",
    "ma": "MAD",
    "eh": "MAD",
    "mz": "MZN",
    "mm": "MMK",
    "na": "NAD",
    "np": "NPR",
    "ni": "NIO",
    "ng": "NGN",
    "om": "OMR",
    "pk": "PKR",
    "pa": "PAB",
    "pg": "PGK",
    "py": "PYG",
    "pe": "PEN",
    "ph": "PHP",
    "pl": "PLN",
    "qa": "QAR",
    "ro": "RON",
    "ru": "RUB",
    "rw": "RWF",
    "st": "STD",
    "sa": "SAR",
    "sc": "SCR",
    "sl": "SLL",
    "sg": "SGD",
    "sk": "SKK",
    "sb": "SBD",
    "so": "SOS",
    "za": "ZAR",
    "lk": "LKR",
    "sd": "SDG",
    "sr": "SRD",
    "sz": "SZL",
    "se": "SEK",
    "sy": "SYP",
    "tw": "TWD",
    "tj": "TJS",
    "tz": "TZS",
    "th": "THB",
    "to": "TOP",
    "tt": "TTD",
    "tn": "TND",
    "tr": "TRY",
    "tm": "TMT",
    "ug": "UGX",
    "ua": "UAH",
    "ae": "AED",
    "uy": "UYU",
    "uz": "UZS",
    "vu": "VUV",
    "ve": "VEF",
    "vn": "VND",
    "ye": "YER",
    "zm": "ZMK",
    "zw": "ZWD",
    "ao": "AOA",
    "aq": "AQD",
    "ba": "BAM",
    "gh": "GHS",
    "gg": "GGP",
    "ps": "JOD",
    "mf": "ANG",
    "rs": "RSD",
  };

  // Check for country-specific domains (e.g., amazon.co.uk, ebay.ca)
  for (final entry in countryCurrencyMap.entries) {
    if (host.contains('.${entry.key}') || host.endsWith('.${entry.key}')) {
      return entry.value;
    }
  }

  return null;
}

/// Detect currency from language codes in URL path
String? _getLanguageCurrencyFromPath(String path) {
  // Language code to currency mapping (fallback)
  final languageCurrencyMap = <String, String>{
    "en": "USD",
    "de": "EUR",
    "fr": "EUR",
    "es": "EUR",
    "it": "EUR",
    "pt": "EUR",
    "nl": "EUR",
    "ja": "JPY",
    "ko": "KRW",
    "zh": "CNY",
    "ru": "RUB",
    "ar": "SAR",
    "hi": "INR",
    "th": "THB",
    "vi": "VND",
    "tr": "TRY",
    "pl": "PLN",
    "sv": "SEK",
    "no": "NOK",
    "da": "DKK",
    "fi": "EUR",
  };

  // Look for language codes in URL (e.g., /en-us/, /de/, /fr-fr/)
  final langMatch = RegExp(
    r'/([a-z]{2})(?:-[a-z]{2})?/',
    caseSensitive: false,
  ).firstMatch(path.toLowerCase());
  if (langMatch != null) {
    final langCode = langMatch.group(1);
    return languageCurrencyMap[langCode];
  }

  return null;
}
