/// URL de base de l'API Letter Race.
///
/// À changer à la compilation : `flutter run
/// --dart-define=API_BASE_URL=http://192.168.1.88:8010`
/// Par défaut, vise la machine hôte depuis l'émulateur Android.
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8010',
);
