/// How hot the customer wants a dish, where the kitchen offers the choice.
///
/// Only three values, and the API's own words for them. Optional even when a
/// dish offers it — no choice is a legitimate answer, and the backend stores
/// null rather than assuming a default nobody asked for.
///
/// Currently free: the guide is explicit that spice level has no price effect,
/// so nothing here touches money.
enum SpiceLevel {
  low('Low', 'Mild — gentle warmth.'),
  mid('Mid', 'Medium — noticeable heat.'),
  high('High', 'Hot — bring water.');

  const SpiceLevel(this.label, this.description);

  final String label;
  final String description;

  /// What goes on the wire. Lowercase, exactly as the API defines it.
  String get apiValue => name;

  /// Null for absent, unknown or malformed.
  ///
  /// Tolerant on purpose: an order placed before the backend renamed a value
  /// should show no spice rather than fail the whole receipt.
  static SpiceLevel? tryParse(Object? value) => switch (value
      ?.toString()
      .trim()
      .toLowerCase()) {
    'low' => low,
    'mid' || 'medium' => mid,
    'high' || 'hot' => high,
    _ => null,
  };
}
