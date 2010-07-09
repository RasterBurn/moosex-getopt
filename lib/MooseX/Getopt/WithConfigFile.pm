package MooseX::Getopt::WithConfigFile;
# ABSTRACT: A Moose role for processing command line options using MooseX::ConfigFromFile

use Moose::Role 0.56;
use Carp ();

my $_slot_mx_getopt_config_from_file;

before 'new_with_options' => sub {

    # If new_with_options is called multiple times,
    # reset the slot.

    undef $_slot_mx_getopt_config_from_file;
};

around _mx_getopt_config_from_file => sub {
    my $next  = shift;
    my $class = shift;

    # If we've already done the work to get the config,
    # don't do it again!

    my $config_from_file = $_slot_mx_getopt_config_from_file;
    return $config_from_file if defined $config_from_file;

    if($class->meta->does_role('MooseX::ConfigFromFile')) {
        local @ARGV = @ARGV;

        # just get the configfile arg now; the rest of the args will be
        # fetched later
        my $configfile;
        my $opt_parser = Getopt::Long::Parser->new( config => [ qw( no_auto_help pass_through ) ] );
        $opt_parser->getoptions( "configfile=s" => \$configfile );

        if(!defined $configfile) {
            my $cfmeta = $class->meta->find_attribute_by_name('configfile');
            $configfile = $cfmeta->default if $cfmeta->has_default;
            if (ref $configfile eq 'CODE') {
                # not sure theres a lot you can do with the class and may break some assumptions
                # warn?
                $configfile = &$configfile($class);
            }
            if (defined $configfile) {
                $config_from_file = eval {
                    $class->get_config_from_file($configfile);
                };
                if ($@) {
                    die $@ unless $@ =~ /Specified configfile '\Q$configfile\E' does not exist/;
                }
            }
        }
        else {
            $config_from_file = $class->get_config_from_file($configfile);
        }
    }

    # slot must be defined or else we'll redo this work:
    $config_from_file = defined $config_from_file ? $config_from_file : {};
    $_slot_mx_getopt_config_from_file = $config_from_file;

    return $config_from_file;
};

#
# Add "traits" from config file to our object.
# This must be called before the _mx_getopt_traits in
# MooseX::Getopt::WithTraits or else the overriding doesn't work!
#
around _mx_getopt_traits => sub {
    my $next   = shift;
    my $class  = shift;
    my @traits = @_;

    my $config_from_file = $class->_mx_getopt_config_from_file;
    my $traits_from_config_file = $config_from_file->{traits};

    if (defined $traits_from_config_file) {
      Carp::croak("traits parameter in config file must be an ARRAY ref") unless ref($traits_from_config_file) eq 'ARRAY';
      @traits = @$traits_from_config_file;
    }

    return $class->$next(@traits);
};

no Moose::Role;

1;

=head1 DESCRIPTION

This role adds in support for MooseX::ConfigFromFile.  This is automatically
consumed by C<MooseX::Getopt::Basic>, but factoring it out into its own role
provides the ability to wrap it and other methods.

=cut
