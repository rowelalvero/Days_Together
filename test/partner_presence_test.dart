// The presence channel's client/server contract (re-audit R-02 / audit F-13).
//
// The authorisation itself is tested against the database in
// supabase/tests/011_realtime_presence.sql. What a database test cannot see
// is the client: that it joins the channel as PRIVATE (a public channel is
// never authorised at all) and uses exactly the topic shape the policy
// admits. This pins both.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:days_together/core/session/partner_presence.dart';

void main() {
  test('the topic is the exact shape the realtime policy authorises', () {
    expect(presenceTopicFor('abc-123'), 'couple_presence_abc-123');

    final policy = File(
      'supabase/migrations/20261003030000_private_couple_presence.sql',
    ).readAsStringSync();
    expect(policy, contains("p_topic = 'couple_presence_' || c.id::text"));
  });

  test('PartnerPresence joins the channel as private', () {
    final source = File(
      'lib/core/session/partner_presence.dart',
    ).readAsStringSync();
    expect(source, contains('RealtimeChannelConfig(private: true)'));
    expect(source, contains('presenceTopicFor(coupleId)'));
  });
}
