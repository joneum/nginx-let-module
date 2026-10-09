Name
====

nginx-let-module - evaluate an arithmetic or string expression in the
nginx configuration and put the result into a variable.

[![Build & Test][build-test-badge]][build-test-link]
[![FreeBSD][freebsd-badge]][freebsd-link]
[![A/UBSan][sanitizers-badge]][sanitizers-link]
[![Valgrind][valgrind-badge]][valgrind-link]
[![Reload][reload-badge]][reload-link]
[![CodeQL][codeql-badge]][codeql-link]
[![Lint][lint-badge]][lint-link]

[build-test-badge]: https://github.com/sysadmin-labs/nginx-let-module/actions/workflows/build-test.yml/badge.svg
[build-test-link]: https://github.com/sysadmin-labs/nginx-let-module/actions/workflows/build-test.yml
[freebsd-badge]: https://github.com/sysadmin-labs/nginx-let-module/actions/workflows/freebsd.yml/badge.svg
[freebsd-link]: https://github.com/sysadmin-labs/nginx-let-module/actions/workflows/freebsd.yml
[sanitizers-badge]: https://github.com/sysadmin-labs/nginx-let-module/actions/workflows/sanitizers.yml/badge.svg
[sanitizers-link]: https://github.com/sysadmin-labs/nginx-let-module/actions/workflows/sanitizers.yml
[valgrind-badge]: https://github.com/sysadmin-labs/nginx-let-module/actions/workflows/valgrind.yml/badge.svg
[valgrind-link]: https://github.com/sysadmin-labs/nginx-let-module/actions/workflows/valgrind.yml
[reload-badge]: https://github.com/sysadmin-labs/nginx-let-module/actions/workflows/reload.yml/badge.svg
[reload-link]: https://github.com/sysadmin-labs/nginx-let-module/actions/workflows/reload.yml
[codeql-badge]: https://github.com/sysadmin-labs/nginx-let-module/actions/workflows/codeql.yml/badge.svg
[codeql-link]: https://github.com/sysadmin-labs/nginx-let-module/actions/workflows/codeql.yml
[lint-badge]: https://github.com/sysadmin-labs/nginx-let-module/actions/workflows/lint.yml/badge.svg
[lint-link]: https://github.com/sysadmin-labs/nginx-let-module/actions/workflows/lint.yml

Description
===========

nginx can copy a value into a variable with `set`, and it can match one
with `map`, but it cannot calculate.  This module adds a `let`
directive that evaluates an expression and assigns the result:

```nginx
let $total ( $items + 1 ) * $price ;
```

Arithmetic runs on unsigned integers, decimal or hexadecimal.  Strings
are joined with `.`, as in Perl.  Both sides of an expression may be
nginx variables.

Status
======

In production use, and packaged in the FreeBSD ports tree as the `LET`
option of the nginx ports.  The module builds against every nginx
release listed under [Compatibility](#compatibility), and the suite runs
on each of them, on Linux and on FreeBSD.

Synopsis
========

```nginx
location /price {
    set $items 3 ;
    set $price 199 ;

    let $total ( $items + 1 ) * $price ;
    let $greeting "you owe " . $total . " cents" ;

    echo $greeting;
}
```

Installation
============

Build nginx with the module compiled in:

```
./configure --add-module=/path/to/nginx-let-module
make
make install
```

`ci/build.sh` does the same for a throwaway nginx, which is handy for
trying a patch out.  It adds `echo-nginx-module`, which the test suite
uses to print a variable:

```
ci/build.sh 1.31.6 /tmp/nginx-test
/tmp/nginx-test/sbin/nginx -V
```

Building as a dynamic module
----------------------------

```
./configure --add-dynamic-module=/path/to/nginx-let-module
make modules
```

```nginx
load_module modules/ngx_http_let_module.so;
```

Directives
==========

let
---

**Syntax:** *let $variable expression ;*
**Default:** *-*
**Context:** *http, server, location*

Defines *$variable* and attaches *expression* to it.  Nothing is
computed while the configuration is read and nothing runs in the
rewrite phase: the expression is evaluated the first time something
reads the variable during a request, and the result is kept for the
rest of that request.

The definition is server-wide, not per location.  See [One name, one
expression](#one-name-one-expression) before using the same variable
name twice.

Expressions
===========

| | |
|---|---|
| `+` `-` `*` `/` `%` | arithmetic on unsigned integers |
| `.` | string concatenation |
| `( )` | grouping |
| `0x1f` | hexadecimal literals |
| `$name` | any nginx variable |

Multiplication, division and remainder bind tighter than addition and
subtraction, so `1 + 2 * 3` is 7 and `( 1 + 2 ) * 3` is 9.

Spaces around every token
-------------------------

The module uses the nginx configuration parser as its lexer, and that
parser splits on whitespace.  Every token therefore needs a space around
it:

```nginx
let $v (1+2);              # does not work
let $v ( 1 + 2 ) ;         # works

let $v 1 + (2 * $uid);     # does not work
let $v 1 + ( 2 * $uid ) ;  # works
```

One name, one expression
------------------------

`let` registers an nginx variable, and nginx variables belong to the
server as a whole.  Writing `let` for the same name in two places does
not give each place its own value; the expression parsed last wins
everywhere, including where no `let` was written at all:

```nginx
location /a { let $v 1 + 1 ; echo $v; }    # answers 200
location /b { let $v 100 + 100 ; echo $v; } # answers 200
location /c { echo $v; }                   # answers 200
```

Give each expression its own variable name.

This is also why nginx refuses `let` inside an `if` block with *"let"
directive is not allowed here*.  The directive defines a variable
rather than performing an assignment, so there is nothing for the
condition to make conditional.  To compute a value only in some cases,
put the condition into the expression or pick the variable with `map`.

Compatibility
=============

The test suite runs against nginx 1.28.3, 1.30.5 and 1.31.6, on Linux and
on FreeBSD.  Those are the last release of the previous stable line, the
current stable and the current mainline; nginx keeps nothing older alive.

Test Suite
==========

The suite is written against
[Test::Nginx](https://metacpan.org/pod/Test::Nginx):

```
ci/build.sh 1.31.6 /tmp/nginx-test
TEST_NGINX_BINARY=/tmp/nginx-test/sbin/nginx prove -r t/
```

The Grammar
===========

The expression parser is generated by bison from `src/let.y`, and the
result, `src/let.tab.c` and `src/let.tab.h`, is committed to the tree so
that building the module needs no bison.  After a change to the grammar:

```
cd src && bison -d let.y
```

License
=======

BSD 2-Clause.  The upstream repository ships no licence file; the
text stands in the header of `src/ngx_http_let_module.c` and is
reproduced in [LICENSE](LICENSE).
