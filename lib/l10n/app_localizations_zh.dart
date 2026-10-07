// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '任意日期闹钟';

  @override
  String get homeEmptyTitle => '还没有闹钟';

  @override
  String get homeEmptySubtitle => '点击右下角 + 添加第一个闹钟\n支持指定任意日期任意时间';

  @override
  String get homePermissionBannerTitle => '需要开启「闹钟和提醒」权限';

  @override
  String get homePermissionBannerBody => '没有该权限，闹钟将无法在精确时间响铃';

  @override
  String get homePermissionBannerAction => '去开启';

  @override
  String get homeBatteryBannerTitle => '建议忽略电池优化';

  @override
  String get homeBatteryBannerBody => '部分手机会阻止闹钟准时响铃';

  @override
  String get homeFullscreenBannerTitle => '锁屏全屏提醒被关闭';

  @override
  String get homeFullscreenBannerBody => '开启后响铃界面才能在锁屏上直接弹出';

  @override
  String get homeAutoStartBannerTitle => '建议允许自启动';

  @override
  String get homeAutoStartBannerBody => '此机型清理后台后会拦截闹钟拉起，允许自启动可保证准时响铃';

  @override
  String get homeBannerDismiss => '不再提醒';

  @override
  String homeNextRingLabel(String time) {
    return '下次响铃：$time';
  }

  @override
  String get repeatTypeOnce => '指定日期';

  @override
  String get repeatTypeDaily => '每天';

  @override
  String get repeatTypeWeekly => '每周';

  @override
  String get repeatTypeYearly => '每年';

  @override
  String get repeatTypeMonthly => '每月';

  @override
  String get calendarBasis => '日历';

  @override
  String get calendarSolar => '公历';

  @override
  String get calendarLunar => '农历';

  @override
  String repeatYearlySolar(int m, int d) {
    return '每年 $m 月 $d 日';
  }

  @override
  String repeatYearlyLunar(String date) {
    return '每年农历$date';
  }

  @override
  String repeatMonthlySolar(int d) {
    return '每月 $d 日';
  }

  @override
  String repeatMonthlyLunar(String day) {
    return '每月农历$day';
  }

  @override
  String lunarDateLabel(String date) {
    return '农历$date';
  }

  @override
  String get lunarLeapMonthSwitch => '闰月';

  @override
  String lunarLeapMonthHint(String month) {
    return '仅在闰$month月年份触发';
  }

  @override
  String lunarDatePreview(String date) {
    return '对应公历：$date';
  }

  @override
  String get lunarNoSolarDate => '所选农历日期无法换算';

  @override
  String get lunarPickerYear => '年';

  @override
  String get lunarPickerMonth => '月';

  @override
  String get lunarPickerDay => '日';

  @override
  String get repeatNever => '不重复';

  @override
  String get repeatEveryDay => '每天';

  @override
  String repeatWeekdays(String days) {
    return '每周$days';
  }

  @override
  String get weekdayMon => '周一';

  @override
  String get weekdayTue => '周二';

  @override
  String get weekdayWed => '周三';

  @override
  String get weekdayThu => '周四';

  @override
  String get weekdayFri => '周五';

  @override
  String get weekdaySat => '周六';

  @override
  String get weekdaySun => '周日';

  @override
  String get weekdayMonShort => '一';

  @override
  String get weekdayTueShort => '二';

  @override
  String get weekdayWedShort => '三';

  @override
  String get weekdayThuShort => '四';

  @override
  String get weekdayFriShort => '五';

  @override
  String get weekdaySatShort => '六';

  @override
  String get weekdaySunShort => '日';

  @override
  String get editTitleNew => '新建闹钟';

  @override
  String get editTitleExisting => '编辑闹钟';

  @override
  String get editLabelHint => '标签（如：产品发布会）';

  @override
  String get editSectionRepeat => '重复';

  @override
  String get editRingDate => '响铃日期';

  @override
  String get editSectionRingtone => '铃声';

  @override
  String get editRingtoneDefault => '系统默认';

  @override
  String get editRingtonePick => '选择本地音频…';

  @override
  String get ringtoneClassic => '经典铃声';

  @override
  String get ringtoneDigital => '电子脉冲';

  @override
  String get ringtoneChime => '清晨编钟';

  @override
  String get ringtoneRise => '渐强鸟鸣';

  @override
  String get editSectionSnooze => '贪睡';

  @override
  String get editSnoozeOff => '不允许贪睡';

  @override
  String editSnoozeMinutes(int minutes, int count) {
    return '每次 $minutes 分钟，最多 $count 次';
  }

  @override
  String get editSectionBehavior => '响铃行为';

  @override
  String get editVolumeRamp => '音量渐强';

  @override
  String get editVolumeRampSubtitle => '从静音逐渐增强到最大音量';

  @override
  String get editVibrate => '震动';

  @override
  String get editSectionColor => '标签颜色';

  @override
  String get editSnoozeInterval => '贪睡间隔';

  @override
  String editSnoozeIntervalUnit(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String get editSnoozeCount => '贪睡次数';

  @override
  String editSnoozeCountUnit(int count) {
    return '$count 次';
  }

  @override
  String get editSave => '保存';

  @override
  String get editDelete => '删除';

  @override
  String get editDeleteConfirmTitle => '删除闹钟？';

  @override
  String editDeleteConfirmBody(String label) {
    return '「$label」将被永久删除。';
  }

  @override
  String get commonCancel => '取消';

  @override
  String get commonOk => '确定';

  @override
  String get ringSnooze => '贪睡';

  @override
  String get ringStop => '停止';

  @override
  String get ringAlarmLabel => '闹钟';

  @override
  String get permissionExactTitle => '授权精确闹钟';

  @override
  String get permissionExactBody =>
      '为了让闹钟在你指定的日期和时间准时响铃，需要「闹钟和提醒」权限。请在系统设置中允许本应用。';

  @override
  String get permissionGoSettings => '前往设置';

  @override
  String get errorDateRequired => '请选择响铃日期';

  @override
  String get errorDatePast => '响铃日期和时间必须晚于当前时间';

  @override
  String get errorPickRingtone => '选择音频文件失败';

  @override
  String get toastSaved => '已保存';

  @override
  String get toastDeleted => '已删除';

  @override
  String toastSnoozed(int minutes) {
    return '已贪睡 $minutes 分钟';
  }
}
