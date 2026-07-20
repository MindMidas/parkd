import 'dart:io';

void main(List<String> arguments) {
  final lcovPath = arguments.isEmpty ? 'coverage/lcov.info' : arguments[0];
  final minimumLinePercent = arguments.length > 1
      ? double.parse(arguments[1])
      : 1.0;
  final minimumFilePercent = arguments.length > 2
      ? double.parse(arguments[2])
      : 5.0;

  final lcov = File(lcovPath);
  if (!lcov.existsSync()) {
    stderr.writeln('Coverage file not found: $lcovPath');
    exitCode = 2;
    return;
  }

  final root = Directory.current.absolute.path;
  final lib = Directory('$root/lib');
  final sourceFiles = lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .where((file) => !_isGenerated(file.path))
      .map((file) => _normalize(file.absolute.path))
      .toSet();

  final records = _parseLcov(lcov.readAsLinesSync(), root);
  var hitLines = 0;
  var totalLines = 0;
  var representedFiles = 0;

  for (final path in sourceFiles) {
    final record = records[path];
    if (record != null && record.found > 0) {
      representedFiles++;
      hitLines += record.hit;
      totalLines += record.found;
    } else {
      // LCOV omits libraries that no test imports. Counting their likely
      // executable lines prevents a high percentage from a tiny loaded subset.
      totalLines += _estimatedTestableLines(File(path));
    }
  }

  final linePercent = totalLines == 0 ? 0 : hitLines * 100 / totalLines;
  final filePercent = sourceFiles.isEmpty
      ? 0
      : representedFiles * 100 / sourceFiles.length;

  stdout.writeln(
    'Global source coverage: ${linePercent.toStringAsFixed(2)}% '
    '($hitLines/$totalLines lines)',
  );
  stdout.writeln(
    'Source-file breadth: ${filePercent.toStringAsFixed(2)}% '
    '($representedFiles/${sourceFiles.length} files represented in LCOV)',
  );
  stdout.writeln(
    'Required minimums: ${minimumLinePercent.toStringAsFixed(2)}% lines, '
    '${minimumFilePercent.toStringAsFixed(2)}% files',
  );

  if (linePercent < minimumLinePercent || filePercent < minimumFilePercent) {
    stderr.writeln(
      'Coverage gate failed. Add tests before raising or preserving this ratchet.',
    );
    exitCode = 1;
  }
}

bool _isGenerated(String path) {
  return path.endsWith('.g.dart') ||
      path.endsWith('.freezed.dart') ||
      path.endsWith('.mocks.dart');
}

String _normalize(String path) =>
    File(path).absolute.path.replaceAll('\\', '/');

Map<String, _CoverageRecord> _parseLcov(List<String> lines, String root) {
  final records = <String, _CoverageRecord>{};
  String? current;
  var hit = 0;
  var found = 0;

  void save() {
    if (current == null) return;
    records[current!] = _CoverageRecord(hit: hit, found: found);
  }

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      save();
      final raw = line.substring(3);
      current = _normalize(raw.startsWith('/') ? raw : '$root/$raw');
      hit = 0;
      found = 0;
    } else if (line.startsWith('LH:')) {
      hit = int.tryParse(line.substring(3)) ?? hit;
    } else if (line.startsWith('LF:')) {
      found = int.tryParse(line.substring(3)) ?? found;
    } else if (line == 'end_of_record') {
      save();
      current = null;
      hit = 0;
      found = 0;
    }
  }
  save();
  return records;
}

int _estimatedTestableLines(File file) {
  var inBlockComment = false;
  var count = 0;
  for (final rawLine in file.readAsLinesSync()) {
    var line = rawLine.trim();
    if (inBlockComment) {
      final end = line.indexOf('*/');
      if (end < 0) continue;
      inBlockComment = false;
      line = line.substring(end + 2).trim();
    }
    if (line.startsWith('/*')) {
      final end = line.indexOf('*/', 2);
      if (end < 0) {
        inBlockComment = true;
        continue;
      }
      line = line.substring(end + 2).trim();
    }
    if (line.isEmpty ||
        line.startsWith('//') ||
        line.startsWith('///') ||
        line.startsWith('import ') ||
        line.startsWith('export ') ||
        line.startsWith('part ') ||
        line.startsWith('library ') ||
        line == '{' ||
        line == '}' ||
        line == '};' ||
        line.startsWith('@')) {
      continue;
    }
    count++;
  }
  return count;
}

class _CoverageRecord {
  const _CoverageRecord({required this.hit, required this.found});

  final int hit;
  final int found;
}
