# 2. Smoke test global

Objectif : vérifier rapidement que l'application est utilisable après installation.

- [ ] L'application démarre sans crash.
- [ ] L'écran initial est correct.
- [ ] La navigation principale fonctionne.
- [ ] La connexion fonctionne.
- [ ] Le compte de test est chargé.
- [ ] L'Overview s'affiche.
- [ ] Les comptes sont visibles.
- [ ] Les catégories sont visibles.
- [ ] Une dépense peut être créée.
- [ ] Une dépense peut être modifiée.
- [ ] Une dépense peut être supprimée.
- [ ] Les paramètres sont accessibles.
- [ ] La déconnexion fonctionne.
- [ ] La reconnexion fonctionne.

---

# 3. Authentification

## 3.1 Création de compte

- [ ] Ouvrir l'écran d'inscription.
- [ ] Vérifier les champs obligatoires.
- [ ] Tester un email invalide.
- [ ] Tester un mot de passe invalide.
- [ ] Tester deux mots de passe différents.
- [ ] Créer un compte valide.
- [ ] Vérifier le comportement pendant le chargement.
- [ ] Vérifier l'état après création.
- [ ] Vérifier la vérification email si activée.
- [ ] Fermer et relancer l'application.
- [ ] Vérifier que la session est conservée.

## 3.2 Connexion

- [ ] Connexion avec identifiants valides.
- [ ] Mauvais email.
- [ ] Mauvais mot de passe.
- [ ] Champs vides.
- [ ] Double clic sur le bouton de connexion.
- [ ] Vérifier qu'une seule opération est lancée.
- [ ] Vérifier l'état de chargement.
- [ ] Relancer l'application après connexion.
- [ ] Vérifier la restauration de session.

## 3.3 Google Sign-In

Si activé :

- [ ] Connexion Google avec un compte existant.
- [ ] Première connexion Google.
- [ ] Annulation du sélecteur Google.
- [ ] Retour après échec.
- [ ] Vérifier l'état de chargement.
- [ ] Vérifier qu'aucun doublon de profil n'est créé.

## 3.4 Mot de passe oublié

- [ ] Ouvrir « mot de passe oublié ».
- [ ] Email invalide.
- [ ] Email vide.
- [ ] Email valide.
- [ ] Vérifier le message de confirmation.
- [ ] Vérifier le lien reçu.
- [ ] Définir un nouveau mot de passe.
- [ ] Se reconnecter avec le nouveau mot de passe.

## 3.5 Déconnexion

- [ ] Se déconnecter.
- [ ] Vérifier le retour à l'écran de connexion.
- [ ] Fermer/relancer l'application.
- [ ] Vérifier que la session précédente n'est pas restaurée.

---

# 4. Premier lancement et tutoriel

## 4.1 Nouveau compte

- [ ] Créer un nouveau compte.
- [ ] Vérifier que le tutoriel apparaît.
- [ ] Vérifier l'étape d'accueil.
- [ ] Vérifier l'indicateur d'étape.
- [ ] Avancer dans chaque étape.
- [ ] Revenir en arrière lorsque disponible.
- [ ] Vérifier la conservation des données saisies.

## 4.2 Création du compte pendant le tutoriel

- [ ] Créer un compte.
- [ ] Modifier son nom.
- [ ] Modifier sa couleur.
- [ ] Modifier son icône/avatar.
- [ ] Valider.
- [ ] Vérifier qu'il apparaît dans le récapitulatif.

## 4.3 Création de catégorie pendant le tutoriel

- [ ] Créer une catégorie.
- [ ] Laisser l'icône par défaut.
- [ ] Modifier l'icône.
- [ ] Modifier la couleur.
- [ ] Valider.
- [ ] Vérifier l'affichage dans le récapitulatif.
- [ ] Terminer le tutoriel.
- [ ] Aller dans les paramètres.
- [ ] Modifier l'icône de cette catégorie.
- [ ] Vérifier que toutes les icônes disponibles sont chargées.

## 4.4 Budget initial

- [ ] Saisir un budget.
- [ ] Saisir zéro.
- [ ] Saisir un montant décimal.
- [ ] Modifier le budget.
- [ ] Vérifier le récapitulatif.
- [ ] Terminer le tutoriel.

## 4.5 Fin du tutoriel

- [ ] Terminer complètement le tutoriel.
- [ ] Vérifier l'arrivée sur l'Overview.
- [ ] Fermer l'application.
- [ ] Relancer.
- [ ] Vérifier que le tutoriel ne réapparaît pas.
- [ ] Vérifier qu'un utilisateur déjà initialisé ne retourne jamais au tutoriel.

---

# 5. Overview

## 5.1 Chargement initial

- [ ] Ouvrir l'Overview.
- [ ] Vérifier le loader.
- [ ] Vérifier que les comptes apparaissent.
- [ ] Vérifier les catégories.
- [ ] Vérifier les dépenses.
- [ ] Vérifier le revenu.
- [ ] Vérifier le budget.
- [ ] Vérifier les statistiques.
- [ ] Vérifier le graphique.

## 5.2 Changement de période

Tester :

- [ ] mois précédent ;
- [ ] mois suivant ;
- [ ] mois courant ;
- [ ] plusieurs mois consécutifs ;
- [ ] changement rapide de période.

Vérifier :

- [ ] dépenses correspondant à la période ;
- [ ] statistiques correspondant à la période ;
- [ ] graphique correspondant à la période ;
- [ ] budget correspondant à la période ;
- [ ] revenu correspondant à la période ;
- [ ] aucune donnée de l'ancien mois ne reste affichée.

## 5.3 Swipe de période

- [ ] Swipe vers le mois précédent.
- [ ] Swipe vers le mois suivant.
- [ ] Swipe rapide plusieurs fois.
- [ ] Vérifier qu'il n'y a pas de désynchronisation entre l'animation et les données.

## 5.4 Changement de compte

Avec plusieurs comptes :

- [ ] Sélectionner le compte courant.
- [ ] Sélectionner l'épargne.
- [ ] Sélectionner le compte secondaire.
- [ ] Vérifier que les dépenses correspondent au compte.
- [ ] Vérifier que les statistiques changent.
- [ ] Changer de période après changement de compte.
- [ ] Changer de compte après changement de période.
- [ ] Vérifier qu'aucune donnée de l'ancien compte ne reste affichée.

## 5.5 Statistiques

- [ ] Vérifier le total des dépenses.
- [ ] Vérifier le budget.
- [ ] Vérifier le restant.
- [ ] Vérifier le budget/semaine si présent.
- [ ] Vérifier les valeurs avec calcul manuel.
- [ ] Tester zéro dépense.
- [ ] Tester une seule dépense.
- [ ] Tester beaucoup de dépenses.
- [ ] Tester un mois sans budget.

## 5.6 Graphique

- [ ] Vérifier l'affichage.
- [ ] Vérifier les catégories.
- [ ] Vérifier les montants.
- [ ] Vérifier les couleurs.
- [ ] Tester une seule catégorie.
- [ ] Tester plusieurs catégories.
- [ ] Tester aucune dépense.
- [ ] Cliquer sur une catégorie.
- [ ] Vérifier l'ouverture du détail.
- [ ] Vérifier que la période sélectionnée est conservée.

---

# 6. Création d'une dépense

## 6.1 Dépense simple

- [ ] Ouvrir la modale de création.
- [ ] Vérifier le titre.
- [ ] Vérifier le compte sélectionné.
- [ ] Vérifier la catégorie.
- [ ] Saisir un nom.
- [ ] Saisir un montant entier.
- [ ] Saisir un montant décimal.
- [ ] Choisir une date.
- [ ] Valider.
- [ ] Vérifier la fermeture de la modale.
- [ ] Vérifier l'apparition de la dépense.
- [ ] Vérifier les statistiques.
- [ ] Vérifier le graphique.

## 6.2 Validation

- [ ] Nom vide.
- [ ] Montant vide.
- [ ] Montant à zéro.
- [ ] Montant négatif.
- [ ] Format décimal invalide.
- [ ] Compte absent.
- [ ] Catégorie absente.
- [ ] Date invalide si applicable.
- [ ] Vérifier les messages d'erreur.

## 6.3 Montants

Tester :

- [ ] `1`
- [ ] `1,50`
- [ ] `100`
- [ ] `1000,99`
- [ ] espaces ;
- [ ] séparateur décimal local ;
- [ ] valeur très élevée.

Vérifier que les montants sont enregistrés et affichés correctement.

## 6.4 Options avancées

- [ ] Ouvrir les options avancées.
- [ ] Fermer les options avancées.
- [ ] Modifier la date de débit.
- [ ] Définir une date de fin.
- [ ] Supprimer la date de fin.
- [ ] Sélectionner une récurrence.
- [ ] Vérifier l'aperçu.
- [ ] Valider.

---

# 7. Modification d'une dépense

## 7.1 Dépense simple

- [ ] Ouvrir une dépense.
- [ ] Vérifier les valeurs initiales.
- [ ] Modifier le nom.
- [ ] Modifier le montant.
- [ ] Modifier la catégorie si possible.
- [ ] Modifier la date.
- [ ] Enregistrer.
- [ ] Vérifier la liste.
- [ ] Vérifier les statistiques.
- [ ] Vérifier le graphique.

## 7.2 Annulation

- [ ] Modifier une dépense.
- [ ] Changer plusieurs champs.
- [ ] Annuler.
- [ ] Vérifier que rien n'est enregistré.

## 7.3 Édition récurrente

- [ ] Ouvrir une dépense récurrente.
- [ ] Vérifier les données initiales.
- [ ] Modifier la récurrence.
- [ ] Modifier la date de fin.
- [ ] Supprimer la date de fin.
- [ ] Modifier le montant.
- [ ] Enregistrer.
- [ ] Vérifier les occurrences futures.
- [ ] Vérifier les occurrences passées.
- [ ] Vérifier qu'aucune occurrence inattendue n'est créée.

---

# 8. Occurrences récurrentes

## 8.1 Génération

Pour une dépense mensuelle :

- [ ] Créer une dépense le 15 du mois.
- [ ] Vérifier les occurrences suivantes.
- [ ] Changer de mois.
- [ ] Vérifier l'occurrence attendue.
- [ ] Vérifier qu'il n'y a pas de doublon.

## 8.2 Dates de fin

- [ ] Créer une récurrence sans date de fin.
- [ ] Vérifier les occurrences.
- [ ] Définir une date de fin.
- [ ] Vérifier la dernière occurrence.
- [ ] Vérifier qu'aucune occurrence n'existe après la fin.

## 8.3 Cas des mois courts

Tester une dépense récurrente :

- [ ] 31 janvier ;
- [ ] février ;
- [ ] avril ;
- [ ] mois de 30 jours.

Vérifier le comportement de clamp des dates.

## 8.4 Marquage débité/non débité

- [ ] Marquer une occurrence comme débitée.
- [ ] Vérifier son affichage.
- [ ] La repasser en non débitée.
- [ ] Vérifier son affichage.
- [ ] Changer de mois.
- [ ] Revenir.
- [ ] Vérifier que l'état est conservé.

## 8.5 Split / modification de récurrence

Tester un changement de récurrence sur une série existante :

- [ ] Modifier la fréquence.
- [ ] Vérifier la séparation entre ancienne et nouvelle version.
- [ ] Vérifier les occurrences déjà passées.
- [ ] Vérifier les occurrences futures.
- [ ] Vérifier qu'il n'y a pas de doublons.
- [ ] Vérifier qu'une occurrence déjà débitée reste correctement historisée.

---

# 9. Détail d'une catégorie

## 9.1 Navigation

- [ ] Depuis l'Overview, sélectionner une catégorie.
- [ ] Vérifier l'ouverture du détail.
- [ ] Vérifier le titre.
- [ ] Vérifier les dépenses.
- [ ] Vérifier les totaux.

## 9.2 Période

Important :

- [ ] Depuis janvier, sélectionner une catégorie.
- [ ] Changer vers février.
- [ ] Sélectionner une catégorie.
- [ ] Vérifier que le détail affiche février.
- [ ] Revenir à janvier.
- [ ] Vérifier que le détail affiche janvier.
- [ ] Changer de période avant d'ouvrir le détail.
- [ ] Vérifier que la période affichée reste celle sélectionnée.

## 9.3 Liste

- [ ] Une dépense.
- [ ] Plusieurs dépenses.
- [ ] Aucune dépense.
- [ ] Dépenses récurrentes.
- [ ] Dépenses débitées.
- [ ] Dépenses non débitées.

---

# 10. Actions rapides sur une dépense

- [ ] Ouvrir les actions rapides.
- [ ] Modifier.
- [ ] Supprimer.
- [ ] Marquer comme débitée.
- [ ] Marquer comme non débitée.
- [ ] Annuler une action.
- [ ] Vérifier le feedback utilisateur.
- [ ] Vérifier que l'action ne se déclenche pas deux fois lors de clics rapides.

## Swipe

- [ ] Swipe gauche.
- [ ] Swipe droit.
- [ ] Vérifier les actions proposées.
- [ ] Vérifier l'animation.
- [ ] Vérifier que le geste ne déclenche pas plusieurs actions.
- [ ] Vérifier le comportement sur une liste longue.

---

# 11. Comptes

## 11.1 Création

- [ ] Créer un compte.
- [ ] Nom valide.
- [ ] Nom vide.
- [ ] Nom très long.
- [ ] Modifier couleur.
- [ ] Modifier avatar/icône.
- [ ] Enregistrer.

## 11.2 Modification

- [ ] Modifier le nom.
- [ ] Modifier couleur.
- [ ] Modifier avatar.
- [ ] Vérifier la mise à jour partout.

## 11.3 Suppression

- [ ] Supprimer un compte vide.
- [ ] Supprimer un compte contenant des dépenses.
- [ ] Vérifier la confirmation.
- [ ] Annuler la suppression.
- [ ] Confirmer.
- [ ] Vérifier que le compte disparaît.
- [ ] Vérifier le comportement si le compte supprimé était sélectionné.

---

# 12. Catégories

## 12.1 Création

- [ ] Créer une catégorie.
- [ ] Nom vide.
- [ ] Nom très long.
- [ ] Choisir une couleur.
- [ ] Choisir une icône.
- [ ] Enregistrer.

## 12.2 Icônes

- [ ] Ouvrir le sélecteur.
- [ ] Vérifier toutes les icônes.
- [ ] Sélectionner une icône.
- [ ] Modifier une ancienne catégorie.
- [ ] Vérifier que les icônes sont disponibles après redémarrage.

## 12.3 Modification

- [ ] Modifier le nom.
- [ ] Modifier couleur.
- [ ] Modifier icône.
- [ ] Vérifier la mise à jour dans Overview.
- [ ] Vérifier la mise à jour dans les dépenses.

## 12.4 Suppression

- [ ] Supprimer une catégorie vide.
- [ ] Supprimer une catégorie contenant des dépenses.
- [ ] Vérifier la confirmation.
- [ ] Annuler.
- [ ] Confirmer.
- [ ] Vérifier le comportement des dépenses historiques.

---

# 13. Budget

## 13.1 Création/modification

- [ ] Définir un budget.
- [ ] Modifier le budget.
- [ ] Mettre le budget à zéro.
- [ ] Montant décimal.
- [ ] Montant élevé.
- [ ] Vérifier les statistiques.

## 13.2 Périodes

- [ ] Budget janvier.
- [ ] Budget février différent.
- [ ] Changer de mois.
- [ ] Vérifier que chaque mois possède la bonne valeur.

---

# 14. Revenus

- [ ] Définir un revenu mensuel.
- [ ] Modifier le revenu.
- [ ] Supprimer/vider le revenu si possible.
- [ ] Vérifier les statistiques.
- [ ] Changer de mois.
- [ ] Vérifier le revenu hérité si configuré.
- [ ] Vérifier le comportement lorsqu'aucun revenu n'existe.

---

# 15. Paramètres

## 15.1 Profil

- [ ] Ouvrir le profil.
- [ ] Modifier les informations disponibles.
- [ ] Enregistrer.
- [ ] Vérifier après redémarrage.

## 15.2 Mot de passe

- [ ] Ouvrir le changement de mot de passe.
- [ ] Ancien mot de passe incorrect.
- [ ] Nouveau mot de passe invalide.
- [ ] Confirmation différente.
- [ ] Nouveau mot de passe valide.
- [ ] Se reconnecter.

## 15.3 Préférences

### Devise

Tester :

- [ ] EUR
- [ ] USD
- [ ] GBP

Vérifier :

- [ ] montants ;
- [ ] symboles ;
- [ ] statistiques ;
- [ ] formulaires ;
- [ ] dépenses existantes.

### Langue

Tester :

- [ ] Français.
- [ ] Anglais.

Vérifier :

- [ ] navigation ;
- [ ] titres ;
- [ ] boutons ;
- [ ] messages d'erreur ;
- [ ] validations ;
- [ ] dates ;
- [ ] récurrences.

### Thème

- [ ] Clair.
- [ ] Sombre.
- [ ] Système.

Vérifier chaque écran.

---

# 16. Navigation

- [ ] Bottom navigation.
- [ ] Overview → détail catégorie.
- [ ] Overview → paramètres.
- [ ] Paramètres → comptes.
- [ ] Paramètres → catégories.
- [ ] Paramètres → préférences.
- [ ] Paramètres → profil.
- [ ] Retour Android.
- [ ] Retour après modale.
- [ ] Retour après formulaire.
- [ ] Ouverture/fermeture répétée d'écrans.

Tester également :

- [ ] navigation rapide entre écrans ;
- [ ] ouverture d'un écran pendant un chargement ;
- [ ] retour pendant un chargement ;
- [ ] aucun écran bloqué.

---

# 17. Offline / réseau

Cette section est **prioritaire**.

## 17.1 Lecture offline

Avant de couper le réseau :

- [ ] Charger l'Overview.
- [ ] Charger les comptes.
- [ ] Charger les catégories.
- [ ] Charger les dépenses.
- [ ] Charger les paramètres.

Couper ensuite le réseau :

- [ ] Relancer l'Overview.
- [ ] Vérifier les données locales.
- [ ] Naviguer entre les mois.
- [ ] Ouvrir une catégorie.
- [ ] Ouvrir les paramètres.

## 17.2 Création offline

- [ ] Couper le réseau.
- [ ] Créer une dépense.
- [ ] Vérifier l'affichage immédiat.
- [ ] Vérifier qu'aucun crash ne se produit.
- [ ] Vérifier le banner de synchronisation si présent.
- [ ] Rétablir le réseau.
- [ ] Vérifier la synchronisation.
- [ ] Vérifier l'absence de doublon.

## 17.3 Modification offline

- [ ] Modifier une dépense offline.
- [ ] Modifier une dépense récurrente offline.
- [ ] Modifier un compte offline.
- [ ] Modifier une catégorie offline.
- [ ] Rétablir le réseau.
- [ ] Vérifier la synchronisation.

## 17.4 Suppression offline

- [ ] Supprimer une dépense offline.
- [ ] Rétablir le réseau.
- [ ] Vérifier la suppression serveur.

## 17.5 Perte réseau pendant une opération

- [ ] Commencer une création.
- [ ] Couper le réseau pendant l'opération.
- [ ] Vérifier le comportement.
- [ ] Reconnecter.
- [ ] Vérifier l'état final.

Répéter pour :

- [ ] modification ;
- [ ] suppression ;
- [ ] débit/non-débit ;
- [ ] compte ;
- [ ] catégorie ;
- [ ] budget.

---

# 18. Synchronisation

- [ ] Créer plusieurs éléments offline.
- [ ] Rétablir le réseau.
- [ ] Vérifier l'ordre de synchronisation.
- [ ] Vérifier l'absence de doublons.
- [ ] Vérifier les IDs locaux.
- [ ] Fermer l'application avant synchronisation.
- [ ] Relancer.
- [ ] Vérifier que la queue reprend correctement.

## Conflits

Si reproductible :

- [ ] Modifier une donnée offline.
- [ ] Modifier la même donnée depuis un autre client.
- [ ] Reconnecter.
- [ ] Vérifier le résultat.
- [ ] Vérifier qu'aucune donnée incohérente n'est créée.

---

# 19. Chargements et performances UI

- [ ] Premier lancement.
- [ ] Connexion.
- [ ] Chargement Overview.
- [ ] Changement de compte.
- [ ] Changement de mois.
- [ ] Ouverture d'une catégorie.
- [ ] Ouverture de la modale Expense.
- [ ] Ouverture des paramètres.

Vérifier :

- [ ] pas de freeze ;
- [ ] pas de spinner permanent ;
- [ ] pas de clignotement excessif ;
- [ ] pas de reconstruction visuellement anormale ;
- [ ] pas de données affichées appartenant à une autre période ;
- [ ] pas de double soumission.

---

# 20. Responsivité

Tester sur différentes tailles d'écran.

- [ ] Petit téléphone.
- [ ] Téléphone standard.
- [ ] Grand téléphone.
- [ ] Écran large/tablette si supporté.

Vérifier particulièrement :

- [ ] Overview.
- [ ] graphique + statistiques.
- [ ] sélecteurs de compte/catégorie.
- [ ] ExpenseEditorSheet.
- [ ] formulaires.
- [ ] paramètres.
- [ ] longues catégories.
- [ ] longs noms de comptes.
- [ ] montants élevés.

Aucun :

- [ ] overflow horizontal ;
- [ ] overflow vertical inattendu ;
- [ ] texte coupé ;
- [ ] bouton inaccessible ;
- [ ] élément hors écran.

---

# 21. Thème et apparence

## Clair

- [ ] Overview.
- [ ] ExpenseEditorSheet.
- [ ] CategoryExpenses.
- [ ] Settings.
- [ ] Forms.
- [ ] Dialogs.
- [ ] Snackbars.

## Sombre

Même liste.

Vérifier particulièrement :

- [ ] contraste du texte ;
- [ ] champs ;
- [ ] dropdowns ;
- [ ] graphiques ;
- [ ] icônes ;
- [ ] boutons ;
- [ ] états sélectionnés ;
- [ ] états désactivés.

---

# 22. Données limites

Tester :

- [ ] aucun compte ;
- [ ] un seul compte ;
- [ ] nombreux comptes ;
- [ ] aucune catégorie ;
- [ ] nombreuses catégories ;
- [ ] aucune dépense ;
- [ ] une dépense ;
- [ ] beaucoup de dépenses ;
- [ ] nom très long ;
- [ ] catégorie très longue ;
- [ ] montant très élevé ;
- [ ] montant décimal ;
- [ ] mois sans données ;
- [ ] année sans données ;
- [ ] dépenses sur plusieurs années.

---

# 23. Multi-comptes / multi-catégories — test de non-régression

Créer :

- 3 comptes ;
- 8 catégories ;
- au moins 30 dépenses ;
- plusieurs dépenses récurrentes.

Puis vérifier :

- [ ] Overview du compte A.
- [ ] Overview du compte B.
- [ ] Overview du compte C.
- [ ] changement de mois.
- [ ] ouverture d'une catégorie.
- [ ] retour à Overview.
- [ ] création d'une dépense.
- [ ] modification.
- [ ] suppression.
- [ ] changement de compte.
- [ ] retour à la période précédente.

Objectif : détecter toute fuite d'état entre compte/période/catégorie.

---

# 24. Tests spécifiques au refactor Phase 3

## ExpenseEditorSheet

- [ ] Création et modification utilisent exactement le même style de formulaire.
- [ ] Les champs sont correctement préremplis en édition.
- [ ] Les champs sont vides/initialisés correctement en création.
- [ ] Les options avancées fonctionnent dans les deux modes.
- [ ] Les dates fonctionnent dans les deux modes.
- [ ] La récurrence fonctionne dans les deux modes.
- [ ] Les actions spécifiques à l'édition restent disponibles.
- [ ] La création ne présente pas d'action réservée à l'édition.
- [ ] Annulation fonctionne dans les deux modes.
- [ ] Une erreur serveur n'entraîne pas la fermeture incorrecte de la modale.
- [ ] Le bouton de validation est correctement désactivé pendant l'enregistrement.

## ExpenseFormController

- [ ] Initialisation création.
- [ ] Initialisation édition.
- [ ] Montant.
- [ ] Date.
- [ ] Date de fin.
- [ ] Récurrence.
- [ ] Options avancées.
- [ ] Validation.
- [ ] Réinitialisation/annulation.

## OverviewRepository

- [ ] Premier chargement.
- [ ] Refresh.
- [ ] Changement de période.
- [ ] Changement de compte.
- [ ] Préchargement.
- [ ] Erreur de chargement.
- [ ] Reconnexion après erreur.
- [ ] Données déjà présentes en cache.

---

# 25. Régression des anciens bugs connus

## Période dans le détail catégorie

- [ ] Sélectionner février.
- [ ] Cliquer sur une catégorie.
- [ ] Vérifier que le détail affiche février et non le mois courant.

## Premier login / Supabase / JWT

- [ ] Créer un nouveau compte.
- [ ] Se connecter pour la première fois.
- [ ] Vérifier l'initialisation du profil.
- [ ] Vérifier les données Supabase.
- [ ] Vérifier qu'aucune erreur JWT ne bloque l'utilisateur.

## Tutoriel → création de catégorie

- [ ] Créer une catégorie avec icône par défaut.
- [ ] Terminer le tutoriel.
- [ ] Ouvrir les catégories.
- [ ] Modifier l'icône.
- [ ] Vérifier que le sélecteur d'icônes fonctionne.

## Multi-comptes / redirection tutoriel

- [ ] Créer plusieurs comptes.
- [ ] Fermer l'application.
- [ ] Relancer.
- [ ] Vérifier qu'aucune redirection intempestive vers le tutoriel ne se produit.

---

# 26. Cas de concurrence utilisateur

Tester les clics rapides :

- [ ] double clic création ;
- [ ] double clic modification ;
- [ ] double clic suppression ;
- [ ] double clic débit ;
- [ ] changement de mois pendant chargement ;
- [ ] changement de compte pendant chargement ;
- [ ] fermeture de modale pendant sauvegarde.

Vérifier :

- [ ] aucune duplication ;
- [ ] aucune double requête visible ;
- [ ] aucun état incohérent ;
- [ ] aucun crash.

---

# 27. Relance / persistance

Pour chaque opération importante :

1. effectuer l'opération ;
2. fermer l'application ;
3. relancer ;
4. vérifier les données.

À tester :

- [ ] compte ;
- [ ] catégorie ;
- [ ] dépense ;
- [ ] dépense récurrente ;
- [ ] occurrence débitée ;
- [ ] budget ;
- [ ] revenu ;
- [ ] préférences ;
- [ ] langue ;
- [ ] devise ;
- [ ] thème.

---

# 28. Checklist finale avant prochaine phase

## Fonctionnel

- [ ] Auth OK
- [ ] Tutoriel OK
- [ ] Comptes OK
- [ ] Catégories OK
- [ ] Budgets OK
- [ ] Revenus OK
- [ ] Dépenses simples OK
- [ ] Dépenses récurrentes OK
- [ ] Modification OK
- [ ] Suppression OK
- [ ] Occurrences OK
- [ ] Débit/non-débit OK
- [ ] Split/récurrence OK
- [ ] Overview OK
- [ ] Détail catégorie OK
- [ ] Navigation OK

## Offline

- [ ] Lecture offline
- [ ] Création offline
- [ ] Modification offline
- [ ] Suppression offline
- [ ] Synchronisation
- [ ] Reprise après fermeture
- [ ] Reconnexion

## UI

- [ ] Clair
- [ ] Sombre
- [ ] Français
- [ ] Anglais
- [ ] EUR
- [ ] USD
- [ ] GBP
- [ ] Petit écran
- [ ] Grand écran
- [ ] Aucun overflow

## Régression Phase 3

- [ ] ExpenseEditorSheet
- [ ] ExpenseFormController
- [ ] OverviewRepository
- [ ] Changement de période
- [ ] Changement de compte
- [ ] Création
- [ ] Modification
- [ ] Récurrence
- [ ] Analytics sans double événement

---

# 29. Résumé des résultats

À compléter pendant la campagne de tests.

| Domaine | PASS | FAIL | BLOCKED | N/A | Notes |
|---|---:|---:|---:|---:|---|
| Authentification | | | | | |
| Tutoriel | | | | | |
| Overview | | | | | |
| Dépenses | | | | | |
| Récurrences | | | | | |
| Catégories | | | | | |
| Comptes | | | | | |
| Budgets | | | | | |
| Revenus | | | | | |
| Paramètres | | | | | |
| Navigation | | | | | |
| Offline | | | | | |
| Synchronisation | | | | | |
| Responsivité | | | | | |
| Thème | | | | | |
| Régression Phase 3 | | | | | |

---

# 30. Priorité des tests

Si le temps est limité, exécuter au minimum dans cet ordre :

### P0 — Bloquants

1. [ ] Smoke test
2. [ ] Connexion / déconnexion
3. [ ] Tutoriel nouveau compte
4. [ ] Création dépense simple
5. [ ] Modification dépense
6. [ ] Suppression dépense
7. [ ] Création dépense récurrente
8. [ ] Modification récurrence
9. [ ] Changement de période
10. [ ] Changement de compte
11. [ ] Détail catégorie depuis une période donnée

### P1 — Critiques

12. [ ] Débit/non-débit
13. [ ] Split récurrence
14. [ ] Multi-comptes
15. [ ] Multi-catégories
16. [ ] Offline création
17. [ ] Offline modification
18. [ ] Synchronisation
19. [ ] Budget
20. [ ] Revenu

### P2 — Qualité

21. [ ] Langue
22. [ ] Devise
23. [ ] Thème
24. [ ] Responsivité
25. [ ] Données limites
26. [ ] Clics rapides
27. [ ] Persistance après redémarrage

---

## Conclusion

Cette campagne doit servir de **baseline fonctionnelle avant tout nouveau refactor important**.

Les résultats les plus importants à remonter sont :

- bugs fonctionnels ;
- régressions de période/compte ;
- problèmes de récurrence ;
- problèmes offline/synchronisation ;
- problèmes liés au nouveau `ExpenseEditorSheet` ;
- problèmes de performances perceptibles ;
- incohérences d'état après navigation.

Une fois la campagne terminée, les FAIL peuvent être regroupés par domaine avant de décider de la Phase 4.
