// CachedPhoto: optional image-cache limits are handed to CachedNetworkImage; existing calls keep
// working without them.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_front_end/view/widgets/cached_photo.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: SizedBox(width: 200, height: 120, child: child)));

void main() {
  testWidgets('passes memCacheWidth and maxWidthDiskCache to the cached image', (tester) async {
    await tester.pumpWidget(_host(const CachedPhoto(
      imageUrl: 'https://images.test/book.jpg',
      category: 'BOOKS',
      memCacheWidth: 400,
      maxWidthDiskCache: 800,
    )));

    final image = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    expect(image.memCacheWidth, 400);
    expect(image.maxWidthDiskCache, 800);
  });

  testWidgets('without limits the image is cached as before', (tester) async {
    await tester.pumpWidget(_host(const CachedPhoto(imageUrl: 'https://images.test/book.jpg')));

    final image = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    expect(image.memCacheWidth, isNull);
    expect(image.maxWidthDiskCache, isNull);
  });

  testWidgets('no url: the category placeholder is shown and nothing is downloaded', (tester) async {
    await tester.pumpWidget(_host(const CachedPhoto(imageUrl: '', category: 'BOOKS', memCacheWidth: 400)));

    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
  });
}
