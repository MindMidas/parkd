class ShowcaseListing {
  const ShowcaseListing({
    required this.id,
    required this.title,
    required this.area,
    required this.walk,
    required this.price,
    required this.rating,
    required this.covered,
  });

  final String id;
  final String title;
  final String area;
  final String walk;
  final double price;
  final double rating;
  final bool covered;
}

class ShowcaseReservation {
  const ShowcaseReservation({
    required this.id,
    required this.listing,
    required this.time,
    required this.total,
    this.justBooked = false,
  });

  final String id;
  final ShowcaseListing listing;
  final String time;
  final double total;
  final bool justBooked;
}

const showcaseListings = <ShowcaseListing>[
  ShowcaseListing(
    id: 'downtown-driveway',
    title: 'Quiet downtown driveway',
    area: 'Downtown Guelph',
    walk: '4 min walk',
    price: 4.50,
    rating: 4.9,
    covered: false,
  ),
  ShowcaseListing(
    id: 'campus-garage',
    title: 'Covered spot near campus',
    area: 'University Village',
    walk: '6 min walk',
    price: 6,
    rating: 4.8,
    covered: true,
  ),
  ShowcaseListing(
    id: 'station-lot',
    title: 'Easy-access private lot',
    area: 'Guelph Central Station',
    walk: '2 min walk',
    price: 5.25,
    rating: 4.7,
    covered: false,
  ),
];

final showcaseSeedReservation = ShowcaseReservation(
  id: 'PKD-DEMO-2407',
  listing: showcaseListings[1],
  time: 'Today · 2:00 PM – 5:00 PM',
  total: 19.26,
);
