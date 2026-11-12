import '../logging/app_logger.dart';
import 'app_failure.dart';

const _log = AppLogger('data');

/// Runs a data-layer call and converts anything it throws into an
/// [AppFailure], logging the technical cause once.
///
/// Repositories wrap every network call with this, so the layers above only
/// ever see user-safe failures.
Future<T> guard<T>(String operation, Future<T> Function() body) async {
  try {
    return await body();
  } catch (error, stackTrace) {
    final failure = AppFailure.from(error);
    _log.warning(
      'operation failed',
      fields: {'operation': operation, 'kind': failure.kind.name, 'code': failure.code},
      error: error,
    );
    Error.throwWithStackTrace(failure, stackTrace);
  }
}
