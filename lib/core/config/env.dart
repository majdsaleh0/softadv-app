import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  Env._();

  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ??
      (throw StateError('SUPABASE_URL is not set. Did you forget to load .env?'));

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ??
      (throw StateError('SUPABASE_ANON_KEY is not set. Did you forget to load .env?'));
}
