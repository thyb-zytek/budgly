# Budgly — Campagne de validation manuelle

> **Source de vérité d'exécution : Testiny** (projet **Budgly**, clé `P-2`).
> Suite pre-release = **2 déroulés** chaînables.
>
> | Élément Testiny | Référence |
> |---|---|
> | Dossier | `Release Validation` |
> | Cas | `E2E-FLOW-A` (TC-35), `E2E-FLOW-B` (TC-36) |
> | Run pre-release | `Pre-release E2E chaînés` (TR-4) — **nouveau run à chaque release** |
>
> Date : ____________  Appareil : ____________  OS : ____________  Build : ____________

## Mode d'emploi

1. Installer l'APK de debug sur un **vrai téléphone**.
2. Exécuter **FLOW-A** d'une traite. Puis **FLOW-B** (logout ou autre compte Google).
3. Saisir le résultat dans Testiny (`PASSED` / `FAILED` / `BLOCKED` / `SKIPPED`) + commentaire
   (appareil, build, **numéro d'étape** en cas d'échec, ex. `A11`).
4. **Go release** : FLOW-A `PASSED` (ou `SKIPPED`/`BLOCKED` justifié). FLOW-B `PASSED` ou `SKIPPED`
   si Google Sign-In indisponible sur le build.

**Hors campagne** : FIFO SyncQueue, coalescence, backoff, goldens, formats devise/locale isolés,
CRUD offline purement service.

---

## FLOW-A — Parcours email (un seul déroulé)

**Testiny** : TC-35 · Critical · Acceptance

**Prérequis** : app désinstallée / données vidées ; réseau au départ ; boîte mail réelle + email neuf ;
noter témoins (noms/montants) et effectifs comptes/catégories.

### Phase Auth

| Étape | Action | Valider |
|---|---|---|
| **A1** | Inscription email / mot de passe | Message d'envoi de vérif, adresse correcte |
| **A2** | Sans cliquer le lien : reconnexion / relance | Bloqué, pas d'Overview |
| **A3** | Mail reçu ; « Renvoyer… » puis 2ᵉ renvoi rapide | Mail &lt; 2 min ; cooldown/message, pas de crash |
| **A4** | Clic lien + reconnexion | Accès onboarding ; plus de demande de vérif |

### Phase Onboarding

| Étape | Action | Valider |
|---|---|---|
| **A5** | Bienvenue → créer le **compte budgétaire** → **kill** (pas de catégorie) | App tuée après l'étape compte |
| **A6** | Relance → fin catégorie + budget → « C'est parti ! » | Reprise étape inachevée ; **pas de doublon** ; Overview |
| **A7** | Kill / relance | Overview directe ; données présentes sans doublon |

### Phase Dépenses

| Étape | Action | Valider |
|---|---|---|
| **A8** | Create → update → delete dépense ponctuelle | UI + totaux cohérents ; confirmation delete |
| **A9** | Recréer dépense **témoin** → kill / relance | Témoin présent, valeurs exactes, pas de doublon |

### Phase Récurrence

| Étape | Action | Valider |
|---|---|---|
| **A10** | Créer série mensuelle navigable ≥ 3 mois ; noter M0 / N0 | Occurrences passée / courante / future |
| **A11** | Occurrence **milieu** → M1 → « Cette échéance uniquement » | Seule la cible change ; passé/futur = M0 |
| **A12** | **Autre** série, milieu → M2 → « … et les suivantes » | Antérieur intact ; courant+suivants = M2 |

### Phase Non débitées

| Étape | Action | Valider |
|---|---|---|
| **A13** | ≥ 3 dépenses mois précédent(s), non débitées (idéalement 2 périodes) | Données prêtes |
| **A14** | Cold start → bannière → sheet « Dépenses à traiter » | Bannière au démarrage ; compteur + regroupement |
| **A15** | Reporter ; débiter origine (swipe gauche) ; débiter période courante | Chaque action met à jour liste/compteur/bannière |

### Phase Offline (en dernier)

| Étape | Action | Valider |
|---|---|---|
| **A16** | Noter état → couper réseau → mutations compte / catégorie / dépense | Acceptées sans freeze ; UI locale OK |
| **A17** | Kill offline → rouvrir offline → rétablir réseau (ou « Réessayer ») → kill online | Sync OK ; bandeau disparu ; **aucun doublon** ; rien perdu |

**Résultat FLOW-A** : ☐ PASSED  ☐ FAILED (étape ____)  ☐ BLOCKED  ☐ SKIPPED  
**Notes** :

---

## FLOW-B — Parcours Google (second déroulé)

**Testiny** : TC-36 · High · Acceptance  
Indépendant de A (logout après A, ou install / utilisateur distinct).

**Prérequis** : compte Google de test ; SHA/config Sign-In OK (sinon SKIPPED + motif).

| Étape | Action | Valider |
|---|---|---|
| **B1** | Login → Continuer avec Google | Feuille système Google |
| **B2** | Sélectionner le compte | Retour app sans crash |
| **B3** | Profil + onboarding si besoin → Overview | Pas de vérif email ; Overview OK |
| **B4** | Logout → même Google | Mêmes données ; pas de reset silencieux |

**Résultat FLOW-B** : ☐ PASSED  ☐ FAILED (étape ____)  ☐ BLOCKED  ☐ SKIPPED  
**Notes** :

---

## Bilan release

| Flow | Testiny | PASSED | FAILED | BLOCKED | SKIPPED |
|---|---|---|---|---|---|
| A — Email chaîné | TC-35 | | | | |
| B — Google | TC-36 | | | | |

**Décision release** : ☐ Oui  ☐ Non — motif : ____________________________

### Anomalies

| # | Flow / étape | Description | Reproductible ? | Ticket |
|---|---|---|---|---|
| 1 | | | | |
| 2 | | | | |
