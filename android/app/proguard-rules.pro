# Flutter and its plugins ship their own consumer rules; this file exists for
# anything this app needs on top of them.

# flutter_local_notifications keeps its scheduled-notification receivers alive
# by name, so shrinking must not rename or drop them.
-keep class com.dexterous.** { *; }

# The plugin persists its pending notifications as JSON through Gson, and Gson
# reads the generic type argument off an anonymous TypeToken subclass at
# runtime:
#
#     new TypeToken<ArrayList<NotificationDetails>>() {}.getType()
#
# Keeping the *class* is not enough — that erased argument lives in the
# Signature attribute, which R8 drops by default. Without it the boot receiver
# throws "TypeToken must be created with a type argument" and dies, so every
# scheduled reminder is lost on reboot. The plugin ships no consumer rules of
# its own, so this has to live here.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep public class * implements java.lang.reflect.Type
-dontwarn sun.misc.**

# Firestore and Auth serialise through reflection on model fields.
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
}

# Keep the line numbers that make a Play Console crash report readable, while
# still obfuscating names.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
