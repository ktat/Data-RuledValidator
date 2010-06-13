use Test::Base;

use lib qw(t/lib);
use Readonly;
use Clone qw/clone/;
use Data::RuledValidator;
use DRV_Test;
use Data::Dumper;
use strict;

Readonly my $DEFAULT =>
  {
   page        => 'registration'                ,
   first_name  => 'Atsushi'                     ,
   last_name   => 'Kato'                        ,
   age         => 29                            ,
   sex         => 'male'                        ,
   mail        => 'ktat@cpan.org'               ,
   mail2       => 'ktat@cpan.org'               ,
   mail3       => 'ktat@example.com'            ,
   mail4       => 'ktat@example.com'            ,
   password    => 'pass'                        ,
   password2   => 'pass'                        ,
   hobby       => [qw/programming outdoor camp/],
   birth_year  => 1777                          ,
   birth_month => 1                             ,
   birth_day   => 1                             ,
   favorite    => [qw/books music/]             ,
   favorite_books  => ["Nodame", "Ookiku Furikabutte"],
   favorite_music  => ["Paul Simon"],
   must_select3    => [qw/1 2 3/],
   must_select1    => [qw/1/],
   same_data       => 'compare_from_data',
   must_gt_1000    => 1001,
   must_lt_1000    => 999,
   must_in_1_10    => [qw/8 9 7 4 3/],
   length_in_10    => '1234567890',
   regex           => 'abcdef',
  };

Readonly my $RESULT =>
  {
   page              => {is_alpha => 1, valid => 1},
   first_name        => {is_alpha => 1, valid => 1},
   last_name         => {is_alpha => 1, valid => 1},
   age               => {is_num   => 1, valid => 1},
   sex               => {in       => 1, valid => 1},
   mail              => {is_mail  => 1, valid => 1},
   mail2             => {eq       => 1, valid => 1},
   mail3             => {eq => 1, ne       => 1, valid => 1},
   password          => {is_alphanum => 1, valid => 1},
   password2         => {eq => 1, valid => 1},
   same_data         => {eq => 1, valid => 1},
   require           => {'of-valid' => 1, valid => 1},
   required          => {valid => 1},
   birth_year        => {is_num => 1, valid => 1},
   birth_month       => {is_num => 1, valid => 1},
   birth_day         => {is_num => 1, valid => 1},
   birthdate         => {'of-valid' => 1, valid => 1},
   hobby             => {in => 1, valid => 1},
   favorite          => {in => 1, valid => 1},
   favorite_books    => {is_words => 1, valid => 1},
   favorite_music    => {is_words => 1, valid => 1},
   must_select3      => {has => 1, valid => 1},
   must_select1      => {has => 1, valid => 1},
   'must_gt_1000'    => {'>' => 1, valid => 1},
   'must_lt_1000'    => {'<' => 1, valid => 1},
   must_in_1_10      => {between => 1, valid => 1},
   length_in_10      => {'<=' => 1, length => 1, valid => 1},
   regex             => {match => 1, valid => 1},
   hogehoge          => { },
   hogehoge2         => { }
  };

filters({
         i => [qw/eval validator/],
         e => [qw/eval result/],
        });

run_compare i  => 'e';

sub validator{
  my $in = shift;
  my %default = %{clone $DEFAULT};
  foreach my $k (keys %$in){
    $default{$k} = $in->{$k};
  }
  my $q = DRV_Test->new(%default);

  my $v = Data::RuledValidator->new(strict => 1, obj => $q, method => 'p', rule => "t/validator_complicate.rule");
  $v->by_rule({same_data => 'compare_from_data'});
  use Util::All;
  # warn Data::Dumper::Dumper($v->result->{page}, $v->valid);
  my %tmp;
  foreach(qw/failure result valid missing/){
    $tmp{$_} = $v->{$_};
  }
  @{$tmp{missing}} = sort {$a cmp $b} @{$tmp{missing}};
  # warn Data::Dumper::Dumper([$tmp{valid}, $tmp{result}, $tmp{missing}, $tmp{failure}]);
  return \%tmp;
}

sub result{
  my $in = shift;
  if(exists $in->{result}){
    foreach my $k (keys %$RESULT){
      if(not exists $in->{result}->{$k}){
        $in->{result}->{$k} = clone $RESULT->{$k};
      }elsif(not defined $in->{result}->{$k}){
        delete $in->{result}->{$k};
      }
    }
  }else{
    $in->{result} = $in->{result2} || {};
    delete $in->{result2};
  }
  $in->{missing} = [ sort {$a cmp $b} @{$in->{missing} || []} ];
  # warn Data::Dumper::Dumper($in);
  return $in;
}

__END__
=== all ok
--- i
  {};
--- e
  {
   result => {},
   valid   => 1,
   failure => {},
#   missing => [ qw/hogehoge hogehoge2/]
}
=== mail incorrect
--- i
  {
   mail        => 'ktat@cpa'                    ,
   mail2       => 'ktat@cpan'                   ,
   mail3       => 'ktat@exampl'                 ,
   mail4       => 'ktat@example'                ,
 };
--- e
  {
   result =>
   {
    mail               => {is_mail => 0, valid => 0},
    mail2              => {eq =>0, valid => 0},
    mail3              => {ne => 1, eq => 0, valid => 0},
    require            => {'of-valid' => 0, valid => 0},
   },
   valid   => 0,
   failure => {
               mail  => {is_mail => ['ktat@cpa']},
               mail2 => {eq => ['ktat@cpan']},
               mail3 => {eq => ['ktat@exampl']},
               require => {'of-valid' => [undef]},
              },
#   missing => [sort {$a cmp $b} qw/hogehoge hogehoge2/]
}
=== mail missing
--- i
  {
   mail        => undef               ,
   mail2       => undef               ,
   mail3       => undef               ,
   mail4       => undef               ,
 };
--- e
  {
   result =>
   {
    require     => {'of-valid' => 0, valid => 0},
    required    => {valid => 0},
    mail        => {},
    mail2       => {},
    mail3       => {},
   },
   valid   => 0,
   failure => {
               require => {'of-valid' => [undef]},
              },
   missing => [sort {$a cmp $b} qw/mail mail2/],
}
=== mail missing ok
--- i
  {
   page        => 'registrationNoRequired',
   mail        => undef               ,
   mail2       => undef               ,
   mail3       => undef               ,
   mail4       => undef               ,
 };
--- e
  {
   result =>
   {
    'require' => {'of-valid' => 1, valid => 1},
    required  => {valid => 0},
    mail => {},
    mail3 => {},
    mail2 => {}
   },
   valid   => 0,
   failure => {},
   missing => [sort {$a cmp $b} qw/mail mail2/],

}
=== mail missing ok 2
--- i
  {
   page        => 'registration_no_required',
   mail        => undef               ,
   mail2       => undef,
   mail3       => undef               ,
   mail4       => undef               ,
 };
--- e
  {
   result =>
   {
    page     => {is_word =>1, valid => 1},
    require   => {'of-valid' => 0, valid => 0},
    required       => {valid => 0},
    mail              => {},
    mail2             => {},
    mail3             => {},
   },
   valid   => 0,
   failure => {
               'require' => {'of-valid' => [undef]},
              },
   missing => [sort qw/mail mail2/]
#   missing => [sort {$a cmp $b} qw/hogehoge hogehoge2 mail mail2 mail3/],
}
=== mail missing not ok
--- i
  {
   page        => 'registrationNoRequired2',
   mail        => undef               ,
   mail2       => undef               ,
   mail3       => undef               ,
   mail4       => undef               ,
 };
--- e
  {
   result =>
   {
    'require'   => {'of-valid' => 0, valid => 0},
    page            => {is_alphanum => 1, valid => 1},
    required        => { valid => 0},
    mail            => {},
    mail2           => {},
    mail3           => {},
   },
   valid   => 0,
   failure => {
               'require' => { 'of-valid' => [undef]},
              },
   missing => [sort {$a cmp $b} qw/mail mail2/],
}
=== mail missing ok 3
--- i
  {
   page        => 'registrationNoRequired2',
   mail        => undef               ,
   mail2       => undef               ,
   mail3       => undef               ,
   mail4       => undef               ,
   hogehoge    => 'hogehoge',
 };
--- e
  {
   result =>
   {
    page        => {is_alphanum => 1, valid => 1},
    'require'   => {'of-valid' =>1, valid => 1},
    required    => {valid => 0},
    mail        => {},
    mail2       => {},
    mail3       => {},
    hogehoge    => {valid =>1, eq => 1},
   },
   failure => {},
   missing => [],
   missing => [sort {$a cmp $b} qw/mail mail2/],
   valid   => 0,
}
=== GLOBAL is n/a
--- i
  {
    page => 'registration2'
  };
--- e
  {
   valid   => 1,
   failure => {},
   missing => [],
   result => {
   page              => undef,
   first_name        => undef,
   last_name         => undef,
   age               => undef,
   sex               => undef,
   mail              => undef,
   mail2             => undef,
   mail3             => undef,
   password          => undef,
   password2         => undef,
   same_data         => undef,
   require           => undef,
   required          => {},
   birth_year        => undef,
   birth_month       => undef,
   birth_day         => undef,
   birthdate         => undef,
   hobby             => undef,
   favorite          => undef,
   favorite_books    => undef,
   favorite_music    => undef,
   must_select3      => undef,
   must_select1      => undef,
   'must_gt_1000'    => undef,
   'must_lt_1000'    => undef,
   must_in_1_10      => undef,
   length_in_10      => undef,
   regex             => undef,
   hogehoge          => undef,
   hogehoge2         => undef,
   }
}
=== no rule
--- i
  {
    page => 'no_rule'
  };
--- e
{
   valid   => 0,
   failure => {
     page => { is_alpha => ['no_rule']}
   },
   result => {
     page => {valid => 0, is_alpha => 0}
   },
   missing => [],
}
=== id missing
--- i
  {
    page => undef
  };
--- e
{
   valid   => 1,
   failure => {
   },
   result => {
      page => {},
   },
   missing => [],
}
=== filter
--- i
  {
    page => 'filter',
    name => '  ktat  ',
    zip  => '000-000',
  };
--- e
  {
   valid   => 1,
   result2 => {
               zip     => {valid => 1, is_num => 1},
               name    => {valid => 1, is_alphanum => 1},
	       required => {},
              },
   failure => {},
   missing => [],
  };
=== filter2
--- i
  {
    page => 'filter2',
    name => '  ktat  ',
    zip  => '000-000',
  };
--- e
  {
   valid   => 1,
   result2 => {
               zip     => {valid => 1, is_num => 1},
               name    => {valid => 1, is_alphanum => 1},
	       required => {},
              },
   failure => {},
   missing => [],
  };
=== no_filter
--- i
  {
    page => 'no_filter',
    name => '  ktat  ',
    zip  => '000-000',
  };
--- e
  {
   missing => [sort {$a cmp $b} qw/mail mail2/],
   valid   => 0,
   result2 => {
               zip     => {valid => 0, is_num => 0},
               name    => {valid => 0, is_alphanum => 0},
	       required => {},
              },
   failure => {
               zip  => {is_num => ['000-000']},
               name => {is_alphanum => ['  ktat  ']},
              },
   missing => [],
  };
=== filter3
--- i
  {
    page => 'filter3',
    name => '  ktat  ',
    zip  => '000-000',
  };
--- e
  {
   valid   => 0,
   result2 => {
               zip     => {valid => 1, is_num => 1},
               name    => {valid => 0, is_alpha => 0},
	       required => {},
              },
   failure => {
               name => {is_alpha => ['  ktat  ']},
              },
   missing => [],
  };
=== filter4
--- i
  {
    page => 'filter4',
    name => '  ktat  ',
    zip  => '000-000',
  };
--- e
  {
   valid   => 0,
   result2 => {
               zip     => {valid => 1, is_num => 1},
               name    => {valid => 0, is_alpha => 0},
	       required => {},
              },
   failure => {
               name => {is_alpha => ['  ktat  ']},
              },
   missing => [],
  };
=== special filter
--- i
  {
    page => 'specialfilter',
  };
--- e
  {
   valid   => 1,
   result2 => {
               birth_year_is_1777 => {valid => 1, eq => 1},
	       required => {},
              },
   failure => {},
   missing => [],
  };
=== filter *
--- i
  {
    page => 'filter5',
    name => '  ktat  ',
    zip  => '  000000  ',
  };
--- e
  {
   valid   => 1,
   result2 => {
               zip     => {valid => 1, is_num => 1},
               name    => {valid => 1, is_alpha => 1},
	       required => {},
              },
   failure => {},
   missing => [],
  };

=== order test
--- i
  {
    page => 'order_test',
    name => '  ktat  ',
    zip  => '  000000  ',
  };
--- e
  {
   valid   => 1,
   result2 => {
               zip     => {valid => 1, is_num => 1},
               name    => {valid => 1, is_alpha => 1},
	       required => {},
               'all_v'   => {'of-valid' => 1, valid => 1},
               all_valid    => {valid => 1, of => 1},
              },
   failure => {},
   missing => [],
  };
  
