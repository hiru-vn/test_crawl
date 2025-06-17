import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'product_crawl.dart';

void main() {
  runApp(const ProductParserApp());
}

class ProductParserApp extends StatelessWidget {
  const ProductParserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Product Parser Tester',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const ProductParserScreen(),
    );
  }
}

class ProductParserScreen extends StatefulWidget {
  const ProductParserScreen({super.key});

  @override
  State<ProductParserScreen> createState() => _ProductParserScreenState();
}

class _ProductParserScreenState extends State<ProductParserScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _htmlController = TextEditingController();
  Map<String, dynamic>? _parseResult;
  bool _isLoading = false;
  String? _errorMessage;
  List<String> _testFiles = [];
  String? _selectedTestFile;

  @override
  void initState() {
    super.initState();
    _loadTestFiles();
  }

  Future<void> _loadTestFiles() async {
    try {
      final assetsDir = Directory('assets');
      if (await assetsDir.exists()) {
        final files = await assetsDir
            .list()
            .where((entity) => entity is File && entity.path.endsWith('.txt'))
            .cast<File>()
            .toList();

        // Sort files numerically
        files.sort((a, b) {
          final fileNameA = a.path.split('\\').last;
          final fileNameB = b.path.split('\\').last;

          final numA = int.tryParse(fileNameA.replaceAll('.txt', '')) ?? 0;
          final numB = int.tryParse(fileNameB.replaceAll('.txt', '')) ?? 0;

          return numA.compareTo(numB);
        });

        setState(() {
          _testFiles = files.map((f) => f.path.split('\\').last).toList();
        });
      }
    } catch (e) {
      print('Error loading test files: $e');
    }
  }

  Future<void> _loadTestFile(String fileName) async {
    try {
      final file = File('assets/$fileName');
      if (await file.exists()) {
        final content = await file.readAsString();
        final lines = content.split('\n');
        final url = lines[0].trim();
        final html = lines.skip(1).join('\n');

        setState(() {
          _urlController.text = url;
          _htmlController.text = html;
          _selectedTestFile = fileName;
          _parseResult = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading file: $e';
      });
    }
  }

  Future<void> _parseProduct() async {
    if (_urlController.text.trim().isEmpty || _htmlController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both URL and HTML content';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _parseResult = null;
    });

    try {
      final result = await parseProduct(_htmlController.text, _urlController.text);
      setState(() {
        _parseResult = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Parsing error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🛒 Product Parser Tester'),
        backgroundColor: Colors.blue[100],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Test File Selector
            if (_testFiles.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📁 Load Test File',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedTestFile,
                        hint: const Text('Select a test file'),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: _testFiles.map((file) {
                          return DropdownMenuItem(value: file, child: Text(file));
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            _loadTestFile(value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // URL Input
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🔗 Product URL',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        hintText: 'https://example.com/product',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // HTML Input
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📄 HTML Content',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _htmlController,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        hintText: 'Paste HTML content here...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Parse Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _parseProduct,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_isLoading ? 'Parsing...' : 'Parse Product'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Error Message
            if (_errorMessage != null)
              Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMessage!, style: TextStyle(color: Colors.red[700])),
                      ),
                    ],
                  ),
                ),
              ),

            // Results
            if (_parseResult != null) _buildResultsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsCard() {
    if (_parseResult == null) return const SizedBox.shrink();

    final result = _parseResult!;
    final hasAllFields =
        result['name'] != null &&
        result['description'] != null &&
        result['price'] != null &&
        result['priceCurrency'] != null &&
        result['images'] != null &&
        (result['images'] as List).isNotEmpty;

    return Card(
      color: hasAllFields ? Colors.green[50] : Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasAllFields ? Icons.check_circle : Icons.warning,
                  color: hasAllFields ? Colors.green[700] : Colors.orange[700],
                ),
                const SizedBox(width: 8),
                Text(
                  hasAllFields ? '✅ Parse Successful' : '⚠️ Parse Incomplete',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: hasAllFields ? Colors.green[700] : Colors.orange[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Product Name
            _buildFieldCard('🏷️ Name', result['name']),
            const SizedBox(height: 8),

            // Price
            _buildFieldCard(
              '💰 Price',
              result['price'] != null && result['priceCurrency'] != null
                  ? '${result['price']} ${result['priceCurrency']}'
                  : result['price'] ?? 'Not found',
            ),
            const SizedBox(height: 8),

            // Description
            _buildFieldCard('📝 Description', result['description'], maxLines: 3),
            const SizedBox(height: 8),

            // Images
            if (result['images'] != null && (result['images'] as List).isNotEmpty)
              _buildImagesCard(result['images'] as List<dynamic>)
            else
              _buildFieldCard('🖼️ Images', 'No images found'),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldCard(String label, String? value, {int maxLines = 1}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            value ?? 'Not found',
            style: TextStyle(
              color: value != null ? Colors.black87 : Colors.grey[600],
              fontSize: 13,
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildImagesCard(List<dynamic> images) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🖼️ Images (${images.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              itemBuilder: (context, index) {
                final imageUrl = images[index].toString();
                return Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 8),
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image, color: Colors.grey),
                                    Text('Failed to load', style: TextStyle(fontSize: 10)),
                                  ],
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey[100],
                                child: const Center(child: CircularProgressIndicator()),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Image ${index + 1}',
                        style: const TextStyle(fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Show first few URLs as text
          ...images
              .take(3)
              .map(
                (url) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    url.toString(),
                    style: TextStyle(fontSize: 11, color: Colors.blue[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          if (images.length > 3)
            Text(
              '... and ${images.length - 3} more images',
              style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _htmlController.dispose();
    super.dispose();
  }
}
