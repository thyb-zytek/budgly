# Guidelines de Commit et Qualité Code

## 🎯 Règles de Commit avec Gitmojis

Utilisez les gitmojis du projet [carloscuesta/gitmoji](https://github.com/carloscuesta/gitmoji) pour standardiser les messages de commit.

### Gitmojis Principaux Utilisés

| Emoji | Nom | Utilisation |
|-------|-----|-------------|
| ✨ | sparkles | Nouvelles fonctionnalités |
| ♻️ | recycle | Refactoring du code |
| 🔧 | wrench | Corrections de bugs |
| 📦 | package | Mises à jour de dépendances/imports |
| 🗑️ | wastebasket | Suppression de code/fichiers |
| ➕ | heavy_plus_sign | Ajout de dépendances |
| 🔨 | hammer | Mises à jour de configuration/scripts |
| ✅ | white_check_mark | Tests et qualité |
| 🎨 | art | Améliorations UI/UX |
| ♿ | wheelchair | Accessibilité |

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

1. **Jamais** utiliser ➕ pour des nouvelles fonctionnalités (réservé aux dépendances)
2. Utiliser ✨ pour l'ajout de nouvelles fonctionnalités
3. Utiliser ♻️ pour le refactoring (changement de structure sans changement de comportement)
4. Utiliser 📦 pour les mises à jour d'imports et de dépendances existantes
5. Utiliser 🗑️ pour la suppression de code/fichiers
6. Utiliser 🔧 pour les corrections de bugs
7. Les commits doivent être **atomiques** (une seule fonctionnalité par commit)
8. Ne **jamais** inclure les signatures Devin dans les messages de commit

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
