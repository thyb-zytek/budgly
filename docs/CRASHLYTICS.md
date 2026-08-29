# Firebase Crashlytics — activation

Le code (`main.dart`, `AppLogger`) est déjà câblé pour envoyer les crashs et
les erreurs non-fatales à Crashlytics. Il reste une étape de configuration
côté Firebase/plateformes à faire une seule fois par projet Firebase.

## 1. Activer Crashlytics dans la console Firebase

1. Ouvrir la [console Firebase](https://console.firebase.google.com/) → projet Budgly.
2. Menu **Build → Crashlytics** → cliquer sur **Get started / Activer**.
3. Aucune donnée n'apparaîtra tant qu'un premier crash n'a pas été envoyé
   par l'app (voir étape 4, test).

## 2. Android

1. Vérifier que `android/build.gradle` (niveau projet) déclare le plugin
   Google Services (normalement déjà présent puisque Firebase Auth est en
   place) :
   ```groovy
   buildscript {
     dependencies {
       classpath 'com.google.gms:google-services:...'
       classpath 'com.google.firebase:firebase-crashlytics-gradle:...'
     }
   }
   ```
2. Dans `android/app/build.gradle`, appliquer les deux plugins :
   ```groovy
   apply plugin: 'com.google.gms.google-services'
   apply plugin: 'com.google.firebase.crashlytics'
   ```
3. Pour que les stack traces natives (crashs NDK) soient lisibles, activer
   l'upload automatique des symboles de debug :
   ```groovy
   android {
     buildTypes {
       release {
         firebaseCrashlytics {
           nativeSymbolUploadEnabled true
         }
       }
     }
   }
   ```
4. `google-services.json` doit être à jour (déjà exclu du commit d'après
   `docs/README.md` — le récupérer depuis la console Firebase si besoin).

## 3. iOS

1. `ios/Runner/GoogleService-Info.plist` doit être présent (même remarque
   que pour Android — fichier de config locale, à récupérer sur la
   console Firebase si absent).
2. Ajouter une **Run Script Build Phase** dans Xcode (après "Embed
   Pods Frameworks") qui appelle le script fourni par le pod
   `FirebaseCrashlytics` pour uploader les dSYM :
   ```bash
   "${PODS_ROOT}/FirebaseCrashlytics/run"
   ```
   avec en *Input Files* :
   ```
   ${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${TARGET_NAME}
   $(SRCROOT)/$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)
   ```
3. `flutter pub get` (via CocoaPods) installera le pod nécessaire —
   pas d'étape manuelle côté `Podfile` au-delà d'un `pod install`.

## 4. Vérifier que ça fonctionne

Avant de livrer, provoquer un crash de test en debug/release (à retirer
ensuite) :

```dart
FirebaseCrashlytics.instance.crash(); // crash natif immédiat
// ou, pour une erreur non-fatale :
FirebaseCrashlytics.instance.recordError('test error', StackTrace.current);
```

Le crash apparaît dans la console Firebase sous quelques minutes (parfois
jusqu'à mise en arrière-plan puis relance de l'app pour un crash natif,
Crashlytics envoyant le rapport au démarrage suivant).

## 5. Ce qui est déjà branché côté code

- `main.dart` : `FlutterError.onError` et `PlatformDispatcher.instance.onError`
  envoient toute erreur Flutter/Dart non interceptée à Crashlytics, en plus
  de la config existante.
- La collecte est activée dans tous les modes (debug, profile, release)
  pour que le bouton de test de la console Firebase fonctionne.
- `AppLogger.error(...)` et `AppLogger.warning(...)` — utilisés dans une
  quarantaine de `catch` à travers le code — envoient désormais aussi
  l'information à Crashlytics (`recordError` / `log`) en plus de l'affichage
  console en mode debug. Les appels sont protégés par un `try/catch` interne
  pour ne jamais faire planter un test unitaire qui n'a pas initialisé
  Firebase.

## 6. Ce qui reste à faire (hors scope de ce commit)

- Auditer au cas par cas les ~31 `catch (_)` qui ignoraient l'erreur : leur
  faire appeler `AppLogger.error(...)` avec l'exception réelle plutôt que de
  rester silencieux, pour que Crashlytics ait une trace exploitable
  (actuellement seuls les appels déjà passés par `AppLogger` bénéficient du
  nouveau câblage).
- Ajouter `FirebaseCrashlytics.instance.setUserIdentifier(uid)` au moment du
  login (dans `AuthService`), pour pouvoir filtrer les crashs par
  utilisateur en support.
