# Budgly — Campagne de validation manuelle

> **Statut : à compléter par vous.** Ce fichier est un support de traçage, pas un rapport.
> Chaque scénario décrit le comportement attendu. Notez ce que vous observez, puis cochez.
> Date de la campagne : ____________  Appareil : ____________  OS : ____________  Build : ____________

## Mode d'emploi

1. Installez l'APK de debug sur un **vrai téléphone** (`flutter run` ou `flutter build apk --debug`).
2. Parcourez les scénarios dans l'ordre : les P0 conditionnent la validité des P1.
3. Pour chaque scénario, remplissez la colonne **Observé** : ce que vous avez réellement vu, pas ce qui
   était attendu. En cas d'échec, copiez le message d'erreur exact et cochez **NON**.
4. Un scénario marqué **NON** devient soit un test automatisé (si reproductible en `flutter_test`),
   soit un defect à corriger. Ne le laissez pas en « à voir plus tard ».

**Légende** : ✅ conforme · ❌ non conforme · ⚠️ conforme avec réserve (précisez) · ⏭ non testable ici

---

## P0 — Bloquants (à faire avant toute release)

### 1. Première installation → onboarding complet

| Attendu | Observé |
|---|---|
| Écran de bienvenue affiché, aucun écran bloqué | |
| Création du compte, puis de la catégorie, puis du budget : chaque étape persistée | |
| Redirection vers l'Overview après l'onboarding | |
| Fermer l'app et rouvrir : l'Overview s'affiche directement (onboarding mémorisé) | |

**Résultat** : ☐ ✅  ☐ ❌  ☐ ⚠️
**Notes** :

---

### 2. Fermeture forcée pendant l'onboarding, puis relance

| Attendu | Observé |
|---|---|
| L'app rouvre sur l'étape d'onboarding inachevée (pas l'Overview) | |
| Aucune donnée dupliquée (un seul compte, une seule catégorie) | |
| Terminer l'onboarding mène à l'Overview | |

**Résultat** : ☐ ✅  ☐ ❌  ☐ ⚠️
**Notes** :

---

### 3. Connexion email + vérification email

| Attendu | Observé |
|---|---|
| Email de vérification reçu, redirection tutorielle puis Overview | |
| Un compte non vérifié est bloqué sur l'écran de login | |
| « Renvoyer l'email » fonctionne, cooldown respecté | |

**Résultat** : ☐ ✅  ☐ ❌  ☐ ⚠️
**Notes** :

---

### 4. CRUD dépense avec réseau réel

| Attendu | Observé |
|---|---|
| Créer une dépense : elle apparaît immédiatement dans la liste | |
| Modifier son montant : la nouvelle valeur s'affiche | |
| Supprimer : la ligne disparaît, confirmation demandée | |
| **Force-fermer l'app puis rouvrir** : la dépense est toujours là, valeurs correctes | |

**Résultat** : ☐ ✅  ☐ ❌  ☐ ⚠️
**Notes** :

---

### 5. Coupure réseau pendant create/update/delete, puis reconnexion

| Attendu | Observé |
|---|---|
| **Couper le Wi-Fi et les données mobiles avant l'action** | |
| Créer/modifier/supprimer fonctionne hors ligne, l'UI reste cohérente | |
| L'UI affiche un indicateur de synchronisation en attente (bandeau) | |
| **Rétablir le réseau** : la synchronisation part seule, sans action utilisateur | |
| Après reconnexion : aucun doublon, aucune donnée perdue | |
| Le bandeau « problème de synchronisation » disparaît une fois le rejeu réussi | |

**Résultat** : ☐ ✅  ☐ ❌  ☐ ⚠️
**Notes** :

---

### 6. Occurrence récurrente : modification passée / milieu / future

| Attendu | Observé |
|---|---|
| Ouvrir une occurrence récurrente, choisir la portée de modification | |
| **« Cette occurrence uniquement »** : les autres occurrences sont inchangées | |
| **« Cette occurrence et les suivantes »** : la série est scindée, l'historique antérieur intact | |
| Le montant, le nom et la catégorie de la série sont corrects après modification | |

**Résultat** : ☐ ✅  ☐ ❌  ☐ ⚠️
**Notes** :

---

### 7. Dépenses non débitées au démarrage

| Attendu | Observé |
|---|---|
| Créer une dépense le mois dernier, ne pas la débiter | |
| Relancer l'app : la bannière d'avertissement est visible d��s l'ouverture | |
| La bottom sheet affiche le **total** et le **regroupement par période d'origine** | |
| Action « reporter sur la période courante » : la dépense apparaît au bon mois | |
| Action « débiter sur la période d'origine » : elle disparaît de la liste | |
| Action « débiter maintenant » : déplacée et marquée débitée | |
| Le total de la bannière se recalcule après chaque action | |

**Résultat** : ☐ ✅  ☐ ❌  ☐ ⚠️
**Notes** :

---

## P1 — Importants

### 8. Connexion Google réelle

| Attendu | Observé |
|---|---|
| La feuille Google s'ouvre, la sélection de compte fonctionne | |
| Le profil est créé ou récupéré sans erreur | |
| Aucune demande de vérification email (compte Google considéré vérifié) | |

**Résultat** : ☐ ✅  ☐ ❌  ☐ ⚠️
**Notes** :

---

### 9. Préférences : devise, décimales, langue, thème

| Attendu | Observé |
|---|---|
| Changer la devise : tous les montants sont réaffichés dans la nouvelle devise | |
| Changer le nombre de décimales : l'affichage suit (0, 1 ou 2 décimales) | |
| Changer la langue FR/EN : toute l'interface suit, y compris les dates | |
| Changer le thème clair/sombre : application immédiate | |
| **Redémarrer l'app** : les 4 préférences sont conservées (pas de retour aux défauts) | |
| Les préférences ne fuient pas vers un autre compte (déconnexion/reconnexion) | |

**Résultat** : ☐ ✅  ☐ ❌  ☐ ⚠️
**Notes** :

---

### 10. Photo / avatar

| Attendu | Observé |
|---|---|
| Ouvrir la galerie, sélectionner une image, rognage circulaire | |
| L'aperçu se met à jour, l'image estUploaded et visible après reconnexion | |
| **Refuser la permission** : message d'erreur clair, pas de crash | |
| Supprimer la photo : retour à l'initiale du compte | |

**Résultat** : ☐ ✅  ☐ ❌  ☐ ⚠️
**Notes** :

---

### 11. Petits écrans, tablettes, thèmes, polices

| Attendu | Observé |
|---|---|
| Écran compact (iPhone SE / petit Android) : aucun débordement, menus accessibles | |
| Tablette : la mise en page s'adapte, la navigation reste utilisable | |
| Thème clair ET sombre sur chaque écran | |
| Police système agrandie (accessibilité) : pas de texte tronqué | |
| Noms de catégories longs : troncature ou passage à la ligne correct |

**Résultat** : ☐ ✅  ☐ ❌  ☐ ⚠️
**Notes** :

---

## P2 — Complémentaires (facultatif)

### 12. Déconnexion avec mutations en attente

| Attendu | Observé |
|---|---|
| Créer une dépense hors ligne, puis se déconnecter | |
| La déconnexion **n'est pas bloquée** par la file d'attente | |
| Se reconnecter : la dépense en attente est synchronisée | |

**Résultat** : ☐ ✅  ☐ ❌  ☐ ⚠️
**Notes** :

---

## Bilan

| Priorité | Scénarios prévus | ✅ | ❌ | ⚠️ | ⏭ |
|---|---|---|---|---|---|
| P0 | 7 | | | | |
| P1 | 4 | | | | |
| P2 | 1 | | | | |

**Décision release** : ☐ Oui  ☐ Non — motif : ____________________________

### Anomalies remontées (à transformer en tests ou en tickets)

| # | Scénario | Description de l'anomalie | Reproductible ? | Ticket |
|---|---|---|---|---|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |
