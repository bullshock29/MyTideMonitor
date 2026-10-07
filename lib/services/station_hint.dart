/// What kind of water a station seems to be on, guessed from its name.
enum StationSetting {
  oceanCoast('Ocean coast'),
  harborOrBay('Harbor or bay'),
  waterway('Waterway');

  final String label;
  const StationSetting(this.label);
}

// Checked in this order, so a name with a strong ocean word ("Pier") wins
// over a weaker word that also appears ("Myrtle Beach, Combination Bridge"
// has no strong ocean word, so it falls through to "bridge" = waterway).
final _strongOcean = RegExp(r'\b(pier|ocean|oceanfront|jetty)\b');
final _waterway = RegExp(
  r'\b(icww|icw|intracoastal|waterway|creek|river|canal|bayou|slough|'
  r'channel|lock|bridge|landing)\b',
);
final _harborOrBay = RegExp(
  r'\b(harbor|harbour|bay|sound|basin|marina|cove|lagoon|inlet)\b',
);
final _weakOcean = RegExp(r'\b(beach|shore)\b');

/// A guess at the station's setting from its name, or null if the name gives
/// no clue. This is only a hint for display, since NOAA names are written by
/// people and aren't consistent. Don't use it for anything important.
StationSetting? guessSetting(String stationName) {
  final name = stationName.toLowerCase();

  if (_strongOcean.hasMatch(name)) return StationSetting.oceanCoast;
  if (_waterway.hasMatch(name)) return StationSetting.waterway;
  if (_harborOrBay.hasMatch(name)) return StationSetting.harborOrBay;
  if (_weakOcean.hasMatch(name)) return StationSetting.oceanCoast;
  return null;
}
