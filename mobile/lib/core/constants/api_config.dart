/// Base URL of the Letter Battle API.
///
/// Override at build time: `flutter run --dart-define=API_BASE_URL=http://192.168.1.88:8010`
/// Default targets the host machine from the Android emulator.
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8010',
);
