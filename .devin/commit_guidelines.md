# Guidelines de Commit et Qualité Code

## 🎯 Règles de Commit avec Gitmojis

Utilisez les gitmojis du projet [carloscuesta/gitmoji](https://github.com/carloscuesta/gitmoji) pour standardiser les messages de commit.

### Gitmojis Principaux Utilisés

| Emoji | Nom | Utilisation |
|-------|-----|-------------|
| ✨ | sparkles | Introduce new features |
| 🐛 | bug | Fix a bug |
| ♻️ | recycle | Refactor code |
| 🎨 | art | Improve structure / format of the code |
| � | lipstick | Add or update the UI and style files |
| �🔧 | wrench | Add or update configuration files |
| 📦 | package | Add or update compiled files or packages |
| 🔥 | fire | Remove code or files |
| ➕ | heavy_plus_sign | Add a dependency |
| ➖ | heavy_minus_sign | Remove a dependency |
| ⬆️ | arrow_up | Upgrade dependencies |
| ⬇️ | arrow_down | Downgrade dependencies |
| ✅ | white_check_mark | Add, update, or pass tests |
| 🌐 | globe_with_meridians | Internationalization and localization |
| ♿ | wheelchair | Improve accessibility |
| 🚸 | children_crossing | Improve user experience / usability |
| 🗑️ | wastebasket | Deprecate code that needs to be cleaned up |
| � | truck | Move or rename resources (e.g.: files, paths, routes) |
| 🩹 | adhesive_bandage | Simple fix for a non-critical issue |
| 🛂 | passport_control | Work on code related to authorization, roles and permissions |
| 🗃️ | card_file_box | Perform database related changes |
| 👔 | necktie | Add or update business logic |
| �️ | label | Add or update types |
| 🦺 | safety_vest | Add or update code related to validation |
| 💥 | boom | Introduce breaking changes |
| 🚑️ | ambulance | Critical hotfix |
| ⚡️ | zap | Improve performance |
| 🔒️ | lock | Fix security or privacy issues |

### Format de Commit

```
<gitmoji> <titre du commit (max 50 caractères)>

<description détaillée (optionnelle)>

- <détail 1>
- <détail 2>
```

### Exemples de Commits Corrects

```
✨ Add core stores for state management

- Add AccountsStore for account data management and caching
- Add CategoriesStore for category data management and caching  
- Implement proper cache invalidation and loading patterns
```

```
♻️ Refactor login view model to extend BaseViewModel

- Change LoginViewModel from ChangeNotifier mixin to BaseViewModel inheritance
- Remove duplicate _mounted variable and use isDisposed from BaseViewModel
- Update all disposal checks to use isDisposed
```

```
📦 Update shared widgets imports

- Update all imports to use package name 'budgly' instead of 'app'
- Affects currency_form, locale_form, preferences_tab, and theme_form
```

### Règles Importantes

1. Les commits doivent être **atomiques** (une seule fonctionnalité par commit)
2. Ne **jamais** inclure les signatures Devin dans les messages de commit

## 🧪 Qualité du Code - Flutter Analyze

### Commandes de Base

```bash
# Analyser le code complet
flutter analyze

# Analyser un fichier spécifique
flutter analyze lib/src/pages/login/view_model.dart

# Analyser avec des options spécifiques
flutter analyze --no-fatal-infos
```

### Corrections Communes

#### Imports non utilisés
```bash
# Avertissement: Unused import
# Solution: Supprimer l'import non utilisé
```

#### Arguments non constants
```bash
# Avertissement: non_const_argument_for_const_parameter
# Solution: Utiliser des constantes ou ignorer avec commentaire
// ignore: non_const_argument_for_const_parameter
```

#### BuildContext async gaps
```bash
# Info: use_build_context_synchronously
# Solution: Vérifier 'mounted' avant d'utiliser BuildContext après async
if (mounted) {
  Navigator.of(context).pop();
}
```

### Avant Commit

Toujours exécuter `flutter analyze` avant de créer un commit :

```bash
flutter analyze
# Si pas d'erreurs, procéder au commit
git add .
git commit -m "✨ Ma nouvelle fonctionnalité"
```

## 📜 Scripts Automatisés

### Script de Commit avec Vérification

Créer le fichier `scripts/commit-with-check.sh` :

```bash
#!/bin/bash

# Vérifier flutter analyze
echo "🧪 Exécution de flutter analyze..."
flutter analyze

if [ $? -ne 0 ]; then
  echo "❌ Flutter analyze a échoué. Corrigez les erreurs avant de commit."
  exit 1
fi

echo "✅ Flutter analyze réussi."
echo "📝 Veuillez entrer votre message de commit:"
read -p "Gitmoji + Titre: " commit_title
read -p "Description (optionnelle): " commit_desc

if [ -z "$commit_desc" ]; then
  git commit -m "$commit_title"
else
  git commit -m "$commit_title" -m "$commit_desc"
fi
```

### Script d'Analyse Rapide

Créer le fichier `scripts/quick-analyze.sh` :

```bash
#!/bin/bash

echo "🧪 Analyse Flutter rapide..."
flutter analyze --no-fatal-infos

echo "📊 Résumé des problèmes:"
flutter analyze | grep -E "(warning|info|error)" | head -20
```

## 🚫 Fichiers à Exclure des Commits

Ne **jamais** commit ces fichiers :
- `firebase.json` (configuration locale)
- `lib/l10n/app_localizations*.dart` (fichiers générés)
- `pubspec.lock` (fichier généré)
- `lib/src/models/budget/` (en développement)
- `lib/src/services/budget_status.dart` (en développement)
- `supabase/` (configuration locale)
- Scripts temporaires dans `tmp/`

## ✅ Checklist Avant Commit

- [ ] `flutter analyze` passe sans erreurs
- [ ] Le commit est atomique (une seule fonctionnalité)
- [ ] Le gitmoji est correctement utilisé
- [ ] Le message de commit est clair et descriptif
- [ ] Pas de fichiers générés inclus
- [ ] Pas de fichiers de configuration locale inclus
- [ ] Pas de signature Devin dans le message

## 🔧 Configuration Git

Assurez-vous d'avoir configuré votre identité git :

```bash
git config user.email "votre@email.com"
git config user.name "Votre Nom"
```

## 📚 Références

- [Gitmoji - carloscuesta/gitmoji](https://github.com/carloscuesta/gitmoji)
- [Flutter Analyze Documentation](https://flutter.dev/docs/development/tools/sdk/flutter-analyze)
- [Conventional Commits](https://www.conventionalcommits.org/)
