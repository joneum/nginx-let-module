Upstream reports
================

Everything that is open at
[arut/nginx-let-module](https://github.com/arut/nginx-let-module), and
where this fork stands on it.  Upstream has taken no change since 2012.

Fixed here
----------

| | | |
|---|---|---|
| [PR #1](https://github.com/arut/nginx-let-module/pull/1) | fix crash with bogus config | Open upstream since 2014. The patch is in, and `t/crash.t` feeds the configuration that used to kill nginx. |

Answered, not changed
---------------------

| | | |
|---|---|---|
| [#3](https://github.com/arut/nginx-let-module/issues/3) | `"let" directive is not allowed here` inside an `if` block | `let` defines an nginx variable and attaches an expression to it; it does not assign anything at that point in the configuration. The value is computed the first time the variable is read during a request. There is therefore nothing for an `if` to make conditional, and allowing the directive there would only look as though the condition had an effect. The README says so under *One name, one expression*, and `t/scope.t` pins the behaviour: the expression parsed last wins for a given variable name, server-wide, including in a location that never mentions `let`. |
