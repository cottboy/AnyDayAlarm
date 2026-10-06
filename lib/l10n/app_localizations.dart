import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'任意日期闹钟'**
  String get appTitle;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有闹钟'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'点击右下角 + 添加第一个闹钟\n支持指定任意日期任意时间'**
  String get homeEmptySubtitle;

  /// No description provided for @homePermissionBannerTitle.
  ///
  /// In zh, this message translates to:
  /// **'需要开启「闹钟和提醒」权限'**
  String get homePermissionBannerTitle;

  /// No description provided for @homePermissionBannerBody.
  ///
  /// In zh, this message translates to:
  /// **'没有该权限，闹钟将无法在精确时间响铃'**
  String get homePermissionBannerBody;

  /// No description provided for @homePermissionBannerAction.
  ///
  /// In zh, this message translates to:
  /// **'去开启'**
  String get homePermissionBannerAction;

  /// No description provided for @homeBatteryBannerTitle.
  ///
  /// In zh, this message translates to:
  /// **'建议忽略电池优化'**
  String get homeBatteryBannerTitle;

  /// No description provided for @homeBatteryBannerBody.
  ///
  /// In zh, this message translates to:
  /// **'部分手机会阻止闹钟准时响铃'**
  String get homeBatteryBannerBody;

  /// No description provided for @homeNextRingLabel.
  ///
  /// In zh, this message translates to:
  /// **'下次响铃：{time}'**
  String homeNextRingLabel(String time);

  /// No description provided for @repeatTypeOnce.
  ///
  /// In zh, this message translates to:
  /// **'指定日期'**
  String get repeatTypeOnce;

  /// No description provided for @repeatTypeDaily.
  ///
  /// In zh, this message translates to:
  /// **'每天'**
  String get repeatTypeDaily;

  /// No description provided for @repeatTypeWeekly.
  ///
  /// In zh, this message translates to:
  /// **'每周'**
  String get repeatTypeWeekly;

  /// No description provided for @repeatTypeYearly.
  ///
  /// In zh, this message translates to:
  /// **'每年'**
  String get repeatTypeYearly;

  /// No description provided for @repeatTypeMonthly.
  ///
  /// In zh, this message translates to:
  /// **'每月'**
  String get repeatTypeMonthly;

  /// No description provided for @calendarBasis.
  ///
  /// In zh, this message translates to:
  /// **'日历'**
  String get calendarBasis;

  /// No description provided for @calendarSolar.
  ///
  /// In zh, this message translates to:
  /// **'公历'**
  String get calendarSolar;

  /// No description provided for @calendarLunar.
  ///
  /// In zh, this message translates to:
  /// **'农历'**
  String get calendarLunar;

  /// No description provided for @repeatYearlySolar.
  ///
  /// In zh, this message translates to:
  /// **'每年 {m} 月 {d} 日'**
  String repeatYearlySolar(int m, int d);

  /// No description provided for @repeatYearlyLunar.
  ///
  /// In zh, this message translates to:
  /// **'每年农历{date}'**
  String repeatYearlyLunar(String date);

  /// No description provided for @repeatMonthlySolar.
  ///
  /// In zh, this message translates to:
  /// **'每月 {d} 日'**
  String repeatMonthlySolar(int d);

  /// No description provided for @repeatMonthlyLunar.
  ///
  /// In zh, this message translates to:
  /// **'每月农历{day}'**
  String repeatMonthlyLunar(String day);

  /// No description provided for @lunarDateLabel.
  ///
  /// In zh, this message translates to:
  /// **'农历{date}'**
  String lunarDateLabel(String date);

  /// No description provided for @lunarLeapMonthSwitch.
  ///
  /// In zh, this message translates to:
  /// **'闰月'**
  String get lunarLeapMonthSwitch;

  /// No description provided for @lunarLeapMonthHint.
  ///
  /// In zh, this message translates to:
  /// **'仅在闰{month}月年份触发'**
  String lunarLeapMonthHint(String month);

  /// No description provided for @lunarDatePreview.
  ///
  /// In zh, this message translates to:
  /// **'对应公历：{date}'**
  String lunarDatePreview(String date);

  /// No description provided for @lunarNoSolarDate.
  ///
  /// In zh, this message translates to:
  /// **'所选农历日期无法换算'**
  String get lunarNoSolarDate;

  /// No description provided for @lunarPickerYear.
  ///
  /// In zh, this message translates to:
  /// **'年'**
  String get lunarPickerYear;

  /// No description provided for @lunarPickerMonth.
  ///
  /// In zh, this message translates to:
  /// **'月'**
  String get lunarPickerMonth;

  /// No description provided for @lunarPickerDay.
  ///
  /// In zh, this message translates to:
  /// **'日'**
  String get lunarPickerDay;

  /// No description provided for @repeatNever.
  ///
  /// In zh, this message translates to:
  /// **'不重复'**
  String get repeatNever;

  /// No description provided for @repeatEveryDay.
  ///
  /// In zh, this message translates to:
  /// **'每天'**
  String get repeatEveryDay;

  /// No description provided for @repeatWeekdays.
  ///
  /// In zh, this message translates to:
  /// **'每周{days}'**
  String repeatWeekdays(String days);

  /// No description provided for @weekdayMon.
  ///
  /// In zh, this message translates to:
  /// **'周一'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In zh, this message translates to:
  /// **'周二'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In zh, this message translates to:
  /// **'周三'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In zh, this message translates to:
  /// **'周四'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In zh, this message translates to:
  /// **'周五'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In zh, this message translates to:
  /// **'周六'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In zh, this message translates to:
  /// **'周日'**
  String get weekdaySun;

  /// No description provided for @weekdayMonShort.
  ///
  /// In zh, this message translates to:
  /// **'一'**
  String get weekdayMonShort;

  /// No description provided for @weekdayTueShort.
  ///
  /// In zh, this message translates to:
  /// **'二'**
  String get weekdayTueShort;

  /// No description provided for @weekdayWedShort.
  ///
  /// In zh, this message translates to:
  /// **'三'**
  String get weekdayWedShort;

  /// No description provided for @weekdayThuShort.
  ///
  /// In zh, this message translates to:
  /// **'四'**
  String get weekdayThuShort;

  /// No description provided for @weekdayFriShort.
  ///
  /// In zh, this message translates to:
  /// **'五'**
  String get weekdayFriShort;

  /// No description provided for @weekdaySatShort.
  ///
  /// In zh, this message translates to:
  /// **'六'**
  String get weekdaySatShort;

  /// No description provided for @weekdaySunShort.
  ///
  /// In zh, this message translates to:
  /// **'日'**
  String get weekdaySunShort;

  /// No description provided for @editTitleNew.
  ///
  /// In zh, this message translates to:
  /// **'新建闹钟'**
  String get editTitleNew;

  /// No description provided for @editTitleExisting.
  ///
  /// In zh, this message translates to:
  /// **'编辑闹钟'**
  String get editTitleExisting;

  /// No description provided for @editLabelHint.
  ///
  /// In zh, this message translates to:
  /// **'标签（如：产品发布会）'**
  String get editLabelHint;

  /// No description provided for @editSectionRepeat.
  ///
  /// In zh, this message translates to:
  /// **'重复'**
  String get editSectionRepeat;

  /// No description provided for @editRingDate.
  ///
  /// In zh, this message translates to:
  /// **'响铃日期'**
  String get editRingDate;

  /// No description provided for @editSectionRingtone.
  ///
  /// In zh, this message translates to:
  /// **'铃声'**
  String get editSectionRingtone;

  /// No description provided for @editRingtoneDefault.
  ///
  /// In zh, this message translates to:
  /// **'系统默认'**
  String get editRingtoneDefault;

  /// No description provided for @editRingtonePick.
  ///
  /// In zh, this message translates to:
  /// **'选择本地音频…'**
  String get editRingtonePick;

  /// No description provided for @ringtoneClassic.
  ///
  /// In zh, this message translates to:
  /// **'经典铃声'**
  String get ringtoneClassic;

  /// No description provided for @ringtoneDigital.
  ///
  /// In zh, this message translates to:
  /// **'电子脉冲'**
  String get ringtoneDigital;

  /// No description provided for @ringtoneChime.
  ///
  /// In zh, this message translates to:
  /// **'清晨编钟'**
  String get ringtoneChime;

  /// No description provided for @ringtoneRise.
  ///
  /// In zh, this message translates to:
  /// **'渐强鸟鸣'**
  String get ringtoneRise;

  /// No description provided for @editSectionSnooze.
  ///
  /// In zh, this message translates to:
  /// **'贪睡'**
  String get editSectionSnooze;

  /// No description provided for @editSnoozeOff.
  ///
  /// In zh, this message translates to:
  /// **'不允许贪睡'**
  String get editSnoozeOff;

  /// No description provided for @editSnoozeMinutes.
  ///
  /// In zh, this message translates to:
  /// **'每次 {minutes} 分钟，最多 {count} 次'**
  String editSnoozeMinutes(int minutes, int count);

  /// No description provided for @editSectionBehavior.
  ///
  /// In zh, this message translates to:
  /// **'响铃行为'**
  String get editSectionBehavior;

  /// No description provided for @editVolumeRamp.
  ///
  /// In zh, this message translates to:
  /// **'音量渐强'**
  String get editVolumeRamp;

  /// No description provided for @editVolumeRampSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'从静音逐渐增强到最大音量'**
  String get editVolumeRampSubtitle;

  /// No description provided for @editVibrate.
  ///
  /// In zh, this message translates to:
  /// **'震动'**
  String get editVibrate;

  /// No description provided for @editSectionColor.
  ///
  /// In zh, this message translates to:
  /// **'标签颜色'**
  String get editSectionColor;

  /// No description provided for @editSnoozeInterval.
  ///
  /// In zh, this message translates to:
  /// **'贪睡间隔'**
  String get editSnoozeInterval;

  /// No description provided for @editSnoozeIntervalUnit.
  ///
  /// In zh, this message translates to:
  /// **'{minutes} 分钟'**
  String editSnoozeIntervalUnit(int minutes);

  /// No description provided for @editSnoozeCount.
  ///
  /// In zh, this message translates to:
  /// **'贪睡次数'**
  String get editSnoozeCount;

  /// No description provided for @editSnoozeCountUnit.
  ///
  /// In zh, this message translates to:
  /// **'{count} 次'**
  String editSnoozeCountUnit(int count);

  /// No description provided for @editSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get editSave;

  /// No description provided for @editDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get editDelete;

  /// No description provided for @editDeleteConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除闹钟？'**
  String get editDeleteConfirmTitle;

  /// No description provided for @editDeleteConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'「{label}」将被永久删除。'**
  String editDeleteConfirmBody(String label);

  /// No description provided for @commonCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get commonCancel;

  /// No description provided for @commonOk.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get commonOk;

  /// No description provided for @ringSnooze.
  ///
  /// In zh, this message translates to:
  /// **'贪睡'**
  String get ringSnooze;

  /// No description provided for @ringStop.
  ///
  /// In zh, this message translates to:
  /// **'停止'**
  String get ringStop;

  /// No description provided for @ringAlarmLabel.
  ///
  /// In zh, this message translates to:
  /// **'闹钟'**
  String get ringAlarmLabel;

  /// No description provided for @permissionExactTitle.
  ///
  /// In zh, this message translates to:
  /// **'授权精确闹钟'**
  String get permissionExactTitle;

  /// No description provided for @permissionExactBody.
  ///
  /// In zh, this message translates to:
  /// **'为了让闹钟在你指定的日期和时间准时响铃，需要「闹钟和提醒」权限。请在系统设置中允许本应用。'**
  String get permissionExactBody;

  /// No description provided for @permissionGoSettings.
  ///
  /// In zh, this message translates to:
  /// **'前往设置'**
  String get permissionGoSettings;

  /// No description provided for @errorDateRequired.
  ///
  /// In zh, this message translates to:
  /// **'请选择响铃日期'**
  String get errorDateRequired;

  /// No description provided for @errorDatePast.
  ///
  /// In zh, this message translates to:
  /// **'响铃日期和时间必须晚于当前时间'**
  String get errorDatePast;

  /// No description provided for @errorPickRingtone.
  ///
  /// In zh, this message translates to:
  /// **'选择音频文件失败'**
  String get errorPickRingtone;

  /// No description provided for @toastSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get toastSaved;

  /// No description provided for @toastDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除'**
  String get toastDeleted;

  /// No description provided for @toastSnoozed.
  ///
  /// In zh, this message translates to:
  /// **'已贪睡 {minutes} 分钟'**
  String toastSnoozed(int minutes);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
