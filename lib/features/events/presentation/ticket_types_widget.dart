import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/glass_card.dart';
import '../../../core/ui/custom_input.dart';
import '../../../core/utils/currency_helper.dart';

class TicketTypesWidget extends StatefulWidget {
  final List<Map<String, dynamic>> initialTypes;
  final String currency; // New property
  final Function(List<Map<String, dynamic>>) onChanged;
  final Function(String)? onDeleted;

  const TicketTypesWidget(
      {super.key,
      required this.initialTypes,
      required this.currency,
      required this.onChanged,
      this.onDeleted});

  @override
  State<TicketTypesWidget> createState() => _TicketTypesWidgetState();
}

class _TicketTypesWidgetState extends State<TicketTypesWidget> {
  late List<Map<String, dynamic>> _types;

  @override
  void initState() {
    super.initState();
    _types = List.from(widget.initialTypes);
  }

  @override
  void didUpdateWidget(TicketTypesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If currency changes parent side, we might want to update local state logic if needed.
    // However, currency is display-only mostly here, but we store it in new types.
  }

  static const List<Color> _presetColors = [
    Color(0xFF4F46E5), // Indigo (Default)
    Color(0xFFEF4444), // Red
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEC4899), // Pink
  ];

  void _addType() {
    setState(() {
      _types.add({
        'name': '',
        'price': 0.0,
        'currency': widget.currency,
        'color': '#4F46E5', // Default Indigo
        'is_active': true,
        'is_new': true,
      });
    });
    widget.onChanged(_types);
  }

  void _updateColor(int index, Color color) {
    setState(() {
      _types[index]['color'] =
          '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
    });
    widget.onChanged(_types);
  }

  void _showColorPicker(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select Color"),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _presetColors.map((color) {
            return InkWell(
              onTap: () {
                _updateColor(index, color);
                Navigator.pop(context);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ]),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _removeType(int index) {
    setState(() {
      final type = _types.removeAt(index);
      if (type['id'] != null && widget.onDeleted != null) {
        widget.onDeleted!(type['id']);
      }
    });
    widget.onChanged(_types);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.ticketTypes,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(
              onPressed: _addType,
              icon: const Icon(Icons.add_circle, color: AppTheme.neonBlue),
              tooltip: l10n.addType,
            )
          ],
        ),
        const SizedBox(height: 8),
        if (_types.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(l10n.noTicketTypesAdded,
                style: const TextStyle(color: Colors.grey)),
          ),
        ..._types.asMap().entries.map((entry) {
          final index = entry.key;
          final type = entry.value;

          // Parse color
          Color typeColor = const Color(0xFF4F46E5);
          if (type['color'] != null) {
            try {
              final hex = type['color'].toString().replaceAll('#', '');
              typeColor = Color(int.parse('FF$hex', radix: 16));
            } catch (_) {}
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: GlassCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: CustomInput(
                      label: l10n.name,
                      // icon: Icons.label, // Removed default icon
                      prefixWidget: IconButton(
                        onPressed: () => _showColorPicker(index),
                        icon: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                              color: typeColor,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white24, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                    color: typeColor.withOpacity(0.5),
                                    blurRadius: 4)
                              ]),
                        ),
                      ),
                      initialValue: type['name'],
                      onChanged: (v) {
                        type['name'] = v;
                        widget.onChanged(_types);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: CustomInput(
                      label: l10n.price,
                      // icon: Icons.attach_money, // Removed in favor of text
                      prefixText:
                          '${CurrencyHelper.getSymbol(widget.currency)} ', // Shows Gs or $
                      keyboardType: TextInputType.number,
                      initialValue: type['price'].toString(),
                      onChanged: (v) {
                        type['price'] = double.tryParse(v) ?? 0;
                        widget.onChanged(_types);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _removeType(index),
                    icon: const Icon(Icons.delete, color: Colors.red),
                    visualDensity: VisualDensity.compact,
                  )
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
