package Data::RuledValidator::Plugin::Date;

Data::RuledValidator->add_condition_operator
  (
   'date' => sub{
     my ($self, $v) = @_;
     my ($y, $m, $d);
     if ($v =~ /^(\d{4})(\d{2})(\d{2})$/) {
       ($y, $m, $d) = ($1, $2, $3);
     } elsif ($v =~ m{^(\d{4})([\-/])(\d{1,2})\2(\d{1,2})$}) {
       ($y, $m, $d) = ($1, $3, $4);
     } else {
       return ();
     }
   },
  );

1;
__END__

=pod

=head1 NAME

Data::RuledValidator::Plugin::Date - variety date validation

=head1 DESCRIPTION

 # date format is YYYY/MM/DD or YYYYMMDD
 name is date

=head1 Description

=head1 Synopsys

=head1 Author

Ktat, E<lt>ktat@cpan.orgE<gt>

=head1 Copyright

Copyright 2006-2010 by Ktat

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
