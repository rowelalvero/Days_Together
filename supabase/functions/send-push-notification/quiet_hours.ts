export type QuietHoursPreferences = {
  quiet_hours_enabled: boolean;
  quiet_hours_start: string;
  quiet_hours_end: string;
  timezone: string;
};

function minutesFromClock(value: string): number {
  if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(value)) {
    throw new RangeError('Invalid quiet-hours time');
  }
  const [hour, minute] = value.split(':').map(Number);
  return hour * 60 + minute;
}

export function isWithinQuietHours(
  prefs: QuietHoursPreferences,
  now: Date = new Date(),
): boolean {
  if (!prefs.quiet_hours_enabled) return false;

  try {
    const formatter = new Intl.DateTimeFormat('en-US', {
      timeZone: prefs.timezone,
      hour: '2-digit',
      minute: '2-digit',
      hourCycle: 'h23',
    });
    const parts = formatter.formatToParts(now);
    const hour = Number(parts.find((part) => part.type === 'hour')?.value);
    const minute = Number(parts.find((part) => part.type === 'minute')?.value);
    if (!Number.isInteger(hour) || !Number.isInteger(minute)) {
      throw new RangeError('Cannot read local time');
    }

    const current = hour * 60 + minute;
    const start = minutesFromClock(prefs.quiet_hours_start);
    const end = minutesFromClock(prefs.quiet_hours_end);
    if (start < end) return current >= start && current <= end;
    return current >= start || current <= end;
  } catch {
    // Legacy clients stored abbreviations such as "PDT" that Intl rejects.
    // Respect enabled quiet hours until a new client writes an IANA id.
    return true;
  }
}
