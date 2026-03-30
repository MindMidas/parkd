import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/host_earnings_row.dart';

// read-only public.host_earnings
class HostEarningsRemote {
  HostEarningsRemote(this._client);

  final SupabaseClient _client;

  Future<List<HostEarningsRow>> fetchForHost(String hostId) async {
    final rows = await _client
        .from('host_earnings')
        .select()
        .eq('host_id', hostId)
        .order('month', ascending: false);
    return (rows as List)
        .map((e) => HostEarningsRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
