import 'package:sqflite/sqflite.dart';

/// Editorial review workflow for imported content packages.
///
/// This repository records decisions; it does not authenticate the reviewer.
/// A trusted admin boundary must be enforced before production use.
class ContentPackageReviewRepository {
  ContentPackageReviewRepository(this._database);

  final Database _database;

  Future<List<Map<String, Object?>>> getPackages({
    String? reviewStatus,
  }) async {
    if (reviewStatus != null &&
        !['pending_review', 'approved', 'rejected'].contains(reviewStatus)) {
      throw ArgumentError.value(reviewStatus, 'reviewStatus');
    }
    return _database.query(
      'content_packages',
      columns: [
        'id',
        'package_code',
        'version',
        'source_label',
        'review_status',
        'imported_at',
        'reviewed_at',
        'reviewer_label',
        'review_notes',
      ],
      where: reviewStatus == null ? null : 'review_status = ?',
      whereArgs: reviewStatus == null ? null : [reviewStatus],
      orderBy: 'imported_at DESC, id DESC',
    );
  }

  Future<List<Map<String, Object?>>> getReviewHistory(int packageId) {
    return _database.query(
      'content_package_reviews',
      where: 'package_id = ?',
      whereArgs: [packageId],
      orderBy: 'reviewed_at DESC, id DESC',
    );
  }

  Future<void> reviewPackage({
    required int packageId,
    required String decision,
    required String reviewerLabel,
    String? notes,
  }) async {
    if (!['approved', 'rejected'].contains(decision)) {
      throw ArgumentError.value(decision, 'decision');
    }
    final reviewer = reviewerLabel.trim();
    if (reviewer.isEmpty) {
      throw ArgumentError.value(reviewerLabel, 'reviewerLabel', 'Required.');
    }
    final cleanNotes = notes?.trim();
    if (decision == 'rejected' &&
        (cleanNotes == null || cleanNotes.isEmpty)) {
      throw ArgumentError.value(notes, 'notes', 'A rejection reason is required.');
    }

    await _database.transaction((txn) async {
      final rows = await txn.query(
        'content_packages',
        columns: ['source_label', 'review_status'],
        where: 'id = ?',
        whereArgs: [packageId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Content package not found.');
      if (rows.single['review_status'] != 'pending_review') {
        throw StateError('Only packages pending review can receive a decision.');
      }
      // The current manifest does not carry independently verifiable official
      // provenance fields. Never approve an official-labelled package yet.
      if (decision == 'approved' && rows.single['source_label'] == 'official') {
        throw StateError(
          'Official packages cannot be approved until their source provenance is independently verified.',
        );
      }

      final now = DateTime.now().toUtc().toIso8601String();
      await txn.update(
        'content_packages',
        {
          'review_status': decision,
          'reviewed_at': now,
          'reviewer_label': reviewer,
          'review_notes': cleanNotes,
        },
        where: 'id = ? AND review_status = ?',
        whereArgs: [packageId, 'pending_review'],
      );
      await txn.insert('content_package_reviews', {
        'package_id': packageId,
        'decision': decision,
        'reviewer_label': reviewer,
        'notes': cleanNotes,
        'reviewed_at': now,
      });
    });
  }
}
