import 'package:supabase_flutter/supabase_flutter.dart';

/// Edge Functions in this app always respond with { "error": "..." } on failure -
/// pulls that message out of a FunctionException, falling back to a generic message.
String edgeFunctionErrorMessage(Object error) {
  if (error is FunctionException && error.details is Map && (error.details as Map)['error'] is String) {
    return (error.details as Map)['error'] as String;
  }
  return 'Something went wrong. Please try again.';
}
