import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show SupabaseClient, UserAttributes;

/// Supported app locales. Keep in sync with `l10n.yaml` / `lib/l10n/*.arb`.
const supportedAppLocales = [Locale('en'), Locale('hi')];

const _prefsKey = 'app_locale_code';

/// Identifies where saving an app language preference failed.
enum LocalePreferenceStore { localStorage, accountMetadata }

/// Reports a failure to read or save an app language preference.
class LocalePreferenceException implements Exception {
  const LocalePreferenceException({required this.store, this.cause});

  final LocalePreferenceStore store;
  final Object? cause;

  @override
  String toString() {
    final cause = this.cause;
    if (cause == null) {
      return 'Unable to persist the app language preference to $store.';
    }
    return 'Unable to persist the app language preference to $store: $cause';
  }
}

/// Holds the active [Locale] and persists the user's choice.
///
/// The preference is cached locally so it is available before sign-in, and is
/// also saved to signed-in Supabase user metadata so it follows the account.
/// All translations are static ARB resources; no translation API is called at
/// runtime.
class LocaleController extends ChangeNotifier {
  LocaleController({SupabaseClient? authClient}) : _supabaseClient = authClient;

  final SupabaseClient? _supabaseClient;
  Locale _locale = supportedAppLocales.first;

  Locale get locale => _locale;

  /// Loads the account preference when signed in, otherwise the local choice.
  ///
  /// An account preference is authoritative and is copied to local storage.
  /// Throws [LocalePreferenceException] when local storage cannot be read or
  /// synchronized.
  Future<void> loadSaved() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final metadataCode =
          _supabaseClient?.auth.currentUser?.userMetadata?['language_code'];
      final accountLocale = _localeForCode(
        metadataCode is String ? metadataCode : null,
      );
      final savedLocale =
          accountLocale ?? _localeForCode(preferences.getString(_prefsKey));

      if (savedLocale != null && savedLocale != _locale) {
        _locale = savedLocale;
        notifyListeners();
      }

      if (accountLocale != null) {
        final saved = await preferences.setString(
          _prefsKey,
          accountLocale.languageCode,
        );
        if (!saved) {
          throw const LocalePreferenceException(
            store: LocalePreferenceStore.localStorage,
          );
        }
      }
    } on LocalePreferenceException {
      rethrow;
    } on Exception catch (error) {
      throw LocalePreferenceException(
        store: LocalePreferenceStore.localStorage,
        cause: error,
      );
    }
  }

  /// Applies a signed-in user's saved language preference, if it is supported.
  Future<void> applyUserPreference(Map<String, dynamic>? userMetadata) async {
    final metadataCode = userMetadata?['language_code'];
    final preferred = _localeForCode(
      metadataCode is String ? metadataCode : null,
    );
    if (preferred != null && preferred != _locale) {
      await setLocale(preferred, persistToAccount: false);
    }
  }

  /// Applies [locale] and persists it locally and, when signed in, to Supabase.
  ///
  /// Throws [ArgumentError] for an unsupported locale and
  /// [LocalePreferenceException] if either preference store cannot be updated.
  Future<void> setLocale(Locale locale, {bool persistToAccount = true}) async {
    if (!supportedAppLocales.contains(locale)) {
      throw ArgumentError.value(locale, 'locale', 'Unsupported app locale.');
    }
    if (locale != _locale) {
      _locale = locale;
      notifyListeners();
    }

    await _saveLocally(locale);

    final client = _supabaseClient;
    if (persistToAccount && client?.auth.currentUser != null) {
      try {
        await client!.auth.updateUser(
          UserAttributes(data: {'language_code': locale.languageCode}),
        );
      } on Exception catch (error) {
        throw LocalePreferenceException(
          store: LocalePreferenceStore.accountMetadata,
          cause: error,
        );
      }
    }
  }

  Future<void> _saveLocally(Locale locale) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(_prefsKey, locale.languageCode);
      if (!saved) {
        throw const LocalePreferenceException(
          store: LocalePreferenceStore.localStorage,
        );
      }
    } on LocalePreferenceException {
      rethrow;
    } on Exception catch (error) {
      throw LocalePreferenceException(
        store: LocalePreferenceStore.localStorage,
        cause: error,
      );
    }
  }

  Locale? _localeForCode(String? code) {
    if (code == null) {
      return null;
    }
    for (final candidate in supportedAppLocales) {
      if (candidate.languageCode == code) {
        return candidate;
      }
    }
    return null;
  }
}

/// Exposes a [LocaleController] to descendant widgets.
class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({
    required LocaleController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  /// Gets the nearest app locale controller.
  static LocaleController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocaleScope>();
    assert(scope != null, 'No LocaleScope found in context');
    return scope!.notifier!;
  }

  /// Gets the nearest app locale controller, if one exists.
  static LocaleController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LocaleScope>()?.notifier;
  }
}
