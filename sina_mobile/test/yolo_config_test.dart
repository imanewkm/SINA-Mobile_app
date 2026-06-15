// Detection geometry & thresholds (pure functions in yolo_config.dart).

import 'package:flutter_test/flutter_test.dart';
import 'package:sina_mobile/constants/yolo_config.dart';

void main() {
  group('confidence thresholds', () {
    test('sensitivity → confidence', () {
      expect(confidenceForSensitivity(1), 0.60); // quiet
      expect(confidenceForSensitivity(2), 0.50); // normal
      expect(confidenceForSensitivity(3), 0.40); // noisy
      expect(confidenceForSensitivity(99), 0.50); // unknown → default
    });

    test('generic (unnamed) floor sits below the naming threshold', () {
      expect(genericConfidenceFor(0.50), closeTo(0.30, 1e-9));
      expect(genericConfidenceFor(0.60), closeTo(0.40, 1e-9));
      // Never below the absolute floor.
      expect(genericConfidenceFor(0.40), closeTo(kUncertainObjectFloor, 1e-9));
      expect(genericConfidenceFor(0.40), closeTo(0.25, 1e-9));
    });
  });

  group('distance tiers', () {
    test('from real metres', () {
      expect(distanceTierFromMeters(0.5), 'very_close');
      expect(distanceTierFromMeters(1.5), 'close');
      expect(distanceTierFromMeters(3.0), 'medium');
      expect(distanceTierFromMeters(10.0), 'far');
    });

    test('invalid metres treated as far', () {
      expect(distanceTierFromMeters(0), 'far');
      expect(distanceTierFromMeters(-1), 'far');
    });

    test('from bounding-box area ratio', () {
      expect(estimateDistance(0, 0, 0.5, 0.5, 1, 1), 'very_close'); // 0.25
      expect(estimateDistance(0, 0, 0.3, 0.3, 1, 1), 'close'); // 0.09
      expect(estimateDistance(0, 0, 0.15, 0.15, 1, 1), 'medium'); // 0.0225
      expect(estimateDistance(0, 0, 0.05, 0.05, 1, 1), 'far'); // 0.0025
    });

    test('rank index orders closest first; unknown is last', () {
      expect(distanceRankIndex('very_close'), 0);
      expect(distanceRankIndex('close'), 1);
      expect(distanceRankIndex('medium'), 2);
      expect(distanceRankIndex('far'), 3);
      expect(distanceRankIndex('bogus'), distanceRank.length);
    });
  });

  group('class-aware distance (distanceFromBoxArea)', () {
    // A square box from the origin; area = side*side.
    double estFor(String label, double side) =>
        distanceFromBoxArea(label, 0, 0, side, side);

    test('known class yields a positive distance', () {
      expect(estFor('person', 0.3), greaterThan(0));
      expect(estFor('car', 0.3), greaterThan(0));
    });

    test('same apparent size: a bigger object is farther away', () {
      // The whole point of class-awareness — a bus and a person filling the
      // same box area are at very different distances.
      expect(estFor('bus', 0.3), greaterThan(estFor('person', 0.3)));
      expect(estFor('truck', 0.3), greaterThan(estFor('car', 0.3)));
    });

    test('larger box (closer) → smaller distance; 2x linear → half distance', () {
      expect(estFor('person', 0.4), lessThan(estFor('person', 0.2)));
      // side 0.4 has 4x the area of side 0.2 → distance halves.
      expect(estFor('person', 0.2) / estFor('person', 0.4), closeTo(2.0, 1e-9));
    });

    test('unknown class or zero-area box returns non-positive (fall back)', () {
      expect(distanceFromBoxArea('unicorn', 0, 0, 0.3, 0.3), lessThanOrEqualTo(0));
      expect(distanceFromBoxArea('person', 0.1, 0.1, 0.1, 0.1), lessThanOrEqualTo(0));
    });

    test('maps into sensible tiers', () {
      expect(distanceTierFromMeters(estFor('person', 0.8)), 'very_close');
      expect(distanceTierFromMeters(estFor('person', 0.12)), 'far');
    });
  });

  group('position from x-center', () {
    test('left / center / right', () {
      expect(estimatePosition(0.0, 0.2, 1), 'left'); // center 0.10
      expect(estimatePosition(0.4, 0.6, 1), 'center'); // center 0.50
      expect(estimatePosition(0.8, 1.0, 1), 'right'); // center 0.90
    });
  });

  group('class configuration (custom 24-class navigation model)', () {
    test('canonical labels at their indices', () {
      expect(cocoLabels[2], 'bus');
      expect(cocoLabels[4], 'car');
      expect(cocoLabels[10], 'person');
      expect(cocoLabels[16], 'traffic light');
      expect(cocoLabels[19], 'truck');
      expect(cocoLabels[23], 'crosswalk');
    });

    test('traffic-light id matches the labels table', () {
      expect(kTrafficLightClassId, 16);
      expect(cocoLabels[kTrafficLightClassId], 'traffic light');
    });

    test('all 24 classes are targeted', () {
      expect(targetClassIds.length, 24);
      expect(targetClassIds.contains(16), isTrue);
      expect(targetClassIds.contains(24), isFalse);
    });
  });
}
