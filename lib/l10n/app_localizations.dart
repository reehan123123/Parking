import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('hi'),
  ];

  /// App title shown in the browser tab and sign-in app bar.
  ///
  /// In en, this message translates to:
  /// **'Parking Management'**
  String get appTitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageHindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get languageHindi;

  /// No description provided for @languageSwitchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Change language'**
  String get languageSwitchTooltip;

  /// No description provided for @languageSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Language changed for this session, but the preference could not be saved.'**
  String get languageSaveFailed;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @commonSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get commonSomethingWentWrong;

  /// No description provided for @commonTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonTryAgain;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get commonActive;

  /// No description provided for @commonExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get commonExpired;

  /// No description provided for @commonInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get commonInactive;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use the private account created by your administrator.'**
  String get signInSubtitle;

  /// No description provided for @signInEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get signInEmailLabel;

  /// No description provided for @signInPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get signInPasswordLabel;

  /// No description provided for @signInRememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get signInRememberMe;

  /// No description provided for @signInForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get signInForgotPassword;

  /// No description provided for @signInForgotPasswordUnavailableTooltip.
  ///
  /// In en, this message translates to:
  /// **'Password reset email is not available in local development mode.'**
  String get signInForgotPasswordUnavailableTooltip;

  /// No description provided for @signInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInButton;

  /// No description provided for @signInPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your password.'**
  String get signInPasswordRequired;

  /// No description provided for @signInGenericError.
  ///
  /// In en, this message translates to:
  /// **'Unable to sign in. Check your connection and try again.'**
  String get signInGenericError;

  /// No description provided for @configurationRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Supabase configuration required'**
  String get configurationRequiredTitle;

  /// No description provided for @configurationRequiredHint.
  ///
  /// In en, this message translates to:
  /// **'Run with --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...'**
  String get configurationRequiredHint;

  /// No description provided for @configurationMissingMessage.
  ///
  /// In en, this message translates to:
  /// **'Supabase is not configured for this build.'**
  String get configurationMissingMessage;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @navAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get navAdmin;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get navSignOut;

  /// No description provided for @navAllTenants.
  ///
  /// In en, this message translates to:
  /// **'All tenants'**
  String get navAllTenants;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for that email address, a password reset link has been sent. Check your inbox and spam folder.'**
  String get forgotPasswordSuccessMessage;

  /// No description provided for @forgotPasswordInstructions.
  ///
  /// In en, this message translates to:
  /// **'Enter your account email address. We will send a password reset link if an account exists for it.'**
  String get forgotPasswordInstructions;

  /// No description provided for @forgotPasswordGenericError.
  ///
  /// In en, this message translates to:
  /// **'The reset email could not be sent right now. Check your connection and try again.'**
  String get forgotPasswordGenericError;

  /// No description provided for @forgotPasswordSendButton.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get forgotPasswordSendButton;

  /// No description provided for @passwordRecoveryBackToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get passwordRecoveryBackToSignIn;

  /// No description provided for @passwordRecoveryChooseTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password'**
  String get passwordRecoveryChooseTitle;

  /// No description provided for @passwordRecoveryInstructions.
  ///
  /// In en, this message translates to:
  /// **'Enter a new password to finish resetting your account.'**
  String get passwordRecoveryInstructions;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordLabel;

  /// No description provided for @newPasswordHelper.
  ///
  /// In en, this message translates to:
  /// **'Use 12 to 128 characters.'**
  String get newPasswordHelper;

  /// No description provided for @showPasswordTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPasswordTooltip;

  /// No description provided for @hidePasswordTooltip.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePasswordTooltip;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 12 characters.'**
  String get passwordTooShort;

  /// No description provided for @passwordTooLong.
  ///
  /// In en, this message translates to:
  /// **'Use 128 characters or fewer.'**
  String get passwordTooLong;

  /// No description provided for @confirmNewPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmNewPasswordLabel;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'The passwords do not match.'**
  String get passwordsDoNotMatch;

  /// No description provided for @updatePasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get updatePasswordButton;

  /// No description provided for @passwordRecoveryGenericError.
  ///
  /// In en, this message translates to:
  /// **'The password could not be updated. Check your connection and retry.'**
  String get passwordRecoveryGenericError;

  /// No description provided for @temporaryPasswordSetTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a new password'**
  String get temporaryPasswordSetTitle;

  /// No description provided for @temporaryPasswordInstructions.
  ///
  /// In en, this message translates to:
  /// **'Your administrator created a temporary password. Choose a new password before accessing parking data.'**
  String get temporaryPasswordInstructions;

  /// No description provided for @changePasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordButton;

  /// No description provided for @temporaryPasswordGenericError.
  ///
  /// In en, this message translates to:
  /// **'The password could not be changed. Check your connection and retry.'**
  String get temporaryPasswordGenericError;

  /// No description provided for @signOutFailedError.
  ///
  /// In en, this message translates to:
  /// **'You could not be signed out. Please retry.'**
  String get signOutFailedError;

  /// No description provided for @authStateError.
  ///
  /// In en, this message translates to:
  /// **'Unable to read the authentication state. Try again.'**
  String get authStateError;

  /// No description provided for @workspaceLoadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Preparing your workspace…'**
  String get workspaceLoadingMessage;

  /// No description provided for @workspaceAccessLoadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Loading workspace access…'**
  String get workspaceAccessLoadingMessage;

  /// No description provided for @tenantAccessMigrationError.
  ///
  /// In en, this message translates to:
  /// **'Tenant access is not configured. Apply all tenant migrations before using this version.'**
  String get tenantAccessMigrationError;

  /// No description provided for @tenantAccessLoadError.
  ///
  /// In en, this message translates to:
  /// **'Tenant access could not be loaded. Check your connection and retry.'**
  String get tenantAccessLoadError;

  /// No description provided for @noWorkspaceTitle.
  ///
  /// In en, this message translates to:
  /// **'No workspace assigned'**
  String get noWorkspaceTitle;

  /// No description provided for @noWorkspaceMessage.
  ///
  /// In en, this message translates to:
  /// **'Ask your administrator to assign your account to a parking tenant.'**
  String get noWorkspaceMessage;

  /// No description provided for @selectTenantBeforeVehicle.
  ///
  /// In en, this message translates to:
  /// **'Select a tenant before adding a vehicle.'**
  String get selectTenantBeforeVehicle;

  /// No description provided for @createTenantBeforeVehicle.
  ///
  /// In en, this message translates to:
  /// **'Create or restore a tenant before adding a vehicle.'**
  String get createTenantBeforeVehicle;

  /// No description provided for @selectTenantDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Select a tenant'**
  String get selectTenantDialogTitle;

  /// No description provided for @parkingEntrySavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Parking entry for {plate} was saved successfully.'**
  String parkingEntrySavedMessage(String plate);

  /// No description provided for @tenantSelectorTooltip.
  ///
  /// In en, this message translates to:
  /// **'Select tenant'**
  String get tenantSelectorTooltip;

  /// No description provided for @workspaceChipLabel.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get workspaceChipLabel;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSignOutError.
  ///
  /// In en, this message translates to:
  /// **'Unable to sign out. Check your connection and try again.'**
  String get settingsSignOutError;

  /// No description provided for @settingsSigningOut.
  ///
  /// In en, this message translates to:
  /// **'Signing out…'**
  String get settingsSigningOut;

  /// No description provided for @settingsLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageTitle;

  /// No description provided for @settingsLanguageDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the language used throughout the app.'**
  String get settingsLanguageDescription;

  /// No description provided for @deviceSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Your devices'**
  String get deviceSessionTitle;

  /// No description provided for @deviceSessionDescription.
  ///
  /// In en, this message translates to:
  /// **'Review and remove active device sessions for your account.'**
  String get deviceSessionDescription;

  /// No description provided for @deviceSessionLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading your devices…'**
  String get deviceSessionLoading;

  /// No description provided for @deviceSessionLoadError.
  ///
  /// In en, this message translates to:
  /// **'Your device sessions could not be loaded. Check your connection and retry.'**
  String get deviceSessionLoadError;

  /// No description provided for @deviceSessionEmpty.
  ///
  /// In en, this message translates to:
  /// **'No active devices'**
  String get deviceSessionEmpty;

  /// No description provided for @deviceSessionThisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get deviceSessionThisDevice;

  /// No description provided for @deviceSessionOtherDevice.
  ///
  /// In en, this message translates to:
  /// **'Other device'**
  String get deviceSessionOtherDevice;

  /// No description provided for @deviceSessionLastActivity.
  ///
  /// In en, this message translates to:
  /// **'Last active'**
  String get deviceSessionLastActivity;

  /// No description provided for @deviceSessionActiveAuthSessions.
  ///
  /// In en, this message translates to:
  /// **'{count} active sign-in sessions on this device'**
  String deviceSessionActiveAuthSessions(int count);

  /// No description provided for @deviceSessionRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this device?'**
  String get deviceSessionRemoveTitle;

  /// No description provided for @deviceSessionRemoveMessage.
  ///
  /// In en, this message translates to:
  /// **'This will sign out active sessions for this device in {tenant}.'**
  String deviceSessionRemoveMessage(String tenant);

  /// No description provided for @deviceSessionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove device'**
  String get deviceSessionRemove;

  /// No description provided for @deviceSessionRemoved.
  ///
  /// In en, this message translates to:
  /// **'The device session was removed.'**
  String get deviceSessionRemoved;

  /// No description provided for @deviceSessionRemoveError.
  ///
  /// In en, this message translates to:
  /// **'The device session could not be removed. Retry.'**
  String get deviceSessionRemoveError;

  /// No description provided for @deviceSessionRegistrationError.
  ///
  /// In en, this message translates to:
  /// **'This device could not be verified. Check your connection and retry.'**
  String get deviceSessionRegistrationError;

  /// No description provided for @deviceLimitReachedTitle.
  ///
  /// In en, this message translates to:
  /// **'Device limit reached'**
  String get deviceLimitReachedTitle;

  /// No description provided for @deviceLimitReachedMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached the maximum of {limit} active devices for this account.'**
  String deviceLimitReachedMessage(int limit);

  /// No description provided for @deviceLimitReachedInstructions.
  ///
  /// In en, this message translates to:
  /// **'Sign out from another device or remove an existing session below, then try again.'**
  String get deviceLimitReachedInstructions;

  /// No description provided for @deviceLimitTenantChoiceDescription.
  ///
  /// In en, this message translates to:
  /// **'Each tenant has its own device limit. You can choose another tenant without using its allowance on this tenant.'**
  String get deviceLimitTenantChoiceDescription;

  /// No description provided for @deviceLimitTenantChoiceLabel.
  ///
  /// In en, this message translates to:
  /// **'Tenant'**
  String get deviceLimitTenantChoiceLabel;

  /// No description provided for @deviceLimitActiveCount.
  ///
  /// In en, this message translates to:
  /// **'Active devices currently using this account: {count}.'**
  String deviceLimitActiveCount(int count);

  /// No description provided for @deviceLimitTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get deviceLimitTryAgain;

  /// No description provided for @deviceLimitSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get deviceLimitSignOut;

  /// No description provided for @devicePolicyAdminTitle.
  ///
  /// In en, this message translates to:
  /// **'Device-session policies'**
  String get devicePolicyAdminTitle;

  /// No description provided for @devicePolicyAdminDescription.
  ///
  /// In en, this message translates to:
  /// **'Configure inherited device limits, account overrides, active sessions, and revocations.'**
  String get devicePolicyAdminDescription;

  /// No description provided for @devicePolicyManageButton.
  ///
  /// In en, this message translates to:
  /// **'Manage policies'**
  String get devicePolicyManageButton;

  /// No description provided for @devicePolicyLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading device policies…'**
  String get devicePolicyLoading;

  /// No description provided for @devicePolicyLoadError.
  ///
  /// In en, this message translates to:
  /// **'Device policies could not be loaded. Check your connection and retry.'**
  String get devicePolicyLoadError;

  /// No description provided for @devicePolicyValidationError.
  ///
  /// In en, this message translates to:
  /// **'Enter a device limit from 1 to 50 and a stale expiry from 7 to 365 days.'**
  String get devicePolicyValidationError;

  /// No description provided for @devicePolicySavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Device-session policy saved.'**
  String get devicePolicySavedMessage;

  /// No description provided for @devicePolicySaveError.
  ///
  /// In en, this message translates to:
  /// **'The device-session policy could not be saved. Retry.'**
  String get devicePolicySaveError;

  /// No description provided for @devicePolicyTenantsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tenant policies and sessions'**
  String get devicePolicyTenantsTitle;

  /// No description provided for @devicePolicyPlatformTitle.
  ///
  /// In en, this message translates to:
  /// **'Platform default'**
  String get devicePolicyPlatformTitle;

  /// No description provided for @devicePolicyPlatformDescription.
  ///
  /// In en, this message translates to:
  /// **'New tenants inherit this limit unless a tenant or account override is set. Existing overrides are not changed.'**
  String get devicePolicyPlatformDescription;

  /// No description provided for @devicePolicyPlatformLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Default devices per account'**
  String get devicePolicyPlatformLimitLabel;

  /// No description provided for @devicePolicyStaleDaysLabel.
  ///
  /// In en, this message translates to:
  /// **'Stale-session expiry (days)'**
  String get devicePolicyStaleDaysLabel;

  /// No description provided for @devicePolicyRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Allowed range'**
  String get devicePolicyRangeLabel;

  /// No description provided for @devicePolicyAuditTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent audit events'**
  String get devicePolicyAuditTitle;

  /// No description provided for @devicePolicyAuditEmpty.
  ///
  /// In en, this message translates to:
  /// **'No device-session policy changes or revocations have been recorded.'**
  String get devicePolicyAuditEmpty;

  /// No description provided for @deviceAuditPlatformPolicy.
  ///
  /// In en, this message translates to:
  /// **'Platform policy updated'**
  String get deviceAuditPlatformPolicy;

  /// No description provided for @deviceAuditTenantPolicy.
  ///
  /// In en, this message translates to:
  /// **'Tenant policy updated'**
  String get deviceAuditTenantPolicy;

  /// No description provided for @deviceAuditMemberOverride.
  ///
  /// In en, this message translates to:
  /// **'Account override updated'**
  String get deviceAuditMemberOverride;

  /// No description provided for @deviceAuditUserRevoked.
  ///
  /// In en, this message translates to:
  /// **'User removed a device'**
  String get deviceAuditUserRevoked;

  /// No description provided for @deviceAuditAdminRevoked.
  ///
  /// In en, this message translates to:
  /// **'Super Admin revoked a device'**
  String get deviceAuditAdminRevoked;

  /// No description provided for @deviceAuditSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Device session signed out'**
  String get deviceAuditSignedOut;

  /// No description provided for @deviceAuditExpired.
  ///
  /// In en, this message translates to:
  /// **'Stale device session expired'**
  String get deviceAuditExpired;

  /// No description provided for @deviceAuditMembershipRemoved.
  ///
  /// In en, this message translates to:
  /// **'Member sessions revoked after membership removal'**
  String get deviceAuditMembershipRemoved;

  /// No description provided for @deviceAuditSessionRegistered.
  ///
  /// In en, this message translates to:
  /// **'Device session registered'**
  String get deviceAuditSessionRegistered;

  /// No description provided for @deviceAuditLimitRejected.
  ///
  /// In en, this message translates to:
  /// **'Device registration rejected at the limit'**
  String get deviceAuditLimitRejected;

  /// No description provided for @devicePolicyEffectiveLimit.
  ///
  /// In en, this message translates to:
  /// **'Effective limit: {count} devices'**
  String devicePolicyEffectiveLimit(int count);

  /// No description provided for @devicePolicyTenantTitle.
  ///
  /// In en, this message translates to:
  /// **'Tenant limit'**
  String get devicePolicyTenantTitle;

  /// No description provided for @devicePolicySourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Policy source'**
  String get devicePolicySourceLabel;

  /// No description provided for @devicePolicyPlatformDefault.
  ///
  /// In en, this message translates to:
  /// **'Platform default'**
  String get devicePolicyPlatformDefault;

  /// No description provided for @devicePolicyTenantOverride.
  ///
  /// In en, this message translates to:
  /// **'Tenant policy'**
  String get devicePolicyTenantOverride;

  /// No description provided for @devicePolicyAccountOverride.
  ///
  /// In en, this message translates to:
  /// **'Account override'**
  String get devicePolicyAccountOverride;

  /// No description provided for @devicePolicyUsage.
  ///
  /// In en, this message translates to:
  /// **'{devices} active devices across {sessions} sign-in sessions'**
  String devicePolicyUsage(int devices, int sessions);

  /// No description provided for @devicePolicyTenantLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Tenant device limit (blank inherits)'**
  String get devicePolicyTenantLimitLabel;

  /// No description provided for @devicePolicyInheritHint.
  ///
  /// In en, this message translates to:
  /// **'Blank uses the platform default of {count}.'**
  String devicePolicyInheritHint(int count);

  /// No description provided for @devicePolicyMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'Member account limits'**
  String get devicePolicyMembersTitle;

  /// No description provided for @devicePolicyNoMembers.
  ///
  /// In en, this message translates to:
  /// **'No tenant members were found.'**
  String get devicePolicyNoMembers;

  /// No description provided for @devicePolicySetOverride.
  ///
  /// In en, this message translates to:
  /// **'Set override'**
  String get devicePolicySetOverride;

  /// No description provided for @devicePolicyActiveDevices.
  ///
  /// In en, this message translates to:
  /// **'{count} active devices'**
  String devicePolicyActiveDevices(int count);

  /// No description provided for @devicePolicySessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Active device sessions'**
  String get devicePolicySessionsTitle;

  /// No description provided for @devicePolicyNoSessions.
  ///
  /// In en, this message translates to:
  /// **'No active device sessions.'**
  String get devicePolicyNoSessions;

  /// No description provided for @devicePolicyInstallationLabel.
  ///
  /// In en, this message translates to:
  /// **'Device …{id}'**
  String devicePolicyInstallationLabel(String id);

  /// No description provided for @devicePolicyActiveSessions.
  ///
  /// In en, this message translates to:
  /// **'{count} active sign-in sessions'**
  String devicePolicyActiveSessions(int count);

  /// No description provided for @devicePolicyRevokeTitle.
  ///
  /// In en, this message translates to:
  /// **'Revoke this device?'**
  String get devicePolicyRevokeTitle;

  /// No description provided for @devicePolicyRevokeMessage.
  ///
  /// In en, this message translates to:
  /// **'Revoke this active device session for {email}? The account will need to sign in again on that device.'**
  String devicePolicyRevokeMessage(String email);

  /// No description provided for @devicePolicyRevokeButton.
  ///
  /// In en, this message translates to:
  /// **'Revoke device'**
  String get devicePolicyRevokeButton;

  /// No description provided for @devicePolicyRevokeError.
  ///
  /// In en, this message translates to:
  /// **'The device session could not be revoked. Retry.'**
  String get devicePolicyRevokeError;

  /// No description provided for @devicePolicyMemberOverrideTitle.
  ///
  /// In en, this message translates to:
  /// **'Account device override'**
  String get devicePolicyMemberOverrideTitle;

  /// No description provided for @devicePolicyOverrideLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Devices allowed for this account'**
  String get devicePolicyOverrideLimitLabel;

  /// No description provided for @devicePolicyInheritButton.
  ///
  /// In en, this message translates to:
  /// **'Use inherited limit'**
  String get devicePolicyInheritButton;

  /// No description provided for @dashboardOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Parking overview'**
  String get dashboardOverviewTitle;

  /// No description provided for @dashboardOverviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Monitor current activity and manage vehicle entries.'**
  String get dashboardOverviewSubtitle;

  /// No description provided for @dashboardRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get dashboardRefresh;

  /// No description provided for @dashboardNewEntry.
  ///
  /// In en, this message translates to:
  /// **'New Parking Entry'**
  String get dashboardNewEntry;

  /// No description provided for @dashboardActiveMessage.
  ///
  /// In en, this message translates to:
  /// **'Currently within the allowed duration'**
  String get dashboardActiveMessage;

  /// No description provided for @dashboardExpiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Past the recorded expiry time'**
  String get dashboardExpiredMessage;

  /// No description provided for @searchRegistrationLabel.
  ///
  /// In en, this message translates to:
  /// **'Search registration'**
  String get searchRegistrationLabel;

  /// No description provided for @searchByPlateHint.
  ///
  /// In en, this message translates to:
  /// **'Search by plate number'**
  String get searchByPlateHint;

  /// No description provided for @clearSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearchTooltip;

  /// No description provided for @dashboardNoSessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'No parking sessions yet'**
  String get dashboardNoSessionsTitle;

  /// No description provided for @noMatchingSessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching sessions'**
  String get noMatchingSessionsTitle;

  /// No description provided for @dashboardNoSessionsMessage.
  ///
  /// In en, this message translates to:
  /// **'Create a parking entry to start tracking a vehicle.'**
  String get dashboardNoSessionsMessage;

  /// No description provided for @tryDifferentSearchMessage.
  ///
  /// In en, this message translates to:
  /// **'Try a different registration search.'**
  String get tryDifferentSearchMessage;

  /// No description provided for @dashboardRecentSessions.
  ///
  /// In en, this message translates to:
  /// **'Recent sessions'**
  String get dashboardRecentSessions;

  /// No description provided for @dashboardViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get dashboardViewAll;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// No description provided for @historyRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh history'**
  String get historyRefreshTooltip;

  /// No description provided for @historyFilterPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get historyFilterPaid;

  /// No description provided for @historyFilterPartiallyPaid.
  ///
  /// In en, this message translates to:
  /// **'Partially paid'**
  String get historyFilterPartiallyPaid;

  /// No description provided for @historyFilterUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get historyFilterUnpaid;

  /// No description provided for @historyClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get historyClearFilters;

  /// No description provided for @historyNoHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'No parking history'**
  String get historyNoHistoryTitle;

  /// No description provided for @historyNoMatchFilters.
  ///
  /// In en, this message translates to:
  /// **'No sessions match the selected filters.'**
  String get historyNoMatchFilters;

  /// No description provided for @historySavedWillAppear.
  ///
  /// In en, this message translates to:
  /// **'Saved parking sessions will appear here.'**
  String get historySavedWillAppear;

  /// No description provided for @historyLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get historyLoadMore;

  /// No description provided for @sessionEntryExpiryTemplate.
  ///
  /// In en, this message translates to:
  /// **'Entry: {entry}\nExpiry: {expiry}'**
  String sessionEntryExpiryTemplate(String entry, String expiry);

  /// No description provided for @contactLineTemplate.
  ///
  /// In en, this message translates to:
  /// **'Contact: {contact}'**
  String contactLineTemplate(String contact);

  /// No description provided for @paymentTooltipTemplate.
  ///
  /// In en, this message translates to:
  /// **'Total: {total}\nPaid: {paid}\nRemaining: {remaining}'**
  String paymentTooltipTemplate(String total, String paid, String remaining);

  /// No description provided for @dateTimeAtTemplate.
  ///
  /// In en, this message translates to:
  /// **'{date} at {time}'**
  String dateTimeAtTemplate(String date, String time);

  /// No description provided for @sessionDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Parking Session'**
  String get sessionDetailsTitle;

  /// No description provided for @editSessionTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit session'**
  String get editSessionTooltip;

  /// No description provided for @deleteSessionTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete session'**
  String get deleteSessionTooltip;

  /// No description provided for @sessionNoIdError.
  ///
  /// In en, this message translates to:
  /// **'This parking session has no identifier.'**
  String get sessionNoIdError;

  /// No description provided for @deleteSessionDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete parking session?'**
  String get deleteSessionDialogTitle;

  /// No description provided for @deleteSessionDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete the parking session for {plate}? This action cannot be undone.'**
  String deleteSessionDialogMessage(String plate);

  /// No description provided for @detailEntryTime.
  ///
  /// In en, this message translates to:
  /// **'Entry time'**
  String get detailEntryTime;

  /// No description provided for @detailContactNumber.
  ///
  /// In en, this message translates to:
  /// **'Contact number'**
  String get detailContactNumber;

  /// No description provided for @detailNotProvided.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get detailNotProvided;

  /// No description provided for @detailAllowedDuration.
  ///
  /// In en, this message translates to:
  /// **'Allowed duration'**
  String get detailAllowedDuration;

  /// No description provided for @detailExpiry.
  ///
  /// In en, this message translates to:
  /// **'Expiry'**
  String get detailExpiry;

  /// No description provided for @detailTotalCharge.
  ///
  /// In en, this message translates to:
  /// **'Total charge'**
  String get detailTotalCharge;

  /// No description provided for @detailAmountPaid.
  ///
  /// In en, this message translates to:
  /// **'Amount paid'**
  String get detailAmountPaid;

  /// No description provided for @detailRemainingBalance.
  ///
  /// In en, this message translates to:
  /// **'Remaining balance'**
  String get detailRemainingBalance;

  /// No description provided for @noVehiclePhotoMessage.
  ///
  /// In en, this message translates to:
  /// **'No vehicle photo is attached to this session.'**
  String get noVehiclePhotoMessage;

  /// No description provided for @vehiclePhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle photo'**
  String get vehiclePhotoTitle;

  /// No description provided for @photoDisplayError.
  ///
  /// In en, this message translates to:
  /// **'The private vehicle photo could not be displayed.'**
  String get photoDisplayError;

  /// No description provided for @durationUnitMinutes.
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get durationUnitMinutes;

  /// No description provided for @durationUnitHours.
  ///
  /// In en, this message translates to:
  /// **'hours'**
  String get durationUnitHours;

  /// No description provided for @durationUnitDays.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get durationUnitDays;

  /// No description provided for @durationUnitMonths.
  ///
  /// In en, this message translates to:
  /// **'months'**
  String get durationUnitMonths;

  /// No description provided for @durationUnitMinutesCap.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get durationUnitMinutesCap;

  /// No description provided for @durationUnitHoursCap.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get durationUnitHoursCap;

  /// No description provided for @durationUnitDaysCap.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get durationUnitDaysCap;

  /// No description provided for @durationUnitMonthsCap.
  ///
  /// In en, this message translates to:
  /// **'Months'**
  String get durationUnitMonthsCap;

  /// No description provided for @entryPageEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Parking Entry'**
  String get entryPageEditTitle;

  /// No description provided for @entryPageNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New Parking Entry'**
  String get entryPageNewTitle;

  /// No description provided for @cameraOpenError.
  ///
  /// In en, this message translates to:
  /// **'The camera could not be opened. Choose a file instead.'**
  String get cameraOpenError;

  /// No description provided for @imageSelectError.
  ///
  /// In en, this message translates to:
  /// **'The image could not be selected. Try again or choose a file instead.'**
  String get imageSelectError;

  /// No description provided for @plateRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a vehicle registration number.'**
  String get plateRequired;

  /// No description provided for @plateTooLong.
  ///
  /// In en, this message translates to:
  /// **'Use 64 characters or fewer.'**
  String get plateTooLong;

  /// No description provided for @contactRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a contact mobile number.'**
  String get contactRequired;

  /// No description provided for @contactInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 10-digit mobile number, with or without +91.'**
  String get contactInvalid;

  /// No description provided for @durationRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a parking duration.'**
  String get durationRequired;

  /// No description provided for @durationPositiveInteger.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive whole number.'**
  String get durationPositiveInteger;

  /// No description provided for @durationMaxExceeded.
  ///
  /// In en, this message translates to:
  /// **'The maximum for {unit} is {max}.'**
  String durationMaxExceeded(String unit, int max);

  /// No description provided for @expiryCalculationError.
  ///
  /// In en, this message translates to:
  /// **'The expiry time could not be calculated.'**
  String get expiryCalculationError;

  /// No description provided for @amountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount.'**
  String get amountInvalid;

  /// No description provided for @chargeNegative.
  ///
  /// In en, this message translates to:
  /// **'The charge cannot be negative.'**
  String get chargeNegative;

  /// No description provided for @paidNegative.
  ///
  /// In en, this message translates to:
  /// **'The amount paid cannot be negative.'**
  String get paidNegative;

  /// No description provided for @paidExceedsTotal.
  ///
  /// In en, this message translates to:
  /// **'The amount paid cannot exceed the total charge.'**
  String get paidExceedsTotal;

  /// No description provided for @durationBeforeSaving.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid duration before saving.'**
  String get durationBeforeSaving;

  /// No description provided for @chargeBeforeSaving.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid parking charge before saving.'**
  String get chargeBeforeSaving;

  /// No description provided for @saveGenericError.
  ///
  /// In en, this message translates to:
  /// **'The parking entry could not be saved. Check your connection and try again.'**
  String get saveGenericError;

  /// No description provided for @photoSelectionRequired.
  ///
  /// In en, this message translates to:
  /// **'Select a vehicle photo or explicitly choose Continue without photo.'**
  String get photoSelectionRequired;

  /// No description provided for @cleanupGenericError.
  ///
  /// In en, this message translates to:
  /// **'Cleanup could not complete. Check your connection and retry.'**
  String get cleanupGenericError;

  /// No description provided for @cleanupSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Cleanup completed. The incomplete session was removed. You can try again.'**
  String get cleanupSuccessMessage;

  /// No description provided for @photoCleanupGenericError.
  ///
  /// In en, this message translates to:
  /// **'Photo cleanup could not complete. Check your connection and retry.'**
  String get photoCleanupGenericError;

  /// No description provided for @photoCleanupSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Photo cleanup completed. Review the changes and try saving again.'**
  String get photoCleanupSuccessMessage;

  /// No description provided for @introEditing.
  ///
  /// In en, this message translates to:
  /// **'Update the vehicle details and confirm the expiry time before saving.'**
  String get introEditing;

  /// No description provided for @introCreating.
  ///
  /// In en, this message translates to:
  /// **'Enter the vehicle details and confirm the expiry time before saving.'**
  String get introCreating;

  /// No description provided for @parkingDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Parking details'**
  String get parkingDetailsTitle;

  /// No description provided for @vehicleRegistrationLabel.
  ///
  /// In en, this message translates to:
  /// **'Vehicle registration'**
  String get vehicleRegistrationLabel;

  /// No description provided for @vehicleRegistrationHint.
  ///
  /// In en, this message translates to:
  /// **'For example, ABC 123'**
  String get vehicleRegistrationHint;

  /// No description provided for @contactNumberHint.
  ///
  /// In en, this message translates to:
  /// **'For example, 9876543210 or +919876543210'**
  String get contactNumberHint;

  /// No description provided for @unitLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unitLabel;

  /// No description provided for @parkingChargeTitle.
  ///
  /// In en, this message translates to:
  /// **'Parking charge'**
  String get parkingChargeTitle;

  /// No description provided for @totalChargeLabel.
  ///
  /// In en, this message translates to:
  /// **'Total charge'**
  String get totalChargeLabel;

  /// No description provided for @totalChargeHint.
  ///
  /// In en, this message translates to:
  /// **'For example, 50.00'**
  String get totalChargeHint;

  /// No description provided for @fullyPaidLabel.
  ///
  /// In en, this message translates to:
  /// **'Fully paid'**
  String get fullyPaidLabel;

  /// No description provided for @fullyPaidSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Leave unchecked to record a partial payment.'**
  String get fullyPaidSubtitle;

  /// No description provided for @amountPaidHint.
  ///
  /// In en, this message translates to:
  /// **'For example, 20.00'**
  String get amountPaidHint;

  /// No description provided for @entryDateTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Entry date and time'**
  String get entryDateTimeLabel;

  /// No description provided for @calculatedExpiryTitle.
  ///
  /// In en, this message translates to:
  /// **'Calculated expiry'**
  String get calculatedExpiryTitle;

  /// No description provided for @expiryPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Expiry preview'**
  String get expiryPreviewTitle;

  /// No description provided for @expiryPreviewMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid duration to calculate the expiry.'**
  String get expiryPreviewMessage;

  /// No description provided for @vehiclePhotoInstructions.
  ///
  /// In en, this message translates to:
  /// **'Use the camera when supported, or choose an existing JPEG, PNG, or WebP image.'**
  String get vehiclePhotoInstructions;

  /// No description provided for @imagePreviewError.
  ///
  /// In en, this message translates to:
  /// **'This image cannot be previewed in the browser.'**
  String get imagePreviewError;

  /// No description provided for @existingPhotoKeptTitle.
  ///
  /// In en, this message translates to:
  /// **'Existing private photo will be kept'**
  String get existingPhotoKeptTitle;

  /// No description provided for @existingPhotoKeptSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a new photo only if you want to replace it.'**
  String get existingPhotoKeptSubtitle;

  /// No description provided for @replaceWithCamera.
  ///
  /// In en, this message translates to:
  /// **'Replace with camera'**
  String get replaceWithCamera;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @retakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Retake photo'**
  String get retakePhoto;

  /// No description provided for @chooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose file'**
  String get chooseFile;

  /// No description provided for @replacePhoto.
  ///
  /// In en, this message translates to:
  /// **'Replace photo'**
  String get replacePhoto;

  /// No description provided for @discardReplacement.
  ///
  /// In en, this message translates to:
  /// **'Discard replacement'**
  String get discardReplacement;

  /// No description provided for @removeButton.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeButton;

  /// No description provided for @continueWithoutPhoto.
  ///
  /// In en, this message translates to:
  /// **'Continue without photo'**
  String get continueWithoutPhoto;

  /// No description provided for @continueWithoutPhotoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose this explicitly if no photo is available.'**
  String get continueWithoutPhotoSubtitle;

  /// No description provided for @updatingButton.
  ///
  /// In en, this message translates to:
  /// **'Updating...'**
  String get updatingButton;

  /// No description provided for @savingButton.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get savingButton;

  /// No description provided for @updateEntryButton.
  ///
  /// In en, this message translates to:
  /// **'Update parking entry'**
  String get updateEntryButton;

  /// No description provided for @saveEntryButton.
  ///
  /// In en, this message translates to:
  /// **'Save parking entry'**
  String get saveEntryButton;

  /// No description provided for @retryingCleanup.
  ///
  /// In en, this message translates to:
  /// **'Retrying cleanup...'**
  String get retryingCleanup;

  /// No description provided for @retryCleanupButton.
  ///
  /// In en, this message translates to:
  /// **'Retry cleanup'**
  String get retryCleanupButton;

  /// No description provided for @retryingPhotoCleanup.
  ///
  /// In en, this message translates to:
  /// **'Retrying photo cleanup...'**
  String get retryingPhotoCleanup;

  /// No description provided for @retryPhotoCleanupButton.
  ///
  /// In en, this message translates to:
  /// **'Retry photo cleanup'**
  String get retryPhotoCleanupButton;

  /// No description provided for @captureDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Take vehicle photo'**
  String get captureDialogTitle;

  /// No description provided for @cameraTimeoutError.
  ///
  /// In en, this message translates to:
  /// **'The camera took too long to initialize. Check permissions and try again.'**
  String get cameraTimeoutError;

  /// No description provided for @cameraInitError.
  ///
  /// In en, this message translates to:
  /// **'The camera could not be initialized. Check browser permissions and try again.'**
  String get cameraInitError;

  /// No description provided for @captureTimeoutError.
  ///
  /// In en, this message translates to:
  /// **'The camera capture took too long. Try again or choose a file instead.'**
  String get captureTimeoutError;

  /// No description provided for @captureGenericError.
  ///
  /// In en, this message translates to:
  /// **'The photo could not be captured. Try again.'**
  String get captureGenericError;

  /// No description provided for @switchTimeoutError.
  ///
  /// In en, this message translates to:
  /// **'Switching cameras took too long. Try again or choose a file instead.'**
  String get switchTimeoutError;

  /// No description provided for @switchGenericError.
  ///
  /// In en, this message translates to:
  /// **'The selected camera could not be opened. Try another camera or choose a file instead.'**
  String get switchGenericError;

  /// No description provided for @switchingCamera.
  ///
  /// In en, this message translates to:
  /// **'Switching...'**
  String get switchingCamera;

  /// No description provided for @switchCameraButton.
  ///
  /// In en, this message translates to:
  /// **'Switch camera'**
  String get switchCameraButton;

  /// No description provided for @capturingButton.
  ///
  /// In en, this message translates to:
  /// **'Capturing...'**
  String get capturingButton;

  /// No description provided for @captureButton.
  ///
  /// In en, this message translates to:
  /// **'Capture'**
  String get captureButton;

  /// No description provided for @retakeButton.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get retakeButton;

  /// No description provided for @usePhotoButton.
  ///
  /// In en, this message translates to:
  /// **'Use Photo'**
  String get usePhotoButton;

  /// No description provided for @cameraUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'The camera is unavailable. Choose an existing photo.'**
  String get cameraUnavailableMessage;

  /// No description provided for @tenantCreatedMessage.
  ///
  /// In en, this message translates to:
  /// **'{tenant} was created.'**
  String tenantCreatedMessage(String tenant);

  /// No description provided for @tenantCreatedWithPasswordMessage.
  ///
  /// In en, this message translates to:
  /// **'{tenant} was created. The temporary password was shown once.'**
  String tenantCreatedWithPasswordMessage(String tenant);

  /// No description provided for @tenantCreateGenericError.
  ///
  /// In en, this message translates to:
  /// **'The tenant could not be created. Check your connection and retry.'**
  String get tenantCreateGenericError;

  /// No description provided for @tenantUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'{tenant} was updated.'**
  String tenantUpdatedMessage(String tenant);

  /// No description provided for @archiveTenantTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive tenant?'**
  String get archiveTenantTitle;

  /// No description provided for @archiveTenantMessage.
  ///
  /// In en, this message translates to:
  /// **'{tenant} will no longer be available to its members. Parking records and photos will be retained, and this tenant can be restored later.'**
  String archiveTenantMessage(String tenant);

  /// No description provided for @archiveButton.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archiveButton;

  /// No description provided for @tenantArchivedMessage.
  ///
  /// In en, this message translates to:
  /// **'{tenant} was archived. Its data was retained.'**
  String tenantArchivedMessage(String tenant);

  /// No description provided for @tenantRestoredMessage.
  ///
  /// In en, this message translates to:
  /// **'{tenant} was restored.'**
  String tenantRestoredMessage(String tenant);

  /// No description provided for @tenantUpdateGenericError.
  ///
  /// In en, this message translates to:
  /// **'The tenant could not be updated. Check your connection and retry.'**
  String get tenantUpdateGenericError;

  /// No description provided for @tenantWorkspacesTitle.
  ///
  /// In en, this message translates to:
  /// **'Tenant workspaces'**
  String get tenantWorkspacesTitle;

  /// No description provided for @tenantWorkspacesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Each workspace keeps its parking records and photos isolated.'**
  String get tenantWorkspacesSubtitle;

  /// No description provided for @allTenantsTitle.
  ///
  /// In en, this message translates to:
  /// **'All tenants'**
  String get allTenantsTitle;

  /// No description provided for @createTenantButton.
  ///
  /// In en, this message translates to:
  /// **'Create tenant'**
  String get createTenantButton;

  /// No description provided for @noTenantsTitle.
  ///
  /// In en, this message translates to:
  /// **'No tenant workspaces yet'**
  String get noTenantsTitle;

  /// No description provided for @noTenantsMessage.
  ///
  /// In en, this message translates to:
  /// **'Create a workspace and assign an existing Supabase account as its owner.'**
  String get noTenantsMessage;

  /// No description provided for @validUntilTemplate.
  ///
  /// In en, this message translates to:
  /// **'Valid until {date}'**
  String validUntilTemplate(String date);

  /// No description provided for @manageTenantTooltip.
  ///
  /// In en, this message translates to:
  /// **'Manage {name}'**
  String manageTenantTooltip(String name);

  /// No description provided for @manageMembersMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Manage members'**
  String get manageMembersMenuItem;

  /// No description provided for @archiveTenantMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Archive tenant'**
  String get archiveTenantMenuItem;

  /// No description provided for @restoreTenantMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Restore tenant'**
  String get restoreTenantMenuItem;

  /// No description provided for @superAdminTitle.
  ///
  /// In en, this message translates to:
  /// **'Super Admin'**
  String get superAdminTitle;

  /// No description provided for @superAdminSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage parking workspaces across the platform.'**
  String get superAdminSubtitle;

  /// No description provided for @createTenantDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Create tenant'**
  String get createTenantDialogTitle;

  /// No description provided for @tenantCreatedDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Tenant created'**
  String get tenantCreatedDialogTitle;

  /// No description provided for @tenantNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Tenant name'**
  String get tenantNameLabel;

  /// No description provided for @tenantNameHint.
  ///
  /// In en, this message translates to:
  /// **'Example: Central Parking'**
  String get tenantNameHint;

  /// No description provided for @tenantNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a tenant name.'**
  String get tenantNameRequired;

  /// No description provided for @tenantNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Use 120 characters or fewer.'**
  String get tenantNameTooLong;

  /// No description provided for @ownerEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Owner email'**
  String get ownerEmailLabel;

  /// No description provided for @ownerEmailHint.
  ///
  /// In en, this message translates to:
  /// **'owner@example.com'**
  String get ownerEmailHint;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get emailInvalid;

  /// No description provided for @activeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Inactive tenants cannot sign in until reactivated.'**
  String get activeSubtitle;

  /// No description provided for @validUntilTitle.
  ///
  /// In en, this message translates to:
  /// **'Valid until'**
  String get validUntilTitle;

  /// No description provided for @contactPersonNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Contact person name (optional)'**
  String get contactPersonNameLabel;

  /// No description provided for @contactMobileLabel.
  ///
  /// In en, this message translates to:
  /// **'Contact mobile (optional)'**
  String get contactMobileLabel;

  /// No description provided for @contactMobileHint.
  ///
  /// In en, this message translates to:
  /// **'9876543210 or +919876543210'**
  String get contactMobileHint;

  /// No description provided for @contactMobileInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 10-digit Indian mobile number.'**
  String get contactMobileInvalid;

  /// No description provided for @contactEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Contact email (optional)'**
  String get contactEmailLabel;

  /// No description provided for @accountPasswordNote.
  ///
  /// In en, this message translates to:
  /// **'An existing account keeps its current password. A new account receives a temporary password that must be changed before it can access parking data.'**
  String get accountPasswordNote;

  /// No description provided for @copyPasswordFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Could not copy the password. Select it and copy it manually.'**
  String get copyPasswordFailedMessage;

  /// No description provided for @passwordCopiedMessage.
  ///
  /// In en, this message translates to:
  /// **'Temporary password copied.'**
  String get passwordCopiedMessage;

  /// No description provided for @tenantReadyMessage.
  ///
  /// In en, this message translates to:
  /// **'{tenant} is ready.'**
  String tenantReadyMessage(String tenant);

  /// No description provided for @ownerMustChangePassword.
  ///
  /// In en, this message translates to:
  /// **'The owner must change this password before accessing tenant data.'**
  String get ownerMustChangePassword;

  /// No description provided for @sharePasswordSecurely.
  ///
  /// In en, this message translates to:
  /// **'Share this password with the owner through a secure channel. It will not be shown again after closing this dialog.'**
  String get sharePasswordSecurely;

  /// No description provided for @temporaryPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Temporary password'**
  String get temporaryPasswordLabel;

  /// No description provided for @retrySetupNote.
  ///
  /// In en, this message translates to:
  /// **'If you retry setup, use the latest password shown here.'**
  String get retrySetupNote;

  /// No description provided for @copyButton.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyButton;

  /// No description provided for @closeWithPasswordSavedButton.
  ///
  /// In en, this message translates to:
  /// **'Close (I\'ve saved the password)'**
  String get closeWithPasswordSavedButton;

  /// No description provided for @retryTenantSetupButton.
  ///
  /// In en, this message translates to:
  /// **'Retry tenant setup'**
  String get retryTenantSetupButton;

  /// No description provided for @doneButton.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneButton;

  /// No description provided for @editTenantDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit tenant'**
  String get editTenantDialogTitle;

  /// No description provided for @removeTenantMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove tenant member?'**
  String get removeTenantMemberTitle;

  /// No description provided for @removeTenantMemberMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove {email} from {tenant}? Their Auth account and parking records will not be deleted.'**
  String removeTenantMemberMessage(String email, String tenant);

  /// No description provided for @membersDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Members: {tenant}'**
  String membersDialogTitle(String tenant);

  /// No description provided for @restoreBeforeAddingMembers.
  ///
  /// In en, this message translates to:
  /// **'Restore this tenant before adding members.'**
  String get restoreBeforeAddingMembers;

  /// No description provided for @existingAccountEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Member account email'**
  String get existingAccountEmailLabel;

  /// No description provided for @memberEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Member email'**
  String get memberEmailLabel;

  /// No description provided for @roleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get roleLabel;

  /// No description provided for @addButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addButton;

  /// No description provided for @noMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'No members'**
  String get noMembersTitle;

  /// No description provided for @noMembersMessage.
  ///
  /// In en, this message translates to:
  /// **'Add an existing account or create a new member login for this tenant.'**
  String get noMembersMessage;

  /// No description provided for @keepAtLeastOneOwner.
  ///
  /// In en, this message translates to:
  /// **'Each tenant must keep at least one owner.'**
  String get keepAtLeastOneOwner;

  /// No description provided for @unknownEmail.
  ///
  /// In en, this message translates to:
  /// **'Unknown email'**
  String get unknownEmail;

  /// No description provided for @manageMemberTooltip.
  ///
  /// In en, this message translates to:
  /// **'Manage {email}'**
  String manageMemberTooltip(String email);

  /// No description provided for @makeOwnerMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Make owner'**
  String get makeOwnerMenuItem;

  /// No description provided for @makeMemberMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Make member'**
  String get makeMemberMenuItem;

  /// No description provided for @removeMemberMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Remove member'**
  String get removeMemberMenuItem;

  /// No description provided for @roleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get roleOwner;

  /// No description provided for @roleMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get roleMember;

  /// No description provided for @membersLoadGenericError.
  ///
  /// In en, this message translates to:
  /// **'Tenant members could not be loaded. Retry the request.'**
  String get membersLoadGenericError;

  /// No description provided for @memberActionGenericError.
  ///
  /// In en, this message translates to:
  /// **'The member change failed. Check your connection and retry.'**
  String get memberActionGenericError;

  /// No description provided for @addOnlyAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'You can add parking entries'**
  String get addOnlyAccessTitle;

  /// No description provided for @addOnlyAccessMessage.
  ///
  /// In en, this message translates to:
  /// **'You can create parking entries but cannot view existing records. Ask the tenant owner to enable View if you need to see them.'**
  String get addOnlyAccessMessage;

  /// No description provided for @limitedEntryPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'View permission is disabled'**
  String get limitedEntryPermissionsTitle;

  /// No description provided for @limitedEntryPermissionsMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account has entry-management permissions, but records are not visible without View. Ask the tenant owner to enable View.'**
  String get limitedEntryPermissionsMessage;

  /// No description provided for @noEntryPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'No parking-entry access'**
  String get noEntryPermissionsTitle;

  /// No description provided for @noEntryPermissionsMessage.
  ///
  /// In en, this message translates to:
  /// **'Your tenant owner has not enabled any parking-entry permissions for your account.'**
  String get noEntryPermissionsMessage;

  /// No description provided for @navAddEntry.
  ///
  /// In en, this message translates to:
  /// **'Add entry'**
  String get navAddEntry;

  /// No description provided for @navEntryAccess.
  ///
  /// In en, this message translates to:
  /// **'Entry access'**
  String get navEntryAccess;

  /// No description provided for @settingsManageMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'Tenant members'**
  String get settingsManageMembersTitle;

  /// No description provided for @settingsManageMembersDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage member accounts in this tenant, their parking-entry permissions, and member usage.'**
  String get settingsManageMembersDescription;

  /// No description provided for @settingsParkingNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Parking reminders'**
  String get settingsParkingNotificationsTitle;

  /// No description provided for @settingsParkingNotificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications on this device. Expired parking sessions with an outstanding balance send a reminder every five minutes. Tapping a reminder opens the parking record after sign-in and access checks.'**
  String get settingsParkingNotificationsDescription;

  /// No description provided for @parkingNotificationsEnableAction.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get parkingNotificationsEnableAction;

  /// No description provided for @parkingNotificationsDisableAction.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get parkingNotificationsDisableAction;

  /// No description provided for @parkingNotificationsStatusLoading.
  ///
  /// In en, this message translates to:
  /// **'Checking push notification settings…'**
  String get parkingNotificationsStatusLoading;

  /// No description provided for @parkingNotificationsSetupRequired.
  ///
  /// In en, this message translates to:
  /// **'OneSignal is not configured for this deployment.'**
  String get parkingNotificationsSetupRequired;

  /// No description provided for @parkingNotificationsUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This browser or platform does not support push notifications.'**
  String get parkingNotificationsUnsupported;

  /// No description provided for @parkingNotificationsPermissionNotGranted.
  ///
  /// In en, this message translates to:
  /// **'Notifications are not allowed. Enable site notifications in your browser settings, then retry.'**
  String get parkingNotificationsPermissionNotGranted;

  /// No description provided for @parkingNotificationsPending.
  ///
  /// In en, this message translates to:
  /// **'The push subscription is still being updated. Retry in a moment.'**
  String get parkingNotificationsPending;

  /// No description provided for @parkingNotificationsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Push notifications are enabled for this account on this device.'**
  String get parkingNotificationsEnabled;

  /// No description provided for @parkingNotificationsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Push notifications are disabled on this device.'**
  String get parkingNotificationsDisabled;

  /// No description provided for @parkingNotificationsEnabledMessage.
  ///
  /// In en, this message translates to:
  /// **'Parking reminders enabled.'**
  String get parkingNotificationsEnabledMessage;

  /// No description provided for @parkingNotificationsDisabledMessage.
  ///
  /// In en, this message translates to:
  /// **'Parking reminders disabled.'**
  String get parkingNotificationsDisabledMessage;

  /// No description provided for @parkingNotificationsNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in again before enabling or disabling push notifications.'**
  String get parkingNotificationsNotSignedIn;

  /// No description provided for @parkingNotificationsRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Push notification settings could not be updated. Check your connection and retry.'**
  String get parkingNotificationsRequestFailed;

  /// No description provided for @parkingNotificationsCenterTitle.
  ///
  /// In en, this message translates to:
  /// **'Parking notifications'**
  String get parkingNotificationsCenterTitle;

  /// No description provided for @parkingNotificationsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No unpaid parking reminders'**
  String get parkingNotificationsEmptyTitle;

  /// No description provided for @parkingNotificationsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Expired parking sessions with an outstanding balance will appear here.'**
  String get parkingNotificationsEmptyMessage;

  /// No description provided for @parkingNotificationsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Parking notifications could not be loaded. Check your connection and retry.'**
  String get parkingNotificationsLoadFailed;

  /// No description provided for @parkingNotificationsInvalidData.
  ///
  /// In en, this message translates to:
  /// **'Parking notification data is invalid. Contact the system administrator.'**
  String get parkingNotificationsInvalidData;

  /// No description provided for @parkingNotificationsMarkReadFailed.
  ///
  /// In en, this message translates to:
  /// **'The notification could not be marked as read.'**
  String get parkingNotificationsMarkReadFailed;

  /// No description provided for @parkingNotificationsClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get parkingNotificationsClearAll;

  /// No description provided for @parkingNotificationsClearAllFailed.
  ///
  /// In en, this message translates to:
  /// **'The notifications could not be cleared. Please retry.'**
  String get parkingNotificationsClearAllFailed;

  /// No description provided for @parkingNotificationsOpenAction.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get parkingNotificationsOpenAction;

  /// Title for an expired parking notification with a shortened vehicle registration.
  ///
  /// In en, this message translates to:
  /// **'Parking Expired - {platePrefix}...'**
  String parkingNotificationExpiredTitle(String platePrefix);

  /// No description provided for @parkingNotificationExpiredBody.
  ///
  /// In en, this message translates to:
  /// **'Full-Amount Not Paid'**
  String get parkingNotificationExpiredBody;

  /// No description provided for @parkingNotificationsSessionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'That parking session is no longer available in this tenant.'**
  String get parkingNotificationsSessionUnavailable;

  /// No description provided for @parkingNotificationsLaunchInvalid.
  ///
  /// In en, this message translates to:
  /// **'The parking notification link is invalid or expired.'**
  String get parkingNotificationsLaunchInvalid;

  /// No description provided for @settingsManageTenantsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tenant administration'**
  String get settingsManageTenantsTitle;

  /// No description provided for @settingsManageTenantsDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage tenant details, members, member limits, and device-session policies.'**
  String get settingsManageTenantsDescription;

  /// No description provided for @manageTenantsMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Manage tenants'**
  String get manageTenantsMenuItem;

  /// No description provided for @memberUsageTemplate.
  ///
  /// In en, this message translates to:
  /// **'{active} of {limit} members used (owner excluded)'**
  String memberUsageTemplate(int active, int limit);

  /// No description provided for @memberUsageLoading.
  ///
  /// In en, this message translates to:
  /// **'Member usage loading…'**
  String get memberUsageLoading;

  /// No description provided for @memberUsageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Member usage unavailable'**
  String get memberUsageUnavailable;

  /// No description provided for @memberCapacityLoadError.
  ///
  /// In en, this message translates to:
  /// **'Tenant member usage could not be loaded.'**
  String get memberCapacityLoadError;

  /// No description provided for @memberRemainingTemplate.
  ///
  /// In en, this message translates to:
  /// **'{count} member slots remaining'**
  String memberRemainingTemplate(int count);

  /// No description provided for @memberLimitOwnerHint.
  ///
  /// In en, this message translates to:
  /// **'Only a Super Admin can change this limit. The tenant owner is not counted.'**
  String get memberLimitOwnerHint;

  /// No description provided for @memberLimitAdminHint.
  ///
  /// In en, this message translates to:
  /// **'Counts member accounts only; the tenant owner is excluded. Allowed range: 1–50.'**
  String get memberLimitAdminHint;

  /// No description provided for @memberLimitEditButton.
  ///
  /// In en, this message translates to:
  /// **'Change limit'**
  String get memberLimitEditButton;

  /// No description provided for @memberLimitIncreaseButton.
  ///
  /// In en, this message translates to:
  /// **'Increase member limit'**
  String get memberLimitIncreaseButton;

  /// No description provided for @memberLimitReachedTitle.
  ///
  /// In en, this message translates to:
  /// **'Member limit reached'**
  String get memberLimitReachedTitle;

  /// No description provided for @memberLimitReachedMessage.
  ///
  /// In en, this message translates to:
  /// **'This tenant uses {active} of {limit} allowed members. Remove a member or ask a Super Admin to increase the limit.'**
  String memberLimitReachedMessage(int active, int limit);

  /// No description provided for @memberLimitDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Set tenant member limit'**
  String get memberLimitDialogTitle;

  /// No description provided for @memberLimitFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Allowed members'**
  String get memberLimitFieldLabel;

  /// No description provided for @memberLimitRangeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number from 1 to 50. The owner is excluded.'**
  String get memberLimitRangeHint;

  /// No description provided for @memberLimitValidation.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number from 1 to 50.'**
  String get memberLimitValidation;

  /// No description provided for @memberLimitSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'The tenant member limit was saved.'**
  String get memberLimitSavedMessage;

  /// No description provided for @memberNewMemberPermissionNote.
  ///
  /// In en, this message translates to:
  /// **'New members start with View enabled. Add, Edit, and Delete are disabled until granted.'**
  String get memberNewMemberPermissionNote;

  /// No description provided for @memberAccountProvisioningNote.
  ///
  /// In en, this message translates to:
  /// **'An existing Supabase account is reused. If no account exists, a new login is created for this tenant with a temporary password.'**
  String get memberAccountProvisioningNote;

  /// No description provided for @memberTemporaryPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'New member account'**
  String get memberTemporaryPasswordTitle;

  /// No description provided for @memberTemporaryPasswordMessage.
  ///
  /// In en, this message translates to:
  /// **'A new login for {email} was added only to this tenant. Share this temporary password securely. The member must change it at first sign-in. It will not be shown again after closing this dialog.'**
  String memberTemporaryPasswordMessage(String email);

  /// No description provided for @memberSetupIncompleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Member setup may be incomplete. Retry adding the same email to finish safely; do not create a different account.'**
  String get memberSetupIncompleteMessage;

  /// No description provided for @memberAddedMessage.
  ///
  /// In en, this message translates to:
  /// **'{email} was added to the tenant.'**
  String memberAddedMessage(String email);

  /// No description provided for @memberPermissionsEditButton.
  ///
  /// In en, this message translates to:
  /// **'Edit entry permissions'**
  String get memberPermissionsEditButton;

  /// No description provided for @memberPermissionsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Entry permissions: {email}'**
  String memberPermissionsDialogTitle(String email);

  /// No description provided for @memberPermissionsDialogDescription.
  ///
  /// In en, this message translates to:
  /// **'Permissions apply to all parking entries in this tenant and are enforced by the server. Edit or Delete does not grant View; members without View cannot browse existing entries.'**
  String get memberPermissionsDialogDescription;

  /// No description provided for @memberPermissionView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get memberPermissionView;

  /// No description provided for @memberPermissionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get memberPermissionAdd;

  /// No description provided for @memberPermissionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get memberPermissionEdit;

  /// No description provided for @memberPermissionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get memberPermissionDelete;

  /// No description provided for @memberPermissionNone.
  ///
  /// In en, this message translates to:
  /// **'No entry access'**
  String get memberPermissionNone;

  /// No description provided for @memberPermissionViewDescription.
  ///
  /// In en, this message translates to:
  /// **'Read parking entries in this tenant.'**
  String get memberPermissionViewDescription;

  /// No description provided for @memberPermissionAddDescription.
  ///
  /// In en, this message translates to:
  /// **'Create new parking entries.'**
  String get memberPermissionAddDescription;

  /// No description provided for @memberPermissionEditDescription.
  ///
  /// In en, this message translates to:
  /// **'Modify existing parking entries.'**
  String get memberPermissionEditDescription;

  /// No description provided for @memberPermissionDeleteDescription.
  ///
  /// In en, this message translates to:
  /// **'Delete or archive entries according to the application\'s policy.'**
  String get memberPermissionDeleteDescription;

  /// No description provided for @memberPermissionsSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Entry permissions were saved.'**
  String get memberPermissionsSavedMessage;

  /// No description provided for @memberCreatedAt.
  ///
  /// In en, this message translates to:
  /// **'Added {date}'**
  String memberCreatedAt(String date);

  /// No description provided for @memberAuditTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent member and limit changes'**
  String get memberAuditTitle;

  /// No description provided for @memberAuditEmpty.
  ///
  /// In en, this message translates to:
  /// **'No member-management changes have been recorded.'**
  String get memberAuditEmpty;

  /// No description provided for @memberAuditLoadError.
  ///
  /// In en, this message translates to:
  /// **'Member change history could not be loaded.'**
  String get memberAuditLoadError;

  /// No description provided for @memberAuditAdded.
  ///
  /// In en, this message translates to:
  /// **'Member added'**
  String get memberAuditAdded;

  /// No description provided for @memberAuditRemoved.
  ///
  /// In en, this message translates to:
  /// **'Member removed'**
  String get memberAuditRemoved;

  /// No description provided for @memberAuditRoleChanged.
  ///
  /// In en, this message translates to:
  /// **'Member role changed'**
  String get memberAuditRoleChanged;

  /// No description provided for @memberAuditPermissionsChanged.
  ///
  /// In en, this message translates to:
  /// **'Entry permissions changed'**
  String get memberAuditPermissionsChanged;

  /// No description provided for @memberAuditLimitChanged.
  ///
  /// In en, this message translates to:
  /// **'Member limit changed'**
  String get memberAuditLimitChanged;

  /// No description provided for @memberManageDevicePolicies.
  ///
  /// In en, this message translates to:
  /// **'Manage device policies'**
  String get memberManageDevicePolicies;
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
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
