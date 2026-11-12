import 'forms_spec.dart';

/// Auto-incrementing serial numbers per document type, seeded to CONTINUE
/// the physical carbon-copy books (Receipt 2131, MILS 925, Invoice 4335 —
/// docs/forms/FORM_LAYOUTS.md). Admin can re-seed in Settings (M2) so
/// digital and paper documents never collide.
class SerialService {
  SerialService._();
  static final SerialService instance = SerialService._();

  final Map<String, int> _counters = Map.of(MtekForms.seedSerials);

  /// Next serial for 'receipt' | 'invoice' | 'mils'.
  int next(String type) {
    final nextValue = (_counters[type] ?? 0) + 1;
    _counters[type] = nextValue;
    return nextValue;
  }

  int current(String type) => _counters[type] ?? 0;

  /// Admin operation (Settings → Serials): set the counter to the
  /// number of the last used physical page.
  void reseed(String type, int lastUsedNumber) =>
      _counters[type] = lastUsedNumber;

  Map<String, dynamic> toJson() => Map<String, dynamic>.of(_counters);

  void loadFrom(Map<String, dynamic> json) {
    json.forEach((k, v) {
      final n = v is int ? v : int.tryParse('$v');
      if (n != null) _counters[k] = n;
    });
  }
}
