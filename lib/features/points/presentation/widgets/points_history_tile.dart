import 'package:flutter/material.dart';
import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/core/utils/formatters.dart';

class PointsHistoryTile extends StatelessWidget {
  final Map<String, dynamic> transaction;
  const PointsHistoryTile({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final points = (transaction['points'] ?? 0) as int;
    final isEarned = points > 0;
    final description = transaction['description'] as String? ?? '';
    final createdAt = transaction['created_at'] != null
        ? DateTime.tryParse(transaction['created_at'].toString())
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: MonacoColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MonacoColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isEarned ? MonacoColors.success : MonacoColors.destructive)
                  .withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isEarned
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              color:
                  isEarned ? MonacoColors.success : MonacoColors.destructive,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                    color: MonacoColors.foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (createdAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      Formatters.relativeTime(createdAt),
                      style: const TextStyle(
                        color: MonacoColors.foregroundSubtle,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${isEarned ? '+' : ''}$points pts',
            style: TextStyle(
              color:
                  isEarned ? MonacoColors.success : MonacoColors.destructive,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
