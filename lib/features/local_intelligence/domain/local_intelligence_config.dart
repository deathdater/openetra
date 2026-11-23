import 'package:equatable/equatable.dart';

/// Retention policy options in days (`0` means keep until manually deleted).
class HistoryRetentionOptions {
  const HistoryRetentionOptions._();

  static const int sevenDays = 7;
  static const int thirtyDays = 30;
  static const int ninetyDays = 90;
  static const int manualOnly = 0;

  static const List<int> all = [sevenDays, thirtyDays, ninetyDays, manualOnly];

  static String labelFor(int days) {
    switch (days) {
      case sevenDays:
        return '7 days';
      case thirtyDays:
        return '30 days';
      case ninetyDays:
        return '90 days';
      case manualOnly:
        return 'Keep until manually deleted';
      default:
        return '$days days';
    }
  }
}

/// Independent configuration boundary for Openetra Local Intelligence (Beta).
/// Strictly disabled by default so existing Openetra features remain unaffected.
class LocalIntelligenceConfig extends Equatable {
  const LocalIntelligenceConfig({
    this.enabled = false,
    this.historyEnabled = false,
    this.summariesEnabled = false,
    this.wifiOnlyDownload = true,
    this.retentionDays = HistoryRetentionOptions.thirtyDays,
    this.activeModelId,
    this.privacyNoticeAccepted = false,
  });

  final bool enabled;
  final bool historyEnabled;
  final bool summariesEnabled;
  final bool wifiOnlyDownload;
  final int retentionDays;
  final String? activeModelId;
  final bool privacyNoticeAccepted;

  bool get canCollectHistory => enabled && historyEnabled;
  bool get canRunAiSummaries =>
      enabled && summariesEnabled && activeModelId != null;

  LocalIntelligenceConfig copyWith({
    bool? enabled,
    bool? historyEnabled,
    bool? summariesEnabled,
    bool? wifiOnlyDownload,
    int? retentionDays,
    String? activeModelId,
    bool clearActiveModel = false,
    bool? privacyNoticeAccepted,
  }) {
    return LocalIntelligenceConfig(
      enabled: enabled ?? this.enabled,
      historyEnabled: historyEnabled ?? this.historyEnabled,
      summariesEnabled: summariesEnabled ?? this.summariesEnabled,
      wifiOnlyDownload: wifiOnlyDownload ?? this.wifiOnlyDownload,
      retentionDays: retentionDays ?? this.retentionDays,
      activeModelId:
          clearActiveModel ? null : (activeModelId ?? this.activeModelId),
      privacyNoticeAccepted:
          privacyNoticeAccepted ?? this.privacyNoticeAccepted,
    );
  }

  static const String prefEnabled = 'li_enabled';
  static const String prefHistoryEnabled = 'li_history_enabled';
  static const String prefSummariesEnabled = 'li_summaries_enabled';
  static const String prefWifiOnly = 'li_wifi_only';
  static const String prefRetentionDays = 'li_retention_days';
  static const String prefActiveModelId = 'li_active_model_id';
  static const String prefPrivacyAccepted = 'li_privacy_accepted';

  @override
  List<Object?> get props => [
        enabled,
        historyEnabled,
        summariesEnabled,
        wifiOnlyDownload,
        retentionDays,
        activeModelId,
        privacyNoticeAccepted,
      ];
}
