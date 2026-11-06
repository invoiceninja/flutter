import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/review_prompt.dart';
import 'package:admin/domain/sync/landed_mutation.dart';

/// The review prompt's pure rules (docs/review-prompt.md): a store build only
/// ever asks through the OS sheet, and only finishing work opens a moment.
void main() {
  group('resolveReviewChannel', () {
    ReviewChannel resolve(
      TargetPlatform platform, {
      bool isWeb = false,
      bool store = true,
      bool demo = false,
    }) => resolveReviewChannel(
      isWeb: isWeb,
      platform: platform,
      isStoreBuild: store,
      isDemo: demo,
    );

    test('store builds ask through the OS sheet, never the card', () {
      for (final p in [
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.android,
      ]) {
        final c = resolve(p);
        expect(c.isNative, isTrue, reason: '$p');
        expect(c.usesCard, isFalse, reason: '$p');
      }
      expect(resolve(TargetPlatform.iOS), ReviewChannel.appleStore);
      expect(resolve(TargetPlatform.macOS), ReviewChannel.appleStore);
      expect(resolve(TargetPlatform.android), ReviewChannel.playStore);
    });

    test('F-Droid, Linux and the web send reviews to Capterra', () {
      expect(
        resolve(TargetPlatform.android, store: false),
        ReviewChannel.capterra,
      );
      expect(resolve(TargetPlatform.linux), ReviewChannel.capterra);
      for (final p in TargetPlatform.values) {
        expect(resolve(p, isWeb: true), ReviewChannel.capterra, reason: '$p');
      }
    });

    test('Windows asks with the card, then the Microsoft Store', () {
      expect(resolve(TargetPlatform.windows), ReviewChannel.microsoftStore);
      expect(ReviewChannel.microsoftStore.usesCard, isTrue);
    });

    test('the demo never asks', () {
      for (final p in TargetPlatform.values) {
        expect(resolve(p, demo: true), ReviewChannel.none, reason: '$p');
        expect(
          resolve(p, demo: true, isWeb: true),
          ReviewChannel.none,
          reason: '$p web',
        );
      }
    });
  });

  group('reviewListingUri', () {
    test('Apple has no link until the App Store id is known', () {
      expect(reviewListingUri(ReviewChannel.appleStore), isNull);
      expect(
        reviewListingUri(
          ReviewChannel.appleStore,
          appStoreId: '123',
        ).toString(),
        'https://apps.apple.com/app/id123?action=write-review',
      );
    });

    test('each channel opens its own review page', () {
      expect(
        reviewListingUri(ReviewChannel.playStore).toString(),
        'https://play.google.com/store/apps/details?id=com.invoiceninja.admin',
      );
      expect(
        reviewListingUri(ReviewChannel.microsoftStore).toString(),
        'ms-windows-store://review/?ProductId=9NG93WNXN797',
      );
      expect(
        reviewListingFallbackUri(ReviewChannel.microsoftStore).toString(),
        'https://apps.microsoft.com/detail/9NG93WNXN797',
      );
      expect(
        reviewListingUri(ReviewChannel.capterra).toString(),
        kCapterraReviewUrl,
      );
      expect(reviewListingUri(ReviewChannel.none), isNull);
    });
  });

  group('classifyReviewWin', () {
    ReviewWin win(
      String entityType,
      String kind, {
      Set<String> query = const {},
    }) => classifyReviewWin(
      LandedMutation(
        entityType: entityType,
        mutationKind: kind,
        saveQueryKeys: query,
        rowCreatedAt: DateTime.utc(2026, 11, 6, 12),
      ),
    );

    test('finishing actions arm a moment', () {
      expect(win('invoice', 'email_entity'), ReviewWin.arms);
      expect(win('invoice', 'send_e_invoice'), ReviewWin.arms);
      expect(win('invoice', 'mark_sent'), ReviewWin.arms);
      expect(win('invoice', 'mark_paid'), ReviewWin.arms);
      expect(win('invoice', 'auto_bill'), ReviewWin.arms);
      expect(win('payment', 'apply_payment'), ReviewWin.arms);
      expect(win('payment', 'create'), ReviewWin.arms);
      expect(win('expense', 'create'), ReviewWin.arms);
      expect(win('invoice', 'update', query: {'paid'}), ReviewWin.arms);
      expect(win('invoice', 'create', query: {'mark_sent'}), ReviewWin.arms);
      expect(win('credit', 'update', query: {'mark_paid'}), ReviewWin.arms);
    });

    test('work whose next step is Email or Download only counts', () {
      for (final type in [
        'invoice',
        'quote',
        'credit',
        'recurring_invoice',
        'purchase_order',
        'task',
      ]) {
        expect(win(type, 'create'), ReviewWin.counts, reason: type);
      }
      expect(win('quote', 'convert_to_invoice'), ReviewWin.counts);
      expect(win('quote', 'approve'), ReviewWin.counts);
      expect(win('invoice', 'schedule_email'), ReviewWin.counts);
      expect(win('recurring_invoice', 'send_now'), ReviewWin.counts);
      expect(win('recurring_invoice', 'start'), ReviewWin.counts);
      expect(win('quote', 'update', query: {'approve'}), ReviewWin.counts);
      expect(win('quote', 'update', query: {'convert'}), ReviewWin.counts);
    });

    test('the wins that ride a plain save still count', () {
      // A task's timer starts and stops by saving the task.
      expect(win('task', 'update'), ReviewWin.counts);
      // Recurring Send Now and Start from the edit screen and the actions.
      expect(
        win('recurring_invoice', 'update', query: {'send_now'}),
        ReviewWin.counts,
      );
      expect(
        win('recurring_invoice', 'update', query: {'start'}),
        ReviewWin.counts,
      );
      // Stopping a recurring invoice is not a win.
      expect(
        win('recurring_invoice', 'update', query: {'stop'}),
        ReviewWin.none,
      );
      expect(win('recurring_invoice', 'stop'), ReviewWin.none);
    });

    test('housekeeping and a cancel are not wins', () {
      expect(win('invoice', 'update'), ReviewWin.none);
      expect(win('client', 'create'), ReviewWin.none);
      expect(win('product', 'create'), ReviewWin.none);
      expect(win('invoice', 'archive'), ReviewWin.none);
      expect(win('invoice', 'delete'), ReviewWin.none);
      expect(win('invoice', 'add_comment'), ReviewWin.none);
      expect(win('invoice', 'cancel_entity'), ReviewWin.none);
      expect(win('invoice', 'update', query: {'cancel'}), ReviewWin.none);
      expect(
        win('invoice', 'update', query: {'cancel', 'paid'}),
        ReviewWin.none,
      );
      expect(win('invoice', 'no_such_kind'), ReviewWin.none);
    });
  });

  group('LandedMutation.fromRow', () {
    test('reads the save query of a create or update', () {
      final m = LandedMutation.fromRow(
        entityType: 'invoice',
        mutationKind: 'update',
        payload: '{"id":"x","__save_query":{"paid":"true"}}',
        createdAtMs: 0,
      );
      expect(m.saveQueryKeys, {'paid'});
      expect(classifyReviewWin(m), ReviewWin.arms);
    });

    test('ignores the payload of any other kind, and garbage', () {
      expect(
        LandedMutation.fromRow(
          entityType: 'invoice',
          mutationKind: 'email_entity',
          payload: '{"__save_query":{"paid":"true"}}',
          createdAtMs: 0,
        ).saveQueryKeys,
        isEmpty,
      );
      expect(
        LandedMutation.fromRow(
          entityType: 'invoice',
          mutationKind: 'create',
          payload: 'not json',
          createdAtMs: 0,
        ).saveQueryKeys,
        isEmpty,
      );
    });
  });
}
