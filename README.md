# Fonctionnalités supplementaires : 

## Gestion d'égalité : 

Si au cours de la phase 'votes tallied' l'enum unanimity est 'equality', l'admin a la posibilité de reinitialiser le vote en gardant les propositions

## Visibilité d'abstention : 

Tout le monde peut voir le pourcentage d'abstention pendant la phase votes tallied

Si l'abstentionnisme est au dessus de 50% l'admin ne peut pas mettre fin à la session de vote

## Restart : 

Possibilité de recommencer un nouveau cycle et donc un nouveau vote

# Note pour Cyril : 

-La fonction pour recuperer le winner s'appelle 'result'. Elle retourne l'id de la proposition gagnante + le nombre de vote
