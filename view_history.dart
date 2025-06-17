import 'dart:io';
import 'dart:convert';

/// Simple script to view test history and performance trends
void main() async {
  const historyFile = 'test_history.json';

  if (!File(historyFile).existsSync()) {
    print('❌ No history file found. Run tests first to generate history.');
    return;
  }

  try {
    final content = await File(historyFile).readAsString();
    final history = jsonDecode(content) as List<dynamic>;

    if (history.isEmpty) {
      print('📭 No test history available.');
      return;
    }

    print('=' * 70);
    print('  📊 TEST HISTORY VIEWER');
    print('=' * 70);
    print('📈 Total test runs: ${history.length}');
    print('');

    // Show last 5 runs summary
    print('🕒 Recent Test Runs (Last 5):');
    print('-' * 70);
    final recentRuns = history.reversed.take(5).toList();

    for (int i = 0; i < recentRuns.length; i++) {
      final run = recentRuns[i] as Map<String, dynamic>;
      final summary = run['summary'] as Map<String, dynamic>;
      final timestamp = DateTime.parse(run['timestamp'] as String);

      String timeAgo = _formatTimeAgo(DateTime.now().difference(timestamp));

      print('${i + 1}. ${run['date']} ${run['time']} ($timeAgo)');
      print(
        '   ✅ Success: ${summary['successCount']}/${summary['totalFiles']} (${summary['successRate']}%)',
      );
      print(
        '   ⏱️  Speed: avg ${summary['avgParseTime']}ms, median ${summary['medianParseTime']}ms',
      );
      print(
        '   🏷️  Brands: ${summary['uniqueBrands']}, 🖼️  Images: ${summary['medianImageCount']}',
      );
      print('');
    }

    // Performance trends
    print('📈 Performance Trends:');
    print('-' * 70);

    final avgTimes = history.map((r) => (r['summary'] as Map)['avgParseTime'] as double).toList();
    final successRates = history
        .map((r) => (r['summary'] as Map)['successRate'] as double)
        .toList();

    // Calculate trends
    if (avgTimes.length >= 2) {
      final avgTimeChange = ((avgTimes.last - avgTimes.first) / avgTimes.first * 100);
      final successRateChange = successRates.last - successRates.first;

      print('🚀 Average parse time trend: ${_formatTrend(avgTimeChange, true)}');
      print('📊 Success rate trend: ${_formatTrend(successRateChange, false)}');
      print('');
    }

    // Best and worst performances
    print('🏆 Performance Records:');
    print('-' * 70);

    final bestAvgTime = avgTimes.reduce((a, b) => a < b ? a : b);
    final worstAvgTime = avgTimes.reduce((a, b) => a > b ? a : b);
    final bestSuccessRate = successRates.reduce((a, b) => a > b ? a : b);
    final worstSuccessRate = successRates.reduce((a, b) => a < b ? a : b);

    print('⚡ Best average time: ${bestAvgTime.toStringAsFixed(2)}ms');
    print('🐌 Worst average time: ${worstAvgTime.toStringAsFixed(2)}ms');
    print('🎯 Best success rate: ${bestSuccessRate.toStringAsFixed(1)}%');
    print('📉 Worst success rate: ${worstSuccessRate.toStringAsFixed(1)}%');
    print('');

    // Summary insights
    print('📊 Historical Summary:');
    print('-' * 70);

    if (history.length >= 10) {
      print('🎯 Sufficient history for meaningful trends (${history.length} runs)');
    } else if (history.length >= 5) {
      print('📈 Building good trend data (${history.length} runs)');
    } else {
      print('🌱 Early stage tracking (${history.length} runs)');
    }

    final avgSuccessRate = successRates.reduce((a, b) => a + b) / successRates.length;
    final avgAvgTime = avgTimes.reduce((a, b) => a + b) / avgTimes.length;

    print('🎯 Overall average success rate: ${avgSuccessRate.toStringAsFixed(1)}%');
    print('⚡ Overall average parse time: ${avgAvgTime.toStringAsFixed(2)}ms');

    print('');
    print('=' * 70);
  } catch (e) {
    print('❌ Error reading history file: $e');
  }
}

String _formatTimeAgo(Duration diff) {
  if (diff.inDays > 0) return '${diff.inDays}d ago';
  if (diff.inHours > 0) return '${diff.inHours}h ago';
  if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
  return 'just now';
}

String _formatTrend(double change, bool isTime) {
  if (isTime) {
    // For time, lower is better
    if (change < -5) return '🚀 ${(-change).toStringAsFixed(1)}% faster overall';
    if (change > 5) return '🐌 ${change.toStringAsFixed(1)}% slower overall';
    return '≈ Stable performance';
  } else {
    // For success rate, higher is better
    if (change > 2) return '📈 +${change.toStringAsFixed(1)}% better overall';
    if (change < -2) return '📉 ${change.toStringAsFixed(1)}% worse overall';
    return '≈ Stable success rate';
  }
}
