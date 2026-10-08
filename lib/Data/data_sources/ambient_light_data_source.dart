import 'package:light/light.dart';

/// The phone's ambient light sensor (Android `Sensor.TYPE_LIGHT`) through the light plugin.
/// The sensor reports only when the value changes; a phone without one never reports.
class AmbientLightDataSource {
  Stream<double> luxReadings() =>
      Light().lightSensorStream.where((lux) => lux >= 0).map((lux) => lux.toDouble());
}
