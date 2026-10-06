// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AnyDay Alarm';

  @override
  String get homeEmptyTitle => 'No alarms yet';

  @override
  String get homeEmptySubtitle =>
      'Tap + to add your first alarm\nPick any date and any time';

  @override
  String get homePermissionBannerTitle =>
      'Allow the \"Alarms & reminders\" permission';

  @override
  String get homePermissionBannerBody =>
      'Without it, alarms cannot ring at the exact time';

  @override
  String get homePermissionBannerAction => 'Enable';

  @override
  String get homeBatteryBannerTitle => 'Consider ignoring battery optimization';

  @override
  String get homeBatteryBannerBody =>
      'Some phones may prevent alarms from ringing on time';

  @override
  String homeNextRingLabel(String time) {
    return 'Next ring: $time';
  }

  @override
  String get repeatTypeOnce => 'Specific date';

  @override
  String get repeatTypeDaily => 'Every day';

  @override
  String get repeatTypeWeekly => 'Weekly';

  @override
  String get repeatTypeYearly => 'Yearly';

  @override
  String get repeatTypeMonthly => 'Monthly';

  @override
  String get calendarBasis => 'Calendar';

  @override
  String get calendarSolar => 'Solar';

  @override
  String get calendarLunar => 'Lunar';

  @override
  String repeatYearlySolar(int m, int d) {
    return 'Yearly on $m/$d';
  }

  @override
  String repeatYearlyLunar(String date) {
    return 'Yearly lunar $date';
  }

  @override
  String repeatMonthlySolar(int d) {
    return 'Monthly on day $d';
  }

  @override
  String repeatMonthlyLunar(String day) {
    return 'Monthly lunar $day';
  }

  @override
  String lunarDateLabel(String date) {
    return 'Lunar $date';
  }

  @override
  String get lunarLeapMonthSwitch => 'Leap month';

  @override
  String lunarLeapMonthHint(String month) {
    return 'Only in years with a leap $month';
  }

  @override
  String lunarDatePreview(String date) {
    return 'Solar date: $date';
  }

  @override
  String get lunarNoSolarDate => 'Cannot resolve the selected lunar date';

  @override
  String get lunarPickerYear => 'Year';

  @override
  String get lunarPickerMonth => 'Month';

  @override
  String get lunarPickerDay => 'Day';

  @override
  String get repeatNever => 'One time';

  @override
  String get repeatEveryDay => 'Every day';

  @override
  String repeatWeekdays(String days) {
    return 'Weekly on $days';
  }

  @override
  String get weekdayMon => 'Mon';

  @override
  String get weekdayTue => 'Tue';

  @override
  String get weekdayWed => 'Wed';

  @override
  String get weekdayThu => 'Thu';

  @override
  String get weekdayFri => 'Fri';

  @override
  String get weekdaySat => 'Sat';

  @override
  String get weekdaySun => 'Sun';

  @override
  String get weekdayMonShort => 'M';

  @override
  String get weekdayTueShort => 'T';

  @override
  String get weekdayWedShort => 'W';

  @override
  String get weekdayThuShort => 'T';

  @override
  String get weekdayFriShort => 'F';

  @override
  String get weekdaySatShort => 'S';

  @override
  String get weekdaySunShort => 'S';

  @override
  String get editTitleNew => 'New alarm';

  @override
  String get editTitleExisting => 'Edit alarm';

  @override
  String get editLabelHint => 'Label (e.g. Product launch)';

  @override
  String get editSectionRepeat => 'Repeat';

  @override
  String get editRingDate => 'Ring date';

  @override
  String get editSectionRingtone => 'Sound';

  @override
  String get editRingtoneDefault => 'System default';

  @override
  String get editRingtonePick => 'Choose local audio…';

  @override
  String get ringtoneClassic => 'Classic';

  @override
  String get ringtoneDigital => 'Digital pulse';

  @override
  String get ringtoneChime => 'Morning chime';

  @override
  String get ringtoneRise => 'Rising tone';

  @override
  String get editSectionSnooze => 'Snooze';

  @override
  String get editSnoozeOff => 'Snooze disabled';

  @override
  String editSnoozeMinutes(int minutes, int count) {
    return '$minutes min each time, up to $count times';
  }

  @override
  String get editSectionBehavior => 'Ring behavior';

  @override
  String get editVolumeRamp => 'Gradual volume';

  @override
  String get editVolumeRampSubtitle =>
      'Start silent and ramp up to full volume';

  @override
  String get editVibrate => 'Vibrate';

  @override
  String get editSectionColor => 'Label color';

  @override
  String get editSnoozeInterval => 'Snooze interval';

  @override
  String editSnoozeIntervalUnit(int minutes) {
    return '$minutes min';
  }

  @override
  String get editSnoozeCount => 'Snooze count';

  @override
  String editSnoozeCountUnit(int count) {
    return '$count times';
  }

  @override
  String get editSave => 'Save';

  @override
  String get editDelete => 'Delete';

  @override
  String get editDeleteConfirmTitle => 'Delete alarm?';

  @override
  String editDeleteConfirmBody(String label) {
    return '\"$label\" will be permanently deleted.';
  }

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonOk => 'OK';

  @override
  String get ringSnooze => 'Snooze';

  @override
  String get ringStop => 'Stop';

  @override
  String get ringAlarmLabel => 'Alarm';

  @override
  String get permissionExactTitle => 'Allow exact alarms';

  @override
  String get permissionExactBody =>
      'To ring at the exact date and time you pick, this app needs the \"Alarms & reminders\" permission. Please allow it in system settings.';

  @override
  String get permissionGoSettings => 'Open settings';

  @override
  String get errorDateRequired => 'Please pick a ring date';

  @override
  String get errorDatePast => 'The ring date and time must be in the future';

  @override
  String get errorPickRingtone => 'Failed to pick audio file';

  @override
  String get toastSaved => 'Saved';

  @override
  String get toastDeleted => 'Deleted';

  @override
  String toastSnoozed(int minutes) {
    return 'Snoozed for $minutes minutes';
  }
}
