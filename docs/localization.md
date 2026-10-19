# App localization

The Flutter UI uses `lib/l10n/app_en.arb` as its source and `lib/l10n/app_hi.arb` for Hindi. Flutter compiles these ARB files into static localization classes. The app makes no translation API requests at runtime.

To regenerate the Hindi ARB from the English source, run this from the repository root:

```powershell
dart run scripts/generate_hindi_arb.dart
flutter gen-l10n
```

The generator uses the public, keyless LibreTranslate mirror at `https://translate.cutie.dating/translate` by default. Set `LIBRETRANSLATE_URL` to another LibreTranslate `/translate` endpoint if that mirror is unavailable. If an endpoint requires a key, set `LIBRETRANSLATE_API_KEY` in the current shell; never put it in source control. The public mirror has no availability guarantee and may rate-limit requests.

The generator preserves ARB placeholder metadata, protects placeholders and common technical terms while translating, and writes `app_hi.arb` only after all entries have translated successfully. Review the generated Hindi before release. Dynamic tenant, vehicle, contact, and note data is not translated.