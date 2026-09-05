# Budgly — Modèle économique de lancement

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
