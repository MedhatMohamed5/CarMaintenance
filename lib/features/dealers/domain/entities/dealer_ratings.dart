/// Every rating this device has given, keyed by workshop id.
///
/// **Ratings had to move out of the workshop row itself.** They used to be two
/// fields on the stored `Dealer`, which worked only while every workshop —
/// standard ones included — was written into the local store. Now the standard
/// directory is read straight from Remote Config and never persisted, so a row
/// the driver rated may not exist anywhere on disk. The rating is about the
/// workshop but it does not belong *to* it; it belongs to this device.
///
/// Device-local on purpose, as before: the app is a directory, not a review
/// platform, and a score gathered from one person's taps is not something to
/// publish or to sync between their devices.
class DealerRatings {
  const DealerRatings(this._byId);

  static const empty = DealerRatings({});

  final Map<String, DealerRating> _byId;

  DealerRating? ratingOf(String dealerId) => _byId[dealerId];

  /// Adds one vote, as a running mean so a single enthusiastic tap cannot swing
  /// an established score.
  DealerRatings withVote(String dealerId, double stars) {
    final existing = _byId[dealerId];
    final next = existing == null
        ? DealerRating(average: stars, count: 1)
        : DealerRating(
            average:
                ((existing.average * existing.count) + stars) /
                (existing.count + 1),
            count: existing.count + 1,
          );
    return DealerRatings({..._byId, dealerId: next});
  }

  /// Places a rating wholesale, for the upgrade that lifts scores off the old
  /// stored workshop rows. [withVote] is the path for a driver actually tapping
  /// a star; this one carries an average and a count that already exist.
  DealerRatings withRating(String dealerId, DealerRating rating) =>
      DealerRatings({..._byId, dealerId: rating});

  Map<String, dynamic> toJson() => {
    for (final entry in _byId.entries)
      entry.key: {'r': entry.value.average, 'n': entry.value.count},
  };

  factory DealerRatings.fromJson(Object? value) {
    if (value is! Map) return empty;
    final parsed = <String, DealerRating>{};
    for (final entry in value.entries) {
      final raw = entry.value;
      if (raw is! Map) continue;
      final average = (raw['r'] as num?)?.toDouble();
      final count = (raw['n'] as num?)?.toInt();
      if (average == null || count == null || count <= 0) continue;
      if (!average.isFinite) continue;
      parsed['${entry.key}'] = DealerRating(average: average, count: count);
    }
    return parsed.isEmpty ? empty : DealerRatings(parsed);
  }
}

class DealerRating {
  const DealerRating({required this.average, required this.count});

  final double average;
  final int count;

  /// Rounded for storage and display alike, so the figure the driver sees is
  /// the figure that was kept.
  double get rounded => double.parse(average.toStringAsFixed(2));
}
