import 'package:supabase_flutter/supabase_flutter.dart';

/// Global Supabase client — import and use anywhere in the app:
/// import '../config/supabase_config.dart';
/// final data = await supabase.from('modules').select();
final supabase = Supabase.instance.client;
