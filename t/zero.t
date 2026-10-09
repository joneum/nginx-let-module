# vi:filetype=perl

# A divisor the client controls.  Integer division by zero is undefined and
# on x86 it raises SIGFPE, so before the guard in ngx_let_apply_binary_
# integer_op a request of ?a=1&b=0 took the worker down with "exited on
# signal 8 (core dumped)".  Every configuration that puts a variable on the
# right of / or % was open to that from anywhere.
#
# One let per block on purpose: the module registers a global variable and
# the expression parsed last wins everywhere, which t/scope.t nails down.
# Two of these expressions in one configuration would measure the wrong one.

use lib 'lib';
use Test::Nginx::Socket;

repeat_each(2);

# Four checks per block -- body, the expected error line, no alert --
# except TEST 4, which has no error line to expect.
plan tests => repeat_each() * (4 * blocks() - 1);

run_tests();

__DATA__

=== TEST 1: a zero divisor from the query string
--- config
    location /let {
        let $v $arg_a / $arg_b ;
        echo "[$v]";
    }
--- request
GET /let?a=1&b=0
--- response_body
[]
--- error_log
let division by zero
--- no_error_log
[alert]



=== TEST 2: a zero divisor for the remainder, from the query string
--- config
    location /let {
        let $v $arg_a % $arg_b ;
        echo "[$v]";
    }
--- request
GET /let?a=1&b=0
--- response_body
[]
--- error_log
let remainder by zero
--- no_error_log
[alert]



=== TEST 3: a zero divisor written out in the configuration
--- config
    location /let {
        let $v 1 / 0 ;
        echo "[$v]";
    }
--- request
GET /let
--- response_body
[]
--- error_log
let division by zero
--- no_error_log
[alert]



=== TEST 4: a divisor that is not zero still divides
--- config
    location /let {
        let $v $arg_a / $arg_b ;
        echo "[$v]";
    }
--- request
GET /let?a=84&b=2
--- response_body
[42]
--- no_error_log
[alert]



=== TEST 5: an operand that is not a number
--- config
    location /let {
        let $v $arg_a + $arg_b ;
        echo "[$v]";
    }
--- request
GET /let?a=abc&b=1
--- response_body
[]
--- error_log
let error parsing argument
--- no_error_log
[alert]



=== TEST 6: the arguments are missing altogether
--- config
    location /let {
        let $v $arg_a + $arg_b ;
        echo "[$v]";
    }
--- request
GET /let
--- response_body
[]
--- error_log
let variable
--- no_error_log
[alert]
