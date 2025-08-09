% Family relationships example
% This file demonstrates basic Prolog facts and rules

% Facts about parent relationships
parent(tom, bob).
parent(tom, liz).
parent(bob, ann).
parent(bob, pat).
parent(pat, jim).
parent(liz, joe).
parent(liz, tim).

% Facts about gender
male(tom).
male(bob).
male(jim).
male(joe).
male(tim).
female(liz).
female(ann).
female(pat).

% Rules for family relationships
father(X, Y) :- parent(X, Y), male(X).
mother(X, Y) :- parent(X, Y), female(X).

% Grandparent relationship
grandparent(X, Y) :- parent(X, Z), parent(Z, Y).
grandfather(X, Y) :- grandparent(X, Y), male(X).
grandmother(X, Y) :- grandparent(X, Y), female(X).

% Sibling relationship
sibling(X, Y) :- parent(Z, X), parent(Z, Y), X \= Y.
brother(X, Y) :- sibling(X, Y), male(X).
sister(X, Y) :- sibling(X, Y), female(X).

% Ancestor relationship (recursive)
ancestor(X, Y) :- parent(X, Y).
ancestor(X, Y) :- parent(X, Z), ancestor(Z, Y).

% Descendant is the inverse of ancestor
descendant(X, Y) :- ancestor(Y, X).

% Count descendants
count_descendants(Person, Count) :-
    findall(D, descendant(D, Person), Descendants),
    length(Descendants, Count).

% Find all children of a person
children(Parent, Children) :-
    findall(Child, parent(Parent, Child), Children).

% Example queries to try:
% ?- parent(tom, X).
% ?- ancestor(tom, jim).
% ?- grandparent(X, jim).
% ?- sibling(ann, X).
% ?- count_descendants(tom, Count).
% ?- children(bob, C).
