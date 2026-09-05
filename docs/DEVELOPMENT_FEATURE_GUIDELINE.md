# Budgly — Guideline de développement d'une nouvelle fonctionnalité

Cette guideline définit le niveau de qualité attendu avant qu'une nouvelle fonctionnalité soit considérée comme terminée.

L'objectif n'est **pas** de maximiser artificiellement la couverture ou de multiplier les abstractions. Une fonctionnalité doit être fiable, cohérente avec l'architecture existante, utilisable hors ligne lorsque le domaine le permet et suffisamment testée sur ses comportements importants.

---

## 1. Avant de coder

### 1.1 Définir le périmètre

L'issue doit préciser :

- le problème utilisateur à résoudre ;
- le comportement attendu ;
- les cas limites connus ;
- les états UI attendus : chargement, vide, erreur, succès ;
- les règles métier impactées ;
- les données créées ou modifiées ;
- les impacts offline/synchronisation ;
- les analytics nécessaires, si la fonctionnalité est mesurable ;
- les critères d'acceptation vérifiables.

Éviter de mélanger dans la même issue une fonctionnalité et un refactor sans rapport.

### 1.2 Vérifier l'existant

Avant d'ajouter du code :

- rechercher les services, stores, ViewModels, widgets et calculators existants ;
- réutiliser les helpers existants avant d'en créer un nouveau ;
- vérifier les règles de formatage, devise, arrondi et localisation ;
- vérifier le comportement des données hors ligne ;
- vérifier si une fonctionnalité similaire existe déjà.

**Principe : modifier l'architecture existante le moins possible.**

---

## 2. Architecture

Budgly utilise une architecture **MVVM pragmatique**.

### Responsabilités

- **View** : affichage, interaction utilisateur et composition des widgets.
- **ViewModel** : état de présentation et orchestration des actions utilisateur.
- **Service** : orchestration d'accès aux données, synchronisation et opérations applicatives.
- **Store** : état local observable et cache de l'application.
- **Calculator / logique pure** : calculs métier déterministes et testables sans Flutter/Firebase.
- **Provider** : accès technique à une source externe (Firestore, Supabase, Storage...).
- **Model** : représentation des données et conversions associées.

### Règles

1. Ne pas créer automatiquement un `Repository` ou un `UseCase` pour chaque fonctionnalité.
2. Une abstraction est justifiée si elle isole une responsabilité réelle, simplifie les tests ou supprime une duplication significative.
3. Ne pas déplacer du code uniquement pour réduire le nombre de lignes d'un fichier.
4. La logique métier non liée à l'UI doit, autant que possible, être pure et indépendante de Flutter.
5. Les providers restent concentrés sur leur source de données ; l'orchestration reste dans les services/ViewModels selon le besoin.
6. Éviter les dépendances globales dans les nouvelles classes testables : préférer l'injection des dépendances externes lorsque cela apporte un vrai bénéfice de testabilité.

---

## 3. Données et offline-first

Pour toute fonctionnalité qui modifie des données :

### 3.1 Définir le comportement local

La fonctionnalité doit préciser ce qui se passe :

- en ligne ;
- hors ligne ;
- pendant une synchronisation ;
- après reconnexion ;
- après redémarrage de l'application ;
- lorsqu'une mutation échoue définitivement.

### 3.2 Mutations

Pour les données synchronisées :

- mettre à jour l'état local dès que possible lorsque le produit attend un comportement optimiste ;
- conserver une identité stable pour les objets créés localement ;
- persister les mutations qui doivent survivre à un redémarrage ;
- rendre la mutation rejouable ;
- ne considérer une mutation comme acquittée qu'après un succès réel de persistance/rejeu ;
- éviter qu'un refresh serveur obsolète écrase une mutation locale plus récente.

### 3.3 Nouvelles données

Toute nouvelle collection/table doit définir :

- identifiant ;
- index/requêtes nécessaires ;
- stratégie de suppression ;
- ownership utilisateur ;
- règles de sécurité ;
- migration éventuelle ;
- comportement du cache.

---

## 4. UI / UX

Une fonctionnalité UI doit gérer au minimum :

- état normal ;
- état de chargement si une opération est asynchrone ;
- état vide si applicable ;
- erreur récupérable ;
- interaction désactivée pendant une opération non réentrante ;
- retour utilisateur après une mutation ;
- navigation et retour arrière cohérents.

### Cohérence Budgly

Vérifier systématiquement :

- thème clair/sombre ;
- locale FR/EN ;
- devise ;
- nombre de décimales / préférence d'arrondi ;
- format des dates ;
- responsive sur les tailles d'écran utilisées ;
- accessibilité minimale : labels, tailles tactiles, contraste et navigation logique.

Ne pas ajouter de logique métier dans un widget uniquement pour simplifier son ViewModel.

---

## 5. Analytics et observabilité

Si la fonctionnalité introduit un comportement produit important :

- identifier les événements utiles à la mesure ;
- utiliser `AnalyticsService` plutôt qu'un appel PostHog direct ;
- respecter l'allowlist d'événements ;
- ne jamais envoyer de PII ou de données financières sensibles dans les propriétés ;
- ajouter Crashlytics/logging uniquement lorsque cela apporte une information exploitable.

Une fonctionnalité n'a pas besoin d'un événement Analytics si l'information n'est pas utile à une décision produit.

---

## 6. Tests — Definition of Done

### 6.1 Logique pure

Toute nouvelle règle métier déterministe doit avoir des tests unitaires couvrant :

- cas nominal ;
- limites ;
- valeurs vides/nulles lorsqu'elles sont possibles ;
- cas invalides ;
- régressions connues.

La logique pure importante doit viser une couverture proche de 100 %.

### 6.2 Services / providers

Tester les comportements importants plutôt que chaque ligne :

- succès ;
- échec ;
- données absentes ;
- filtrage/tri/pagination ;
- mutations ;
- comportement offline lorsque concerné ;
- reprise après erreur lorsque concerné.

Les frontières Firestore/Supabase/Storage doivent être testées avec un fake ou un test d'intégration adapté lorsque cela permet de vérifier réellement la requête ou la mutation.

### 6.3 Widgets

Ajouter un widget test lorsqu'il est **peu coûteux et apporte une vraie garantie**, notamment pour :

- une interaction utilisateur importante ;
- une condition d'affichage ;
- un état erreur/vide ;
- une régression visuelle/comportementale simple ;
- une navigation.

Ne pas écrire des tests UI uniquement pour faire monter le pourcentage global.

### 6.4 Intégration

Utiliser un test d'intégration pour les parcours où plusieurs couches doivent fonctionner ensemble, notamment :

- création/modification/suppression critique ;
- offline → reconnexion → synchronisation ;
- parcours utilisateur complet ;
- régressions difficiles à reproduire avec unitaire/widget.

---

## 7. Couverture

La couverture globale est un **indicateur**, pas un objectif produit.

La priorité est :

1. logique métier ;
2. synchronisation/offline ;
3. mutations de données ;
4. ViewModels et orchestration ;
5. widgets à comportement significatif ;
6. code purement visuel ou généré en dernier.

Une fonctionnalité est validée même si la couverture globale ne progresse pas, à condition que ses nouveaux comportements critiques soient correctement testés.

À l'inverse, une hausse de couverture obtenue uniquement en testant des branches triviales ne constitue pas une amélioration de qualité.

---

## 8. Performance

Avant validation, vérifier les risques évidents :

- requêtes réseau inutiles ;
- chargement de données non nécessaire ;
- listeners trop larges ;
- rebuilds Flutter excessifs ;
- calculs lourds dans `build()` ;
- pagination/lazy loading ;
- opérations répétées à chaque frame ;
- allocations inutiles dans les chemins fréquents.

Ne pas optimiser prématurément un chemin non critique : mesurer ou identifier un coût concret avant d'introduire une complexité supplémentaire.

---

## 9. Localisation et contenu

Toute chaîne visible par l'utilisateur doit être localisée.

Ne pas modifier manuellement les fichiers générés de `lib/l10n/`.

Ajouter les entrées ARB nécessaires puis régénérer les fichiers de localisation.

---

## 10. Documentation et migration

Une fonctionnalité doit mettre à jour la documentation lorsque nécessaire :

- architecture ;
- offline-first ;
- analytics ;
- comportement produit ;
- manuel de test ;
- migration de données ;
- limites connues.

Les changements de schéma doivent inclure leur migration SQL/Firestore/règles associée lorsqu'elle existe.

---

## 11. Validation finale

Avant de considérer l'issue terminée :

```bash
flutter pub get
flutter analyze
flutter test
flutter test --coverage
```

Pour une fonctionnalité nécessitant un parcours complet :

```bash
flutter test integration_test
```

Puis vérifier manuellement le parcours principal sur l'environnement cible lorsque nécessaire.

### Checklist de PR / issue

- [ ] Critères d'acceptation remplis.
- [ ] Architecture cohérente avec MVVM pragmatique.
- [ ] Aucune abstraction générique ajoutée sans justification.
- [ ] États UI principaux gérés.
- [ ] FR/EN et format monétaire/date vérifiés.
- [ ] Offline/reconnexion/redémarrage vérifiés si concernés.
- [ ] Sécurité/règles/migrations vérifiées si données nouvelles.
- [ ] Tests unitaires ajoutés pour les règles métier.
- [ ] Tests service/provider ajoutés pour les comportements critiques.
- [ ] Widget tests ajoutés lorsque le coût est faible et la garantie utile.
- [ ] Intégration ajoutée si le comportement traverse plusieurs couches critiques.
- [ ] Analytics ajoutées uniquement si utiles.
- [ ] Aucun PII dans Analytics/logs.
- [ ] Pas de requête/rebuild inutile évident.
- [ ] Documentation mise à jour si nécessaire.
- [ ] `flutter analyze` sans erreur/warning.
- [ ] Tous les tests passent.
- [ ] Couverture examinée sur le code modifié et non uniquement sur le pourcentage global.

---

## 12. Principe directeur

> **Une fonctionnalité est terminée lorsqu'elle est fiable pour l'utilisateur, testée sur ses comportements importants et cohérente avec l'architecture — pas lorsqu'un chiffre de couverture atteint une cible arbitraire.**
