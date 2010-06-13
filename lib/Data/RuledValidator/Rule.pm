package Data::RuledValidator::Rule;

use strict;
use Data::RuledValidator::Util;
use Data::RuledValidator::Definition ();
use File::Slurp ();
use Carp ();
use warnings qw/all/;
use base qw/Class::Accessor::Fast/;

__PACKAGE__->mk_accessors(qw/t bare_rule id_key id_method v/);

my $COND_OP    = \%Data::RuledValidator::COND_OP;
my $MK_CLOSURE = \%Data::RuledValidator::MK_CLOSURE;
my %RULES;

sub rule {
  my ($self, $v, $rule_file) = @_;
  my $bare_rule = $v->rule_path . ($rule_file || $v->rule);

  Carp::croak("need rule name for new of " . __PACKAGE__) unless $bare_rule;

  if (exists $RULES{$bare_rule} and $RULES{$bare_rule}->is_latest) {
    return $RULES{$bare_rule};
  } else {
    return $RULES{$bare_rule} = $self->new($v);
  }
}

sub new {
  my ($class, $v) = @_;
  my $rule = $v->rule;
  tie my %defs, "Tie::IxHash";
  my $self = bless
    {
     defs      => \%defs,
     required  => {},
     optional  => {},
     filter    => {},
     as        => {},
     trigger   => {},
     t         => 0,
     id_key    => "",
     id_method => "",
     regex_group => [],
     v         => $v,
    }, $class;
  $self->bare_rule($v->rule_path . $rule);
  $self->parse_rule;
  return $self;
}

sub regex_group {
  my ($self, $id_name) = @_;
  if (@_ == 2) {
    return push @{$self->{regex_group}}, $id_name;
  } else {
    return @{$self->{regex_group}};
  }
}

sub is_latest {
  my ($self) = @_;
  if ($self->t < (my $t = $self->modified_time)) {
    $self->t($t);
    return 0;
  }
  return 1;
}

sub modified_time {
  my ($self) = @_;
  return((stat $self->bare_rule)[9]);
}

# parse_rule file / rule scalarref
sub parse_rule {
  my ($self) = @_;
  my $bare_rule = $self->bare_rule;
  my $rules = {};
  my $id_name = 'GLOBAL';

  my @rule;
  if (ref $bare_rule eq 'SCALAR') {
    @rule = split/[\n\r]+/, $$bare_rule;
  } else {
    $self->t((stat $bare_rule)[9]);
    @rule = File::Slurp::read_file($bare_rule)
      or Carp::croak "cannot open $bare_rule";
  }

  foreach (@rule) {
    chomp;
    my $line = $_;
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;
    next unless $line and $line !~ /^\s*#/;

    my $is_regex = 0;

    if ($line =~ s/^;+path;+// or $line =~ s/path\{/\{/) {
      $is_regex = 1;
      $line =~ s{/+$}{};
      $line = ';^'. $line . '/?$';
    } elsif ($line =~ s/^;+r;+/;/ or $line =~ s/r\{/\{/) {
      $is_regex = 1;
    }

    if ($line =~s/^ID_KEY\s+//i) {
      $self->id_key($line);
    } elsif ($line =~s/^ID_METHOD\s+//i) {
      my @method = grep $_, split /\s*,\s*/, $line;
      $self->id_method(\@method);
    } elsif ($line =~/^\s*\{\s*([^\s]+)\s*\}\s*$/ or $line =~m|^\s*;+\s*([^\s]+)\s*$|) {
      # page name
      $id_name = $1;
      $rules->{$id_name} ||= [];
      $self->regex_group($id_name) if $is_regex;
    } else {
      # rule
      push @{$rules->{$id_name}}, $line;
    }
  }
  $self->{defs}->{GLOBAL} = Data::RuledValidator::Definition->new($self->v)->parse($rules->{GLOBAL});

  my $global_rule = Clone::clone($self->global_group);

  while (my($id_name, $defs) = each %$rules){
    next if $id_name eq 'GLOBAL';

    my $o_group_rule = Data::RuledValidator::Definition->new($self->v)->parse($defs);
    my ($required, $filter, $as, $optional, $trigger) = map { $o_group_rule->$_ } qw/required filter as optional trigger/;
    my $global_is_na;
    ($self->{defs}->{$id_name}->{defs}, $global_is_na) = $self->_merge_rule($global_rule->defs, $o_group_rule->defs);

    if (defined $required) {
      $self->{defs}->{$id_name}->{required} = %$required ? $required : $global_is_na      ? {} : $global_rule->required;
    }
    if (defined $optional) {
      $self->{defs}->{$id_name}->{optional} = %$optional ? $optional : $global_is_na      ? {} : $global_rule->optional;
    }
    if (defined $filter) {
      $self->{defs}->{$id_name}->{filter}   = $self->_merge_filter($filter, $global_is_na ? {} : $global_rule->filter);
    }
    if (defined $as) {
      $self->{defs}->{$id_name}->{as}       = $self->_merge_as($as, $global_is_na         ? {} : $global_rule->as);
    }
    if (defined $trigger) {
      $self->{defs}->{$id_name}->{trigger}  = $trigger    ? $global_is_na ? '' : $trigger : $global_rule->trigger;
    }
    $self->{defs}->{$id_name} = bless $self->{defs}->{$id_name}, 'Data::RuledValidator::Definition';
  }
  return $self;
}

sub _merge_rule {
  my ($self, $global_rule, $rule) = @_;

  my %has;
  my %na;
  tie my %new_rule, "Tie::Hash::Indexed";
  tie my %rule,     "Tie::Hash::Indexed";
  my $global_is_na = 0;

  if (my $rule_global = $rule->{GLOBAL}) {
  LOOP:
    foreach my $def (@$rule_global) {
      if (    ref $def  eq 'ARRAY'
         and $def->[1] eq 'GLOBAL'
         and $def->[2] eq 'is'
         and $def->[3] eq 'n/a'
        ) {
        %rule = %$rule;
        $global_is_na = 1;
        last LOOP;
      }
    }
  }

  unless ($global_is_na) {
    foreach my $k (keys %$global_rule) {
      @{$rule{$k} ||= []} = @{Clone::clone $global_rule->{$k}};
    }
    foreach my $k (keys %$rule) {
      my $first_rule = $rule->{$k}->[0];
      if (
          defined $first_rule->[2] and $first_rule->[2] eq 'is' and
          defined $first_rule->[3] and $first_rule->[3] eq 'n/a'
         ) {
        $rule{$k} = [ @{$rule->{$k}}[1 .. $#{$rule->{$k}}] ];
      } else {
        push @{$rule{$k} ||= []}, @{$rule->{$k} || []};
      }
    }
  }

  foreach my $alias (keys %rule) {
    my @new_rule;
    foreach my $def (@{$rule{$alias}}) {
      next unless $def->[2];
      my($alias, $key, $op, $cond, $closure, $flg) = @$def;
      $alias = $alias || $key;
      if (exists $MK_CLOSURE->{$op}) {
        if ($cond eq 'n/a') {
          $na{$alias}->{$op} = 1;
          next;
        }
        my $result_key = ($flg & USE_COND) ? $op . '_' . $cond : $op;
        if (not $na{$alias}->{$result_key} and not $has{$alias}->{$result_key}++) {
          push @new_rule, $def
        } else {
          # warn Data::Dumper::Dumper $def;
        }
      } else {
        push @new_rule, $def;
      }
    }
    $new_rule{$alias} = \@new_rule;
  }

  return \%new_rule, $global_is_na;
}

sub _merge_filter {
  my ($self, $filter, $global_filter) = @_;
  while (my($k, $v) = each %$global_filter) {
    $filter->{$k} = $v if not exists $filter->{$k};
  }
  return $filter;
}

sub _merge_as {
  my ($self, $as, $global_as) = @_;
  while (my($k, $v) = each %$global_as) {
    $as->{$k} = $v if not exists $as->{$k};
  }
  return $as;
}

sub group {
  my ($self, $group) = @_;
  Carp::croak "need group name" unless $group;
  if (exists $self->{defs}->{$group}) {
    return $self->{defs}->{$group};
  } else {
    foreach my $rg ($self->regex_group) {
      return $self->{defs}->{$rg}  if $group =~/$rg/;
    }
  }
}

sub global_group {
  my ($self) = @_;
  return $self->{defs}->{GLOBAL};
}

sub _cond_op { my $self = shift; return @_ ? $COND_OP->{shift()} : keys %$COND_OP };

sub add_operator {
  my ($self, %op_sub) = @_;
  while (my($op, $sub) = each %op_sub) {
    if ($MK_CLOSURE->{$op}) {
      Carp::croak "$op has already defined as normal operator.";
    }
    $MK_CLOSURE->{$op} = $sub;
  }
}

sub add_condition {
  my ($self, %op_sub) = @_;
  while (my($op, $sub) = each %op_sub) {
    if (defined $COND_OP->{$op}) {
      Carp::croak "$op is already defined as condition operator.";
    }
    $COND_OP->{$op} = $sub;
  }
}

sub add_condition_operator { my $self = shift; $self->add_condition(@_); }

sub create_alias_operator {
  my ($self, $alias, $original) = @_;
  if ($MK_CLOSURE->{$alias}) {
    Carp::croak "$alias has already defined as context/normal operator.";
  } elsif (not $MK_CLOSURE->{$original}) {
    Carp::croak "$original is not defined as context/normal operator.";
  }
  $MK_CLOSURE->{$alias} = $MK_CLOSURE->{$original};
}

sub create_alias_cond_operator {
  my ($self, $alias, $original) = @_;
  if ($COND_OP->{$alias}++) {
    Carp::croak "$alias has already defined as condition operator.";
  }
  $COND_OP->{$alias} = $COND_OP->{$original};
}

1;

=head1 NAME

Data::RuledValidator::Rule - rule file parser/manager

=head1 DESCRIPTION

It is internally used in Data::RuledValidator.

=head1 SYNOPSIS

 my $v = Data::RuledValidator->new(...);
 my $rule = Data::RuledValidator->rule($v);

=head1 AUTHOR

Ktat, E<lt>ktat@cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2006-2008 by Ktat

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut

