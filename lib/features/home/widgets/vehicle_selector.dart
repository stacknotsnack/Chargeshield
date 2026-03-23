import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/vehicle.dart';

class VehicleSelector extends StatelessWidget {
  const VehicleSelector({
    super.key,
    required this.vehicles,
    required this.selected,
    required this.onSelect,
    required this.onAdd,
  });

  final List<Vehicle> vehicles;
  final Vehicle? selected;
  final ValueChanged<Vehicle> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (vehicles.isEmpty) {
      return OutlinedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add),
        label: const Text('Add your first vehicle'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.directions_car, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Vehicle>(
                  value: selected,
                  isExpanded: true,
                  hint: const Text('Select vehicle'),
                  items: vehicles
                      .map(
                        (v) => DropdownMenuItem<Vehicle>(
                          value: v,
                          child: Text(
                            '${v.nickname} · ${v.registration}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) onSelect(v);
                  },
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
              tooltip: 'Add vehicle',
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}
