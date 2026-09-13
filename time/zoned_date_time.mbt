// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
/// A datetime with a time zone and offset in the ISO 8601 calendar system.
struct ZonedDateTime {
  datetime : PlainDateTime
  zone : Zone
  offset : ZoneOffset
} derive(Debug)

///|
/// Creates a ZonedDateTime from year, month, day, hour, minute, second and a time zone.
/// The default time zone is UTC+0.
pub fn date_time(
  year : Int,
  month : Int,
  day : Int,
  hour? : Int = 0,
  minute? : Int = 0,
  second? : Int = 0,
  nanosecond? : Int = 0,
  zone? : Zone = utc_zone,
) -> ZonedDateTime raise Error {
  ZonedDateTime::of(
    year,
    month,
    day,
    hour~,
    minute~,
    second~,
    nanosecond~,
    zone~,
  )
}

///|
/// Creates a ZonedDateTime from elapsed seconds since the unix epoch and a time zone.
/// The default time zone is UTC+0.
pub fn unix(
  second : Int64,
  nanosecond? : Int = 0,
  zone? : Zone = utc_zone,
) -> ZonedDateTime raise Error {
  ZonedDateTime::from_unix_second(second, nanosecond~, zone~)
}

///|
/// Creates a ZonedDateTime from year, month, day, hour, minute and second.
/// The default time zone is UTC+0.
pub fn ZonedDateTime::of(
  year : Int,
  month : Int,
  day : Int,
  hour? : Int = 0,
  minute? : Int = 0,
  second? : Int = 0,
  nanosecond? : Int = 0,
  zone? : Zone = utc_zone,
) -> ZonedDateTime raise Error {
  let datetime = PlainDateTime::of(
    year,
    month,
    day,
    hour~,
    minute~,
    second~,
    nanosecond~,
  )
  create_from_plain(datetime, zone)
}

///|
/// Creates a ZonedDateTime from a PlainDateTime and a time zone.
/// The default time zone is UTC+0.
pub fn ZonedDateTime::from_plain_datetime(
  datetime : PlainDateTime,
  zone? : Zone = utc_zone,
) -> ZonedDateTime {
  create_from_plain(datetime, zone)
}

///|
/// Creates a ZonedDateTime from elapsed seconds since the unix epoch and a time zone.
/// The default time zone is UTC+0.
pub fn ZonedDateTime::from_unix_second(
  second : Int64,
  nanosecond? : Int = 0,
  zone? : Zone = utc_zone,
) -> ZonedDateTime raise Error {
  let offset = zone.lookup_offset(second)
  let datetime = PlainDateTime::from_unix_second(second, nanosecond, offset)
  { datetime, zone, offset, }
}

///|
/// Returns a string representing this datetime, like "2008-08-08T20:00:00+8:00[Asia/Beijing]"
pub fn ZonedDateTime::to_string(self : ZonedDateTime) -> String {
  let buf = StringBuilder(size_hint=0)
  buf.write_string(self.datetime.to_string())
  buf.write_string(self.offset.to_string())
  if self.zone != utc_zone && self.zone.id != "" {
    buf.write_char('[')
    let abbrev = self.offset.abbreviation()
    if abbrev == "" {
      buf.write_string(self.zone.to_string())
    } else {
      buf.write_string(abbrev)
    }
    buf.write_char(']')
  }
  buf.to_string()
}

///|
pub impl @string.FromStr for ZonedDateTime with fn from_str(str) {
  ZonedDateTime::parse_str(str)
}

///|
/// Parses a RFC 3339 string with an optional bracketed time zone id, like
/// `2008-08-08T20:00:00Z`, `2008-08-08T20:00:00Z[UTC]`,
/// `2008-08-08T20:00:00+08:00[Asia/Shanghai]` or
/// `2008-08-08T20:00:00.123456789+08:00[Asia/Shanghai]`.
///
/// The offset is required. The bracketed id is represented as a fixed-offset
/// zone built from the parsed offset; this function does not look up the
/// IANA/TZData rules of the id. A value without a bracketed id carries a zone
/// with an empty id.
pub fn ZonedDateTime::parse_str(str : StringView) -> ZonedDateTime raise Error {
  guard str.length() >= 20 else { fail(invalid_zoned_date_time_err) }
  // `[-]YYYY-MM-DDTHH:MM:SS`, optionally followed by fractional seconds.
  lexmatch str with longest {
    // 2008-08-08T20:00:00Z, 2008-08-08T20:00:00.123456789Z
    (re"^-?[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:\.]{8,}" as _plain_datetime) +
    re"Z$" => {
      let date_time = PlainDateTime::parse_str(_plain_datetime) catch {
        _ => fail(invalid_zoned_date_time_err)
      }
      ZonedDateTime::{
        datetime: date_time,
        zone: utc_zone,
        offset: utc_offset,
      }
    }
    // 2008-08-08T20:00:00Z[UTC], 2008-08-08T20:00:00.123456789Z[Asia/Shanghai]
    (re"^-?[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:\.]{8,}" as _plain_datetime) +
    (re"Z\[[^\[\]]+\]$" as _zone) => {
      // `to_string` renders a zero offset as `Z` followed by the bracketed
      // abbreviation, so `Z[...]` values have to be readable back.
      let date_time = PlainDateTime::parse_str(_plain_datetime) catch {
        _ => fail(invalid_zoned_date_time_err)
      }
      let zone = parse_zone(_zone, utc_offset)
      ZonedDateTime::{ datetime: date_time, zone, offset: utc_offset, }
    }
    // 2008-08-08T20:00:00.123456789+08:00, 2008-08-08T20:00:00+08:00
    (re"^-?[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:\.]{8,}" as _plain_datetime) +
    (re"[+\-:0-9]{6}$" as _zone_offset) => {
      let date_time = PlainDateTime::parse_str(_plain_datetime) catch {
        _ => fail(invalid_zoned_date_time_err)
      }
      let offset = ZoneOffset::parse_str(_zone_offset) catch {
        _ => fail(invalid_zoned_date_time_err)
      }
      // The parsed offset is the only offset of the zone, so calculations do
      // not shift the instant. The empty id marks a value without a bracketed
      // zone id.
      let zone = Zone::fixed_zone("", offset.seconds())
      ZonedDateTime::{ datetime: date_time, zone, offset, }
    }
    // 2008-08-08T20:00:00.123456789+08:00[Asia/Shanghai], 2026-09-12T14:30:00-05:00[America/New_York]
    (re"^-?[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:\.]{8,}" as _plain_datetime) +
    (re"[+\-:0-9]{6}" as _zone_offset) +
    (re"\[[^\[\]]+\]$" as _zone) => {
      let date_time = PlainDateTime::parse_str(_plain_datetime) catch {
        _ => fail(invalid_zoned_date_time_err)
      }
      let offset = ZoneOffset::parse_str(_zone_offset) catch {
        _ => fail(invalid_zoned_date_time_err)
      }
      let zone = parse_zone(_zone, offset)
      ZonedDateTime::{ datetime: date_time, zone, offset, }
    }
    _ => fail(invalid_zoned_date_time_err)
  }
}

///|
/// Parses a bracketed zone annotation like `[Asia/Shanghai]`, or the `Z[UTC]`
/// form, into a fixed-offset zone built from `offset`.
fn parse_zone(str : StringView, offset : ZoneOffset) -> Zone raise {
  lexmatch str with longest {
    re"^Z?\[" + (re"[^\[\]]{2,}" as zone_id) + re"\]$" =>
      Zone::fixed_zone(zone_id.to_owned(), offset.seconds())
    _ => fail(invalid_zoned_date_time_err)
  }
}

///|
pub impl Show for ZonedDateTime with fn output(
  self : ZonedDateTime,
  logger : &Logger,
) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl ToJson for ZonedDateTime with fn to_json(self : ZonedDateTime) -> Json {
  Json(self.to_string())
}

///|
pub impl FromJson for ZonedDateTime with fn from_json(json, path) -> ZonedDateTime raise {
  guard json is Json::String(str) else {
    raise @json.JsonDecodeError(
      (path, "ZonedDateTime: expected string \{Repr(json)}"),
    )
  }
  let zdt : ZonedDateTime = @string.FromStr::from_str(str) catch {
    _e =>
      raise @json.JsonDecodeError(
        (path, "ZonedDateTime: Invalid RFC3339 string \{str}"),
      )
  }
  zdt
}

///|
/// Two datetimes are equal when they denote the same instant; see `Compare`.
pub impl Eq for ZonedDateTime with fn equal(
  self : ZonedDateTime,
  other : ZonedDateTime,
) -> Bool {
  Compare::compare(self, other) == 0
}

///|
/// Compares two datetimes by the instant they denote.
///
/// The zone and offset are not part of the comparison: two datetimes denoting
/// the same instant are equal even when they are in different zones.
/// Nanoseconds are significant.
pub impl Compare for ZonedDateTime with fn compare(
  self : ZonedDateTime,
  other : ZonedDateTime,
) -> Int {
  let self_second = self.to_unix_second()
  let other_second = other.to_unix_second()
  if self_second > other_second {
    1
  } else if self_second < other_second {
    -1
  } else if self.nanosecond() > other.nanosecond() {
    1
  } else if self.nanosecond() < other.nanosecond() {
    -1
  } else {
    0
  }
}

///|
/// Returns the elapsed seconds since the unix epoch.
pub fn ZonedDateTime::to_unix_second(self : ZonedDateTime) -> Int64 {
  self.datetime.to_unix_second() - self.offset.seconds().to_int64()
}

///|
/// Returns the date part of this datetime, without timezone.
pub fn ZonedDateTime::to_plain_date(self : ZonedDateTime) -> PlainDate {
  self.datetime.to_plain_date()
}

///|
/// Returns the time part of this datetime, without timezone.
pub fn ZonedDateTime::to_plain_time(self : ZonedDateTime) -> PlainTime {
  self.datetime.to_plain_time()
}

///|
/// Returns the datetime part of this datetime, without timezone.
pub fn ZonedDateTime::to_plain_date_time(self : ZonedDateTime) -> PlainDateTime {
  self.datetime
}

///|
/// Returns the era of this datetime.
pub fn ZonedDateTime::era(self : ZonedDateTime) -> String {
  self.datetime.era()
}

///|
/// Returns the year of era of this datetime.
pub fn ZonedDateTime::era_year(self : ZonedDateTime) -> Int {
  self.datetime.era_year()
}

///|
/// Returns the year of this datetime.
pub fn ZonedDateTime::year(self : ZonedDateTime) -> Int {
  self.datetime.year()
}

///|
/// Returns the month of this datetime.
pub fn ZonedDateTime::month(self : ZonedDateTime) -> Int {
  self.datetime.month()
}

///|
/// Returns the day of month of this datetime.
pub fn ZonedDateTime::day(self : ZonedDateTime) -> Int {
  self.datetime.day()
}

///|
/// Returns the weekday of this datetime.
pub fn ZonedDateTime::weekday(self : ZonedDateTime) -> Weekday {
  self.datetime.weekday()
}

///|
/// Returns the ordinal day of year of this datetime.
pub fn ZonedDateTime::ordinal(self : ZonedDateTime) -> Int {
  self.datetime.ordinal()
}

///|
/// Returns the number of days in a month of this datetime.
pub fn ZonedDateTime::days_in_week(self : ZonedDateTime) -> Int {
  self.datetime.days_in_week()
}

///|
/// Returns the number of days in a month of this datetime.
pub fn ZonedDateTime::days_in_month(self : ZonedDateTime) -> Int {
  self.datetime.days_in_month()
}

///|
/// Returns the number of days in a year of this datetime.
pub fn ZonedDateTime::days_in_year(self : ZonedDateTime) -> Int {
  self.datetime.days_in_year()
}

///|
/// Returns the number of months in a year of this datetime.
pub fn ZonedDateTime::months_in_year(self : ZonedDateTime) -> Int {
  self.datetime.months_in_year()
}

///|
/// Checks if this datetime is in a leap year.
pub fn ZonedDateTime::in_leap_year(self : ZonedDateTime) -> Bool {
  self.datetime.in_leap_year()
}

///|
/// Returns the hour of this datetime.
pub fn ZonedDateTime::hour(self : ZonedDateTime) -> Int {
  self.datetime.hour()
}

///|
/// Returns the minute of this datetime.
pub fn ZonedDateTime::minute(self : ZonedDateTime) -> Int {
  self.datetime.minute()
}

///|
/// Returns the second of this datetime.
pub fn ZonedDateTime::second(self : ZonedDateTime) -> Int {
  self.datetime.second()
}

///|
/// Returns the nanosecond of this datetime.
pub fn ZonedDateTime::nanosecond(self : ZonedDateTime) -> Int {
  self.datetime.nanosecond()
}

///|
/// Returns the time zone of this datetime.
///
/// A datetime parsed from a string without a bracketed zone id carries a zone
/// with an empty id.
pub fn ZonedDateTime::zone(self : ZonedDateTime) -> Zone {
  self.zone
}

///|
/// Returns the time offset of this datetime.
pub fn ZonedDateTime::offset(self : ZonedDateTime) -> ZoneOffset {
  self.offset
}

///|
/// Adds specified years to this datetime, and returns a new datetime.
pub fn ZonedDateTime::add_years(
  self : ZonedDateTime,
  years : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.add_years(years), self.zone)
}

///|
/// Adds specified months to this datetime, and returns a new datetime.
pub fn ZonedDateTime::add_months(
  self : ZonedDateTime,
  months : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.add_months(months), self.zone)
}

///|
/// Adds specified weeks to this datetime, and returns a new datetime.
pub fn ZonedDateTime::add_weeks(
  self : ZonedDateTime,
  weeks : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.add_weeks(weeks), self.zone)
}

///|
/// Adds specified days to this datetime, and returns a new datetime.
pub fn ZonedDateTime::add_days(
  self : ZonedDateTime,
  days : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.add_days(days), self.zone)
}

///|
/// Adds specified hours to this datetime, and returns a new datetime.
pub fn ZonedDateTime::add_hours(
  self : ZonedDateTime,
  hours : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.add_hours(hours), self.zone)
}

///|
/// Adds specified minutes to this datetime, and returns a new datetime.
pub fn ZonedDateTime::add_minutes(
  self : ZonedDateTime,
  minutes : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.add_minutes(minutes), self.zone)
}

///|
/// Adds specified seconds to this datetime, and returns a new datetime.
pub fn ZonedDateTime::add_seconds(
  self : ZonedDateTime,
  seconds : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.add_seconds(seconds), self.zone)
}

///|
/// Adds specified nanoseconds to this datetime, and returns a new datetime.
pub fn ZonedDateTime::add_nanoseconds(
  self : ZonedDateTime,
  nanoseconds : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.add_nanoseconds(nanoseconds), self.zone)
}

///|
/// Returns a new datetime with the specified year.
pub fn ZonedDateTime::with_year(
  self : ZonedDateTime,
  year : Int,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.with_year(year), self.zone)
}

///|
/// Returns a new datetime with the specified month.
pub fn ZonedDateTime::with_month(
  self : ZonedDateTime,
  month : Int,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.with_month(month), self.zone)
}

///|
/// Returns a new datetime with the specified day of the month.
pub fn ZonedDateTime::with_day(
  self : ZonedDateTime,
  day : Int,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.with_day(day), self.zone)
}

///|
/// Returns a new datetime with the specified ordinal day of the year.
pub fn ZonedDateTime::with_ordinal(
  self : ZonedDateTime,
  ordinal : Int,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.with_ordinal(ordinal), self.zone)
}

///|
/// Returns a new datetime with the specified hour.
pub fn ZonedDateTime::with_hour(
  self : ZonedDateTime,
  hour : Int,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.with_hour(hour), self.zone)
}

///|
/// Returns a new datetime with the specified minute.
pub fn ZonedDateTime::with_minute(
  self : ZonedDateTime,
  minute : Int,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.with_minute(minute), self.zone)
}

///|
/// Returns a new datetime with the specified second.
pub fn ZonedDateTime::with_second(
  self : ZonedDateTime,
  second : Int,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.with_second(second), self.zone)
}

///|
/// Returns a new datetime with the specified nanosecond.
pub fn ZonedDateTime::with_nanosecond(
  self : ZonedDateTime,
  nanosecond : Int,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.with_nanosecond(nanosecond), self.zone)
}

///|
fn create_from_plain(datetime : PlainDateTime, zone : Zone) -> ZonedDateTime {
  let offset = zone.lookup_offset(datetime.to_unix_second())
  { datetime, zone, offset, }
}

///|
#deprecated
pub extend ZonedDateTime with Debug::{to_repr}

///|
#deprecated
pub extend ZonedDateTime with Show::{output}
