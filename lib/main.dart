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

class TestResult {
  final String fileName;
  final String url;
  final Map<String, dynamic>? result;
  final bool success;
  final Duration parseTime;
  final String? error;

  TestResult({
    required this.fileName,
    required this.url,
    required this.result,
    required this.success,
    required this.parseTime,
    this.error,
  });
}

class _ProductParserScreenState extends State<ProductParserScreen> {
  List<TestResult> _testResults = [];
  bool _isRunning = false;
  int _currentTestIndex = 0;
  int _totalTests = 0;
  String _status = 'Ready to test';

  Future<List<String>> _getAssetFileNames() async {
    // Generate list of test files 1.txt through 40.txt
    final fileNames = <String>[];
    for (int i = 1; i <= 40; i++) {
      fileNames.add('$i.txt');
    }
    return fileNames;
  }

  Future<void> _runAllTests() async {
    setState(() {
      _isRunning = true;
      _testResults.clear();
      _currentTestIndex = 0;
      _status = 'Loading test files...';
    });

    try {
      // Get all test files from assets
      final fileNames = await _getAssetFileNames();

      setState(() {
        _totalTests = fileNames.length;
        _status = 'Running tests...';
      });

      // Run tests for each file
      for (int i = 0; i < fileNames.length; i++) {
        setState(() {
          _currentTestIndex = i + 1;
        });

        final fileName = fileNames[i];

        try {
          final content = await rootBundle.loadString('assets/$fileName');
          final lines = content.split('\n');
          final url = lines[0].trim();
          final html = lines.skip(1).join('\n');

          final stopwatch = Stopwatch()..start();
          final result = await parseProduct(html, url);
          stopwatch.stop();

          final success =
              result != null &&
              result['name'] != null &&
              result['description'] != null &&
              result['price'] != null &&
              result['priceCurrency'] != null &&
              result['image'] != null &&
              (result['image'] as List).isNotEmpty;

          _testResults.add(
            TestResult(
              fileName: fileName,
              url: url,
              result: result,
              success: success,
              parseTime: stopwatch.elapsed,
            ),
          );
        } catch (e) {
          _testResults.add(
            TestResult(
              fileName: fileName,
              url: 'Error loading file',
              result: null,
              success: false,
              parseTime: Duration.zero,
              error: e.toString(),
            ),
          );
        }

        // Update UI after each test
        setState(() {});

        // Small delay to show progress
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final successCount = _testResults.where((r) => r.success).length;
      final successRate = (successCount / _testResults.length * 100).toStringAsFixed(1);

      setState(() {
        _status = 'Completed: $successCount/${_testResults.length} ($successRate%) successful';
        _isRunning = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isRunning = false;
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
          children: [
            // Big Test Button
            Container(
              width: double.infinity,
              height: 120,
              margin: const EdgeInsets.only(bottom: 20),
              child: ElevatedButton(
                onPressed: _isRunning ? null : _runAllTests,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRunning ? Colors.grey : Colors.blue,
                  foregroundColor: Colors.white,
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isRunning) ...[
                      const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                      const SizedBox(height: 12),
                      Text(
                        'Testing $_currentTestIndex/$_totalTests',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ] else ...[
                      const Icon(Icons.play_arrow, size: 48),
                      const SizedBox(height: 8),
                      const Text(
                        'RUN ALL TESTS',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _isRunning ? Icons.hourglass_empty : Icons.info,
                      color: _isRunning ? Colors.orange : Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _status,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Results List
            if (_testResults.isNotEmpty) ...[
              Text(
                'Test Results (${_testResults.where((r) => r.success).length}/${_testResults.length} passed)',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _testResults.length,
                itemBuilder: (context, index) {
                  return _buildResultCard(_testResults[index]);
                },
              ),
            ] else if (!_isRunning) ...[
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.touch_app, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Tap the button above to run all tests',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This will test all files in the assets folder',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(TestResult testResult) {
    final result = testResult.result;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: testResult.success ? Colors.green[50] : Colors.red[50],
      child: ExpansionTile(
        leading: Icon(
          testResult.success ? Icons.check_circle : Icons.error,
          color: testResult.success ? Colors.green[700] : Colors.red[700],
        ),
        title: Text(
          testResult.fileName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: testResult.success ? Colors.green[700] : Colors.red[700],
          ),
        ),
        subtitle: Text(
          testResult.success
              ? 'Parse time: ${testResult.parseTime.inMilliseconds}ms'
              : testResult.error ?? 'Failed to parse',
          style: TextStyle(
            fontSize: 12,
            color: testResult.success ? Colors.green[600] : Colors.red[600],
          ),
        ),
        children: [
          if (result != null) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('🏷️ Name', result['name']),
                  _buildDetailRow('🏢 Brand', result['brand']),
                  _buildDetailRow('🌐 Site', result['site']),
                  _buildDetailRow(
                    '💰 Price',
                    result['price'] != null && result['priceCurrency'] != null
                        ? '${result['price']} ${result['priceCurrency']}'
                        : result['price'] ?? 'Not found',
                  ),
                  _buildDetailRow('📝 Description', result['description'], maxLength: 100),

                  // Images section
                  if (result['image'] != null && (result['image'] as List).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '🖼️ Images (${(result['image'] as List).length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: (result['image'] as List).length,
                        itemBuilder: (context, imgIndex) {
                          final imageUrl = (result['image'] as List)[imgIndex].toString();
                          return Container(
                            width: 80,
                            margin: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.broken_image, size: 20),
                                  );
                                },
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: Colors.grey[100],
                                    child: const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ] else
                    _buildDetailRow('🖼️ Images', 'No images found'),

                  const SizedBox(height: 8),
                  Text(
                    '🔗 URL: ${testResult.url}',
                    style: TextStyle(fontSize: 11, color: Colors.blue[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value, {int? maxLength}) {
    String displayValue = value ?? 'Not found';
    if (maxLength != null && displayValue.length > maxLength) {
      displayValue = '${displayValue.substring(0, maxLength)}...';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: TextStyle(
                fontSize: 12,
                color: value != null ? Colors.black87 : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
