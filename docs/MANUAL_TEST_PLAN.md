# Budgly — campagne manuelle minimale

L'automatisation couvre les invariants métier, la sérialisation, les mutations offline, la queue/reconnexion, le versioning récurrent et la majorité des interactions widgets. La campagne manuelle doit donc rester courte et chercher uniquement les comportements dépendants du vrai appareil, du vrai réseau ou des services externes.

## Passe recommandée — 10 scénarios

| # | Scénario | Vérification | Priorité |
|---|---|---|---|
| 1 | Première installation → ouverture → onboarding complet | aucun écran bloqué, création compte/catégorie/budget cohérente | P0 |
| 2 | Fermeture forcée pendant onboarding puis relance | reprise à l'étape attendue, aucune donnée dupliquée | P0 |
| 3 | Login email + vérification email | connexion, redirection overview/tutorial correcte | P0 |
| 4 | Login Google réel | authentification et création/récupération du profil | P1 |
| 5 | Création/modification/suppression d'une dépense avec réseau réel | données persistées après relance | P0 |
| 6 | Coupure réseau pendant create/update/delete puis reconnexion | UI reste cohérente, synchronisation finale sans doublon | P0 |
| 7 | Modifier une occurrence récurrente passée/milieu/future | choisir « uniquement » ou « et les suivantes », vérifier que l'historique reste inchangé | P0 |
| 8 | Dépenses non débitées des mois précédents au démarrage | bannière d'avertissement visible dès qu'il reste des dépenses antérieures non débitées, total en tête de la bottom sheet, regroupement par période d'origine, actions reporter / débiter sur origine / débiter maintenant cohérentes après traitement | P0 |
| 9 | Changer devise + nombre de décimales + langue | formats affichés partout, après redémarrage | P1 |
| 10 | Photo/avatar : prise/sélection, refus permission, suppression | fallback visuel et permissions OS | P1 |
| 11 | Parcours long sur petit écran + tablette | pas d'overflow, menus/dialogues accessibles, swipe utilisable | P1 |

## Scénarios à ne pas refaire manuellement

Les combinaisons suivantes sont volontairement automatisées :

- CRUD offline des comptes, catégories et dépenses ;
- ordre FIFO et coalescence create/update/delete ;
- backoff et retry forcé ;
- snapshot serveur obsolète contre mutation locale ;
- suppression locale qui ne doit pas être ressuscitée par un refresh ;
- migration des statistiques lors d'un déplacement compte/catégorie ;
- conservation des occurrences débitées lors du versioning récurrent ;
- bornes de dates, mois, récurrences et formats de données ;
- états loading/success/error des ViewModels testables sans service externe.

## Vérification visuelle ciblée

Les goldens couvrent déjà des composants représentatifs. Sur appareil réel, vérifier seulement :

1. iPhone/Android compact : login, overview, formulaire dépense ;
2. écran tablette : overview et category details ;
3. thème clair/sombre ;
4. locale française et anglaise ;
5. clavier ouvert dans les formulaires ;
6. texte long / noms de catégories longs.

Une anomalie visuelle reproductible dans `flutter_test` doit devenir un test widget ou golden plutôt qu'un nouveau point de checklist manuel.
