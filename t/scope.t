# vi:filetype=perl
#
# What the scope of a let actually is.  The directive registers an nginx
# variable, and those belong to the server, so the expression parsed last
# wins everywhere.  Pinned here because the README promises it and
# because anyone rewriting the module would otherwise change it by
# accident.

use lib 'lib';
use Test::Nginx::Socket 'no_plan';

repeat_each(2);

run_tests();

__DATA__

=== TEST 1: the first of two locations gets the expression of the last
--- config
    location /a {
        let $v 1 + 1 ;
        echo $v;
    }

    location /b {
        let $v 100 + 100 ;
        echo $v;
    }
--- request
GET /a
--- response_body
200



=== TEST 2: and so does the last one
--- config
    location /a {
        let $v 1 + 1 ;
        echo $v;
    }

    location /b {
        let $v 100 + 100 ;
        echo $v;
    }
--- request
GET /b
--- response_body
200



=== TEST 3: a location that never says let reads the variable all the same
--- config
    location /a {
        let $v 1 + 1 ;
        echo $v;
    }

    location /c {
        echo $v;
    }
--- request
GET /c
--- response_body
2



=== TEST 4: a name of its own keeps its own expression
--- config
    location /a {
        let $one 1 + 1 ;
        echo $one;
    }

    location /b {
        let $two 100 + 100 ;
        echo $two;
    }
--- request
GET /a
--- response_body
2



=== TEST 5: the expression is evaluated per request, not while reading the configuration
--- config
    location /args {
        let $sum $arg_a + $arg_b ;
        echo $sum;
    }
--- request
GET /args?a=20&b=22
--- response_body
42
