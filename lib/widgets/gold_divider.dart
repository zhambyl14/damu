import 'package:flutter/material.dart';
import '../theme.dart';

class GoldDivider extends StatelessWidget {
  final String label;

  const GoldDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.navyBlue,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
        ),
      ],
    );
  }
}