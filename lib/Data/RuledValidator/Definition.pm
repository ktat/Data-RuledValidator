package Data::RuledValidator::Definition;

use strict;
use Data::RuledValidator::Util;
use Carp ();

BEGIN {
  no strict 'refs';
  foreach my $name (qw/defs required filter as optional/) {
    *$name = sub {
      my $self = shift;
      return $self->{$name} ||= {};
    }
  }
}

sub new {
  my ($class, $validator, $option) = @_;
  my $self = bless {
                    v => $validator,
                    %{$option || {}},
                }, $class;
  return $self;
}

sub v {
  my ($self) = @_;
  return $self->{v};
}

sub trigger {
  my ($self) = @_;
  return $self->{trigger};
}

sub parse {
  my ($self, $def_lines) = @_;
  my (%def, %required, %filter, %as, %optional);

  my %mk_closure = %{Data::RuledValidator->_mk_closure};
  # use Tie::IxHash instead of Tie::Hash::Indexed
  #  because Tie::Hash::Indexed claims.
  tie %def, 'Tie::IxHash';
  tie %required, "Tie::IxHash";
  tie %optional, "Tie::IxHash";
#  my($no_required, $no_filter) = (0, 0);

  my $required_name = $self->v->required_alias_name;
  my $optional_name = $self->v->optional_alias_name;

  my $no_required = 0;

  foreach my $def (@$def_lines){
    if ($def =~ /^trigger\s*=\s*(\w+)/) {
      $self->{trigger} = $1;
      next;
    }
    if ($def =~ /^(.+)\s+as\s+(\w+)(?:\s+with\s+(.+))?$/) {
      my ($combination, $as, $with) = ($1, $2, $3);
      $as{$as} = {key => [split /\s+/, $combination], with => (_arg($with))[0]};
      next;
    }
    my $alias = $def =~ s/^\s*(\w+)\s*=\s*// ? $1 : '';
    if($alias and $alias eq $required_name){
      if($def =~ m{^\s*n/a\s*$}){
        $no_required = 1;
        %required = ();
      }elsif(my @keys = grep $_, split /\s*,\s*/, $def){
        @required{@keys} = ();
      }
    }elsif($alias and $alias eq $optional_name){
      if($def =~ m{^\s*n/a\s*$}){
        $no_required = 1;
      }elsif(my @keys = grep $_, split /\s*,\s*/, $def){
        @optional{@keys} = ();
      }
    }elsif($def =~/filter\s+(.+?)\s+with\s+(.+?)\s*$/){
      my($keys, $values) = ($1, $2);
      my @values =  grep $_, split /\s*,\s*/, $values;
      if($def =~ m{^\s*n/a\s*$}){
#        $no_filter = 1;
      }elsif($keys eq '*'){
        $filter{'*'} = \@values;
      }elsif(my @keys = grep $_, split /\s*,\s*/, $keys){
        @filter{@keys} = (\@values) x @keys;
      }
    }else{
      my $filter;
      if($def =~ s{\s+with\s+n/a\s*$}{}){
        $filter = [ 'no_filter' ];
      }elsif($def =~ s/\s+with\s+(.+?)\s*$//){
        $filter = [ grep $_, split /\s*,\s*/, $filter = $1];
      }
      my($key, $op, $cond) = split /\s+/, $def, 3;
      my($closure, $flg) = $mk_closure{$op}
        ? $mk_closure{$op}->($key, $cond, $op, \%required, \%optional)
        : Carp::croak("not defined operator: $op (" . join(", ", keys %mk_closure) . ")");
      $flg ||= 0;
      if($flg & NEED_ALIAS and not $alias){
        Carp::croak("Rule Syntax Error: $op needs alias name.");
      }
      push @{$def{$alias || $key} ||= []}, [$alias, $key, $op, $cond, $closure, $flg, $filter];
    }
  }

  # return(\%def, $no_required ? undef : \%required, $no_filter ? undef : \%filter);
  @{$self}{qw/defs required filter as optional/}
    = (\%def, ($no_required ? undef : \%required), \%filter, \%as, \%optional);
  return $self;
}

1;

=head1 NAME

Data::RuledValidator::Definition - definition parser

=head1 DESCRIPTION

It is internally used in Data::RuledValidator.

=head1 SYNOPSIS

 my $v = Data::RuledValidator->new(...);
 my $def = Data::RuledValidator::Definition->new($v)->parse(\@definition);

=head1 AUTHOR

Ktat, E<lt>ktat@cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2006-2008 by Ktat

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut

