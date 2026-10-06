import 'package:my_tide_monitor/models/station.dart';
import 'package:my_tide_monitor/models/us_states.dart';

extension StationText on Station {
  /// The state and station number on one line: "South Carolina • Station
  /// 8661070". The state is left out when the station doesn't have one.
  String get stateAndId {
    final hasState = state != null && state!.isNotEmpty;
    return [if (hasState) stateName(state!), 'Station $id'].join(' • ');
  }
}
