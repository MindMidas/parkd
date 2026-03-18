import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../home/presentation/home_map_screen.dart';
import 'add_card_screen.dart';

class AllCardsScreen extends StatelessWidget {
  const AllCardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppTopBar(
        title: 'All Cards',
        showBack: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    // --- Mastercard ---
                    const _CreditCard(
                      cardNumber: '4562  1122  4595  7852',
                      holderName: 'Lucas Scott',
                      expiryDate: '24/2000',
                      cvv: '6986',
                      cardType: _CardType.mastercard,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // --- Visa ---
                    const _CreditCard(
                      cardNumber: '4562 1122 4595 7852',
                      holderName: 'Lucas Scott',
                      expiryDate: '24/2000',
                      cardType: _CardType.visa,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
            // --- Add Card button ---
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AddCardScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Add Card',
                          style: AppTypography.button.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        const Icon(Icons.add, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
// Card type enum
// ---------------------------------------------------------------------------

enum _CardType { mastercard, visa }

// ---------------------------------------------------------------------------
// Credit card widget
// ---------------------------------------------------------------------------

class _CreditCard extends StatelessWidget {
  const _CreditCard({
    required this.cardNumber,
    required this.holderName,
    required this.expiryDate,
    this.cvv,
    required this.cardType,
  });

  final String cardNumber;
  final String holderName;
  final String expiryDate;
  final String? cvv;
  final _CardType cardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: cardType == _CardType.mastercard
              ? [const Color(0xFF1A1F71), const Color(0xFF2D35A8)]
              : [const Color(0xFF1B1D3E), const Color(0xFF131428)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: chip left, contactless right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // SIM chip icon
              _buildChipIcon(),
              // Contactless icon (Mastercard only)
              if (cardType == _CardType.mastercard)
                RotatedBox(
                  quarterTurns: 1,
                  child: Icon(
                    Icons.wifi,
                    size: 24,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          // Card number
          Text(
            cardNumber,
            style: AppTypography.title.copyWith(
              color: Colors.white,
              fontSize: cardType == _CardType.mastercard ? 18 : 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          // Holder name
          Text(
            holderName,
            style: AppTypography.body.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          // Expiry / CVV row + card brand
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Expiry
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expiry Date',
                    style: AppTypography.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    expiryDate,
                    style: AppTypography.label.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (cvv != null) ...[
                const SizedBox(width: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CVV',
                      style: AppTypography.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cvv!,
                      style: AppTypography.label.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              const Spacer(),
              // Card brand
              _buildCardBrand(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChipIcon() {
    return Container(
      width: 36,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 20,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 4),
            Container(
              width: 20,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 4),
            Container(
              width: 20,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardBrand() {
    if (cardType == _CardType.mastercard) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 30,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 1,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEB001B),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 1,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF79E1B).withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Mastercard',
            style: AppTypography.caption.copyWith(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    } else {
      return Text(
        'VISA',
        style: AppTypography.title.copyWith(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: 2,
        ),
      );
    }
  }
}
