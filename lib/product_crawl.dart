import 'dart:convert';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'fallback_extractors.dart';

// Pre-compiled regex patterns for better performance
class _RegexPatterns {
  static final pricePattern = RegExp(r'[\d,.]+', unicode: true);
  static final currencyPatternVND = RegExp(r'[đ]|VND', caseSensitive: false);
  static final currencyPatternUSD = RegExp(r'[\$]|USD', caseSensitive: false);
  static final currencyPatternEUR = RegExp(r'[€]|EUR', caseSensitive: false);
  static final whitespacePattern = RegExp(r'\s+');
  static final leadingPunctuationPattern = RegExp(r'^[\s]*[\.\,\-][\s]+(?=\w)');
  static final nonNumericPattern = RegExp(r'[^0-9.]');
  static final srcsetPattern = RegExp(r'([^,\s]+)');

  // Shopify patterns
  static final shopifyVariantsPattern = RegExp(r'variants"?\s*:\s*(\[[\s\S]*?\])', multiLine: true);
  static final shopifyPricePattern = RegExp(r'"price":\s*([0-9.]+)', caseSensitive: false);
  static final shopifyCurrencyPattern = RegExp(
    r'"price_currency":\s*"([A-Z]{3})"',
    caseSensitive: false,
  );
}

class ProductData {
  String? name;
  String? description;
  Set<String> _images = <String>{}; // Use Set for automatic deduplication
  String? price;
  String? priceCurrency;
  String? brand;
  final String url;

  ProductData(this.url);

  // Getter for images as List for backward compatibility
  List<String> get images => _images.toList();

  // Setter for images
  set images(List<String> value) => _images = value.toSet();

  // Add images method
  void addImage(String imageUrl) => _images.add(imageUrl);
  void addImages(Iterable<String> imageUrls) => _images.addAll(imageUrls);

  bool get hasImages => _images.isNotEmpty;

  Map<String, dynamic> toJson() {
    final imageList = _images.toList();
    return {
      'name': name,
      'url': url,
      'image': imageList,
      'brand': brand,
      'price': price,
      'priceCurrency': priceCurrency,
      'site': _extractSiteName(url),
      'description': description,
      'gallery': imageList, // Reuse the same list
    };
  }

  String _extractSiteName(String url) {
    try {
      final uri = Uri.parse(url);

      // Get the base components
      final scheme = uri.scheme;
      final host = uri.host;

      if (scheme.isEmpty || host.isEmpty) {
        return '';
      }

      // Build the base URL that's clickable
      var baseUrl = '$scheme://$host';

      // Add port if present
      if (uri.hasPort && uri.port != 80 && uri.port != 443) {
        baseUrl += ':${uri.port}';
      }

      return baseUrl;
    } catch (e) {
      return '';
    }
  }
}

/// Extract brand name from URL (e.g., www.zara.com -> "Zara")
String? _extractBrandFromUrl(String url) {
  try {
    final uri = Uri.parse(url);
    final host = uri.host.toLowerCase();

    if (host.isEmpty) return null;

    // Remove common prefixes
    String domain = host;
    if (domain.startsWith('www.')) {
      domain = domain.substring(4);
    } else if (domain.startsWith('shop.')) {
      domain = domain.substring(5);
    } else if (domain.startsWith('store.')) {
      domain = domain.substring(6);
    } else if (domain.startsWith('m.')) {
      domain = domain.substring(2);
    }

    // Split by dots and get the main domain part
    final parts = domain.split('.');
    if (parts.isEmpty) return null;

    // Get the brand part (usually the first part before TLD)
    String brandName = parts[0];

    // Filter out generic domain names that aren't actual brands
    const genericDomains = {
      'localhost', 'test', 'dev', 'staging', 'demo', 'example', 'sample',
      'shop', 'store', 'ecommerce', 'marketplace', 'mall', 'outlet',
      'amazon', 'ebay', 'etsy', 'aliexpress', 'shopify', // marketplace domains
    };

    if (genericDomains.contains(brandName)) {
      return null;
    }

    // Skip very short names (likely not real brands)
    if (brandName.length < 2) {
      return null;
    }

    // Capitalize first letter and return
    return brandName[0].toUpperCase() + brandName.substring(1);
  } catch (e) {
    return null;
  }
}

/// Hàm chính để phân tích cú pháp HTML và trích xuất thông tin sản phẩm.
///
/// Trả về một Map chứa dữ liệu sản phẩm, hoặc null nếu không tìm thấy
/// các thông tin cần thiết (tên và hình ảnh).
Future<Map<String, dynamic>?> parseProduct(String htmlContent, String url) async {
  final product = ProductData(url);
  final baseUri = Uri.parse(url);

  // --- Lớp 0: Lối tắt Shopify (with smarter detection) ---
  if (_isLikelyShopifyPage(htmlContent, url)) {
    final shopifyData = await _extractShopifyData(htmlContent, url);
    if (shopifyData != null) {
      return shopifyData;
    }
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
  if (product.brand == null || product.brand!.isEmpty) {
    product.brand = _extractHeuristicBrand(document);
    // Fallback: extract brand from URL if still not found
    if (product.brand == null || product.brand!.isEmpty) {
      product.brand = _extractBrandFromUrl(url);
    }
  }
  if (product.price == null || product.price!.isEmpty) {
    _extractHeuristicPrice(document, product);
  }
  if (!product.hasImages) {
    product.addImages(_extractHeuristicImages(document, baseUri, product.name ?? ''));
  }

  // Cố gắng tìm dữ liệu trong các script nhúng nếu vẫn thiếu
  if (product.name == null || product.price == null || !product.hasImages) {
    _extractEmbeddedJson(document, product, baseUri);
  }

  // --- Lớp bổ sung: Fallback methods for edge cases ---
  // if (product.price == null ||
  //     product.price!.isEmpty ||
  //     product.priceCurrency == null ||
  //     product.priceCurrency!.isEmpty) {
  //   extractMicrodataPrice(document, product);
  //   extractDataTestPrice(document, product);
  // }

  // --- Hoàn thiện và xác thực ---
  _finalizeData(product, baseUri);

  // Yêu cầu phải có tên và ít nhất một hình ảnh
  if (product.name != null && product.name!.isNotEmpty && product.hasImages) {
    return product.toJson();
  }

  return null;
}

/// Check if we have essential data (used for optimization, not validation)
bool _hasCompleteData(ProductData product) {
  return product.name != null &&
      product.name!.isNotEmpty &&
      product.price != null &&
      product.price!.isNotEmpty &&
      product.priceCurrency != null &&
      product.priceCurrency!.isNotEmpty &&
      product.hasImages;
}

/// Smart Shopify detection to avoid unnecessary network calls
bool _isLikelyShopifyPage(String htmlContent, String url) {
  final uri = Uri.parse(url);
  return uri.path.contains('/products/') &&
      (htmlContent.contains('window.Shopify') ||
          htmlContent.contains('shopify-checkout') ||
          htmlContent.contains('"@type":"Product"') ||
          htmlContent.toLowerCase().contains('shopify'));
}

/// Lớp 0: Cố gắng trích xuất dữ liệu từ điểm cuối.json của Shopify.
Future<Map<String, dynamic>?> _extractShopifyData(String htmlContent, String url) async {
  try {
    final uri = Uri.parse(url);
    final jsonUrl = Uri.parse('${uri.scheme}://${uri.host}${uri.path}.json');

    // Add timeout and proper headers for better performance
    final response = await http
        .get(jsonUrl, headers: {'User-Agent': 'Mozilla/5.0 (compatible; ProductParser/1.0)'})
        .timeout(const Duration(seconds: 5));

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

        final images =
            (productJson['images'] as List?)?.map<String>((img) => img['src'] as String).toList() ??
            <String>[];

        return {
          'name': productJson['title'],
          'url': url,
          'image': images,
          'brand': productJson['vendor'] as String?,
          'price': price ?? productJson['variants']?.toString(),
          'priceCurrency': currency,
          'site': Uri.parse(url).origin,
          'description': productJson['body_html'],
          'gallery': images,
        };
      }
    }
  } catch (e) {
    // Bỏ qua lỗi và tiếp tục với các phương pháp khác
  }
  return null;
}

/// Lớp 1: Trích xuất dữ liệu từ các thẻ script JSON-LD.
void _extractJsonLd(Document document, ProductData product, Uri baseUri) {
  final scripts = document.querySelectorAll('script[type="application/ld+json"]');
  for (final script in scripts) {
    final text = script.text.trim();
    if (text.isEmpty) continue;

    try {
      final jsonContent = jsonDecode(text);
      _parseJsonLdObject(jsonContent, product);

      // Continue processing - don't skip fallback methods
    } catch (e) {
      // Bỏ qua JSON không hợp lệ
    }
  }
}

/// Hàm đệ quy để phân tích các đối tượng JSON-LD.
void _parseJsonLdObject(dynamic jsonObj, ProductData product) {
  if (jsonObj is! Map) {
    if (jsonObj is List) {
      // Tìm kiếm đệ quy trong các phần tử của list
      for (final item in jsonObj) {
        _parseJsonLdObject(item, product);
      }
    }
    return;
  }

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

    // Extract brand information
    if (product.brand == null && jsonObj.containsKey('brand')) {
      final brand = jsonObj['brand'];
      if (brand is String) {
        product.brand = brand;
      } else if (brand is Map) {
        product.brand = brand['name'] as String? ?? brand['@name'] as String?;
      }
    }

    // Trích xuất giá từ offers
    if ((product.price == null || product.priceCurrency == null) && jsonObj.containsKey('offers')) {
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
    if (!product.hasImages && jsonObj.containsKey('image')) {
      final imageField = jsonObj['image'];
      if (imageField is String) {
        product.addImage(imageField);
      } else if (imageField is List) {
        for (final item in imageField) {
          if (item is String) {
            product.addImage(item);
          } else if (item is Map && item.containsKey('url') && item['url'] is String) {
            product.addImage(item['url']);
          }
        }
      }
    }
  }

  // Tìm kiếm đệ quy trong các giá trị của map
  for (final value in jsonObj.values) {
    _parseJsonLdObject(value, product);
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

  // Extract brand from meta tags
  product.brand ??=
      getMetaContent('og:brand') ??
      getMetaContent('product:brand') ??
      getMetaContent('twitter:data1') ?? // Sometimes brand is in twitter:data1
      getMetaContent('brand');

  // Extract price from product meta tags (critical for many e-commerce sites)
  if (product.price == null || product.price!.isEmpty) {
    final productPrice =
        getMetaContent('product:price:amount') ?? getMetaContent('wanelo:product:price');
    if (productPrice != null && productPrice.isNotEmpty) {
      // Clean price: remove non-numeric characters except dots and commas
      product.price = productPrice.replaceAll(RegExp(r'[^\d.,]'), '').replaceAll(',', '.');
    }
  }

  // Extract currency from product meta tags
  if (product.priceCurrency == null || product.priceCurrency!.isEmpty) {
    final productCurrency =
        getMetaContent('product:price:currency') ?? getMetaContent('wanelo:product:price:currency');
    if (productCurrency != null && productCurrency.isNotEmpty) {
      product.priceCurrency = productCurrency.toUpperCase();
    }
  }

  final ogImage = getMetaContent('og:image');
  if (ogImage != null) product.addImage(ogImage);

  final twitterImage = getMetaContent('twitter:image');
  if (twitterImage != null) product.addImage(twitterImage);
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

/// Lớp 2: Suy nghiệm thương hiệu sản phẩm.
String? _extractHeuristicBrand(Document document) {
  // Try various selectors for brand information
  final brandSelectors = [
    '[class*="brand"]',
    '[id*="brand"]',
    '[data-brand]',
    '.product-brand',
    '.brand-name',
    '[class*="manufacturer"]',
    '[id*="manufacturer"]',
    '[itemprop="brand"]',
    '[class*="vendor"]',
    '[id*="vendor"]',
  ];

  for (final selector in brandSelectors) {
    final element = document.querySelector(selector);
    if (element != null) {
      var brandText = element.text.trim();
      // Get data-brand attribute if available
      brandText = element.attributes['data-brand'] ?? brandText;

      if (brandText.isNotEmpty && brandText.length < 100) {
        // Reasonable brand name length
        return brandText;
      }
    }
  }

  // Try to extract from breadcrumbs (often contains brand)
  final breadcrumbs = document.querySelectorAll(
    '[class*="breadcrumb"] a, [class*="breadcrumb"] span',
  );
  if (breadcrumbs.length >= 2) {
    // Often the second item in breadcrumbs is the brand
    final potentialBrand = breadcrumbs[1].text.trim();
    if (potentialBrand.isNotEmpty && potentialBrand.length < 50) {
      return potentialBrand;
    }
  }

  // Try to extract from product title patterns like "Brand - Product Name"
  final titleElement = document.querySelector('title');
  if (titleElement != null) {
    final title = titleElement.text;
    final dashMatch = RegExp(r'^([^-\|]+)[-\|]').firstMatch(title);
    if (dashMatch != null) {
      final potentialBrand = dashMatch.group(1)?.trim();
      if (potentialBrand != null &&
          potentialBrand.length < 50 &&
          potentialBrand.split(' ').length <= 3) {
        return potentialBrand;
      }
    }
  }

  return null;
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
      if (priceText.length > 100) continue; // Skip overly long text

      final priceMatch = _RegexPatterns.pricePattern.firstMatch(priceText);
      if (priceMatch != null) {
        product.price = priceMatch.group(0)?.replaceAll(',', '');

        // Fast currency detection using pre-compiled patterns
        if (_RegexPatterns.currencyPatternVND.hasMatch(priceText)) {
          product.priceCurrency = 'VND';
        } else if (_RegexPatterns.currencyPatternUSD.hasMatch(priceText)) {
          product.priceCurrency = 'USD';
        } else if (_RegexPatterns.currencyPatternEUR.hasMatch(priceText)) {
          product.priceCurrency = 'EUR';
        }
        return; // Early return when price found
      }
    }
  }
}

/// Lớp 2: Trích xuất hình ảnh bằng phương pháp suy nghiệm.
List<String> _extractHeuristicImages(Document document, Uri baseUri, String productName) {
  final images = <String>{}; // Use Set for automatic deduplication

  // First try to find product-specific containers to reduce scope
  final productContainers = document.querySelectorAll(
    [
      '.product',
      '[class*="gallery"]',
      '[id*="product"]',
      '[class*="product"]',
      '.main-content',
      '#main',
    ].join(', '),
  );

  // If we found product containers, search within them first
  if (productContainers.isNotEmpty) {
    for (final container in productContainers) {
      _extractImagesFromContainer(container, images, baseUri);
      if (images.length >= 10) break; // Limit to reasonable number
    }
  }

  // If we still don't have enough images, search the whole document
  if (images.length < 3) {
    _extractImagesFromContainer(document, images, baseUri);
  }

  return _filterAndRankImages(images.toList(), productName, baseUri);
}

/// Helper method to extract images from a container element or document
void _extractImagesFromContainer(dynamic container, Set<String> images, Uri baseUri) {
  final imageElements = container.querySelectorAll('img');
  const imageAttributePriority = ['data-srcset', 'data-src', 'srcset', 'src'];
  const unwantedKeywords = [
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
  ];

  for (final img in imageElements) {
    // Skip small images early (likely icons/logos)
    final width = int.tryParse(img.attributes['width'] ?? '');
    final height = int.tryParse(img.attributes['height'] ?? '');
    if ((width != null && width < 100) || (height != null && height < 100)) continue;

    for (final attr in imageAttributePriority) {
      final src = img.attributes[attr];
      if (src != null && src.isNotEmpty) {
        // Quick filter for unwanted images
        final srcLower = src.toLowerCase();
        if (unwantedKeywords.any((kw) => srcLower.contains(kw))) continue;

        // Handle srcset or regular src
        final urlToAdd = attr.contains('srcset') ? _parseSrcset(src) : src;
        final resolvedUrl = _resolveUrl(urlToAdd, baseUri);

        if (resolvedUrl.isNotEmpty) {
          images.add(resolvedUrl);
          if (images.length >= 10) return; // Early return when we have enough
        }
        break; // Found valid source for this img, move to next
      }
    }
  }
}

/// Lớp 3: Cố gắng trích xuất dữ liệu từ JSON nhúng trong các thẻ script.
void _extractEmbeddedJson(Document document, ProductData product, Uri baseUri) {
  final scripts = document.querySelectorAll('script:not([src])'); // Only inline scripts
  final processedTexts = <String>{}; // Avoid processing same script multiple times

  for (final script in scripts) {
    final text = script.text.trim();
    if (text.isEmpty || text.length < 50) continue; // Skip very short scripts
    if (processedTexts.contains(text)) continue; // Skip already processed

    processedTexts.add(text);

    // Only process scripts that likely contain product data
    if (!text.contains('product') && !text.contains('variants') && !text.contains('price')) {
      continue;
    }

    // Tìm kiếm Shopify product data specifically
    if (text.contains('variants')) {
      _extractShopifyScriptData(text, product);
    }

    // Tìm kiếm JSON objects khác (with size limit for regex)
    if (text.length < 50000 && (text.contains('product') || text.contains('price'))) {
      // Simplified JSON extraction - look for complete objects
      final jsonMatches = _findJsonObjects(text);

      for (final jsonString in jsonMatches) {
        try {
          final decodedJson = jsonDecode(jsonString);
          _parseJsonLdObject(decodedJson, product);
        } catch (e) {
          // Bỏ qua lỗi phân tích
        }
      }
    }
  }
}

/// Find JSON objects in script text using a more efficient approach
List<String> _findJsonObjects(String text) {
  final jsonObjects = <String>[];
  int braceCount = 0;
  int startIndex = -1;

  for (int i = 0; i < text.length; i++) {
    final char = text[i];

    if (char == '{') {
      if (braceCount == 0) startIndex = i;
      braceCount++;
    } else if (char == '}') {
      braceCount--;
      if (braceCount == 0 && startIndex != -1) {
        final jsonCandidate = text.substring(startIndex, i + 1);
        if (jsonCandidate.length > 50 && jsonCandidate.length < 10000) {
          jsonObjects.add(jsonCandidate);
        }
        startIndex = -1;
      }
    }

    // Safety check to avoid infinite loops
    if (jsonObjects.length >= 10) break;
  }

  return jsonObjects;
}

/// Trích xuất dữ liệu Shopify từ script tags
void _extractShopifyScriptData(String scriptText, ProductData product) {
  // Use pre-compiled pattern for better performance
  final match = _RegexPatterns.shopifyVariantsPattern.firstMatch(scriptText);
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
    } catch (e) {
      // Continue to next pattern
    }
  }

  // Look for other Shopify patterns with size limits
  if (scriptText.length < 20000) {
    final priceMatch = _RegexPatterns.shopifyPricePattern.firstMatch(scriptText);
    if (priceMatch != null && product.price == null) {
      product.price = priceMatch.group(1);
    }

    final currencyMatch = _RegexPatterns.shopifyCurrencyPattern.firstMatch(scriptText);
    if (currencyMatch != null && product.priceCurrency == null) {
      product.priceCurrency = currencyMatch.group(1);
    }
  }
}

/// Parse Shopify specific product data
void _parseShopifyProductData(Map<String, dynamic> productData, ProductData product) {
  // Extract basic info
  product.name ??= productData['title'] as String?;
  product.brand ??= productData['vendor'] as String?; // Shopify brand field

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
          product.addImage(img);
        } else if (img is Map && img.containsKey('src')) {
          product.addImage(img['src'] as String);
        }
      }
    }
  }
}

/// Phân tích srcset để lấy URL tốt nhất.
String _parseSrcset(String srcset) {
  // Use pre-compiled regex for better performance
  final match = _RegexPatterns.srcsetPattern.firstMatch(srcset);
  return match?.group(1) ?? srcset.split(',').first.trim().split(' ').first;
}

/// Lọc và xếp hạng hình ảnh để chọn ra những ảnh phù hợp nhất.
List<String> _filterAndRankImages(List<String> imageUrls, String productName, Uri baseUri) {
  if (imageUrls.isEmpty) return imageUrls;

  const unwantedKeywords = [
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
      .split(_RegexPatterns.whitespacePattern) // Use pre-compiled pattern
      .where((s) => s.length > 2)
      .toList();

  // Filter and resolve URLs
  final filteredImages = <String>[];
  for (final url in imageUrls) {
    final resolvedUrl = _resolveUrl(url, baseUri);
    if (resolvedUrl.isNotEmpty &&
        !unwantedKeywords.any((kw) => resolvedUrl.toLowerCase().contains(kw))) {
      filteredImages.add(resolvedUrl);
    }
  }

  // Simple ranking: prefer images with product keywords in URL
  if (productKeywords.isNotEmpty) {
    filteredImages.sort((a, b) {
      final scoreA = productKeywords.where((kw) => a.toLowerCase().contains(kw)).length;
      final scoreB = productKeywords.where((kw) => b.toLowerCase().contains(kw)).length;
      return scoreB.compareTo(scoreA); // Sắp xếp giảm dần
    });
  }

  return filteredImages;
}

/// Chuyển đổi URL tương đối thành URL tuyệt đối.
String _resolveUrl(String relativeUrl, Uri baseUri) {
  if (relativeUrl.isEmpty) return '';
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
  // Combined string operations for better performance
  if (product.name != null) {
    product.name = product.name!.replaceAll(_RegexPatterns.whitespacePattern, ' ').trim();
  }

  if (product.description != null) {
    product.description = product.description!
        .replaceAll(_RegexPatterns.whitespacePattern, ' ')
        .replaceAll(_RegexPatterns.leadingPunctuationPattern, '')
        .trim();
  }

  // Handle price currency extraction BEFORE cleaning price
  if (product.price != null &&
      product.price!.contains('price_currency') &&
      product.priceCurrency == null) {
    final currencyMatch = _RegexPatterns.shopifyCurrencyPattern.firstMatch(product.price!);
    if (currencyMatch != null) {
      product.priceCurrency = currencyMatch.group(1);

      // Extract clean price from the JSON
      final priceMatch = _RegexPatterns.shopifyPricePattern.firstMatch(product.price!);
      if (priceMatch != null) {
        product.price = priceMatch.group(1);
      }
    }
  }

  // Clean price (AFTER currency extraction)
  if (product.price != null) {
    product.price = product.price!.replaceAll(_RegexPatterns.nonNumericPattern, '');
  }

  // Fallback currency detection nếu priceCurrency vẫn null
  if (product.price != null && product.price!.isNotEmpty && product.priceCurrency == null) {
    product.priceCurrency = detectCurrencyFromUrl(baseUri);
  }
}
