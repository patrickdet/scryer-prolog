% Test file
parent(tom, bob).
parent(bob, ann).

test :- parent(tom, X), write('Tom is parent of: '), write(X), nl.