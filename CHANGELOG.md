# Changelog

Newest first.  Dates are release dates.

## v0.0.6 (2026-10-09)

### Changed

- The bounded apt call moved out of `.github/actions/setup` and into
  `ci/apt-get.sh`, and the lint workflow now uses it instead of carrying a
  second, unbounded copy.  Two things follow.  There is one implementation
  of the bound and the retries rather than two that can drift apart, and
  shellcheck actually sees it: the `shell` job checks every script under
  `ci/`, while a `run:` block inside a workflow is invisible to it.
- The lint workflow no longer installs shellcheck unconditionally.  The
  runner image ships it, so the step only acts if that ever stops being
  true -- and then through the same wrapper, because a stalled mirror must
  not hold this job either.
- The widened gate earned its keep on the spot: a comment in the new
  script began with `# shellcheck`, which shellcheck reads as a directive
  and then cannot parse -- SC1072 and SC1073, both errors.  The sentence is
  reworded.  That line sat in a `run:` block before the move and nothing
  would ever have looked at it.
- `bison` in the grammar job goes through `ci/apt-get.sh` as well.  It was
  the last bare `sudo apt-get` left in any of these repositories.
- That job uses `working-directory: src` instead of a bare `cd src`.
  shellcheck flags such a `cd` (SC2164) because in a script without
  `set -e` the next command then runs in the wrong place.  Here it would
  have aborted anyway, since GitHub runs a `run:` block with `bash -e`, so
  this is tidiness rather than a bug that was waiting -- but the `cd` is
  gone and with it the finding.
- The repository moved from `joneum` to the `sysadmin-labs` organization.
  Badges and links in the README point to the new address; the old URLs
  redirect.
- Two log messages dropped from `alert` to `error`: `let error parsing
  argument` and `let variable %d not found`.  Both are reachable with
  nothing but a request -- `?a=abc` is enough -- and `alert` means the
  operator has to act now.  It also made Test::Nginx print a warning for
  every such request, and it would trip the error log oracles in
  `ci/reload.sh` and in the hostile checks of the sibling modules.  The
  four remaining `alert`s stay: they report a configuration or a grammar
  that is wrong, not something a client did.

### Added

- `t/zero.t`: six cases around operands a client controls -- a zero divisor
  for `/` and for `%`, a zero divisor written out in the configuration, a
  divisor that is not zero and still divides, an operand that is not a
  number, and the arguments missing altogether.  Every block also asserts
  that no `alert` was logged, which is the oracle for "the worker did not
  die".
- One `let` per block on purpose.  The module registers a **global**
  variable and the expression parsed last wins everywhere, which
  `t/scope.t` nails down.  Two expressions in one configuration measure the
  wrong one, and that is not theory: the first run of this proof put three
  locations in one file and reported `84 / 2` as 86, because the addition
  from the last location had won everywhere.

- A reload test: `ci/reload.sh`, the per-module `ci/reload.conf` beside it,
  and a workflow of its own.  nginx is reloaded eight times in a row and
  after every one of them the module has to answer correctly, the worker
  generation has to be the new one and nothing of the old one left, the
  master's descriptor count has to be where it started, and no worker may
  have died by signal.  A module that allocates or opens something per cycle
  and never gives it back is invisible in normal use -- nothing fails,
  nothing is logged, and the process grows by one cycle's worth on every
  reload -- and a test suite cannot see it, because a suite starts nginx
  once.
- The probe asks the module, not the server.  A reload that left the module
  behind still answers 200, so the check is the value `let` computed, the
  field `set_form_input` read out of the body, the `Content-Encoding` header
  only this module can set, or the file that came through the cache.
- Deliberately no band on the master's resident size.  Measured here, a
  healthy series grows the master by about twenty-five pages per reload, the
  allocator keeping what it freed, while a leaked cycle pool is a handful of
  pages.  Any band wide enough not to flap is wider than the thing it would
  have to catch, so it could never fail for the right reason.  The descriptor
  count is sharp and needs no band.
- Proven against a planted leak before it was written down: one descriptor
  opened per configuration load inside the directive handler took the
  master's count from 10 to 18 over eight reloads and the check went red.

- Every archive the build downloads is now verified against a sha256
  recorded in `.github/versions.env`: the nginx release and the actionlint
  release archive, through the new `ci/fetch-verify.sh`.  A changed archive,
  a truncated download or a build cache somebody else filled now fails the
  build instead of being compiled.  A file that fails the check is removed
  so the next run cannot pick it up, and a file that is already present is
  hashed again rather than trusted.
- The companion module is pinned by commit as well as by tag, and the
  clone is refused if the tag no longer points at that commit.  A tag is a
  movable label, so pinning one alone does not say what was built.

### Fixed

- **A client could kill the worker with `?b=0`.**  `/` and `%` in
  `ngx_let_apply_binary_integer_op` divided without looking at the divisor.
  Integer division by zero is undefined, and on x86 it raises SIGFPE, so
  every configuration with a variable on the right of either operator was
  open to that from anywhere.  Measured on nginx 1.30.5 with
  `let $v $arg_a / $arg_b` and a request of `?a=1&b=0`:

        before   HTTP 000   [alert] worker process 24676 exited on signal 8 (core dumped)
        after    HTTP 200   no signal deaths

  A zero divisor now returns `NGX_ERROR` out of the expression, which is
  what an unparseable operand has always done: the variable stays empty and
  the request is answered.

- `ci/ubsan.suppress` names the one finding nginx's own startup produces on
  1.30.5: `ngx_pstrdup` copies a zero-length string from a null pointer while
  `ngx_init_cycle` sets up the prefixes, before a single module is loaded.
  The entry carries the full stack and the reason, and it comes out again as
  soon as the shipped stable line no longer carries it.  1.31.6 does not.

- A cleanup in `ci/build.sh` spelled `rm -rf "$DEPS/$name"`.  Both parts are
  always set, but an empty one would have taken the whole dependency
  directory with it, and two empty ones the root.  Written `${DEPS:?}` now,
  so the shell refuses instead.

### Changed

- Every job now carries a `timeout-minutes`, and the apt step in
  `.github/actions/setup` is bounded with `timeout` and retried.  A mirror
  that accepted the connection and then stopped answering held six jobs in
  that step until GitHub's own six hour ceiling killed them -- 360 and 361
  minutes for two of them.  The run produced no verdict at all and spent
  about 36 hours of runner time doing it.  A step inside a composite action
  cannot carry `timeout-minutes`, hence the explicit `timeout` there.  The
  bounds are measured rather than guessed: across the four repositories the
  slowest healthy job is CodeQL at 2.8 minutes and every other one stays
  under 2.5, so 15 minutes leaves five times the headroom, with 20 for
  CodeQL and 25 for the job that boots a virtual machine.

- `valgrind.suppress` carries two entries instead of 7, and both say what
  they hide.  Measured, not assumed: with an empty file the suite reports
  exactly two things and nothing else, the environment array nginx keeps in
  `ngx_set_environment` and the connection and event arrays it keeps in
  `ngx_event_process_init`.  No invalid read, no uninitialised value, no
  conditional jump -- so everything beyond those two suppressed something
  that never happens.  The file is now the same in all four module
  repositories.
- Both traces run through `ngx_single_process_cycle`, because Test::Nginx
  starts nginx with `master_process off`.  An entry for the master's own path
  could never be reached from this suite, which is why there is none: a
  suppression nobody can check is worse than no suppression.

- The deep checks -- codeql, lint, sanitizers, valgrind and the FreeBSD run
  -- now build 1.30.5, the release `www/nginx`, `www/nginx-full` and
  `www/nginx-lite` ship, instead of mainline.  They used to look at a version
  no package carries.

- Versions live in `.github/versions.env` and nowhere else.  Every workflow
  and `ci/build.sh` read them from there, so a release bump is one edit in
  one file instead of one per workflow, and the digest moves with the
  version it belongs to.  `ci/build.sh` refuses a version it has no digest
  for rather than building it unverified.
- `.github/scripts/pins.sh` hands the release list to `build-test` as a job
  output, because a matrix is read before any step of its own job can run.

### Removed

- nginx 1.22.0, 1.24.0 and 1.26.3 are out of the test matrix.  nginx keeps
  only the current stable and the current mainline alive; everything below
  1.30 is archive material upstream, and no FreeBSD port of this module uses
  it.  The floor is now 1.28.3, the last release of the previous stable line,
  kept so a newer nginx interface cannot creep in unnoticed.

### Known gap

- `Test::Nginx` still comes from CPAN unpinned, installed by `cpanm` in the
  shared setup action.  Pinning it means choosing a version for the suite,
  which is a separate decision.
- The digests prove what we build against, not where it came from.
  nginx.org publishes a detached signature next to each archive; verifying
  it would need the signing keys in the workflow.

## v0.0.5 (2026-10-05)

- First release from this repository.
