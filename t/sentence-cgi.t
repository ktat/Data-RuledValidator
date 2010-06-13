use Test::More;

BEGIN {
  use_ok('Data::RuledValidator');
  $ENV{REQUEST_METHOD} = "GET";
  $ENV{QUERY_STRING} = "page=index&i=9&v=aaaaa&k=bbbb&m=1&m=2&m=4&m=5";
}

use CGI;

my $q = new CGI;
my $v = Data::RuledValidator->new(obj => $q, method => 'param');
ok(ref $v, 'Data::RuledValidator');
is($v->obj, $q);
is($v->method, 'param');

# correct rule
ok($v->by_sentence('page is word', 'i is num', 'v is word', 'k is word',  'i re ^\d+$', 'all = all of i, k, v', 'm has 4', 'm < 6', 'm > 0', 'all = all of-valid i, k, v'), 'by sentence');
ok($v->ok('page'), 'page');
ok($v->ok('i'), 'i');
ok($v->ok('k'), 'k');
ok($v->ok('all'), 'all');
ok($v->ok('page'), 'page');
ok($v->ok('i'), 'i');
ok($v->ok('k'), 'k');
ok($v->ok('all'), 'all');
ok($v->ok('m'), 'm');
ok($v->valid, 'valid');
# warn join "\n", @$v;
$v->reset;
ok(! $v, 'reseted valid; it should be undef');

# mistake rule
ok(not $v->by_sentence('page is num', 'i is num', 'v is num', 'k is num',  'v re ^\d+$', 'all = all of i, k, v, x'));
ok(not $v->ok('page'));
ok($v->ok('i'));
ok(not $v->ok('v'));
ok(not $v->ok('k'));
ok(not $v->ok('all'));
ok(not $v->ok('page'));
ok(ok $v->ok('i'));
ok(not $v->ok('k'));
ok(not $v->valid);
ok(! $v);

# create alias
Data::RuledValidator->create_alias_operator('isis', 'is');
Data::RuledValidator->create_alias_cond_operator('number2', 'num');
ok(not $v->by_sentence('page is num', 'i isis num', 'v is number2', 'k isis num', 'all = all of i, k, v, x'));
ok(not $v->ok('page'));
ok($v->ok('i'));
ok(not $v->ok('k'));
ok(not $v->ok('all'));
ok(not $v->ok('page'));
ok(ok $v->ok('i'));
ok(not $v->ok('k'));
ok(not $v->ok('all'));
ok(not $v->valid);
ok(! $v);

=functions
add_operator
add_condition_operator
to_obj
id_key
result
reset
get_rule
by_rule
=cut

done_testing;
