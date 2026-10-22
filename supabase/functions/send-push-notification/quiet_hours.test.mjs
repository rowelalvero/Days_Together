import test from 'node:test';
import assert from 'node:assert/strict';
import { isWithinQuietHours } from './quiet_hours.ts';

const overnight = {
  quiet_hours_enabled: true,
  quiet_hours_start: '22:00',
  quiet_hours_end: '07:00',
  timezone: 'Asia/Singapore',
};

test('quiet hours use the recipient local time across midnight', () => {
  assert.equal(isWithinQuietHours(overnight, new Date('2026-09-26T15:00:00Z')), true);
  assert.equal(isWithinQuietHours(overnight, new Date('2026-09-26T04:00:00Z')), false);
});

test('a daylight-saving zone is evaluated using its IANA rules', () => {
  const prefs = { ...overnight, timezone: 'America/New_York' };
  assert.equal(isWithinQuietHours(prefs, new Date('2026-01-15T04:00:00Z')), true);
  assert.equal(isWithinQuietHours(prefs, new Date('2026-07-15T04:00:00Z')), true);
  assert.equal(isWithinQuietHours(prefs, new Date('2026-07-15T16:00:00Z')), false);
});

test('invalid legacy zones suppress pushes while quiet hours are enabled', () => {
  assert.equal(isWithinQuietHours({ ...overnight, timezone: 'PDT' }), true);
  assert.equal(
    isWithinQuietHours({ ...overnight, quiet_hours_enabled: false, timezone: 'PDT' }),
    false,
  );
});
