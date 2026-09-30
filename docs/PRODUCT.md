# Budgly — Produit, fonctionnalités et roadmap

> Source de vérité produit. Vision, fonctionnalités livrées, fonctionnalités planifiées, roadmap, modèle économique et décisions produit sont regroupés ici.

## 1. Vision et fonctionnalités



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
| Architecture | Riverpod pragmatique : `View → Notifier → Service → persistence/backend` |
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
  `FinancialInsights` Notifier.
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
commits gitmoji atomiques, `dart analyze` propre avant tout commit.

---

## 2. Roadmap



Roadmap consolidé à partir des issues ouvertes sur GitHub (aucun milestone n'étant
défini, le découpage suit les dépendances fonctionnelles et la valeur produit).

## Dépendances clés entre issues

```
#11 (onboarding/guest) ── indépendant, base acquisition
#15 (FI-1 périodes/stats) ── fondation de #16 → #19
#20 (bubble + UX FI) ── définit l'UX de #15-19 + action rapide
#22 (Free/Premium) ── a de la valeur seulement quand #15-19 existent
#21 (Forecast) ── s'appuie sur #14 (fermée), #15, et la Summary Card
```

## S1 — Acquisition : onboarding + mode invité

- **#11** Refonte du tutorial : parcours interactif pré-auth, guest mode local,
  prompt d'inscription à la 1re dépense, migration guest → compte.

Pourquoi en premier : débloque l'usage sans compte, améliore l'activation (le
point de friction n°1 du funnel).

## S2 — Fondation Financial Insights

- **#15** FI-1 sélecteurs période cible/référence + stats globales comparatives
  (`FinancialInsightsCalculator` réutilisable).
- **#20** Floating Expense Bubble + hiérarchie UX du module Insights (résumé →
  évolutions → analyse → détails).

Pourquoi ensemble : la calculator de #15 est le socle de #16-19, et #20 fixe
l'UX progressive qui évite le « scroll infini » de #16.

## S3 — Insights avancés (valeur Premium)

- **#16** FI-2 statistiques dérivées (taux d'épargne, ratios, poids des catégories).
- **#17** FI-3 analyse factuelle des évolutions et ratios.
- **#18** FI-4 évolution des dépenses récurrentes.
- **#19** FI-5 benchmark Budgly par thème (côté Supabase, `category_benchmarks`).

Pourquoi : construire les features analytiques *avant* la monétisation — ce sont
elles qui justifient le Premium selon la philosophie de #22 (« comprendre ses
finances »).

## S4 — Forecast (projection)

- **#21** Financial Forecast : montant restant projeté + budget hebdo dans la
  Summary Card, hypothèses modifiables, percentiles (P25/P50/P75), offline-first.

Pourquoi : s'appuie sur la règle de période de #14 (fermée) et sur les agrégats
de #15 ; enrichit l'Overview sans nouvelle page.

## S5 — Monétisation : plans Free / Premium

- **#22** Système d'entitlements (`SubscriptionPlan`/`SubscriptionEntitlements`),
  limites (1/5 comptes, 5/15 catégories, 50/mois, historique 3 mois/3 ans),
  `TopBanner` générique + upsell, formulaire d'abonnement (RevenueCat à
  arbitrer), publicités via `hasAds`, downgrade sans perte de données, migration
  Supabase `007`.

Pourquoi en dernier : chaque feature Premium est déjà livrée et démontrable, ce
qui donne du sens à l'upsell et au comparatif Free/Premium.

## Notes transverses

- #21 et #22 (historique 3 ans) dépendent du gating d'historique
  (`Overview.minPeriod`) → cohérence à garder entre la limite
  `historyMonths` (#22) et l'historique utilisé par le Forecast (#21).
- Les issues #15-19 étant dédiées « Insights/Premium », vérifier en S5 que les
  gates d'entitlement (périodes custom, comparaisons, trends) s'appliquent bien
  dessus — c'est listé dans les critères de #22.
- Chaque issue impose `dart analyze` + tests + l10n EN/FR ; rien de bloquant
  entre eux.

---

## 3. Modèle économique



> **Version de travail — 3 septembre 2026**
>
> Ce document synthétise le modèle de lancement de Budgly : modèle Free/Premium, hypothèse de conversion, revenus publicitaires, coûts des plateformes et choix des comptes développeur.

## 1. Positionnement du produit

Budgly est pensé autour d'un modèle **Freemium** :

- **Free** = permettre à l'utilisateur de gérer son mois.
- **Premium** = permettre à l'utilisateur de comprendre ses finances.

L'objectif est de conserver une vraie utilité dans la version gratuite, tout en réservant les fonctionnalités d'analyse avancée à Premium.

### Offre Free

- 1 compte
- 5 catégories
- 50 dépenses/mois, occurrences récurrentes comprises
- 3 mois d'historique
- période courante uniquement
- comparaison simple avec le mois précédent
- insights essentiels
- budget par catégorie
- publicité :
  - bannière en haut
  - interstitiel/skippable avant les Insights

### Offre Premium

**1,99 €/mois** ou **20 €/an**

- 5 comptes
- 15 catégories
- dépenses illimitées
- 3 ans d'historique
- budget par catégorie
- périodes d'analyse personnalisées
- comparaisons historiques
- insights avancés
- analyse par catégorie
- tendances / évolution
- analyse multi-périodes
- aucune publicité

L'idée est de faire de Premium une offre de **profondeur d'analyse**, plutôt qu'une simple suppression des limites.

---

# 2. Hypothèse de conversion

Pour le premier modèle financier, on retient une hypothèse volontairement prudente de **1 % des utilisateurs actifs qui deviennent Premium**.

Cette hypothèse est cohérente avec les benchmarks récents, tout en restant prudente pour Budgly.

Le rapport *State of Subscription Apps 2026* de RevenueCat indique notamment :

- **2,1 %** de conversion médiane mondiale entre téléchargement et abonnement payant à J+35 pour les apps Freemium.
- **0,9 %** sur Google Play.
- **2,6 %** sur l'App Store.
- Les apps à hard paywall convertissent beaucoup plus, mais ce n'est pas le modèle retenu pour Budgly.

Sources : [RevenueCat — State of Subscription Apps 2026](https://www.revenuecat.com/state-of-subscription-apps).

### Tendance globale

La tendance intéressante est donc la suivante :

> **Le Freemium convertit moins bien que le hard paywall, mais reste parfaitement viable lorsque le produit apporte suffisamment de valeur gratuitement et que les fonctionnalités Premium répondent à un besoin clair.**

RevenueCat observe également que les conversions Freemium sont plus étalées dans le temps : une partie significative des utilisateurs convertit plusieurs semaines après l'installation. Cela correspond assez bien à Budgly, car l'utilisateur doit d'abord utiliser l'application, accumuler des données et ressentir le besoin d'aller plus loin dans l'analyse.

Pour Budgly, **1 % constitue donc une hypothèse prudente de départ**, pas un objectif maximal.

---

# 3. Projection avec 1 % de conversion

### Hypothèses

- Conversion Premium : **1 %**
- Un utilisateur Premium est compté uniquement lorsque 1 % du parc atteint au moins 1 utilisateur.
- Lorsque le résultat est inférieur à 1 utilisateur Premium, il est conservé à **0**.
- Prix Premium mensuel : **1,99 €**
- Frais Google Play utilisés dans le modèle : **15 %**
- Revenu Premium net modélisé : `1,99 × 85 % = 1,69 €/mois`
- Publicité Free :
  - environ 25 impressions de bannière/mois
  - environ 4 interstitiels/mois
  - hypothèse moyenne ≈ **0,039 € / utilisateur Free / mois**

> Le revenu publicitaire est une estimation et dépend fortement du pays, du taux de remplissage, du consentement publicitaire, de l'activité réelle des utilisateurs et des performances des réseaux publicitaires.

## Projection mensuelle

| Utilisateurs totaux | Premium à 1 % | Free | Revenu Premium net | Revenus publicitaires | Revenus mensuels totaux |
|---:|---:|---:|---:|---:|---:|
| 5 | 0 | 5 | 0,00 € | 0,20 € | **0,20 €** |
| 10 | 0 | 10 | 0,00 € | 0,39 € | **0,39 €** |
| 20 | 0 | 20 | 0,00 € | 0,78 € | **0,78 €** |
| 50 | 0 | 50 | 0,00 € | 1,95 € | **1,95 €** |
| 100 | 1 | 99 | 1,69 € | 3,86 € | **5,55 €** |
| 150 | 1 | 149 | 1,69 € | 5,81 € | **7,50 €** |
| 200 | 2 | 198 | 3,38 € | 7,72 € | **11,10 €** |
| 250 | 2 | 248 | 3,38 € | 9,67 € | **13,05 €** |
| 300 | 3 | 297 | 5,07 € | 11,58 € | **16,65 €** |

### Lecture

À faible volume, **la publicité constitue la principale source de revenus** avec cette hypothèse de conversion.

Cela donne une progression approximative :

- 100 utilisateurs → ~5,55 €/mois
- 200 utilisateurs → ~11,10 €/mois
- 300 utilisateurs → ~16,65 €/mois

Le passage à plusieurs centaines d'utilisateurs devient donc intéressant même avec seulement 1 % de conversion, car les deux modèles de monétisation se cumulent :

**Free → publicité**  
**Premium → abonnement**

---

# 4. Coûts de lancement et coûts récurrents

## Plateformes et services

| Service / coût | Montant | Type | Quand le coût apparaît ? |
|---|---:|---|---|
| Google Play Developer | **25 USD** | Paiement unique | À la création du compte développeur |
| Apple Developer Program | **99 USD/an** | Annuel | Pour publier et maintenir Budgly sur iOS |
| Google Play — abonnements | **15 %** | Commission sur CA | Sur les abonnements vendus via Google Play |
| Apple App Store — abonnements éligibles | **15 %** | Commission sur CA | Pour les abonnements éligibles |
| RevenueCat | **0 $** | Mensuel | Gratuit jusqu'à 2 500 $ de MTR |
| RevenueCat au-delà du seuil | **1 % du MTR** | Mensuel | Lorsque le MTR dépasse 2 500 $ |
| Supabase Free | **0 €** | Mensuel | Tant que le projet reste dans les limites Free |
| Supabase Pro | **25 $/mois** | Mensuel | Seulement lorsque le Free tier n'est plus suffisant |
| Firebase | **0 € au lancement** | Variable | Tant que les quotas gratuits suffisent |
| PostHog | **0 € au lancement** | Variable | Tant que les quotas gratuits suffisent |

### RevenueCat

RevenueCat est particulièrement intéressant au lancement :

- gratuit jusqu'à **2 500 $ de Monthly Tracked Revenue (MTR)** ;
- au-delà, le plan applique **1 % du revenu suivi**.

Cela permet de ne pas ajouter de coût fixe important tant que Budgly reste une petite application.

Source : [RevenueCat — Pricing](https://www.revenuecat.com/pricing).

### Google Play

Le compte développeur Google Play coûte **25 USD une seule fois**.

Pour les abonnements à renouvellement automatique, Google indique actuellement un modèle de frais de **10 % + 5 % de frais de facturation**, soit **15 %**, pour les transactions concernées dans l'EEE, notamment depuis le déploiement du nouveau modèle au 30 juin 2026.

Sources :
- [Google Play — Informations requises pour le compte développeur](https://support.google.com/googleplay/android-developer/answer/13628312?hl=fr)
- [Google Play — Frais de service](https://support.google.com/googleplay/android-developer/answer/112622?hl=fr)

### Apple

Le programme Apple Developer coûte **99 USD par an**.

Apple indique également que les abonnements éligibles sont soumis à une commission de **15 %**.

Source : [Apple Developer — Membership](https://developer.apple.com/programs/).

---

# 5. Compte Google Play pour Budgly

Google propose deux types de comptes :

- compte personnel ;
- compte d'organisation.

Les deux peuvent être monétisés, mais Google recommande le compte **Organisation** lorsqu'il est destiné à une activité commerciale ou professionnelle.

Pour Budgly, le choix recommandé est donc :

> **Compte Google personnel utilisé comme administrateur**
>
> ↓
>
> **Play Console — compte Organisation**
>
> ↓
>
> **Organisation = micro-entreprise**
>
> ↓
>
> **Application = Budgly**

Le nom affiché sur Google Play peut être différent du nom légal de l'entreprise. On peut donc avoir la micro-entreprise comme entité légale tout en affichant **Budgly** comme nom de développeur.

Pour un compte Organisation, Google demande notamment :

- nom de l'organisation ;
- adresse de l'organisation ;
- numéro D-U-N-S ;
- site web ;
- coordonnées de contact ;
- profil de paiement Google correspondant à l'organisation.

Le numéro D-U-N-S peut être demandé gratuitement auprès de Dun & Bradstreet.

### Pourquoi choisir Organisation dès le départ ?

Même si un compte personnel peut être monétisé, Budgly est destiné à devenir une activité commerciale avec :

- abonnements ;
- publicité ;
- revenus récurrents ;
- potentiellement une présence sur plusieurs plateformes.

Il est donc plus propre de rattacher directement la publication à la structure professionnelle.

De plus, certaines informations du compte, comme le type de compte, ne peuvent pas simplement être modifiées dans le profil de paiement existant.

Sources :
- [Google Play — Choisir un type de compte](https://support.google.com/googleplay/android-developer/answer/13634885?hl=fr)
- [Google Play — Informations requises](https://support.google.com/googleplay/android-developer/answer/13628312?hl=fr)

---

# 6. Compte Apple pour le lancement iOS

Pour publier Budgly sur l'App Store, il faudra rejoindre le **Apple Developer Program**.

Coût :

**99 USD / an**

Apple permet l'inscription en tant que particulier ou organisation. Pour Budgly, si l'objectif est de publier sous la micro-entreprise, il est préférable de préparer l'inscription en tant qu'organisation.

Apple demande notamment un **D-U-N-S** pour vérifier l'organisation.

Le nom de l'organisation peut ensuite apparaître comme vendeur de l'application sur l'App Store.

Source : [Apple Developer — Enrollment](https://developer.apple.com/programs/enroll/).

---

# 7. Architecture de paiement recommandée

Pour Budgly, l'approche recommandée est :

```text
                    ┌───────────────────┐
                    │      Budgly       │
                    │      Flutter      │
                    └─────────┬─────────┘
                              │
                              ▼
                    ┌───────────────────┐
                    │    RevenueCat     │
                    └─────────┬─────────┘
                         ┌────┴────┐
                         ▼         ▼
                 ┌────────────┐ ┌────────────┐
                 │ Google Play│ │ App Store  │
                 │  Billing   │ │ StoreKit   │
                 └────────────┘ └────────────┘
                         │         │
                         └────┬────┘
                              ▼
                    ┌───────────────────┐
                    │ Backend Budgly     │
                    │ Entitlements      │
                    └───────────────────┘
```

L'application ne devrait pas considérer directement un achat comme la source de vérité.

La logique devrait plutôt être :

**achat → store → RevenueCat → entitlement → backend Budgly → droits Premium**

Cela permettra ensuite d'ajouter facilement d'autres niveaux comme Advanced ou Unlimited sans refaire toute l'architecture.

---

# 8. Stratégie financière de lancement

L'approche retenue permet de limiter fortement les coûts fixes.

### Phase 1 — lancement

Objectif : **dépenser le minimum**

- Google Play : paiement unique
- Apple : 99 USD/an uniquement lorsque la version iOS est lancée
- Supabase : Free
- Firebase : Free
- PostHog : Free
- RevenueCat : Free
- publicité : source de revenus dès les premiers utilisateurs Free
- Premium : source de revenus supplémentaire

### Phase 2 — croissance

Lorsque le nombre d'utilisateurs augmente :

1. les revenus publicitaires augmentent avec le nombre d'utilisateurs Free ;
2. les revenus Premium augmentent avec les conversions ;
3. RevenueCat reste gratuit jusqu'à 2 500 $ de MTR ;
4. Supabase reste gratuit tant que les limites du projet ne sont pas atteintes ;
5. le premier coût récurrent significatif devrait donc apparaître seulement lorsque l'utilisation réelle le justifie.

---

# 9. Point important : 1 % n'est pas une limite

L'hypothèse de 1 % sert principalement à construire un scénario prudent.

Les benchmarks 2026 de RevenueCat montrent une médiane mondiale de **2,1 % pour les apps Freemium** à J+35, avec une forte différence entre iOS et Android :

- iOS : **2,6 %**
- Google Play : **0,9 %**

Budgly étant lancé d'abord sur Android en France, **1 % est donc une hypothèse raisonnablement conservatrice**.

Si Budgly arrive à :

- 2 % → les revenus Premium doublent ;
- 3 % → ils triplent ;
- 5 % → le modèle économique devient nettement plus intéressant.

La priorité n'est donc pas nécessairement d'augmenter immédiatement le prix Premium, mais plutôt de mesurer :

- activation ;
- rétention ;
- nombre de dépenses saisies ;
- utilisation des Insights ;
- exposition aux limites Free ;
- affichage du paywall ;
- conversion Free → Premium ;
- churn Premium.

---

# 10. Conclusion

Le modèle retenu pour Budgly repose sur une structure volontairement légère :

**Free + publicité + Premium à 1,99 €/mois ou 20 €/an**

avec :

- peu de coûts fixes ;
- RevenueCat gratuit au démarrage ;
- Supabase conservé sur l'offre gratuite tant qu'elle suffit ;
- Firebase et PostHog sans coût initial significatif ;
- Google Play comme première plateforme ;
- iOS ajouté ensuite avec un coût de 99 USD/an.

L'hypothèse financière de départ peut être fixée à **1 % de conversion Premium**, tout en gardant en tête que les benchmarks montrent qu'un Freemium correctement exécuté peut dépasser cette valeur.

Le principal enjeu économique de Budgly n'est donc pas le coût de l'infrastructure au lancement : **c'est l'acquisition, la rétention et la capacité à transformer une partie des utilisateurs Free en utilisateurs Premium.**


---

## 4. Décisions de conception produit



Issue #13 uses **Option A: a nullable `monthly_threshold` column on `categories`**.

The threshold is a category property, is easy to query with the existing category load path, and automatically participates in the current local cache and category SyncQueue payload because `Category.toJson` / `fromJson` are the shared serialization boundary.

A dedicated table is intentionally deferred until the product needs threshold history, multiple periods, or multiple threshold types. The calculator remains independent from persistence so Financial Insights and Forecast can reuse it later.

## Offline behavior

Category updates remain optimistic through `CategoriesSession`, are persisted to the existing local category cache, and are queued as the existing `categories` sync operation. A restart therefore retains the pending threshold change and reconnection reuses the existing sync handler.
