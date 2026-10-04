# vi:filetype=perl

use lib 'lib';
use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * 2 * blocks();

run_tests();

__DATA__

=== TEST 1: addition
--- config
    location /let {
        let $v 1 + 2 ;
        echo $v;
    }
--- request
GET /let
--- response_body
3



=== TEST 2: subtraction
--- config
    location /let {
        let $v 10 - 4 ;
        echo $v;
    }
--- request
GET /let
--- response_body
6



=== TEST 3: multiplication
--- config
    location /let {
        let $v 6 * 7 ;
        echo $v;
    }
--- request
GET /let
--- response_body
42



=== TEST 4: division
--- config
    location /let {
        let $v 84 / 2 ;
        echo $v;
    }
--- request
GET /let
--- response_body
42



=== TEST 5: remainder
--- config
    location /let {
        let $v 17 % 5 ;
        echo $v;
    }
--- request
GET /let
--- response_body
2



=== TEST 6: parentheses bind tighter
--- config
    location /let {
        let $v ( 1 + 2 ) * 3 ;
        echo $v;
    }
--- request
GET /let
--- response_body
9



=== TEST 7: without parentheses the product goes first
--- config
    location /let {
        let $v 1 + 2 * 3 ;
        echo $v;
    }
--- request
GET /let
--- response_body
7



=== TEST 8: hexadecimal
--- config
    location /let {
        let $v 0x12 + 0 ;
        echo $v;
    }
--- request
GET /let
--- response_body
18



=== TEST 9: string concatenation
--- config
    location /let {
        let $v "a" . "b" . "c" ;
        echo $v;
    }
--- request
GET /let
--- response_body
abc



=== TEST 10: an nginx variable in an expression
--- config
    location /let {
        set $n 20 ;
        let $v $n * 2 ;
        echo $v;
    }
--- request
GET /let
--- response_body
40



=== TEST 11: a variable in a concatenation
--- config
    location /let {
        set $who "world" ;
        let $v "hello, " . $who ;
        echo $v;
    }
--- request
GET /let
--- response_body
hello, world



=== TEST 12: the directive is allowed at server level
--- config
    let $v 2 + 3 ;
    location /let {
        echo $v;
    }
--- request
GET /let
--- response_body
5
