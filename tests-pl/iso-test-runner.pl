% Comprehensive ISO test runner
% Include all test definitions from iso-conformity-tests.pl inline

:- use_module(library(charsio)).
:- use_module(library(dcgs)).
:- use_module(library(files)).
:- use_module(library(iso_ext)).

% Test utilities
writeq_term_to_chars(Term, Chars) :-
    Options = [ignore_ops(false), numbervars(true), quoted(true), variable_names([])],
    write_term_to_chars(Term, Options, Chars).

write_term_to_chars(Term, Chars) :-
    Options = [ignore_ops(false), numbervars(false), quoted(false), variable_names([])],
    write_term_to_chars(Term, Options, Chars).

write_canonical_term_to_chars(Term, Chars) :-
    Options = [ignore_ops(true), numbervars(false), quoted(true), variable_names([])],
    write_term_to_chars(Term, Options, Chars).

test_syntax_error(ReadString, Error) :-
    catch((once(read_from_chars(ReadString, _)), false),
          error(Error, _),
          true).

% Include first 10 ISO tests as a sample
test_1 :- write_term_to_chars('\n', Chars),
          Chars = "\n".

test_2 :- test_syntax_error("'\n", syntax_error(_)).

test_3 :- test_syntax_error(")\n", syntax_error(incomplete_reduction)).

test_4 :- test_syntax_error(".\n", syntax_error(incomplete_reduction)).

test_6 :- test_syntax_error("writeq('\n').", syntax_error(invalid_single_quoted_character)).

test_7 :- read_from_chars("writeq('\\\n').", T),
          T == writeq('').

test_8 :- read_from_chars("writeq('\\\na').", T),
          T == writeq(a).

test_9 :- read_from_chars("writeq('a\\\nb').", T),
          T == writeq(ab).

test_10 :- read_from_chars("writeq('a\\\n b').", T),
           T == writeq('a b').

test_11 :- test_syntax_error("writeq('\\ ').", syntax_error(invalid_single_quoted_character)).

% Test runner
run_test(Test, Result) :-
    catch((call(Test) -> Result = pass ; Result = fail),
          _Error,
          Result = error).

run_iso_sample(Results) :-
    Tests = [test_1, test_2, test_3, test_4, test_6, test_7, test_8, test_9, test_10, test_11],
    findall(Test-Result,
            (member(Test, Tests),
             run_test(Test, Result)),
            Results).

count_results(Results, Pass, Fail, Error) :-
    findall(p, member(_-pass, Results), PassList),
    findall(f, member(_-fail, Results), FailList),
    findall(e, member(_-error, Results), ErrorList),
    length(PassList, Pass),
    length(FailList, Fail),
    length(ErrorList, Error).

summary(Results, Summary) :-
    count_results(Results, Pass, Fail, Error),
    Total is Pass + Fail + Error,
    Summary = summary(total-Total, pass-Pass, fail-Fail, error-Error).