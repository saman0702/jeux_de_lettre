# WorkManager (google_mobile_ads / play-services-ads) — évite le crash au
# démarrage en release : Unable to get provider InitializationProvider.
-keep class androidx.work.** { *; }
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
