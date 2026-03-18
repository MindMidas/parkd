import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../home/presentation/home_map_screen.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  int _selectedMonthIndex = 3; // Jan selected by default

  static const _months = ['Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar'];

  // Dummy earnings data per month (index matches _months).
  static const _earningsData = <List<double>>[
    [40, 60, 45, 70, 50, 65], // Oct
    [50, 40, 60, 55, 70, 45], // Nov
    [30, 50, 70, 40, 60, 55], // Dec
    [35, 55, 70, 85, 60, 80], // Jan
    [45, 65, 50, 60, 75, 55], // Feb
    [60, 45, 55, 70, 50, 65], // Mar
  ];

  // Dummy transactions list.
  static const _transactions = [
    _Transaction(name: 'Haley James', address: '1291 Gordon Street', spot: 'Spot #1', amount: 15.00),
    _Transaction(name: 'Lucas Scott', address: '1291 Gordon Street', spot: 'Spot #1', amount: 15.00),
    _Transaction(name: 'Haley James', address: '1291 Gordon Street', spot: 'Spot #1', amount: 15.00),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppTopBar(
        title: 'Earnings',
        showBack: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.md),
            // --- Chart ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: SizedBox(
                height: 180,
                child: _EarningsChart(
                  dataPoints: _earningsData[_selectedMonthIndex],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // --- Month selector ---
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: _months.length,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
                itemBuilder: (context, index) {
                  final isSelected = index == _selectedMonthIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedMonthIndex = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primaryBlue : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _months[index],
                        style: AppTypography.label.copyWith(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            // --- Recent Transactions header ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: SectionTitle('Recent Transactions'),
            ),
            const SizedBox(height: AppSpacing.sm),
            // --- Transactions list ---
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _transactions.length,
              separatorBuilder: (_, __) => const AppDivider(),
              itemBuilder: (_, index) {
                final tx = _transactions[index];
                return _TransactionRow(transaction: tx);
              },
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 1,
        onDestinationSelected: (index) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => HomeMapScreen(initialIndex: index),
            ),
            (route) => false,
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chart
// ---------------------------------------------------------------------------

class _EarningsChart extends StatelessWidget {
  const _EarningsChart({required this.dataPoints});

  final List<double> dataPoints;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _ChartPainter(dataPoints),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.dataPoints);

  final List<double> dataPoints;

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final maxVal = dataPoints.reduce((a, b) => a > b ? a : b);
    final minVal = dataPoints.reduce((a, b) => a < b ? a : b);
    final range = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);

    // Vertical grid lines.
    final gridPaint = Paint()
      ..color = AppColors.secondaryGrey.withValues(alpha: 0.4)
      ..strokeWidth = 0.5;

    final stepX = size.width / (dataPoints.length - 1);
    for (var i = 0; i < dataPoints.length; i++) {
      final x = i * stepX;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Build points.
    final points = <Offset>[];
    for (var i = 0; i < dataPoints.length; i++) {
      final x = i * stepX;
      final normalized = (dataPoints[i] - minVal) / range;
      final y = size.height - (normalized * size.height * 0.85 + size.height * 0.075);
      points.add(Offset(x, y));
    }

    // Fill gradient under curve.
    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (var i = 0; i < points.length - 1; i++) {
      final cp1 = Offset((points[i].dx + points[i + 1].dx) / 2, points[i].dy);
      final cp2 = Offset((points[i].dx + points[i + 1].dx) / 2, points[i + 1].dy);
      if (i == 0) fillPath.lineTo(points[i].dx, points[i].dy);
      fillPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, points[i + 1].dx, points[i + 1].dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primaryBlue.withValues(alpha: 0.15),
          AppColors.primaryBlue.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // Curve line.
    final linePath = Path();
    for (var i = 0; i < points.length - 1; i++) {
      final cp1 = Offset((points[i].dx + points[i + 1].dx) / 2, points[i].dy);
      final cp2 = Offset((points[i].dx + points[i + 1].dx) / 2, points[i + 1].dy);
      if (i == 0) linePath.moveTo(points[i].dx, points[i].dy);
      linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, points[i + 1].dx, points[i + 1].dy);
    }

    final linePaint = Paint()
      ..color = AppColors.primaryBlue
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);

    // Dots at data points.
    final dotFill = Paint()..color = Colors.white;
    final dotStroke = Paint()
      ..color = AppColors.primaryBlue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final p in points) {
      canvas.drawCircle(p, 5, dotFill);
      canvas.drawCircle(p, 5, dotStroke);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => old.dataPoints != dataPoints;
}

// ---------------------------------------------------------------------------
// Transaction model & row
// ---------------------------------------------------------------------------

class _Transaction {
  const _Transaction({
    required this.name,
    required this.address,
    required this.spot,
    required this.amount,
  });

  final String name;
  final String address;
  final String spot;
  final double amount;
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction});

  final _Transaction transaction;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 4,
      ),
      leading: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: AppColors.secondaryBlue,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.person_rounded,
          size: 28,
          color: AppColors.primaryBlue,
        ),
      ),
      title: Text(
        transaction.name,
        style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${transaction.address}\n${transaction.spot}',
        style: AppTypography.caption,
      ),
      isThreeLine: true,
      trailing: Text(
        '+ \$${transaction.amount.toStringAsFixed(2)}',
        style: AppTypography.body.copyWith(
          color: AppColors.success,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
