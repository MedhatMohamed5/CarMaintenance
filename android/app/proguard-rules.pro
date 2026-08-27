# Flutter and its plugins ship their own consumer rules; this file exists for
# anything this app needs on top of them.

# flutter_local_notifications keeps its scheduled-notification receivers alive
# by name, so shrinking must not rename or drop them.
-keep class com.dexterous.** { *; }

# Firestore and Auth serialise through reflection on model fields.
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
}

# Keep the line numbers that make a Play Console crash report readable, while
# still obfuscating names.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
