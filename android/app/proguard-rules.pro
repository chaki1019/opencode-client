# Flutter's Gradle plugin adds this file to the release build's R8 rules.

# WorkManager (pulled in by the Google Mobile Ads SDK and Firebase) opens its
# database at app start through Room, which creates WorkDatabase_Impl by
# reflection with its no-argument constructor. The keep rule shipped with the
# older Room in that dependency keeps the class but not the constructor, and
# R8 in full mode (the default since AGP 8) then removes it, so every launch
# crashed with "Failed to create an instance of androidx.work.impl.WorkDatabase".
-keep class * extends androidx.room.RoomDatabase {
    <init>();
}
