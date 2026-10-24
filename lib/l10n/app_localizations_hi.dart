// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'Parking Management';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHindi => 'हिंदी';

  @override
  String get languageSwitchTooltip => 'भाषा बदलें';

  @override
  String get languageSaveFailed =>
      'इस सत्र के लिए भाषा बदल दी गई, लेकिन प्राथमिकता सहेजी नहीं जा सकी।';

  @override
  String get commonLoading => 'लोड हो रहा है…';

  @override
  String get commonSomethingWentWrong => 'कुछ गलत हुआ';

  @override
  String get commonTryAgain => 'फिर से प्रयास करें';

  @override
  String get commonCancel => 'रद्द करें';

  @override
  String get commonSave => 'सहेजें';

  @override
  String get commonDelete => 'हटाएँ';

  @override
  String get commonClose => 'बंद करें';

  @override
  String get commonEdit => 'संपादित करें';

  @override
  String get commonRetry => 'पुनः प्रयास करें';

  @override
  String get commonActive => 'सक्रिय';

  @override
  String get commonExpired => 'समाप्त';

  @override
  String get commonInactive => 'निष्क्रिय';

  @override
  String get signInTitle => 'साइन इन करें';

  @override
  String get signInSubtitle =>
      'अपने व्यवस्थापक द्वारा बनाया गया निजी खाता उपयोग करें।';

  @override
  String get signInEmailLabel => 'ईमेल पता';

  @override
  String get signInPasswordLabel => 'पासवर्ड';

  @override
  String get signInRememberMe => 'मुझे याद रखें';

  @override
  String get signInForgotPassword => 'पासवर्ड भूल गए?';

  @override
  String get signInForgotPasswordUnavailableTooltip =>
      'स्थानीय डेवलपमेंट मोड में पासवर्ड रीसेट ईमेल उपलब्ध नहीं है।';

  @override
  String get signInButton => 'साइन इन करें';

  @override
  String get signInPasswordRequired => 'अपना पासवर्ड दर्ज करें।';

  @override
  String get signInGenericError =>
      'साइन इन नहीं हो सका। अपना कनेक्शन जाँचें और फिर से प्रयास करें।';

  @override
  String get configurationRequiredTitle => 'Supabase कॉन्फ़िगरेशन आवश्यक है';

  @override
  String get configurationRequiredHint =>
      '--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=... के साथ चलाएँ';

  @override
  String get configurationMissingMessage =>
      'इस बिल्ड के लिए Supabase कॉन्फ़िगर नहीं है।';

  @override
  String get navDashboard => 'डैशबोर्ड';

  @override
  String get navHistory => 'इतिहास';

  @override
  String get navAdmin => 'व्यवस्थापक';

  @override
  String get navSettings => 'सेटिंग';

  @override
  String get navSignOut => 'साइन आउट';

  @override
  String get navAllTenants => 'सभी टेनेंट';

  @override
  String get forgotPasswordTitle => 'पासवर्ड रीसेट करें';

  @override
  String get forgotPasswordSuccessMessage =>
      'यदि इस ईमेल पते से कोई खाता जुड़ा है, तो पासवर्ड रीसेट लिंक भेज दिया गया है। अपना इनबॉक्स और स्पैम फ़ोल्डर देखें।';

  @override
  String get forgotPasswordInstructions =>
      'अपने खाते का ईमेल पता दर्ज करें। यदि इस पते से कोई खाता जुड़ा होगा, तो हम रीसेट लिंक भेजेंगे।';

  @override
  String get forgotPasswordGenericError =>
      'अभी रीसेट ईमेल नहीं भेजा जा सका। अपना कनेक्शन जाँचें और फिर से प्रयास करें।';

  @override
  String get forgotPasswordSendButton => 'रीसेट लिंक भेजें';

  @override
  String get passwordRecoveryBackToSignIn => 'साइन इन पर वापस जाएँ';

  @override
  String get passwordRecoveryChooseTitle => 'नया पासवर्ड चुनें';

  @override
  String get passwordRecoveryInstructions =>
      'खाता रीसेट करना पूरा करने के लिए नया पासवर्ड दर्ज करें।';

  @override
  String get newPasswordLabel => 'नया पासवर्ड';

  @override
  String get newPasswordHelper => '12 से 128 अक्षरों का उपयोग करें।';

  @override
  String get showPasswordTooltip => 'पासवर्ड दिखाएँ';

  @override
  String get hidePasswordTooltip => 'पासवर्ड छिपाएँ';

  @override
  String get passwordTooShort => 'कम से कम 12 अक्षरों का उपयोग करें।';

  @override
  String get passwordTooLong => '128 या उससे कम अक्षरों का उपयोग करें।';

  @override
  String get confirmNewPasswordLabel => 'नए पासवर्ड की पुष्टि करें';

  @override
  String get passwordsDoNotMatch => 'पासवर्ड मेल नहीं खाते।';

  @override
  String get updatePasswordButton => 'पासवर्ड अपडेट करें';

  @override
  String get passwordRecoveryGenericError =>
      'पासवर्ड अपडेट नहीं किया जा सका। अपना कनेक्शन जाँचें और फिर से प्रयास करें।';

  @override
  String get temporaryPasswordSetTitle => 'नया पासवर्ड सेट करें';

  @override
  String get temporaryPasswordInstructions =>
      'आपके व्यवस्थापक ने एक अस्थायी पासवर्ड बनाया है। पार्किंग डेटा देखने से पहले नया पासवर्ड चुनें।';

  @override
  String get changePasswordButton => 'पासवर्ड बदलें';

  @override
  String get temporaryPasswordGenericError =>
      'पासवर्ड नहीं बदला जा सका। अपना कनेक्शन जाँचें और फिर से प्रयास करें।';

  @override
  String get signOutFailedError =>
      'आप साइन आउट नहीं कर सके। कृपया फिर से प्रयास करें।';

  @override
  String get authStateError =>
      'प्रमाणीकरण स्थिति पढ़ी नहीं जा सकी। फिर से प्रयास करें।';

  @override
  String get workspaceLoadingMessage => 'आपका वर्कस्पेस तैयार किया जा रहा है…';

  @override
  String get workspaceAccessLoadingMessage =>
      'वर्कस्पेस का एक्सेस लोड हो रहा है…';

  @override
  String get tenantAccessMigrationError =>
      'टेनेंट एक्सेस कॉन्फ़िगर नहीं है। इस संस्करण का उपयोग करने से पहले सभी टेनेंट माइग्रेशन लागू करें।';

  @override
  String get tenantAccessLoadError =>
      'टेनेंट एक्सेस लोड नहीं हो सका। अपना कनेक्शन जाँचें और फिर से प्रयास करें।';

  @override
  String get noWorkspaceTitle => 'कोई वर्कस्पेस असाइन नहीं है';

  @override
  String get noWorkspaceMessage =>
      'अपने व्यवस्थापक से अपने खाते को पार्किंग टेनेंट में असाइन करने के लिए कहें।';

  @override
  String get selectTenantBeforeVehicle => 'वाहन जोड़ने से पहले टेनेंट चुनें।';

  @override
  String get createTenantBeforeVehicle =>
      'वाहन जोड़ने से पहले टेनेंट बनाएँ या बहाल करें।';

  @override
  String get selectTenantDialogTitle => 'टेनेंट चुनें';

  @override
  String parkingEntrySavedMessage(String plate) {
    return '$plate की पार्किंग एंट्री सफलतापूर्वक सहेजी गई।';
  }

  @override
  String get tenantSelectorTooltip => 'टेनेंट चुनें';

  @override
  String get workspaceChipLabel => 'वर्कस्पेस';

  @override
  String get settingsTitle => 'सेटिंग';

  @override
  String get settingsSignOutError =>
      'साइन आउट नहीं हो सका। अपना कनेक्शन जाँचें और फिर से प्रयास करें।';

  @override
  String get settingsSigningOut => 'साइन आउट हो रहा है…';

  @override
  String get settingsLanguageTitle => 'भाषा';

  @override
  String get settingsLanguageDescription =>
      'ऐप में उपयोग की जाने वाली भाषा चुनें।';

  @override
  String get deviceSessionTitle => 'आपके डिवाइस';

  @override
  String get deviceSessionDescription =>
      'अपने खाते के सक्रिय डिवाइस सत्र देखें और हटाएँ।';

  @override
  String get deviceSessionLoading => 'आपके डिवाइस लोड हो रहे हैं…';

  @override
  String get deviceSessionLoadError =>
      'डिवाइस सत्र लोड नहीं हो सके। अपना कनेक्शन जाँचें और फिर से प्रयास करें।';

  @override
  String get deviceSessionEmpty => 'कोई सक्रिय डिवाइस नहीं';

  @override
  String get deviceSessionThisDevice => 'यह डिवाइस';

  @override
  String get deviceSessionOtherDevice => 'अन्य डिवाइस';

  @override
  String get deviceSessionLastActivity => 'अंतिम सक्रियता';

  @override
  String deviceSessionActiveAuthSessions(int count) {
    return 'इस डिवाइस पर $count सक्रिय साइन-इन सत्र';
  }

  @override
  String get deviceSessionRemoveTitle => 'यह डिवाइस हटाएँ?';

  @override
  String deviceSessionRemoveMessage(String tenant) {
    return 'इससे $tenant में इस डिवाइस के सक्रिय सत्र साइन आउट हो जाएँगे।';
  }

  @override
  String get deviceSessionRemove => 'डिवाइस हटाएँ';

  @override
  String get deviceSessionRemoved => 'डिवाइस सत्र हटा दिया गया।';

  @override
  String get deviceSessionRemoveError =>
      'डिवाइस सत्र नहीं हटाया जा सका। फिर से प्रयास करें।';

  @override
  String get deviceSessionRegistrationError =>
      'इस डिवाइस की पुष्टि नहीं हो सकी। अपना कनेक्शन जाँचें और फिर से प्रयास करें।';

  @override
  String get deviceLimitReachedTitle => 'डिवाइस सीमा पूरी हो गई';

  @override
  String deviceLimitReachedMessage(int limit) {
    return 'आप इस खाते के लिए अधिकतम $limit सक्रिय डिवाइस तक पहुँच गए हैं।';
  }

  @override
  String get deviceLimitReachedInstructions =>
      'किसी अन्य डिवाइस से साइन आउट करें या नीचे मौजूदा सत्र हटाएँ, फिर दोबारा प्रयास करें।';

  @override
  String get deviceLimitTenantChoiceDescription =>
      'हर टेनेंट की अपनी डिवाइस सीमा है। किसी दूसरे टेनेंट को चुनने से इस टेनेंट की सीमा प्रभावित नहीं होगी।';

  @override
  String get deviceLimitTenantChoiceLabel => 'टेनेंट';

  @override
  String deviceLimitActiveCount(int count) {
    return 'इस खाते का उपयोग कर रहे सक्रिय डिवाइस: $count।';
  }

  @override
  String get deviceLimitTryAgain => 'फिर से प्रयास करें';

  @override
  String get deviceLimitSignOut => 'साइन आउट';

  @override
  String get devicePolicyAdminTitle => 'डिवाइस-सत्र नीतियाँ';

  @override
  String get devicePolicyAdminDescription =>
      'डिवाइस सीमाएँ, खाते के ओवरराइड, सक्रिय सत्र और निरस्तीकरण प्रबंधित करें।';

  @override
  String get devicePolicyManageButton => 'नीतियाँ प्रबंधित करें';

  @override
  String get devicePolicyLoading => 'डिवाइस नीतियाँ लोड हो रही हैं…';

  @override
  String get devicePolicyLoadError =>
      'डिवाइस नीतियाँ लोड नहीं हो सकीं। अपना कनेक्शन जाँचें और फिर से प्रयास करें।';

  @override
  String get devicePolicyValidationError =>
      'डिवाइस सीमा 1 से 50 और निष्क्रिय सत्र अवधि 7 से 365 दिनों के बीच दर्ज करें।';

  @override
  String get devicePolicySavedMessage => 'डिवाइस-सत्र नीति सहेजी गई।';

  @override
  String get devicePolicySaveError =>
      'डिवाइस-सत्र नीति सहेजी नहीं जा सकी। फिर से प्रयास करें।';

  @override
  String get devicePolicyTenantsTitle => 'टेनेंट नीतियाँ और सत्र';

  @override
  String get devicePolicyPlatformTitle => 'प्लेटफ़ॉर्म डिफ़ॉल्ट';

  @override
  String get devicePolicyPlatformDescription =>
      'टेनेंट या खाता ओवरराइड न होने पर नए टेनेंट यह सीमा अपनाते हैं। मौजूदा ओवरराइड नहीं बदलेंगे।';

  @override
  String get devicePolicyPlatformLimitLabel => 'प्रति खाते डिफ़ॉल्ट डिवाइस';

  @override
  String get devicePolicyStaleDaysLabel => 'निष्क्रिय सत्र समाप्ति (दिन)';

  @override
  String get devicePolicyRangeLabel => 'अनुमत सीमा';

  @override
  String get devicePolicyAuditTitle => 'हाल की ऑडिट घटनाएँ';

  @override
  String get devicePolicyAuditEmpty =>
      'डिवाइस-सत्र नीति में कोई बदलाव या निरस्तीकरण दर्ज नहीं है।';

  @override
  String get deviceAuditPlatformPolicy => 'प्लेटफ़ॉर्म नीति अपडेट हुई';

  @override
  String get deviceAuditTenantPolicy => 'टेनेंट नीति अपडेट हुई';

  @override
  String get deviceAuditMemberOverride => 'खाता ओवरराइड अपडेट हुआ';

  @override
  String get deviceAuditUserRevoked => 'उपयोगकर्ता ने डिवाइस हटाया';

  @override
  String get deviceAuditAdminRevoked => 'सुपर एडमिन ने डिवाइस निरस्त किया';

  @override
  String get deviceAuditSignedOut => 'डिवाइस सत्र से साइन आउट हुआ';

  @override
  String get deviceAuditExpired => 'निष्क्रिय डिवाइस सत्र समाप्त हुआ';

  @override
  String get deviceAuditMembershipRemoved => 'सदस्यता हटने पर सत्र निरस्त हुए';

  @override
  String get deviceAuditSessionRegistered => 'डिवाइस सत्र पंजीकृत हुआ';

  @override
  String get deviceAuditLimitRejected =>
      'डिवाइस पंजीकरण सीमा के कारण अस्वीकार हुआ';

  @override
  String devicePolicyEffectiveLimit(int count) {
    return 'प्रभावी सीमा: $count डिवाइस';
  }

  @override
  String get devicePolicyTenantTitle => 'टेनेंट सीमा';

  @override
  String get devicePolicySourceLabel => 'नीति स्रोत';

  @override
  String get devicePolicyPlatformDefault => 'प्लेटफ़ॉर्म डिफ़ॉल्ट';

  @override
  String get devicePolicyTenantOverride => 'टेनेंट नीति';

  @override
  String get devicePolicyAccountOverride => 'खाता ओवरराइड';

  @override
  String devicePolicyUsage(int devices, int sessions) {
    return '$devices सक्रिय डिवाइस और $sessions साइन-इन सत्र';
  }

  @override
  String get devicePolicyTenantLimitLabel =>
      'टेनेंट डिवाइस सीमा (खाली रखने पर डिफ़ॉल्ट)';

  @override
  String devicePolicyInheritHint(int count) {
    return 'खाली रखने पर प्लेटफ़ॉर्म डिफ़ॉल्ट $count लागू होगा।';
  }

  @override
  String get devicePolicyMembersTitle => 'सदस्य खाता सीमाएँ';

  @override
  String get devicePolicyNoMembers => 'कोई टेनेंट सदस्य नहीं मिला।';

  @override
  String get devicePolicySetOverride => 'ओवरराइड सेट करें';

  @override
  String devicePolicyActiveDevices(int count) {
    return '$count सक्रिय डिवाइस';
  }

  @override
  String get devicePolicySessionsTitle => 'सक्रिय डिवाइस सत्र';

  @override
  String get devicePolicyNoSessions => 'कोई सक्रिय डिवाइस सत्र नहीं।';

  @override
  String devicePolicyInstallationLabel(String id) {
    return 'डिवाइस …$id';
  }

  @override
  String devicePolicyActiveSessions(int count) {
    return '$count सक्रिय साइन-इन सत्र';
  }

  @override
  String get devicePolicyRevokeTitle => 'यह डिवाइस निरस्त करें?';

  @override
  String devicePolicyRevokeMessage(String email) {
    return '$email के इस सक्रिय डिवाइस सत्र को निरस्त करें? इस डिवाइस पर खाते को फिर से साइन इन करना होगा।';
  }

  @override
  String get devicePolicyRevokeButton => 'डिवाइस निरस्त करें';

  @override
  String get devicePolicyRevokeError =>
      'डिवाइस सत्र निरस्त नहीं हो सका। फिर से प्रयास करें।';

  @override
  String get devicePolicyMemberOverrideTitle => 'खाता डिवाइस ओवरराइड';

  @override
  String get devicePolicyOverrideLimitLabel => 'इस खाते के लिए अनुमत डिवाइस';

  @override
  String get devicePolicyInheritButton => 'विरासत में मिली सीमा उपयोग करें';

  @override
  String get dashboardOverviewTitle => 'पार्किंग का अवलोकन';

  @override
  String get dashboardOverviewSubtitle =>
      'मौजूदा गतिविधि देखें और वाहन एंट्री प्रबंधित करें।';

  @override
  String get dashboardRefresh => 'रिफ़्रेश करें';

  @override
  String get dashboardNewEntry => 'नई पार्किंग एंट्री';

  @override
  String get dashboardActiveMessage => 'अनुमत अवधि के भीतर';

  @override
  String get dashboardExpiredMessage => 'दर्ज की गई समाप्ति का समय बीत चुका है';

  @override
  String get searchRegistrationLabel => 'पंजीकरण खोजें';

  @override
  String get searchByPlateHint => 'वाहन नंबर से खोजें';

  @override
  String get clearSearchTooltip => 'खोज साफ़ करें';

  @override
  String get dashboardNoSessionsTitle => 'अभी कोई पार्किंग सत्र नहीं है';

  @override
  String get noMatchingSessionsTitle => 'कोई मेल खाता सत्र नहीं';

  @override
  String get dashboardNoSessionsMessage =>
      'वाहन की निगरानी शुरू करने के लिए पार्किंग एंट्री बनाएँ।';

  @override
  String get tryDifferentSearchMessage =>
      'पंजीकरण नंबर से कोई दूसरी खोज आज़माएँ।';

  @override
  String get dashboardRecentSessions => 'हाल के सत्र';

  @override
  String get dashboardViewAll => 'सभी देखें';

  @override
  String get historyTitle => 'इतिहास';

  @override
  String get historyRefreshTooltip => 'इतिहास रिफ़्रेश करें';

  @override
  String get historyFilterPaid => 'भुगतान किया गया';

  @override
  String get historyFilterPartiallyPaid => 'आंशिक भुगतान';

  @override
  String get historyFilterUnpaid => 'भुगतान नहीं किया गया';

  @override
  String get historyClearFilters => 'फ़िल्टर साफ़ करें';

  @override
  String get historyNoHistoryTitle => 'पार्किंग का कोई इतिहास नहीं';

  @override
  String get historyNoMatchFilters =>
      'चुने गए फ़िल्टर से कोई सत्र मेल नहीं खाता।';

  @override
  String get historySavedWillAppear =>
      'सहेजे गए पार्किंग सत्र यहाँ दिखाई देंगे।';

  @override
  String get historyLoadMore => 'और लोड करें';

  @override
  String sessionEntryExpiryTemplate(String entry, String expiry) {
    return 'प्रवेश: $entry\nसमाप्ति: $expiry';
  }

  @override
  String contactLineTemplate(String contact) {
    return 'संपर्क: $contact';
  }

  @override
  String paymentTooltipTemplate(String total, String paid, String remaining) {
    return 'कुल: $total\nभुगतान किया: $paid\nशेष: $remaining';
  }

  @override
  String dateTimeAtTemplate(String date, String time) {
    return '$date, $time बजे';
  }

  @override
  String get sessionDetailsTitle => 'पार्किंग सत्र';

  @override
  String get editSessionTooltip => 'सत्र संपादित करें';

  @override
  String get deleteSessionTooltip => 'सत्र हटाएँ';

  @override
  String get sessionNoIdError => 'इस पार्किंग सत्र का कोई पहचानकर्ता नहीं है।';

  @override
  String get deleteSessionDialogTitle => 'पार्किंग सत्र हटाएँ?';

  @override
  String deleteSessionDialogMessage(String plate) {
    return 'क्या $plate के लिए पार्किंग सत्र हटाना है? यह कार्रवाई पूर्ववत नहीं की जा सकती।';
  }

  @override
  String get detailEntryTime => 'प्रवेश का समय';

  @override
  String get detailContactNumber => 'संपर्क नंबर';

  @override
  String get detailNotProvided => 'नहीं दिया गया';

  @override
  String get detailAllowedDuration => 'अनुमत अवधि';

  @override
  String get detailExpiry => 'समाप्ति';

  @override
  String get detailTotalCharge => 'कुल शुल्क';

  @override
  String get detailAmountPaid => 'भुगतान की गई राशि';

  @override
  String get detailRemainingBalance => 'बाकी राशि';

  @override
  String get noVehiclePhotoMessage =>
      'इस सत्र के साथ वाहन की कोई फ़ोटो नहीं है।';

  @override
  String get vehiclePhotoTitle => 'वाहन की फ़ोटो';

  @override
  String get photoDisplayError => 'निजी वाहन की फ़ोटो दिखाई नहीं जा सकी।';

  @override
  String get durationUnitMinutes => 'मिनट';

  @override
  String get durationUnitHours => 'घंटे';

  @override
  String get durationUnitDays => 'दिन';

  @override
  String get durationUnitMonths => 'महीने';

  @override
  String get durationUnitMinutesCap => 'मिनट';

  @override
  String get durationUnitHoursCap => 'घंटे';

  @override
  String get durationUnitDaysCap => 'दिन';

  @override
  String get durationUnitMonthsCap => 'महीने';

  @override
  String get entryPageEditTitle => 'पार्किंग एंट्री संपादित करें';

  @override
  String get entryPageNewTitle => 'नई पार्किंग एंट्री';

  @override
  String get cameraOpenError => 'कैमरा नहीं खुल सका। इसके बजाय फ़ाइल चुनें।';

  @override
  String get imageSelectError =>
      'छवि नहीं चुनी जा सकी। फिर से प्रयास करें या इसके बजाय फ़ाइल चुनें।';

  @override
  String get plateRequired => 'वाहन पंजीकरण नंबर दर्ज करें।';

  @override
  String get plateTooLong => '64 या उससे कम अक्षरों का उपयोग करें।';

  @override
  String get contactRequired => 'संपर्क मोबाइल नंबर दर्ज करें।';

  @override
  String get contactInvalid =>
      '+91 के साथ या उसके बिना, 10 अंकों का मान्य मोबाइल नंबर दर्ज करें।';

  @override
  String get durationRequired => 'पार्किंग की अवधि दर्ज करें।';

  @override
  String get durationPositiveInteger => 'शून्य से बड़ी पूर्ण संख्या दर्ज करें।';

  @override
  String durationMaxExceeded(String unit, int max) {
    return '$unit की अधिकतम सीमा $max है।';
  }

  @override
  String get expiryCalculationError => 'समाप्ति का समय तय नहीं किया जा सका।';

  @override
  String get amountInvalid => 'मान्य राशि दर्ज करें।';

  @override
  String get chargeNegative => 'शुल्क शून्य से कम नहीं हो सकता।';

  @override
  String get paidNegative => 'भुगतान की गई राशि शून्य से कम नहीं हो सकती।';

  @override
  String get paidExceedsTotal =>
      'भुगतान की गई राशि कुल शुल्क से अधिक नहीं हो सकती।';

  @override
  String get durationBeforeSaving => 'सहेजने से पहले मान्य अवधि दर्ज करें।';

  @override
  String get chargeBeforeSaving =>
      'सहेजने से पहले मान्य पार्किंग शुल्क दर्ज करें।';

  @override
  String get saveGenericError =>
      'पार्किंग एंट्री सहेजी नहीं जा सकी। अपना कनेक्शन जाँचें और फिर से प्रयास करें।';

  @override
  String get photoSelectionRequired =>
      'वाहन की फ़ोटो चुनें या स्पष्ट रूप से बिना फ़ोटो जारी रखने का विकल्प चुनें।';

  @override
  String get cleanupGenericError =>
      'सफ़ाई पूरी नहीं हो सकी। अपना कनेक्शन जाँचें और फिर से प्रयास करें।';

  @override
  String get cleanupSuccessMessage =>
      'सफ़ाई पूरी हुई। अधूरा सत्र हटा दिया गया है। फिर से प्रयास करें।';

  @override
  String get photoCleanupGenericError =>
      'फ़ोटो की सफ़ाई पूरी नहीं हो सकी। अपना कनेक्शन जाँचें और फिर से प्रयास करें।';

  @override
  String get photoCleanupSuccessMessage =>
      'फ़ोटो की सफ़ाई पूरी हुई। बदलाव देखें और फिर से सहेजने का प्रयास करें।';

  @override
  String get introEditing =>
      'वाहन का विवरण अपडेट करें और सहेजने से पहले समाप्ति समय की पुष्टि करें।';

  @override
  String get introCreating =>
      'वाहन का विवरण दर्ज करें और सहेजने से पहले समाप्ति समय की पुष्टि करें।';

  @override
  String get parkingDetailsTitle => 'पार्किंग का विवरण';

  @override
  String get vehicleRegistrationLabel => 'वाहन पंजीकरण नंबर';

  @override
  String get vehicleRegistrationHint => 'उदाहरण: ABC 123';

  @override
  String get contactNumberHint => 'उदाहरण: 9876543210 या +919876543210';

  @override
  String get unitLabel => 'इकाई';

  @override
  String get parkingChargeTitle => 'पार्किंग शुल्क';

  @override
  String get totalChargeLabel => 'कुल शुल्क';

  @override
  String get totalChargeHint => 'उदाहरण: 50.00';

  @override
  String get fullyPaidLabel => 'पूरा भुगतान किया गया';

  @override
  String get fullyPaidSubtitle =>
      'आंशिक भुगतान दर्ज करने के लिए इसे अनचेक छोड़ें।';

  @override
  String get amountPaidHint => 'उदाहरण: 20.00';

  @override
  String get entryDateTimeLabel => 'प्रवेश की तारीख और समय';

  @override
  String get calculatedExpiryTitle => 'गणना की गई समाप्ति';

  @override
  String get expiryPreviewTitle => 'समाप्ति का पूर्वावलोकन';

  @override
  String get expiryPreviewMessage =>
      'समाप्ति का समय तय करने के लिए मान्य अवधि दर्ज करें।';

  @override
  String get vehiclePhotoInstructions =>
      'जहाँ समर्थित हो वहाँ कैमरे का उपयोग करें, या मौजूदा JPEG, PNG या WebP छवि चुनें।';

  @override
  String get imagePreviewError =>
      'ब्राउज़र में इस छवि का पूर्वावलोकन नहीं किया जा सकता।';

  @override
  String get existingPhotoKeptTitle => 'मौजूदा निजी फ़ोटो रखी जाएगी';

  @override
  String get existingPhotoKeptSubtitle =>
      'नई फ़ोटो तभी चुनें जब आप इसे बदलना चाहते हों।';

  @override
  String get replaceWithCamera => 'कैमरे से बदलें';

  @override
  String get takePhoto => 'फ़ोटो लें';

  @override
  String get retakePhoto => 'दोबारा फ़ोटो लें';

  @override
  String get chooseFile => 'फ़ाइल चुनें';

  @override
  String get replacePhoto => 'फ़ोटो बदलें';

  @override
  String get discardReplacement => 'बदलाव रद्द करें';

  @override
  String get removeButton => 'हटाएँ';

  @override
  String get continueWithoutPhoto => 'फ़ोटो के बिना जारी रखें';

  @override
  String get continueWithoutPhotoSubtitle =>
      'फ़ोटो उपलब्ध न होने पर यह विकल्प स्पष्ट रूप से चुनें।';

  @override
  String get updatingButton => 'अपडेट हो रहा है...';

  @override
  String get savingButton => 'सहेजा जा रहा है...';

  @override
  String get updateEntryButton => 'पार्किंग एंट्री अपडेट करें';

  @override
  String get saveEntryButton => 'पार्किंग एंट्री सहेजें';

  @override
  String get retryingCleanup => 'सफ़ाई फिर से की जा रही है...';

  @override
  String get retryCleanupButton => 'सफ़ाई फिर से करें';

  @override
  String get retryingPhotoCleanup => 'फ़ोटो की सफ़ाई फिर से की जा रही है...';

  @override
  String get retryPhotoCleanupButton => 'फ़ोटो की सफ़ाई फिर से करें';

  @override
  String get captureDialogTitle => 'वाहन की फ़ोटो लें';

  @override
  String get cameraTimeoutError =>
      'कैमरा शुरू होने में बहुत समय लगा। अनुमतियाँ जाँचें और फिर से प्रयास करें।';

  @override
  String get cameraInitError =>
      'कैमरा शुरू नहीं हो सका। ब्राउज़र की अनुमतियाँ जाँचें और फिर से प्रयास करें।';

  @override
  String get captureTimeoutError =>
      'फ़ोटो लेने में बहुत समय लगा। फिर से प्रयास करें या इसके बजाय फ़ाइल चुनें।';

  @override
  String get captureGenericError => 'फ़ोटो नहीं ली जा सकी। फिर से प्रयास करें।';

  @override
  String get switchTimeoutError =>
      'कैमरा बदलने में बहुत समय लगा। फिर से प्रयास करें या इसके बजाय फ़ाइल चुनें।';

  @override
  String get switchGenericError =>
      'चुना गया कैमरा नहीं खुल सका। कोई दूसरा कैमरा आज़माएँ या इसके बजाय फ़ाइल चुनें।';

  @override
  String get switchingCamera => 'बदला जा रहा है...';

  @override
  String get switchCameraButton => 'कैमरा बदलें';

  @override
  String get capturingButton => 'फ़ोटो ली जा रही है...';

  @override
  String get captureButton => 'फ़ोटो लें';

  @override
  String get retakeButton => 'दोबारा लें';

  @override
  String get usePhotoButton => 'फ़ोटो उपयोग करें';

  @override
  String get cameraUnavailableMessage =>
      'कैमरा उपलब्ध नहीं है। मौजूदा फ़ोटो चुनें।';

  @override
  String tenantCreatedMessage(String tenant) {
    return '$tenant बनाया गया है।';
  }

  @override
  String tenantCreatedWithPasswordMessage(String tenant) {
    return '$tenant बनाया गया है। अस्थायी पासवर्ड केवल एक बार दिखाया गया था।';
  }

  @override
  String get tenantCreateGenericError =>
      'टेनेंट नहीं बनाया जा सका। अपना कनेक्शन जाँचें और फिर से प्रयास करें।';

  @override
  String tenantUpdatedMessage(String tenant) {
    return '$tenant अपडेट किया गया है।';
  }

  @override
  String get archiveTenantTitle => 'टेनेंट संग्रहित करें?';

  @override
  String archiveTenantMessage(String tenant) {
    return 'टेनेंट $tenant अब अपने सदस्यों के लिए उपलब्ध नहीं होगा। पार्किंग रिकॉर्ड और फ़ोटो सुरक्षित रहेंगे, और इस टेनेंट को बाद में बहाल किया जा सकता है।';
  }

  @override
  String get archiveButton => 'संग्रहित करें';

  @override
  String tenantArchivedMessage(String tenant) {
    return '$tenant संग्रहित किया गया है। इसका डेटा सुरक्षित रखा गया है।';
  }

  @override
  String tenantRestoredMessage(String tenant) {
    return '$tenant बहाल किया गया है।';
  }

  @override
  String get tenantUpdateGenericError =>
      'टेनेंट अपडेट नहीं हो सका। अपना कनेक्शन जाँचें और फिर से प्रयास करें।';

  @override
  String get tenantWorkspacesTitle => 'टेनेंट वर्कस्पेस';

  @override
  String get tenantWorkspacesSubtitle =>
      'हर वर्कस्पेस के पार्किंग रिकॉर्ड और फ़ोटो अलग रखे जाते हैं।';

  @override
  String get allTenantsTitle => 'सभी टेनेंट';

  @override
  String get createTenantButton => 'टेनेंट बनाएँ';

  @override
  String get noTenantsTitle => 'अभी कोई टेनेंट वर्कस्पेस नहीं है';

  @override
  String get noTenantsMessage =>
      'एक वर्कस्पेस बनाएँ और मौजूदा Supabase खाते को उसका मालिक असाइन करें।';

  @override
  String validUntilTemplate(String date) {
    return '$date तक मान्य';
  }

  @override
  String manageTenantTooltip(String name) {
    return '$name प्रबंधित करें';
  }

  @override
  String get manageMembersMenuItem => 'सदस्य प्रबंधित करें';

  @override
  String get archiveTenantMenuItem => 'टेनेंट संग्रहित करें';

  @override
  String get restoreTenantMenuItem => 'टेनेंट बहाल करें';

  @override
  String get superAdminTitle => 'सुपर एडमिन';

  @override
  String get superAdminSubtitle =>
      'प्लेटफ़ॉर्म के पार्किंग वर्कस्पेस प्रबंधित करें।';

  @override
  String get createTenantDialogTitle => 'टेनेंट बनाएँ';

  @override
  String get tenantCreatedDialogTitle => 'टेनेंट बनाया गया';

  @override
  String get tenantNameLabel => 'टेनेंट का नाम';

  @override
  String get tenantNameHint => 'उदाहरण: Central Parking';

  @override
  String get tenantNameRequired => 'टेनेंट का नाम दर्ज करें।';

  @override
  String get tenantNameTooLong => '120 या उससे कम अक्षरों का उपयोग करें।';

  @override
  String get ownerEmailLabel => 'मालिक का ईमेल';

  @override
  String get ownerEmailHint => 'owner@example.com';

  @override
  String get emailInvalid => 'मान्य ईमेल पता दर्ज करें।';

  @override
  String get activeSubtitle =>
      'निष्क्रिय टेनेंट दोबारा सक्रिय किए जाने तक साइन इन नहीं कर सकते।';

  @override
  String get validUntilTitle => 'इस तारीख तक मान्य';

  @override
  String get contactPersonNameLabel => 'संपर्क व्यक्ति का नाम (वैकल्पिक)';

  @override
  String get contactMobileLabel => 'संपर्क मोबाइल (वैकल्पिक)';

  @override
  String get contactMobileHint => '9876543210 या +919876543210';

  @override
  String get contactMobileInvalid =>
      '10 अंकों का मान्य भारतीय मोबाइल नंबर दर्ज करें।';

  @override
  String get contactEmailLabel => 'संपर्क ईमेल (वैकल्पिक)';

  @override
  String get accountPasswordNote =>
      'मौजूदा खाते का वर्तमान पासवर्ड बना रहेगा। नए खाते को अस्थायी पासवर्ड मिलेगा, जिसे पार्किंग डेटा देखने से पहले बदलना होगा।';

  @override
  String get copyPasswordFailedMessage =>
      'पासवर्ड कॉपी नहीं हो सका। उसे चुनकर मैन्युअल रूप से कॉपी करें।';

  @override
  String get passwordCopiedMessage => 'अस्थायी पासवर्ड कॉपी किया गया।';

  @override
  String tenantReadyMessage(String tenant) {
    return '$tenant तैयार है।';
  }

  @override
  String get ownerMustChangePassword =>
      'टेनेंट डेटा देखने से पहले मालिक को यह पासवर्ड बदलना होगा।';

  @override
  String get sharePasswordSecurely =>
      'यह पासवर्ड मालिक के साथ सुरक्षित माध्यम से साझा करें। यह डायलॉग बंद करने के बाद दोबारा नहीं दिखाया जाएगा।';

  @override
  String get temporaryPasswordLabel => 'अस्थायी पासवर्ड';

  @override
  String get retrySetupNote =>
      'सेटअप फिर से करते समय यहाँ दिखाया गया नवीनतम पासवर्ड उपयोग करें।';

  @override
  String get copyButton => 'कॉपी करें';

  @override
  String get closeWithPasswordSavedButton =>
      'बंद करें (मैंने पासवर्ड सहेज लिया है)';

  @override
  String get retryTenantSetupButton => 'टेनेंट सेटअप फिर से करें';

  @override
  String get doneButton => 'हो गया';

  @override
  String get editTenantDialogTitle => 'टेनेंट संपादित करें';

  @override
  String get removeTenantMemberTitle => 'टेनेंट सदस्य हटाएँ?';

  @override
  String removeTenantMemberMessage(String email, String tenant) {
    return '$email को $tenant से हटाएँ? उनका Auth खाता और पार्किंग रिकॉर्ड नहीं हटाए जाएँगे।';
  }

  @override
  String membersDialogTitle(String tenant) {
    return 'सदस्य: $tenant';
  }

  @override
  String get restoreBeforeAddingMembers =>
      'सदस्य जोड़ने से पहले इस टेनेंट को बहाल करें।';

  @override
  String get existingAccountEmailLabel => 'सदस्य खाते का ईमेल';

  @override
  String get memberEmailLabel => 'सदस्य का ईमेल';

  @override
  String get roleLabel => 'भूमिका';

  @override
  String get addButton => 'जोड़ें';

  @override
  String get noMembersTitle => 'कोई सदस्य नहीं';

  @override
  String get noMembersMessage =>
      'इस टेनेंट में मौजूदा खाता जोड़ें या नया सदस्य लॉगिन बनाएँ।';

  @override
  String get keepAtLeastOneOwner =>
      'हर टेनेंट में कम से कम एक मालिक होना चाहिए।';

  @override
  String get unknownEmail => 'अज्ञात ईमेल';

  @override
  String manageMemberTooltip(String email) {
    return '$email प्रबंधित करें';
  }

  @override
  String get makeOwnerMenuItem => 'मालिक बनाएँ';

  @override
  String get makeMemberMenuItem => 'सदस्य बनाएँ';

  @override
  String get removeMemberMenuItem => 'सदस्य हटाएँ';

  @override
  String get roleOwner => 'मालिक';

  @override
  String get roleMember => 'सदस्य';

  @override
  String get membersLoadGenericError =>
      'टेनेंट के सदस्य लोड नहीं हो सके। अनुरोध फिर से करें।';

  @override
  String get memberActionGenericError =>
      'सदस्य में बदलाव नहीं हो सका। अपना कनेक्शन जाँचें और फिर से प्रयास करें।';

  @override
  String get addOnlyAccessTitle => 'आप पार्किंग एंट्री जोड़ सकते हैं';

  @override
  String get addOnlyAccessMessage =>
      'आप पार्किंग एंट्री बना सकते हैं, लेकिन मौजूदा रिकॉर्ड नहीं देख सकते। रिकॉर्ड देखने के लिए टेनेंट मालिक से View अनुमति चालू करने को कहें।';

  @override
  String get limitedEntryPermissionsTitle => 'View अनुमति बंद है';

  @override
  String get limitedEntryPermissionsMessage =>
      'आपके खाते में एंट्री प्रबंधन की अनुमति है, लेकिन View के बिना रिकॉर्ड दिखाई नहीं देंगे। टेनेंट मालिक से View चालू करने को कहें।';

  @override
  String get noEntryPermissionsTitle => 'पार्किंग एंट्री की अनुमति नहीं';

  @override
  String get noEntryPermissionsMessage =>
      'टेनेंट मालिक ने आपके खाते के लिए पार्किंग एंट्री की कोई अनुमति चालू नहीं की है।';

  @override
  String get navAddEntry => 'एंट्री जोड़ें';

  @override
  String get navEntryAccess => 'एंट्री पहुँच';

  @override
  String get settingsManageMembersTitle => 'टेनेंट सदस्य';

  @override
  String get settingsManageMembersDescription =>
      'इस टेनेंट के सदस्य खाते, उनकी पार्किंग एंट्री अनुमतियाँ और सदस्य उपयोग प्रबंधित करें।';

  @override
  String get settingsParkingNotificationsTitle => 'पार्किंग रिमाइंडर';

  @override
  String get settingsParkingNotificationsDescription =>
      'इस डिवाइस पर नोटिफिकेशन की अनुमति दें। समय समाप्त और बकाया राशि वाले पार्किंग सत्रों के लिए हर पाँच मिनट में रिमाइंडर भेजा जाता है। रिमाइंडर पर टैप करने के बाद साइन इन और अनुमति जाँचकर पार्किंग रिकॉर्ड खुलेगा।';

  @override
  String get parkingNotificationsEnableAction => 'चालू करें';

  @override
  String get parkingNotificationsDisableAction => 'बंद करें';

  @override
  String get parkingNotificationsStatusLoading =>
      'ब्राउज़र नोटिफिकेशन सेटिंग जाँची जा रही हैं…';

  @override
  String get parkingNotificationsSetupRequired =>
      'इस डिप्लॉयमेंट में OneSignal कॉन्फ़िगर नहीं है।';

  @override
  String get parkingNotificationsUnsupported =>
      'यह ब्राउज़र या प्लेटफ़ॉर्म पुश नोटिफिकेशन का समर्थन नहीं करता।';

  @override
  String get parkingNotificationsPermissionNotGranted =>
      'नोटिफिकेशन की अनुमति नहीं है। ब्राउज़र सेटिंग में साइट नोटिफिकेशन चालू करके फिर प्रयास करें।';

  @override
  String get parkingNotificationsPending =>
      'पुश सदस्यता अपडेट हो रही है। थोड़ी देर बाद फिर प्रयास करें।';

  @override
  String get parkingNotificationsEnabled =>
      'इस डिवाइस पर इस खाते के लिए पुश नोटिफिकेशन चालू हैं।';

  @override
  String get parkingNotificationsDisabled =>
      'इस डिवाइस पर पुश नोटिफिकेशन बंद हैं।';

  @override
  String get parkingNotificationsEnabledMessage =>
      'पार्किंग रिमाइंडर चालू किए गए।';

  @override
  String get parkingNotificationsDisabledMessage =>
      'पार्किंग रिमाइंडर बंद किए गए।';

  @override
  String get parkingNotificationsNotSignedIn =>
      'पुश नोटिफिकेशन चालू या बंद करने से पहले फिर से साइन इन करें।';

  @override
  String get parkingNotificationsRequestFailed =>
      'पुश नोटिफिकेशन सेटिंग अपडेट नहीं हो सकीं। कनेक्शन जाँचकर फिर प्रयास करें।';

  @override
  String get parkingNotificationsCenterTitle => 'पार्किंग नोटिफिकेशन';

  @override
  String get parkingNotificationsEmptyTitle =>
      'कोई बकाया पार्किंग रिमाइंडर नहीं';

  @override
  String get parkingNotificationsEmptyMessage =>
      'समय समाप्त और बकाया राशि वाले पार्किंग सत्र यहाँ दिखाई देंगे।';

  @override
  String get parkingNotificationsLoadFailed =>
      'पार्किंग नोटिफिकेशन लोड नहीं हो सके। कनेक्शन जाँचकर फिर प्रयास करें।';

  @override
  String get parkingNotificationsInvalidData =>
      'पार्किंग नोटिफिकेशन डेटा अमान्य है। सिस्टम प्रशासक से संपर्क करें।';

  @override
  String get parkingNotificationsMarkReadFailed =>
      'नोटिफिकेशन को पढ़ा हुआ नहीं किया जा सका।';

  @override
  String get parkingNotificationsClearAll => 'सभी साफ़ करें';

  @override
  String get parkingNotificationsClearAllFailed =>
      'नोटिफिकेशन साफ़ नहीं हो सके। कृपया फिर प्रयास करें।';

  @override
  String get parkingNotificationsOpenAction => 'खोलें';

  @override
  String parkingNotificationExpiredTitle(String platePrefix) {
    return 'पार्किंग समय समाप्त - $platePrefix...';
  }

  @override
  String get parkingNotificationExpiredBody => 'पूरा भुगतान नहीं हुआ';

  @override
  String get parkingNotificationsSessionUnavailable =>
      'यह पार्किंग सत्र अब इस टेनेंट में उपलब्ध नहीं है।';

  @override
  String get parkingNotificationsLaunchInvalid =>
      'पार्किंग नोटिफिकेशन लिंक अमान्य है या समाप्त हो गया है।';

  @override
  String get settingsManageTenantsTitle => 'टेनेंट प्रशासन';

  @override
  String get settingsManageTenantsDescription =>
      'टेनेंट विवरण, सदस्य, सदस्य सीमा और डिवाइस-सत्र नीतियाँ प्रबंधित करें।';

  @override
  String get manageTenantsMenuItem => 'टेनेंट प्रबंधित करें';

  @override
  String memberUsageTemplate(int active, int limit) {
    return '$active में से $limit सदस्य उपयोग में (मालिक शामिल नहीं)';
  }

  @override
  String get memberUsageLoading => 'सदस्य उपयोग लोड हो रहा है…';

  @override
  String get memberUsageUnavailable => 'सदस्य उपयोग उपलब्ध नहीं है';

  @override
  String get memberCapacityLoadError => 'टेनेंट सदस्य उपयोग लोड नहीं हो सका।';

  @override
  String memberRemainingTemplate(int count) {
    return '$count सदस्य स्लॉट शेष';
  }

  @override
  String get memberLimitOwnerHint =>
      'यह सीमा केवल सुपर एडमिन बदल सकता है। टेनेंट मालिक की गणना नहीं होती।';

  @override
  String get memberLimitAdminHint =>
      'केवल सदस्य खातों की गणना होती है; टेनेंट मालिक शामिल नहीं है। सीमा: 1–50।';

  @override
  String get memberLimitEditButton => 'सीमा बदलें';

  @override
  String get memberLimitIncreaseButton => 'सदस्य सीमा बढ़ाएँ';

  @override
  String get memberLimitReachedTitle => 'सदस्य सीमा पूरी हो गई';

  @override
  String memberLimitReachedMessage(int active, int limit) {
    return 'इस टेनेंट में $limit में से $active सदस्य उपयोग में हैं। सदस्य हटाएँ या सुपर एडमिन से सीमा बढ़ाने को कहें।';
  }

  @override
  String get memberLimitDialogTitle => 'टेनेंट सदस्य सीमा सेट करें';

  @override
  String get memberLimitFieldLabel => 'अनुमत सदस्य';

  @override
  String get memberLimitRangeHint =>
      '1 से 50 तक पूर्ण संख्या दर्ज करें। मालिक शामिल नहीं है।';

  @override
  String get memberLimitValidation => '1 से 50 तक की पूर्ण संख्या दर्ज करें।';

  @override
  String get memberLimitSavedMessage => 'टेनेंट सदस्य सीमा सहेजी गई।';

  @override
  String get memberNewMemberPermissionNote =>
      'नए सदस्य के लिए View चालू रहता है। Add, Edit और Delete अनुमति देने तक बंद रहते हैं।';

  @override
  String get memberAccountProvisioningNote =>
      'मौजूदा Supabase खाता फिर से उपयोग होगा। खाता न मिलने पर इस टेनेंट के लिए अस्थायी पासवर्ड वाला नया लॉगिन बनाया जाएगा।';

  @override
  String get memberTemporaryPasswordTitle => 'नया सदस्य खाता';

  @override
  String memberTemporaryPasswordMessage(String email) {
    return '$email के लिए नया लॉगिन केवल इस टेनेंट में जोड़ा गया। यह अस्थायी पासवर्ड सुरक्षित रूप से साझा करें। सदस्य को पहली बार साइन इन करते समय इसे बदलना होगा। डायलॉग बंद करने के बाद यह दोबारा नहीं दिखेगा।';
  }

  @override
  String get memberSetupIncompleteMessage =>
      'सदस्य सेटअप अधूरा हो सकता है। सुरक्षित रूप से पूरा करने के लिए उसी ईमेल को फिर से जोड़ें; अलग खाता न बनाएँ।';

  @override
  String memberAddedMessage(String email) {
    return '$email को टेनेंट में जोड़ा गया।';
  }

  @override
  String get memberPermissionsEditButton => 'एंट्री अनुमतियाँ संपादित करें';

  @override
  String memberPermissionsDialogTitle(String email) {
    return 'एंट्री अनुमतियाँ: $email';
  }

  @override
  String get memberPermissionsDialogDescription =>
      'अनुमतियाँ इस टेनेंट की सभी पार्किंग एंट्री पर लागू होती हैं और सर्वर द्वारा लागू की जाती हैं। Edit या Delete से View नहीं मिलता; View के बिना सदस्य मौजूदा एंट्री नहीं देख सकते।';

  @override
  String get memberPermissionView => 'देखें';

  @override
  String get memberPermissionAdd => 'जोड़ें';

  @override
  String get memberPermissionEdit => 'संपादित करें';

  @override
  String get memberPermissionDelete => 'हटाएँ';

  @override
  String get memberPermissionNone => 'एंट्री की अनुमति नहीं';

  @override
  String get memberPermissionViewDescription =>
      'इस टेनेंट की पार्किंग एंट्री पढ़ें।';

  @override
  String get memberPermissionAddDescription => 'नई पार्किंग एंट्री बनाएँ।';

  @override
  String get memberPermissionEditDescription => 'मौजूदा पार्किंग एंट्री बदलें।';

  @override
  String get memberPermissionDeleteDescription =>
      'ऐप की नीति के अनुसार एंट्री हटाएँ या संग्रहित करें।';

  @override
  String get memberPermissionsSavedMessage => 'एंट्री अनुमतियाँ सहेजी गईं।';

  @override
  String memberCreatedAt(String date) {
    return '$date को जोड़ा गया';
  }

  @override
  String get memberAuditTitle => 'सदस्य और सीमा में हाल के बदलाव';

  @override
  String get memberAuditEmpty => 'सदस्य प्रबंधन का कोई बदलाव दर्ज नहीं है।';

  @override
  String get memberAuditLoadError => 'सदस्य बदलाव इतिहास लोड नहीं हो सका।';

  @override
  String get memberAuditAdded => 'सदस्य जोड़ा गया';

  @override
  String get memberAuditRemoved => 'सदस्य हटाया गया';

  @override
  String get memberAuditRoleChanged => 'सदस्य की भूमिका बदली गई';

  @override
  String get memberAuditPermissionsChanged => 'एंट्री अनुमतियाँ बदली गईं';

  @override
  String get memberAuditLimitChanged => 'सदस्य सीमा बदली गई';

  @override
  String get memberManageDevicePolicies => 'डिवाइस नीतियाँ प्रबंधित करें';
}
