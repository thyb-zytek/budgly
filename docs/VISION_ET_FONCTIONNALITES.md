# Budgly — Vision produit et fonctionnalités

> **Document macroscopique** — synthétise le concept, les fonctionnalités
> disponibles (v1.1.0) et la feuille de route. Peut servir de contexte à un
> prompt pour toute personne intervenant sur le projet.

---

## 1. Concept

**Budgly** est une application mobile (Android puis iOS) de **suivi budgétaire
personnel**, pensée pour l'utilisateur qui veut **gérer son mois simplement et
comprendre ses finances sans effort**.

Deux idées directrices se combinent :

> **Free** = permettre à l'utilisateur de **gérer** son mois.
> **Premium** = permettre à l'utilisateur de **comprendre** ses finances.

### Problème résolu

Les outils de budget grand public sont soit trop rigides (quotas mensuels
imposés), soit trop complexes (analyses denses, jargon), soit invisibles
(l'utilisateur ne voit pas où va son argent). Le suivi y est perçu comme une
corvée :

- saisir une dépense prend trop de temps ;
- on perd la trace de ce qui a été **prévu mais pas encore débité** ;
- les **dépenses récurrentes** (abonnements, loyers) sont mal prises en charge ;
- l'app s'appuie rarement sur le **mois le plus récent** pour estimer le reste
  à vivre.

Budgly attaque cela en combinant :

1. une **saisie rapide et visuelle** (sélecteurs icônes/couleurs, éditeur
   commun à la création et à l'édition) ;
2. des **concepts de gestion** — comptes, catégories, dépenses ponctuelles et
   **récurrentes**, revenus/budgets mensuels — sans forcer d'abstraction
   comptable ;
3. un fonctionnement **offline-first** : la saisie ne doit jamais attendre le
   réseau ;
4. une **lecture orientée période** : on vit au mois, on analyse au mois.

### Public cible

Particuliers (démarrage France, Android en premier) qui veulent un regard
honnête sur leurs finances du mois, sans la complexité d'un logiciel de
comptabilité.

### Cœur de l'expérience

- **Accueil (Overview)** : résumé du mois courant (revenu, total dépensé, solde
  prévu, répartition par catégorie), navigation entre périodes.
- **Écran par catégorie** : liste de ses dépenses (pagination, tri, édition).
- **Éditeur de dépense** partagé (ponctuelle ou récurrente), accessible
  rapidement.
- **Paramètres** : comptes, catégories, profil, préférences.

---

## 2. Stack et principe d'architecture

| Domaine | Choix |
|---|---|
| Framework | Flutter (Dart ^3.12.2), Android + iOS |
| Architecture | MVVM pragmatique : `View → ViewModel → Service → Store/Provider → cache local/backend` |
| Identité | Firebase Auth (email/mot de passe + Google Sign-In) |
| Comptes, catégories, profil, images | Supabase PostgreSQL + Storage |
| Dépenses, revenus/budgets | Cloud Firestore (persistance offline native) |
| Offline Supabase | `LocalCache` (SharedPreferences) + `SyncQueue` (rejeu des mutations) |
| Analytics / crash | PostHog (allowlist stricte, sans PII) / Firebase Crashlytics |
| Routing | go_router |
| Localisation | Français (défaut) + Anglais |

Principes cardinaux :

- **Offline-first** : la donnée locale est affichée immédiatement, le refresh
  distant part en arrière-plan. Aucune mutation ne bloque sur le réseau.
- **Frontière backend stricte** : on ne déplace pas une fonctionnalité entre
  backends sans validation explicite.
- **Simplicité** : pas d'abstraction générique ajoutée sans justification (pas
  de couche Repository/UseCase systématique).
- **Dépenses récurrentes puissantes** : expansion en occurrences, exceptions
  par occurrence, versioning des séries.

---

## 3. Fonctionnalités disponibles (v1.1.0)

### Gestion de base

- **Comptes** : création, édition, suppression, personnalisation (nom,
  avatar/icône, couleur).
- **Catégories** : création, édition, suppression, personnalisation (nom,
  icône, couleur).
- **Dépenses** : création, édition, suppression depuis l'Overview ou une
  catégorie ; montant, nom, catégorie, compte, date, date de débit, note ;
  marquer **débitée / non débitée**.

### Dépenses récurrentes

- Séries récurrentes avec **expansion en occurrences** via
  `ExpenseOccurrenceCalculator` (règle unique de projection, réutilisée
  partout).
- **Gestion fine des occurrences** (issue-12, livrée) :
  - modifier ou supprimer une **occurrence isolée**
    (`modifySingleOccurrence`) ;
  - modifier les occurrences **actuelles et suivantes**
    (`modifyFutureOccurrences`) ;
  - exceptions d'occurrence stockées dans le document Firestore (surcharge
    montant/nom/catégorie/date de débit, ou masquage) sans collection
    supplémentaire ;
  - historique immuable : jamais de modification rétroactive des périodes
    passées.
- **Versioning des séries** (`RecurringExpenseVersioning`) lors des
  changements de fréquence/ancrage.

### Changement de période et dépenses non débitées

- Navigation entre périodes depuis l'Overview.
- **Bannière de dépenses non débitées** (issue-14, livrée) : détecte
  automatiquement les échéances antérieures non débitées, propose via une
  bottom sheet trois actions par occurrence :
  1. **reporter** vers la période courante (action principale) ;
  2. **débiter** sur la période d'origine ;
  3. **débiter immédiatement** sur la période courante.
  Total en tête, regroupement par période d'origine, tri croissant, rappel
  après 3 h.

### Revenus et budgets

- **Revenu mensuel** par compte/période (lecture offline-first avec marche
  arrière 60 mois) ; peut être prévu sans transaction réelle.
- Budgets par catégorie et suivi de la dépense relative.

### Offline et synchronisation

- Affichage de la donnée cache dès le démarrage ; refresh en arrière-plan.
- `SyncQueue` : les mutations compte/catégorie/profil sont écrites en local
  puis rejouées dans l'ordre FIFO (dépendance comptes → catégories, backoff et
  retry).
- Firestore gère nativement l'offline des dépenses/revenus.
- Bannière d'état de synchronisation avec action « Réessayer » (contourne le
  backoff).
- Logout sécurisé : aucune perte de mutation critique en attente.

### Compte, profil et configuration

- Onboarding/tutoriel plein écran (reprise sur l'étape en cours).
- Auth email/mot de passe + Google Sign-In.
- Préférences : thème clair/sombre, devise, nombre de décimales, langue FR/EN.
- Profil avec photo (Supabase Storage + recadrage).
- Analytics anonymes (aucune PII, aucune donnée financière) et Crashlytics.

---

## 4. Fonctionnalités planifiées (feuille de route)

> Les brouillons détaillés sont dans `issue_drafts/`. Ce qui est déjà livré
> (issue-12, issue-14) figure en section 3.

### 4.1 Seuils de dépenses par catégorie — issue-13

**Objectif :** avertir quand on approche ou dépasse un plafond mensuel optionnel
par catégorie.

- Champ `monthlyThreshold` (nullable) sur `Category` (Supabase).
- Barre de progression à **3 états** : normal / avertissement (≥ 80 %) /
  dépassement.
- `CategoryThresholdCalculator` (logique pure testable) + widget
  `CategoryThresholdBar`, éditable depuis le détail de catégorie.

### 4.2 Module Financial Insights (5 briques) — issues 15 à 19

**Objectif :** permettre de **comprendre** ses finances via une analyse
comparative factuelle, progressive et non culpabilisante (aucune recommandation,
aucun jugement).

- **#1 Sélection des périodes et statistiques globales** (issue-15) :
  comparatif période cible vs période de référence (mois précédent, moyennes
  pondérées 3/6/12 mois, période personnalisée) sur revenus, dépenses, solde,
  récurrentes (% d'évolution). `FinancialInsightsCalculator` +
  `FinancialInsightsViewModel`.
- **#2 Statistiques dérivées** (issue-16) : taux d'épargne, ratio
  dépenses/revenus, parts par catégorie, évolution en points, dépenses fixes
  vs variables, nombre de dépenses, dépense moyenne, dépense max. UX par
  niveaux (résumé → évolutions → détails).
- **#3 Analyse factuelle des évolutions** (issue-17) : narration descriptive
  (`InsightFact` structurés) distinguant variations **absolues / relatives /
  en points**, avec seuil de significativité — jamais de conseil subjectif.
- **#4 Évolution des dépenses récurrentes** (issue-18) : totaux récurrents
  mensuels, poids dans le revenu, apparitions/suppressions/changements de
  montant au fil des périodes (`RecurringTrendPoint`, `RecurringChange`).
- **#5 Référence Budgly** (issue-19) : benchmark comparatif entre utilisateurs
  par thème (médianes), calculé côté serveur (Supabase, snapshots agrégés
  `category_benchmarks`), respect strict de la vie privée (aucune donnée brute
  exposée).

### 4.3 Prévision financière — issue-21

**Objectif :** projeter le reste à vivre et en dériver un budget hebdomadaire
lissé.

- Estimation statistique (P25/P50/P75) des dépenses restantes à partir de
  fenêtres historiques comparables (3 derniers mois, durée restante
  équivalente) ; repli médiane + marge si la fourchette est trop large.
- Budget hebdomadaire intégré à la carte résumé de l'Overview, en réutilisant
  la logique de week-end existante.
- Hypothèses de revenu/dépenses **éditables** (sans créer de vraies
  transactions) ; solde négatif projeté conservé et affiché.
- `FinancialForecastService` (sans UI) retournant un `ForecastResult` ;
  offline-first.

### 4.4 Boucle flottante de saisie express — issue-20

**Objectif :** créer une dépense depuis n'importe quelle app (ex. pendant qu'on
consulte son app bancaire).

- Overlay système Android (`SYSTEM_ALERT_WINDOW`) ; iOS très contraint
  (PiP/Dynamic Island à étudier — spike requis).
- Réutilise `ExpenseEditingData` + `ExpensesService.createExpense`, respecte
  les droits des plans Free/Premium, reste offline-first.
- Toggle de permission dans les paramètres + onboarding dédié.

### 4.5 Plans Free / Premium — issue-plans-abonnement

**Objectif :** monétiser via un Freemium centré sur la **profondeur
d'analyse**.

- **Free** : 1 compte, 5 catégories, 50 dépenses/mois, 3 mois d'historique,
  période courante uniquement, comparaison simple au mois précédent, insights
  essentiels, budget par catégorie, publicité (bannière + interstitiel).
- **Premium** (1,99 €/mois ou 20 €/an) : 5 comptes, 15 catégories, dépenses
  illimitées, 3 ans d'historique, périodes personnalisées, comparaisons
  historiques, insights avancés, analyse par catégorie, tendances, analyse
  multi-périodes, sans publicité.
- Système centralisé `SubscriptionEntitlements` (aucune limite codée en dur
  dans les widgets), plan stocké sur `user_profiles.plan` (Supabase), widget
  `LimitTopBanner` avec action « Passer à Premium ».
- **Downgrade jamais destructif** : les données excédentaires deviennent
  simplement inaccessibles.
- Paiement via RevenueCat (achat → store → RevenueCat → entitlement → backend),
  décisions restantes : périmètre de la limite catégories, fournisseur de
  paiement, format du plan.

---

## 5. Synthèse — contexte à réutiliser comme prompt

**Produit.** Budgly est une application Flutter (Android/iOS) de suivi
budgétaire personnel, Freemium, offline-first, en français et en anglais.
Objectif du produit : aider chacun à **gérer son mois gratuitement** et à
**comprendre ses finances** avec l'offre Premium — en supprimant la friction de
saisie, en gérant nativement les dépenses récurrentes et les échéances non
débitées, et en apportant des analyses factuelles et non culpabilisantes.

**État actuel (v1.1.0).** Le socle est livré : comptes, catégories, dépenses
simples et récurrentes (avec occurrences gérées individuellement), revenus et
budgets mensuels, saisie offline avec synchronisation différée (SyncQueue pour
Supabase, cache natif pour Firestore), onboarding, paramètres, profil avec
photo, localisation FR/EN, analytics anonymes. Architecture MVVM pragmatique et
offline-first, avec une frontière backend stricte (Firebase Auth, Supabase pour
comptes/catégories/profil/images, Firestore pour dépenses/budgets).

**Feuille de route.** Seuils de dépenses par catégorie (issue-13), module
Financial Insights en 5 volets (issues 15-19), prévision financière et budget
hebdomadaire (issue-21), boucle flottante de saisie express (issue-20), plans
Free/Premium avec RevenueCat (issue-plans). Les brouillons d'issues fournissent
pour chacun le périmètre, l'architecture cible, l'UX, les tests et les critères
d'acceptation.

**Contraintes d'implémentation à toujours respecter** : offline-first (la saisie
ne bloque jamais sur le réseau), frontières de backend intangibles, logique
métier dans des calculators purs testables, localisation FR/EN de chaque chaîne
visible, analytics anonymes sans PII, tests sur les comportements importants,
commits gitmoji atomiques, `flutter analyze` propre avant tout commit.