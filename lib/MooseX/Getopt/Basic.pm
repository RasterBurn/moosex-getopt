package MooseX::Getopt::Basic;
# ABSTRACT: MooseX::Getopt::Basic - role to implement the Getopt::Long functionality

use Moose::Role;

use MooseX::Getopt::OptionTypeMap;
use MooseX::Getopt::Meta::Attribute;
use MooseX::Getopt::Meta::Attribute::NoGetopt;
use Carp ();

use Getopt::Long 2.37 ();

with 'MooseX::Getopt::WithConfigFile';

has ARGV       => (is => 'rw', isa => 'ArrayRef', metaclass => "NoGetopt");
has extra_argv => (is => 'rw', isa => 'ArrayRef', metaclass => "NoGetopt");

sub new_with_options {
    my ($class, @params) = @_;

    my $config_from_file = $class->_mx_getopt_config_from_file;

    my $constructor_params = ( @params == 1 ? $params[0] : {@params} );

    Carp::croak("Single parameters to new_with_options() must be a HASH ref")
        unless ref($constructor_params) eq 'HASH';

    my %processed = $class->_parse_argv(
        options => [
            $class->_attrs_to_options( $config_from_file )
        ],
        params => $constructor_params,
    );

    my $params = $config_from_file ? { %$config_from_file, %{$processed{params}} } : $processed{params};

    # did the user request usage information?
    if ( $processed{usage} and $params->{help_flag} )
    {
        $class->_getopt_full_usage($processed{usage});
    }

    $class->new(
        ARGV       => $processed{argv_copy},
        extra_argv => $processed{argv},
        ( $processed{usage} ? ( usage => $processed{usage} ) : () ),
        %$constructor_params, # explicit params to ->new
        %$params, # params from CLI
    );
}

sub _mx_getopt_config_from_file {
    my $class = shift;
    return {};
}

sub _getopt_spec { shift->_traditional_spec(@_); }

sub _parse_argv {
    my ( $class, %params ) = @_;

    local @ARGV = @{ $params{params}{argv} || \@ARGV };

    my ( $opt_spec, $name_to_init_arg ) = $class->_getopt_spec(%params);

    # Get a clean copy of the original @ARGV
    my $argv_copy = [ @ARGV ];

    my @warnings;
    my ( $parsed_options, $usage ) = eval {
        local $SIG{__WARN__} = sub { push @warnings, @_ };

        return $class->_getopt_get_options(\%params, $opt_spec);
    };

    $class->_getopt_spec_warnings(@warnings) if @warnings;
    $class->_getopt_spec_exception(\@warnings, $@) if $@;

    # Get a copy of the Getopt::Long-mangled @ARGV
    my $argv_mangled = [ @ARGV ];

    my %constructor_args = (
        map {
            $name_to_init_arg->{$_} => $parsed_options->{$_}
        } keys %$parsed_options,
    );

    return (
        params    => \%constructor_args,
        argv_copy => $argv_copy,
        argv      => $argv_mangled,
        ( defined($usage) ? ( usage => $usage ) : () ),
    );
}

sub _getopt_get_options {
    my ($class, $params, $opt_spec) = @_;
    my %options;
    Getopt::Long::GetOptions(\%options, @$opt_spec);
    return ( \%options, undef );
}

sub _getopt_spec_warnings { }

sub _getopt_spec_exception {
    my ($self, $warnings, $exception) = @_;
    die @$warnings, $exception;
}

sub _getopt_full_usage {
    my ($self, $usage) = @_;
    $usage->die;
}

sub _usage_format {
    return "usage: %c %o";
}

sub _traditional_spec {
    my ( $class, %params ) = @_;

    my ( @options, %name_to_init_arg, %options );

    foreach my $opt ( @{ $params{options} } ) {
        push @options, $opt->{opt_string};

        my $identifier = $opt->{name};
        $identifier =~ s/\W/_/g; # Getopt::Long does this to all option names

        $name_to_init_arg{$identifier} = $opt->{init_arg};
    }

    return ( \@options, \%name_to_init_arg );
}

sub _compute_getopt_attrs {
    my $class = shift;
    sort { $a->insertion_order <=> $b->insertion_order }
    grep {
        $_->does("MooseX::Getopt::Meta::Attribute::Trait")
            or
        $_->name !~ /^_/
    } grep {
        !$_->does('MooseX::Getopt::Meta::Attribute::Trait::NoGetopt')
    } $class->meta->get_all_attributes
}

sub _get_cmd_flags_for_attr {
    my ( $class, $attr ) = @_;

    my $flag = $attr->name;

    my @aliases;

    if ($attr->does('MooseX::Getopt::Meta::Attribute::Trait')) {
        $flag = $attr->cmd_flag if $attr->has_cmd_flag;
        @aliases = @{ $attr->cmd_aliases } if $attr->has_cmd_aliases;
    }

    return ( $flag, @aliases );
}

sub _attrs_to_options {
    my $class = shift;
    my $config_from_file = $class->_mx_getopt_config_from_file;

    my @options;

    foreach my $attr ($class->_compute_getopt_attrs) {
        my ( $flag, @aliases ) = $class->_get_cmd_flags_for_attr($attr);

        my $opt_string = join(q{|}, $flag, @aliases);

        if ($attr->name eq 'configfile') {
            $opt_string .= '=s';
        }
        elsif ($attr->has_type_constraint) {
            my $type = $attr->type_constraint;
            if (MooseX::Getopt::OptionTypeMap->has_option_type($type)) {
                $opt_string .= MooseX::Getopt::OptionTypeMap->get_option_type($type)
            }
        }

        push @options, {
            name       => $flag,
            init_arg   => $attr->init_arg,
            opt_string => $opt_string,
            required   => $attr->is_required && !$attr->has_default && !$attr->has_builder && !exists $config_from_file->{$attr->name},
            # NOTE:
            # this "feature" was breaking because
            # Getopt::Long::Descriptive would return
            # the default value as if it was a command
            # line flag, which would then override the
            # one passed into a constructor.
            # See 100_gld_default_bug.t for an example
            # - SL
            #( ( $attr->has_default && ( $attr->is_default_a_coderef xor $attr->is_lazy ) ) ? ( default => $attr->default({}) ) : () ),
            ( $attr->has_documentation ? ( doc => $attr->documentation ) : () ),
        }
    }

    return @options;
}

no Moose::Role;
1;

=head1 SYNOPSIS

  ## In your class
  package My::App;
  use Moose;

  with 'MooseX::Getopt::Basic';

  has 'out' => (is => 'rw', isa => 'Str', required => 1);
  has 'in'  => (is => 'rw', isa => 'Str', required => 1);

  # ... rest of the class here

  ## in your script
  #!/usr/bin/perl

  use My::App;

  my $app = My::App->new_with_options();
  # ... rest of the script here

  ## on the command line
  % perl my_app_script.pl --in file.input --out file.dump

=head1 DESCRIPTION

This is like L<MooseX::Getopt> and can be used instead except that it
doesn't make use of L<Getopt::Long::Descriptive> (or "GLD" for short).

=method new_with_options

See L<MooseX::Getopt/new_with_options>.

=cut
