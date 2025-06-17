import 'package:html/dom.dart';
import 'main.dart'; // For ProductData class

/// Specialized fallback extraction methods for edge cases
/// These methods handle specific website patterns that don't follow standard practices

/// Fallback: Detect currency from URL domain and language codes
String? detectCurrencyFromUrl(Uri baseUri) {
  final host = baseUri.host.toLowerCase();

  // 1. Check country code from domain
  final countryCurrency = getCountryCurrencyFromDomain(host);
  if (countryCurrency != null) return countryCurrency;

  // 2. Check language code from URL path
  final languageCurrency = getLanguageCurrencyFromPath(baseUri.path);
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
String? getCountryCurrencyFromDomain(String host) {
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
String? getLanguageCurrencyFromPath(String path) {
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

/// Fallback: Extract price and currency from microdata (itemprop) meta tags
/// Used by sites that implement schema.org microdata format
void extractMicrodataPrice(Document document, ProductData product) {
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

/// Fallback: Extract price and currency from data-test attributes in HTML elements
/// Used by modern web apps that use test identifiers for automation
void extractDataTestPrice(Document document, ProductData product) {
  // Common data-test keywords for price and currency
  final priceKeywords = [
    'product-price',
    'price',
    'cost',
    'amount',
    'total',
    'sale-price',
    'current-price',
  ];
  final currencyKeywords = ['currency', 'price-currency'];

  // Try to extract price from data-test attributes
  if (product.price == null || product.price!.isEmpty) {
    for (final keyword in priceKeywords) {
      final priceElement = document.querySelector('span[data-test*="$keyword"]');
      if (priceElement != null) {
        final priceText = priceElement.text.trim();
        if (priceText.isNotEmpty) {
          // Extract price numbers, keeping decimal points
          final priceMatch = RegExp(r'[\d,.]+').firstMatch(priceText);
          if (priceMatch != null) {
            final cleanPrice = priceMatch.group(0)?.replaceAll(RegExp(r'[^\d.]'), '');
            if (cleanPrice != null && cleanPrice.isNotEmpty) {
              product.price = cleanPrice;

              // Try to detect currency from the same element
              if (product.priceCurrency == null || product.priceCurrency!.isEmpty) {
                if (priceText.contains('\$')) {
                  product.priceCurrency = 'USD';
                } else if (priceText.contains('€')) {
                  product.priceCurrency = 'EUR';
                } else if (priceText.contains('£')) {
                  product.priceCurrency = 'GBP';
                } else if (priceText.contains('¥')) {
                  product.priceCurrency = 'JPY';
                } else if (priceText.contains('đ') || priceText.contains('VND')) {
                  product.priceCurrency = 'VND';
                }
              }
              break;
            }
          }
        }
      }
    }
  }

  // Try to extract currency from data-test attributes if still missing
  if (product.priceCurrency == null || product.priceCurrency!.isEmpty) {
    for (final keyword in currencyKeywords) {
      final currencyElement = document.querySelector('span[data-test*="$keyword"]');
      if (currencyElement != null) {
        final currencyText = currencyElement.text.trim();
        if (currencyText.isNotEmpty) {
          product.priceCurrency = currencyText;
          break;
        }
      }
    }
  }

  // Also try with other common HTML elements that might have data-test attributes
  if (product.price == null || product.price!.isEmpty) {
    for (final keyword in priceKeywords) {
      final priceElement = document.querySelector('[data-test*="$keyword"]');
      if (priceElement != null) {
        final priceText = priceElement.text.trim();
        if (priceText.isNotEmpty) {
          final priceMatch = RegExp(r'[\d,.]+').firstMatch(priceText);
          if (priceMatch != null) {
            final cleanPrice = priceMatch.group(0)?.replaceAll(RegExp(r'[^\d.]'), '');
            if (cleanPrice != null && cleanPrice.isNotEmpty) {
              product.price = cleanPrice;

              // Try to detect currency from the same element
              if (product.priceCurrency == null || product.priceCurrency!.isEmpty) {
                if (priceText.contains('\$')) {
                  product.priceCurrency = 'USD';
                } else if (priceText.contains('€')) {
                  product.priceCurrency = 'EUR';
                } else if (priceText.contains('£')) {
                  product.priceCurrency = 'GBP';
                } else if (priceText.contains('¥')) {
                  product.priceCurrency = 'JPY';
                } else if (priceText.contains('đ') || priceText.contains('VND')) {
                  product.priceCurrency = 'VND';
                }
              }
              break;
            }
          }
        }
      }
    }
  }
}
