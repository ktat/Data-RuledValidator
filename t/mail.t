use Test::More;

use lib qw(t/lib/);

BEGIN {
  use_ok('Data::RuledValidator');
  # use_ok('Data::RuledValidator::Plugin::EmailLoose');
  $ENV{REQUEST_METHOD} = "GET";
  $ENV{QUERY_STRING} = 'page= index &lm=ktat@cpan.org&lm2=h.@docomo.ne.jp&lm3=test@test.jp&lm4=t@docomo.ne.jp';
}

use CGI;

my $q = new CGI;
my $v = Data::RuledValidator->new(obj => $q, method => 'param', filter_replace => 1);
ok(ref $v, 'Data::RuledValidator');
is($v->obj, $q);
is($v->method, 'param');

# correct rule
ok($v->by_sentence('page is word', 'lm is mail_loose', 'lm2 is mail_loose', 'lm3 is mail_loose', 'all = all of lm, lm2', 'filter page with trim'));
ok($v->ok('page'));
ok($v->ok('lm'));
ok($v->ok('lm2'));
ok($v->ok('all'));
ok($v->ok('page'));
ok($v->ok('lm'));
ok($v->ok('lm2'));
ok($v->ok('all'));
ok($v->ok('lm3'));
# ok(not $v->ok('lm4_valid'));
ok($v->valid);
$v->reset;
ok(! $v);
is($q->param('page'), 'index');

# mistake rule
$v->filter_replace(0);
ok(not $v->by_sentence('page is num', 'lm is num', 'lm2 is num', 'all = all of lm, lm2, lm3, lm4, lm5', 'filter lm with uc'));
ok(not $v->ok('page'));
ok(not $v->ok('lm'));
ok(not $v->ok('lm2'));
ok(not $v->ok('all'));
ok(not $v->ok('page'));
ok(not $v->ok('lm'));
ok(not $v->ok('lm2'));
ok(not $v->ok('all'));
ok(not $v->valid);
ok(! $v);
is($q->param('lm'), 'ktat@cpan.org');

done_testing;
