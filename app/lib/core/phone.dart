import 'package:flutter/material.dart';

/// International phone validation shared by registration, customers and
/// documents. Phone numbers are persisted in E.164 form.
String? internationalPhoneError(String value, {bool required = false}) {
  final text = value.trim();
  if (text.isEmpty) return required ? 'Enter a phone number' : null;
  final compact = text.replaceAll(RegExp(r'[\s()\-]'), '');
  if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(compact)) {
    return 'Enter a valid phone number';
  }
  return null;
}

String normalizeInternationalPhone(String value) =>
    value.trim().replaceAll(RegExp(r'[\s()\-]'), '');

/// Country-code picker plus national-number input. Nigeria is deliberately
/// the default, so users never have to type +234 manually.
class CountryPhoneField extends StatefulWidget {
  const CountryPhoneField({super.key, required this.controller, this.label = 'Phone number'});
  final TextEditingController controller;
  final String label;

  @override
  State<CountryPhoneField> createState() => _CountryPhoneFieldState();
}

class _CountryPhoneFieldState extends State<CountryPhoneField> {
  static const _codes = <String, String>{
    '+234': 'Nigeria (+234)', '+233': 'Ghana (+233)', '+229': 'Benin (+229)',
    '+228': 'Togo (+228)', '+237': 'Cameroon (+237)', '+44': 'United Kingdom (+44)',
    '+1': 'USA/Canada (+1)', '+27': 'South Africa (+27)', '+971': 'UAE (+971)',
  };
  late String _code;
  late final TextEditingController _number;

  @override
  void initState() {
    super.initState();
    final initial = normalizeInternationalPhone(widget.controller.text);
    _code = _codes.keys.where(initial.startsWith).firstOrNull ?? '+234';
    _number = TextEditingController(text: initial.startsWith(_code) ? initial.substring(_code.length) : initial.replaceFirst('+', ''));
    _sync();
  }

  void _sync() => widget.controller.text = '$_code${_number.text.replaceAll(RegExp(r'\D'), '')}';

  @override
  void dispose() { _number.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SizedBox(width: 132, child: DropdownButtonFormField<String>(
      initialValue: _code,
      decoration: const InputDecoration(labelText: 'Country'),
      items: _codes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.key))).toList(),
      selectedItemBuilder: (_) => _codes.keys.map((code) => Align(alignment: Alignment.centerLeft, child: Text(code))).toList(),
      onChanged: (value) { if (value != null) setState(() { _code = value; _sync(); }); },
    )),
    const SizedBox(width: 8),
    Expanded(child: TextField(
      controller: _number,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(labelText: widget.label, hintText: '8033498452', prefixIcon: const Icon(Icons.phone_outlined)),
      onChanged: (_) => _sync(),
    )),
  ]);
}

extension _FirstOrNullPhone<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
