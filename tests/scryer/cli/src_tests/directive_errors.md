```trycmd
$ scryer-prolog -f --no-add-history tests-pl/invalid_decl1.pl -g halt
   error(domain_error(operator_specifier,moin),load/1).

```

```trycmd
$ scryer-prolog -f --no-add-history tests-pl/invalid_decl2.pl -g halt
   error(domain_error(operator_priority,4000),load/1).

```

```trycmd
$ scryer-prolog -f --no-add-history tests-pl/invalid_decl3.pl -g halt
   error(type_error(list,todo_insert_invalid_term_here),load/1).

```

```trycmd
$ scryer-prolog -f --no-add-history tests-pl/invalid_decl4.pl -g halt
   error(domain_error(directive,op/4),load/1).

```

```trycmd
$ scryer-prolog -f --no-add-history tests-pl/invalid_decl5.pl -g halt
   error(domain_error(directive,(;)/2),load/1).

```

```trycmd
$ scryer-prolog -f --no-add-history tests-pl/invalid_decl6.pl -g halt
   error(domain_error(directive,todo_insert_invalid_term_here),load/1).

```

```trycmd
$ scryer-prolog -f --no-add-history tests-pl/invalid_decl7.pl -g halt
   error(domain_error(operator_specifier,todo_insert_invalid_term_here),load/1).

```

```trycmd
$ scryer-prolog -f --no-add-history tests-pl/invalid_decl8.pl -g halt
% Warning: singleton variables Var at line 1 of invalid_decl8.pl
   error(domain_error(operator_specifier,todo_insert_invalid_term_here),load/1).

```

```trycmd
$ scryer-prolog -f --no-add-history tests-pl/invalid_decl9.pl -g halt
% Warning: singleton variables Var at line 1 of invalid_decl9.pl
   error(type_error(integer,todo_insert_invalid_term_here),load/1).

```

```trycmd
$ scryer-prolog -f --no-add-history tests-pl/invalid_decl10.pl -g halt

```

FIXME I belive the following test should result in a `error(instantiation_error,load/1)` error instead of the current error.

```trycmd
$ scryer-prolog -f --no-add-history tests-pl/invalid_decl11.pl -g halt
% Warning: singleton variables Var at line 1 of invalid_decl11.pl
   error(type_error(list,todo_insert_invalid_term_here),load/1).

```

```trycmd
$ scryer-prolog -f --no-add-history tests-pl/invalid_decl12.pl -g halt
   error(permission_error(create,operator,{}),load/1).

```

```trycmd
$ scryer-prolog -f --no-add-history tests-pl/invalid_decl13.pl -g halt
   error(permission_error(create,operator,{}),load/1).

```

```trycmd
$ scryer-prolog -f --no-add-history tests-pl/invalid_decl14.pl -g halt
   error(permission_error(create,operator,'|'),load/1).

```

```trycmd
$ scryer-prolog -f --no-add-history tests-pl/invalid_decl15.pl -g halt
   error(permission_error(create,operator,'|'),load/1).

```

```trycmd
$ scryer-prolog -f --no-add-history tests-pl/invalid_decl16.pl -g halt
   error(permission_error(modify,operator,','),load/1).

```


```trycmd
$ scryer-prolog -f --no-add-history tests-pl/invalid_decl_issue2467.pl -g halt
% Warning: singleton variables D at line 1 of invalid_decl_issue2467.pl
   error(instantiation_error,load/1).

```
