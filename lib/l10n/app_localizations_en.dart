// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Parking Management';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHindi => 'Hindi';

  @override
  String get languageSwitchTooltip => 'Change language';

  @override
  String get languageSaveFailed =>
      'Language changed for this session, but the preference could not be saved.';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonSomethingWentWrong => 'Something went wrong';

  @override
  String get commonTryAgain => 'Try again';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonClose => 'Close';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonActive => 'Active';

  @override
  String get commonExpired => 'Expired';

  @override
  String get commonInactive => 'Inactive';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get signInSubtitle =>
      'Use the private account created by your administrator.';

  @override
  String get signInEmailLabel => 'Email address';

  @override
  String get signInPasswordLabel => 'Password';

  @override
  String get signInRememberMe => 'Remember me';

  @override
  String get signInForgotPassword => 'Forgot password?';

  @override
  String get signInForgotPasswordUnavailableTooltip =>
      'Password reset email is not available in local development mode.';

  @override
  String get signInButton => 'Sign in';

  @override
  String get signInPasswordRequired => 'Enter your password.';

  @override
  String get signInGenericError =>
      'Unable to sign in. Check your connection and try again.';

  @override
  String get configurationRequiredTitle => 'Supabase configuration required';

  @override
  String get configurationRequiredHint =>
      'Run with --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...';

  @override
  String get configurationMissingMessage =>
      'Supabase is not configured for this build.';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navHistory => 'History';

  @override
  String get navAdmin => 'Admin';

  @override
  String get navSettings => 'Settings';

  @override
  String get navSignOut => 'Sign out';

  @override
  String get navAllTenants => 'All tenants';

  @override
  String get forgotPasswordTitle => 'Reset your password';

  @override
  String get forgotPasswordSuccessMessage =>
      'If an account exists for that email address, a password reset link has been sent. Check your inbox and spam folder.';

  @override
  String get forgotPasswordInstructions =>
      'Enter your account email address. We will send a password reset link if an account exists for it.';

  @override
  String get forgotPasswordGenericError =>
      'The reset email could not be sent right now. Check your connection and try again.';

  @override
  String get forgotPasswordSendButton => 'Send reset link';

  @override
  String get passwordRecoveryBackToSignIn => 'Back to sign in';

  @override
  String get passwordRecoveryChooseTitle => 'Choose a new password';

  @override
  String get passwordRecoveryInstructions =>
      'Enter a new password to finish resetting your account.';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get newPasswordHelper => 'Use 12 to 128 characters.';

  @override
  String get showPasswordTooltip => 'Show password';

  @override
  String get hidePasswordTooltip => 'Hide password';

  @override
  String get passwordTooShort => 'Use at least 12 characters.';

  @override
  String get passwordTooLong => 'Use 128 characters or fewer.';

  @override
  String get confirmNewPasswordLabel => 'Confirm new password';

  @override
  String get passwordsDoNotMatch => 'The passwords do not match.';

  @override
  String get updatePasswordButton => 'Update password';

  @override
  String get passwordRecoveryGenericError =>
      'The password could not be updated. Check your connection and retry.';

  @override
  String get temporaryPasswordSetTitle => 'Set a new password';

  @override
  String get temporaryPasswordInstructions =>
      'Your administrator created a temporary password. Choose a new password before accessing parking data.';

  @override
  String get changePasswordButton => 'Change password';

  @override
  String get temporaryPasswordGenericError =>
      'The password could not be changed. Check your connection and retry.';

  @override
  String get signOutFailedError => 'You could not be signed out. Please retry.';

  @override
  String get authStateError =>
      'Unable to read the authentication state. Try again.';

  @override
  String get workspaceLoadingMessage => 'Preparing your workspace…';

  @override
  String get workspaceAccessLoadingMessage => 'Loading workspace access…';

  @override
  String get tenantAccessMigrationError =>
      'Tenant access is not configured. Apply all tenant migrations before using this version.';

  @override
  String get tenantAccessLoadError =>
      'Tenant access could not be loaded. Check your connection and retry.';

  @override
  String get noWorkspaceTitle => 'No workspace assigned';

  @override
  String get noWorkspaceMessage =>
      'Ask your administrator to assign your account to a parking tenant.';

  @override
  String get selectTenantBeforeVehicle =>
      'Select a tenant before adding a vehicle.';

  @override
  String get createTenantBeforeVehicle =>
      'Create or restore a tenant before adding a vehicle.';

  @override
  String get selectTenantDialogTitle => 'Select a tenant';

  @override
  String parkingEntrySavedMessage(String plate) {
    return 'Parking entry for $plate was saved successfully.';
  }

  @override
  String get tenantSelectorTooltip => 'Select tenant';

  @override
  String get workspaceChipLabel => 'Workspace';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsComingLaterTitle => 'Settings are coming later';

  @override
  String get settingsComingLaterMessage =>
      'Account and application settings will be added in a later phase.';

  @override
  String get settingsSignOutError =>
      'Unable to sign out. Check your connection and try again.';

  @override
  String get settingsSigningOut => 'Signing out…';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsLanguageDescription =>
      'Choose the language used throughout the app.';

  @override
  String get dashboardOverviewTitle => 'Parking overview';

  @override
  String get dashboardOverviewSubtitle =>
      'Monitor current activity and manage vehicle entries.';

  @override
  String get dashboardRefresh => 'Refresh';

  @override
  String get dashboardNewEntry => 'New Parking Entry';

  @override
  String get dashboardActiveMessage => 'Currently within the allowed duration';

  @override
  String get dashboardExpiredMessage => 'Past the recorded expiry time';

  @override
  String get searchRegistrationLabel => 'Search registration';

  @override
  String get searchByPlateHint => 'Search by plate number';

  @override
  String get clearSearchTooltip => 'Clear search';

  @override
  String get dashboardNoSessionsTitle => 'No parking sessions yet';

  @override
  String get noMatchingSessionsTitle => 'No matching sessions';

  @override
  String get dashboardNoSessionsMessage =>
      'Create a parking entry to start tracking a vehicle.';

  @override
  String get tryDifferentSearchMessage =>
      'Try a different registration search.';

  @override
  String get dashboardRecentSessions => 'Recent sessions';

  @override
  String get dashboardViewAll => 'View all';

  @override
  String get historyTitle => 'History';

  @override
  String get historyRefreshTooltip => 'Refresh history';

  @override
  String get historyFilterPaid => 'Paid';

  @override
  String get historyFilterPartiallyPaid => 'Partially paid';

  @override
  String get historyFilterUnpaid => 'Unpaid';

  @override
  String get historyClearFilters => 'Clear filters';

  @override
  String get historyNoHistoryTitle => 'No parking history';

  @override
  String get historyNoMatchFilters => 'No sessions match the selected filters.';

  @override
  String get historySavedWillAppear =>
      'Saved parking sessions will appear here.';

  @override
  String get historyLoadMore => 'Load more';

  @override
  String sessionEntryExpiryTemplate(String entry, String expiry) {
    return 'Entry: $entry\nExpiry: $expiry';
  }

  @override
  String contactLineTemplate(String contact) {
    return 'Contact: $contact';
  }

  @override
  String paymentTooltipTemplate(String total, String paid, String remaining) {
    return 'Total: $total\nPaid: $paid\nRemaining: $remaining';
  }

  @override
  String dateTimeAtTemplate(String date, String time) {
    return '$date at $time';
  }

  @override
  String get sessionDetailsTitle => 'Parking Session';

  @override
  String get editSessionTooltip => 'Edit session';

  @override
  String get deleteSessionTooltip => 'Delete session';

  @override
  String get sessionNoIdError => 'This parking session has no identifier.';

  @override
  String get deleteSessionDialogTitle => 'Delete parking session?';

  @override
  String deleteSessionDialogMessage(String plate) {
    return 'Delete the parking session for $plate? This action cannot be undone.';
  }

  @override
  String get detailEntryTime => 'Entry time';

  @override
  String get detailContactNumber => 'Contact number';

  @override
  String get detailNotProvided => 'Not provided';

  @override
  String get detailAllowedDuration => 'Allowed duration';

  @override
  String get detailExpiry => 'Expiry';

  @override
  String get detailTotalCharge => 'Total charge';

  @override
  String get detailAmountPaid => 'Amount paid';

  @override
  String get detailRemainingBalance => 'Remaining balance';

  @override
  String get noVehiclePhotoMessage =>
      'No vehicle photo is attached to this session.';

  @override
  String get vehiclePhotoTitle => 'Vehicle photo';

  @override
  String get photoDisplayError =>
      'The private vehicle photo could not be displayed.';

  @override
  String get durationUnitMinutes => 'minutes';

  @override
  String get durationUnitHours => 'hours';

  @override
  String get durationUnitDays => 'days';

  @override
  String get durationUnitMonths => 'months';

  @override
  String get durationUnitMinutesCap => 'Minutes';

  @override
  String get durationUnitHoursCap => 'Hours';

  @override
  String get durationUnitDaysCap => 'Days';

  @override
  String get durationUnitMonthsCap => 'Months';

  @override
  String get entryPageEditTitle => 'Edit Parking Entry';

  @override
  String get entryPageNewTitle => 'New Parking Entry';

  @override
  String get cameraOpenError =>
      'The camera could not be opened. Choose a file instead.';

  @override
  String get imageSelectError =>
      'The image could not be selected. Try again or choose a file instead.';

  @override
  String get plateRequired => 'Enter a vehicle registration number.';

  @override
  String get plateTooLong => 'Use 64 characters or fewer.';

  @override
  String get contactRequired => 'Enter a contact mobile number.';

  @override
  String get contactInvalid =>
      'Enter a valid 10-digit mobile number, with or without +91.';

  @override
  String get durationRequired => 'Enter a parking duration.';

  @override
  String get durationPositiveInteger => 'Enter a positive whole number.';

  @override
  String durationMaxExceeded(String unit, int max) {
    return 'The maximum for $unit is $max.';
  }

  @override
  String get expiryCalculationError =>
      'The expiry time could not be calculated.';

  @override
  String get amountInvalid => 'Enter a valid amount.';

  @override
  String get chargeNegative => 'The charge cannot be negative.';

  @override
  String get paidNegative => 'The amount paid cannot be negative.';

  @override
  String get paidExceedsTotal =>
      'The amount paid cannot exceed the total charge.';

  @override
  String get durationBeforeSaving => 'Enter a valid duration before saving.';

  @override
  String get chargeBeforeSaving =>
      'Enter a valid parking charge before saving.';

  @override
  String get saveGenericError =>
      'The parking entry could not be saved. Check your connection and try again.';

  @override
  String get photoSelectionRequired =>
      'Select a vehicle photo or explicitly choose Continue without photo.';

  @override
  String get cleanupGenericError =>
      'Cleanup could not complete. Check your connection and retry.';

  @override
  String get cleanupSuccessMessage =>
      'Cleanup completed. The incomplete session was removed. You can try again.';

  @override
  String get photoCleanupGenericError =>
      'Photo cleanup could not complete. Check your connection and retry.';

  @override
  String get photoCleanupSuccessMessage =>
      'Photo cleanup completed. Review the changes and try saving again.';

  @override
  String get introEditing =>
      'Update the vehicle details and confirm the expiry time before saving.';

  @override
  String get introCreating =>
      'Enter the vehicle details and confirm the expiry time before saving.';

  @override
  String get parkingDetailsTitle => 'Parking details';

  @override
  String get vehicleRegistrationLabel => 'Vehicle registration';

  @override
  String get vehicleRegistrationHint => 'For example, ABC 123';

  @override
  String get contactNumberHint => 'For example, 9876543210 or +919876543210';

  @override
  String get unitLabel => 'Unit';

  @override
  String get parkingChargeTitle => 'Parking charge';

  @override
  String get totalChargeLabel => 'Total charge';

  @override
  String get totalChargeHint => 'For example, 50.00';

  @override
  String get fullyPaidLabel => 'Fully paid';

  @override
  String get fullyPaidSubtitle =>
      'Leave unchecked to record a partial payment.';

  @override
  String get amountPaidHint => 'For example, 20.00';

  @override
  String get entryDateTimeLabel => 'Entry date and time';

  @override
  String get calculatedExpiryTitle => 'Calculated expiry';

  @override
  String get expiryPreviewTitle => 'Expiry preview';

  @override
  String get expiryPreviewMessage =>
      'Enter a valid duration to calculate the expiry.';

  @override
  String get vehiclePhotoInstructions =>
      'Use the camera when supported, or choose an existing JPEG, PNG, or WebP image.';

  @override
  String get imagePreviewError =>
      'This image cannot be previewed in the browser.';

  @override
  String get existingPhotoKeptTitle => 'Existing private photo will be kept';

  @override
  String get existingPhotoKeptSubtitle =>
      'Choose a new photo only if you want to replace it.';

  @override
  String get replaceWithCamera => 'Replace with camera';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get retakePhoto => 'Retake photo';

  @override
  String get chooseFile => 'Choose file';

  @override
  String get replacePhoto => 'Replace photo';

  @override
  String get discardReplacement => 'Discard replacement';

  @override
  String get removeButton => 'Remove';

  @override
  String get continueWithoutPhoto => 'Continue without photo';

  @override
  String get continueWithoutPhotoSubtitle =>
      'Choose this explicitly if no photo is available.';

  @override
  String get updatingButton => 'Updating...';

  @override
  String get savingButton => 'Saving...';

  @override
  String get updateEntryButton => 'Update parking entry';

  @override
  String get saveEntryButton => 'Save parking entry';

  @override
  String get retryingCleanup => 'Retrying cleanup...';

  @override
  String get retryCleanupButton => 'Retry cleanup';

  @override
  String get retryingPhotoCleanup => 'Retrying photo cleanup...';

  @override
  String get retryPhotoCleanupButton => 'Retry photo cleanup';

  @override
  String get captureDialogTitle => 'Take vehicle photo';

  @override
  String get cameraTimeoutError =>
      'The camera took too long to initialize. Check permissions and try again.';

  @override
  String get cameraInitError =>
      'The camera could not be initialized. Check browser permissions and try again.';

  @override
  String get captureTimeoutError =>
      'The camera capture took too long. Try again or choose a file instead.';

  @override
  String get captureGenericError =>
      'The photo could not be captured. Try again.';

  @override
  String get switchTimeoutError =>
      'Switching cameras took too long. Try again or choose a file instead.';

  @override
  String get switchGenericError =>
      'The selected camera could not be opened. Try another camera or choose a file instead.';

  @override
  String get switchingCamera => 'Switching...';

  @override
  String get switchCameraButton => 'Switch camera';

  @override
  String get capturingButton => 'Capturing...';

  @override
  String get captureButton => 'Capture';

  @override
  String get retakeButton => 'Retake';

  @override
  String get usePhotoButton => 'Use Photo';

  @override
  String get cameraUnavailableMessage =>
      'The camera is unavailable. Choose an existing photo.';

  @override
  String tenantCreatedMessage(String tenant) {
    return '$tenant was created.';
  }

  @override
  String tenantCreatedWithPasswordMessage(String tenant) {
    return '$tenant was created. The temporary password was shown once.';
  }

  @override
  String get tenantCreateGenericError =>
      'The tenant could not be created. Check your connection and retry.';

  @override
  String tenantUpdatedMessage(String tenant) {
    return '$tenant was updated.';
  }

  @override
  String get archiveTenantTitle => 'Archive tenant?';

  @override
  String archiveTenantMessage(String tenant) {
    return '$tenant will no longer be available to its members. Parking records and photos will be retained, and this tenant can be restored later.';
  }

  @override
  String get archiveButton => 'Archive';

  @override
  String tenantArchivedMessage(String tenant) {
    return '$tenant was archived. Its data was retained.';
  }

  @override
  String tenantRestoredMessage(String tenant) {
    return '$tenant was restored.';
  }

  @override
  String get tenantUpdateGenericError =>
      'The tenant could not be updated. Check your connection and retry.';

  @override
  String get tenantWorkspacesTitle => 'Tenant workspaces';

  @override
  String get tenantWorkspacesSubtitle =>
      'Each workspace keeps its parking records and photos isolated.';

  @override
  String get allTenantsTitle => 'All tenants';

  @override
  String get createTenantButton => 'Create tenant';

  @override
  String get noTenantsTitle => 'No tenant workspaces yet';

  @override
  String get noTenantsMessage =>
      'Create a workspace and assign an existing Supabase account as its owner.';

  @override
  String validUntilTemplate(String date) {
    return 'Valid until $date';
  }

  @override
  String manageTenantTooltip(String name) {
    return 'Manage $name';
  }

  @override
  String get manageMembersMenuItem => 'Manage members';

  @override
  String get archiveTenantMenuItem => 'Archive tenant';

  @override
  String get restoreTenantMenuItem => 'Restore tenant';

  @override
  String get superAdminTitle => 'Super Admin';

  @override
  String get superAdminSubtitle =>
      'Manage parking workspaces across the platform.';

  @override
  String get createTenantDialogTitle => 'Create tenant';

  @override
  String get tenantCreatedDialogTitle => 'Tenant created';

  @override
  String get tenantNameLabel => 'Tenant name';

  @override
  String get tenantNameHint => 'Example: Central Parking';

  @override
  String get tenantNameRequired => 'Enter a tenant name.';

  @override
  String get tenantNameTooLong => 'Use 120 characters or fewer.';

  @override
  String get ownerEmailLabel => 'Owner email';

  @override
  String get ownerEmailHint => 'owner@example.com';

  @override
  String get emailInvalid => 'Enter a valid email address.';

  @override
  String get activeSubtitle =>
      'Inactive tenants cannot sign in until reactivated.';

  @override
  String get validUntilTitle => 'Valid until';

  @override
  String get contactPersonNameLabel => 'Contact person name (optional)';

  @override
  String get contactMobileLabel => 'Contact mobile (optional)';

  @override
  String get contactMobileHint => '9876543210 or +919876543210';

  @override
  String get contactMobileInvalid =>
      'Enter a valid 10-digit Indian mobile number.';

  @override
  String get contactEmailLabel => 'Contact email (optional)';

  @override
  String get accountPasswordNote =>
      'An existing account keeps its current password. A new account receives a temporary password that must be changed before it can access parking data.';

  @override
  String get copyPasswordFailedMessage =>
      'Could not copy the password. Select it and copy it manually.';

  @override
  String get passwordCopiedMessage => 'Temporary password copied.';

  @override
  String tenantReadyMessage(String tenant) {
    return '$tenant is ready.';
  }

  @override
  String get ownerMustChangePassword =>
      'The owner must change this password before accessing tenant data.';

  @override
  String get sharePasswordSecurely =>
      'Share this password with the owner through a secure channel. It will not be shown again after closing this dialog.';

  @override
  String get temporaryPasswordLabel => 'Temporary password';

  @override
  String get retrySetupNote =>
      'If you retry setup, use the latest password shown here.';

  @override
  String get copyButton => 'Copy';

  @override
  String get closeWithPasswordSavedButton => 'Close (I\'ve saved the password)';

  @override
  String get retryTenantSetupButton => 'Retry tenant setup';

  @override
  String get doneButton => 'Done';

  @override
  String get editTenantDialogTitle => 'Edit tenant';

  @override
  String get removeTenantMemberTitle => 'Remove tenant member?';

  @override
  String removeTenantMemberMessage(String email, String tenant) {
    return 'Remove $email from $tenant? Their Auth account and parking records will not be deleted.';
  }

  @override
  String membersDialogTitle(String tenant) {
    return 'Members: $tenant';
  }

  @override
  String get restoreBeforeAddingMembers =>
      'Restore this tenant before adding members.';

  @override
  String get existingAccountEmailLabel => 'Existing Supabase account email';

  @override
  String get roleLabel => 'Role';

  @override
  String get addButton => 'Add';

  @override
  String get noMembersTitle => 'No members';

  @override
  String get noMembersMessage =>
      'Add an existing Supabase account to this tenant.';

  @override
  String get keepAtLeastOneOwner => 'Each tenant must keep at least one owner.';

  @override
  String get unknownEmail => 'Unknown email';

  @override
  String manageMemberTooltip(String email) {
    return 'Manage $email';
  }

  @override
  String get makeOwnerMenuItem => 'Make owner';

  @override
  String get makeMemberMenuItem => 'Make member';

  @override
  String get removeMemberMenuItem => 'Remove member';

  @override
  String get roleOwner => 'Owner';

  @override
  String get roleMember => 'Member';

  @override
  String get membersLoadGenericError =>
      'Tenant members could not be loaded. Retry the request.';

  @override
  String get memberActionGenericError =>
      'The member change failed. Check your connection and retry.';
}
