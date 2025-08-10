% Load required libraries
:- use_module(library(charsio)).
:- use_module(library(dcgs)).
:- use_module(library(files)).
:- use_module(library(iso_ext)).

% ISO test helpers
writeq_term_to_chars(Term, Chars) :-
    Options = [ignore_ops(false), numbervars(true), quoted(true), variable_names([])],
    write_term_to_chars(Term, Options, Chars).

test_syntax_error(ReadString, Error) :-
    catch((once(read_from_chars(ReadString, _)), false),
          error(Error, _),
          true).

% Select a few ISO tests to run
test_1 :- 
    write_term_to_chars('\n', [quoted(false)], Chars),
    Chars = "\n".

test_4 :- 
    test_syntax_error(".\n", syntax_error(incomplete_reduction)).

test_43 :- 
    read_from_chars("writeq('a\\\nb').", T),
    T == writeq(ab).

test_60 :- 
    read_from_chars("writeq('\\t').", T),
    T == writeq('\t').

test_64 :- 
    read_from_chars("writeq('\\a').", T),
    T == writeq('\a').

% Run selected tests
run_iso_tests(Results) :-
    findall(Test-Result,
            (member(Test, [test_1, test_4, test_43, test_60, test_64]),
             (call(Test) -> Result = pass ; Result = fail)),
            Results).