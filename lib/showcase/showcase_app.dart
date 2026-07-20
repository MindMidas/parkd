import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_bottom_nav.dart';
import '../core/widgets/app_buttons.dart';
import '../core/widgets/app_demo_banner.dart';
import '../core/widgets/app_static_map_preview.dart';
import 'showcase_models.dart';

class ParkdShowcaseApp extends StatelessWidget {
  const ParkdShowcaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parkd — Portfolio Showcase',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AppDemoFrame(child: ShowcaseHome()),
    );
  }
}

class ShowcaseHome extends StatefulWidget {
  const ShowcaseHome({super.key});

  @override
  State<ShowcaseHome> createState() => _ShowcaseHomeState();
}

class _ShowcaseHomeState extends State<ShowcaseHome> {
  var _tab = 0;
  ShowcaseReservation? _newReservation;

  void _book(ShowcaseListing listing) {
    setState(() {
      _newReservation = ShowcaseReservation(
        id: 'PKD-DEMO-NEW',
        listing: listing,
        time: 'Tomorrow · 10:00 AM – 12:00 PM',
        total: listing.price * 2 * 1.07,
        justBooked: true,
      );
      _tab = 1;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Demo reservation added locally.')),
    );
  }

  void _reset() {
    setState(() {
      _tab = 0;
      _newReservation = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Showcase data reset.')));
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      ShowcaseExploreScreen(onBook: _book),
      ShowcaseReservationsScreen(newReservation: _newReservation),
      const ShowcaseHostingScreen(),
      ShowcaseAccountScreen(onReset: _reset),
    ];

    return Scaffold(
      backgroundColor: AppColors.secondaryBlue,
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _tab,
        reservationsBadgeCount: _newReservation == null ? 1 : 2,
        hostingBadgeCount: 1,
        onDestinationSelected: (index) => setState(() => _tab = index),
      ),
    );
  }
}

class ShowcaseExploreScreen extends StatefulWidget {
  const ShowcaseExploreScreen({super.key, required this.onBook});

  final ValueChanged<ShowcaseListing> onBook;

  @override
  State<ShowcaseExploreScreen> createState() => _ShowcaseExploreScreenState();
}

class _ShowcaseExploreScreenState extends State<ShowcaseExploreScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final results = showcaseListings
        .where(
          (listing) =>
              query.isEmpty ||
              listing.title.toLowerCase().contains(query) ||
              listing.area.toLowerCase().contains(query),
        )
        .toList();

    return _ShowcasePage(
      title: 'Find parking',
      subtitle: 'Try the demo around Guelph',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('showcase-search'),
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'Search an area or parking spot',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const SizedBox(
            height: 230,
            child: AppStaticMapPreview(
              title: 'Parking near downtown Guelph',
              message:
                  'Approximate pins protect host addresses until a reservation is confirmed.',
              pinCount: 3,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Available spots',
                  style: AppTypography.sectionTitle,
                ),
              ),
              Text('${results.length} results', style: AppTypography.caption),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (results.isEmpty)
            const _ShowcaseEmptyState(
              icon: Icons.search_off_rounded,
              title: 'No sample spots found',
              message: 'Try “downtown”, “campus”, or “station”.',
            )
          else
            for (final listing in results) ...[
              _ListingCard(
                listing: listing,
                onTap: () => _showListing(context, listing),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
        ],
      ),
    );
  }

  Future<void> _showListing(
    BuildContext context,
    ShowcaseListing listing,
  ) async {
    final booked = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (context) => _ListingDetailsSheet(listing: listing),
    );
    if (booked == true && mounted) widget.onBook(listing);
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({required this.listing, required this.onTap});

  final ShowcaseListing listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              _SpotIllustration(covered: listing.covered),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(listing.title, style: AppTypography.bodyStrong),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(listing.area, style: AppTypography.bodyMuted),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 17,
                          color: Color(0xFFFFB020),
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(
                          '${listing.rating} · ${listing.walk}',
                          style: AppTypography.captionStrong,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${listing.price.toStringAsFixed(2)}',
                    style: AppTypography.numericStrong,
                  ),
                  Text('per hour', style: AppTypography.caption),
                  const SizedBox(height: AppSpacing.sm),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.iconGrey,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpotIllustration extends StatelessWidget {
  const _SpotIllustration({required this.covered});

  final bool covered;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: covered ? const Color(0xFFEDE9FE) : AppColors.secondaryBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        covered ? Icons.garage_outlined : Icons.local_parking_rounded,
        size: 34,
        color: covered ? const Color(0xFF7C3AED) : AppColors.primaryBlue,
      ),
    );
  }
}

class _ListingDetailsSheet extends StatelessWidget {
  const _ListingDetailsSheet({required this.listing});

  final ShowcaseListing listing;

  @override
  Widget build(BuildContext context) {
    final subtotal = listing.price * 2;
    final fee = subtotal * 0.07;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(listing.title, style: AppTypography.headline),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${listing.area} · ${listing.walk}',
              style: AppTypography.bodyMuted,
            ),
            const SizedBox(height: AppSpacing.lg),
            const _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Tomorrow',
            ),
            const _InfoRow(
              icon: Icons.schedule_rounded,
              label: '10:00 AM – 12:00 PM',
            ),
            const _InfoRow(
              icon: Icons.credit_card_rounded,
              label: 'Simulated Visa ···· 4242',
            ),
            const SizedBox(height: AppSpacing.md),
            _PriceRow(label: '2 hours', amount: subtotal),
            _PriceRow(label: 'Service fee', amount: fee),
            const Divider(height: AppSpacing.lg),
            _PriceRow(
              label: 'Demo total',
              amount: subtotal + fee,
              strong: true,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPrimaryButton(
              key: const Key('showcase-reserve-button'),
              label: 'Simulate reservation',
              icon: Icons.lock_outline_rounded,
              onPressed: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Nothing is charged and no information leaves this browser.',
              textAlign: TextAlign.center,
              style: AppTypography.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class ShowcaseReservationsScreen extends StatelessWidget {
  const ShowcaseReservationsScreen({super.key, this.newReservation});

  final ShowcaseReservation? newReservation;

  @override
  Widget build(BuildContext context) {
    final reservations = [?newReservation, showcaseSeedReservation];
    return _ShowcasePage(
      title: 'Reservations',
      subtitle: 'Your upcoming parking',
      child: Column(
        children: [
          for (final reservation in reservations) ...[
            _ReservationCard(reservation: reservation),
            const SizedBox(height: AppSpacing.sm),
          ],
          const _ShowcaseNote(
            icon: Icons.sync_disabled_rounded,
            text:
                'These sample reservations are stored only while the demo is open.',
          ),
        ],
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({required this.reservation});

  final ShowcaseReservation reservation;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _SpotIllustration(covered: reservation.listing.covered),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE7F8EF),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Confirmed',
                              style: AppTypography.captionStrong.copyWith(
                                color: const Color(0xFF087443),
                              ),
                            ),
                          ),
                          if (reservation.justBooked) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'Just added',
                              style: AppTypography.captionLink,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        reservation.listing.title,
                        style: AppTypography.bodyStrong,
                      ),
                      Text(reservation.time, style: AppTypography.caption),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: Text(reservation.id, style: AppTypography.monoCaption),
                ),
                Text(
                  '\$${reservation.total.toStringAsFixed(2)}',
                  style: AppTypography.numericStrong,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AppSecondaryButton(
              label: 'Message host',
              icon: Icons.chat_bubble_outline_rounded,
              onPressed: () => _showDemoMessage(context),
            ),
          ],
        ),
      ),
    );
  }
}

void _showDemoMessage(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Demo conversation'),
      content: const Text(
        'Host: Your spot is ready. The entrance is beside the blue garage door.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class ShowcaseHostingScreen extends StatelessWidget {
  const ShowcaseHostingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShowcasePage(
      title: 'Hosting',
      subtitle: 'A quick look at your sample listing',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: _MetricCard(
                  label: 'This month',
                  value: '\$186.50',
                  icon: Icons.payments_outlined,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: _MetricCard(
                  label: 'Bookings',
                  value: '14',
                  icon: Icons.event_available_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const _MetricCard(
            label: 'Average rating',
            value: '4.9 ★',
            icon: Icons.star_outline_rounded,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Your listings', style: AppTypography.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  Row(
                    children: [
                      const _SpotIllustration(covered: false),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Downtown driveway',
                              style: AppTypography.bodyStrong,
                            ),
                            Text(
                              'Published · \$4.50/hour',
                              style: AppTypography.bodyMuted,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: AppSpacing.lg),
                  const _InfoRow(
                    icon: Icons.today_outlined,
                    label: '3 bookings this week',
                  ),
                  const _InfoRow(
                    icon: Icons.visibility_outlined,
                    label: '42 listing views',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const _ShowcaseNote(
            icon: Icons.auto_graph_rounded,
            text:
                'The connected app calculates earnings from server-verified payments.',
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primaryBlue),
            const SizedBox(height: AppSpacing.sm),
            Text(value, style: AppTypography.headline),
            Text(label, style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}

class ShowcaseAccountScreen extends StatelessWidget {
  const ShowcaseAccountScreen({super.key, required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return _ShowcasePage(
      title: 'Account',
      subtitle: 'Local portfolio profile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.secondaryBlue,
                    child: Icon(
                      Icons.person_rounded,
                      size: 34,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Demo Driver',
                          style: AppTypography.profileDisplayName,
                        ),
                        Text(
                          'Portfolio showcase account',
                          style: AppTypography.bodyMuted,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Built with', style: AppTypography.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          const _IntegrationTile(
            icon: Icons.flutter_dash_rounded,
            title: 'Flutter + Riverpod',
            subtitle: 'Responsive UI and app state',
          ),
          const _IntegrationTile(
            icon: Icons.storage_rounded,
            title: 'Supabase + PostgreSQL',
            subtitle: 'Auth, storage, realtime, RLS, and Edge Functions',
          ),
          const _IntegrationTile(
            icon: Icons.credit_card_rounded,
            title: 'Stripe',
            subtitle: 'Server-authoritative test checkout',
          ),
          const _IntegrationTile(
            icon: Icons.map_outlined,
            title: 'Mapbox',
            subtitle: 'Native discovery with privacy-safe pins',
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSecondaryButton(
            key: const Key('showcase-reset-button'),
            label: 'Reset showcase',
            icon: Icons.refresh_rounded,
            onPressed: onReset,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No sign-in, backend request, or real payment is used in this public build.',
            textAlign: TextAlign.center,
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}

class _IntegrationTile extends StatelessWidget {
  const _IntegrationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primaryBlue),
        title: Text(title, style: AppTypography.bodyStrong),
        subtitle: Text(subtitle, style: AppTypography.caption),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.iconGrey),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: AppTypography.bodySecondary)),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.amount,
    this.strong = false,
  });

  final String label;
  final double amount;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = strong
        ? AppTypography.bodyStrong
        : AppTypography.bodySecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text('\$${amount.toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }
}

class _ShowcasePage extends StatelessWidget {
  const _ShowcasePage({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                automaticallyImplyLeading: false,
                titleSpacing: AppSpacing.md,
                title: Row(
                  children: [
                    Image.asset(
                      'lib/core/assets/logo.png',
                      width: 34,
                      height: 34,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Text('Parkd'),
                  ],
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: Chip(
                      avatar: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('Showcase'),
                      visualDensity: VisualDensity.compact,
                      side: const BorderSide(color: AppColors.secondaryGrey),
                      backgroundColor: AppColors.surface,
                    ),
                  ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.xl,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(title, style: AppTypography.headline),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(subtitle, style: AppTypography.bodyMuted),
                    const SizedBox(height: AppSpacing.lg),
                    child,
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShowcaseNote extends StatelessWidget {
  const _ShowcaseNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.secondaryGrey),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryBlue),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTypography.bodySecondary)),
        ],
      ),
    );
  }
}

class _ShowcaseEmptyState extends StatelessWidget {
  const _ShowcaseEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Icon(icon, size: 40, color: AppColors.iconGrey),
            const SizedBox(height: AppSpacing.sm),
            Text(title, style: AppTypography.bodyStrong),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.caption,
            ),
          ],
        ),
      ),
    );
  }
}
