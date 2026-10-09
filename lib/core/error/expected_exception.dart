/// An exception that is a normal outcome of something the user did — picking
/// a file that is not a vehicle backup, say — rather than a fault in the app.
///
/// The UI still turns it into a message; what changes is that
/// `CrashReportingObserver` does not send it. Riverpod parks every thrown
/// error in an `AsyncError` the same way, so without this marker a driver
/// choosing the wrong file was filed in Sentry next to real crashes, and the
/// issue list filled up with events nobody can fix.
///
/// Implement it only on exceptions whose every instance is the user's doing.
/// An exception that is sometimes a bug must stay unmarked.
abstract interface class ExpectedException implements Exception {}
