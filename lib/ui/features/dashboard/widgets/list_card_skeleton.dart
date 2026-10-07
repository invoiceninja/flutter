import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';

/// Placeholder rows shared by every list card while data is in flight.
///
/// Drawn in the border tone. The alternate surface these used to use is
/// 1.04–1.22:1 against a card — a skeleton nobody could see, which made a
/// loading panel look like an empty one.
class ListCardSkeleton extends StatelessWidget {
  const ListCardSkeleton({super.key, this.rowCount = 5});

  final int rowCount;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Column(
      children: List.generate(rowCount, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                        color: tokens.border,
                        borderRadius: BorderRadius.circular(InRadii.r1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 140,
                      height: 10,
                      decoration: BoxDecoration(
                        color: tokens.border,
                        borderRadius: BorderRadius.circular(InRadii.r1),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 60,
                height: 12,
                decoration: BoxDecoration(
                  color: tokens.border,
                  borderRadius: BorderRadius.circular(InRadii.r1),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
