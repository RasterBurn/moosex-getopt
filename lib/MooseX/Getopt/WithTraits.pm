package MooseX::Getopt::WithTraits;
# ABSTRACT: A Moose role for processing command line options using MooseX::Traits

# For classes that do "MooseX::Traits", provide a --traits parameter and compose
# those roles before the rest of the args are processed.

use Moose::Role 0.56;
use MooseX::Traits 0.09; # 0.09 is required for "with_traits" method
use MooseX::Getopt::Meta::Attribute;
use MooseX::Getopt::Meta::Attribute::NoGetopt;
use Getopt::Long;

with 'MooseX::Traits', 'MooseX::Getopt';

around _mx_getopt_traits => sub {
    my $next   = shift;
    my $class  = shift;

    # get configfile (and other) traits first
    my @traits = $class->$next(@_);

    # now override them with the command line

    my $cmdline_traits;

    my $opt_parser = Getopt::Long::Parser->new( config => [ qw( no_auto_help pass_through ) ] );
    $opt_parser->getoptions( "traits=s@" => \$cmdline_traits);
   
    @traits = @$cmdline_traits if defined $cmdline_traits;

    return @traits;
};

around '_apply_traits' => sub {
    my $next = shift;
    my $class = shift;

    $class = $class->$next();

    my @traits = $class->_mx_getopt_traits;

    $class = $class->with_traits(@traits) if scalar @traits;

    return $class;
};

no Moose::Role;

1;

=head1 SYNOPSIS

  ## In your class
  package My::App;
  use Moose;

  with 'MooseX::Traits', 'MooseX::Getopt::WithTraits';

  has 'out' => (is => 'rw', isa => 'Str', required => 1);
  has 'in'  => (is => 'rw', isa => 'Str', required => 1);

  # ... rest of the class here

  ## In your role
  package My::Role;
  use Moose::Role;

  has 'filter' => (is => 'rw', isa => 'Str', required => 1);

  # ... rest of the role here

  ## in your script
  #!/usr/bin/perl

  use My::App;

  my $app = My::App->new_with_options();
  # ... rest of the script here

  ## on the command line
  % perl my_app_script.pl -traits My::Role -in file.input -out file.dump -filter foo

=head1 DESCRIPTION

This role adds in support for MooseX::Traits. If your class uses
L<MooseX::Traits> it will apply the roles specified by the C<--traits> option
before the rest of the options are processed.  Attributes provided by those
roles will be treated as commandline options just as those in the base class.

If MooseX::ConfigFromFile is also used, then traits are taken from the config
file, then overridden by command line options.

=cut
