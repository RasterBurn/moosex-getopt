#!/usr/bin/env perl

use strict;
use warnings;

use Test::Moose;
use Test::More;
use Test::Exception;

if ( !eval { require MooseX::Traits } )
{
    plan skip_all => 'Test requires MooseX::Traits';
}
elsif ( $MooseX::Traits::VERSION < 0.09 ) {
    plan skip_all => 'Test requires MooseX::Traits >= 0.09';
}
else
{
    plan tests => 9;
}

{
    package My::Role::A;
    use Moose::Role;
}

{
    package My::Role::B;
    use Moose::Role;
}

{
    package My::Role::FromConfig::A;
    use Moose::Role;
}

{
    package My::Role::FromConfig::B;
    use Moose::Role;
}

{
    package App;

    use Moose;
    with 'MooseX::Getopt::WithTraits';
}

{
  local @ARGV = qw( );

  lives_ok { App->new_with_options } '... no traits provided';
}

{
  local @ARGV = qw( --traits My::Role::A );

  my $app = App->new_with_options;
  does_ok($app, 'My::Role::A', '... role A from command line');
}

{
  local @ARGV = qw( --traits My::Role::A --traits My::Role::B );

  my $app = App->new_with_options;
  does_ok($app, 'My::Role::A', '... role A from command line (multi-use)');
  does_ok($app, 'My::Role::B', '... role B from command line (multi-use)');
}

SKIP: {
  skip 'Test requires MooseX::ConfigFromFile', 5 unless eval { require MooseX::ConfigFromFile };

  {
      package App::WithConfig;
      use Moose;
      with 'MooseX::ConfigFromFile', 'MooseX::Getopt::WithTraits';

      sub get_config_from_file {
          my ( $class, $file ) = @_;

          my %config = (
              traits => [qw/My::Role::FromConfig::A My::Role::FromConfig::B/],
          );

          return \%config;
      }
  }

  {
    local @ARGV = qw( --configfile /notused );

    my $app = App::WithConfig->new_with_options;
    does_ok($app, 'My::Role::FromConfig::A', '... config provided role A');
    does_ok($app, 'My::Role::FromConfig::B', '... config provided role B');
  }

  {
    local @ARGV = qw( --configfile /notused --traits My::Role::B);

    my $app = App::WithConfig->new_with_options;
    does_ok($app, 'My::Role::B', '... role B from commandline');
    ok(! $app->does('My::Role::FromConfig::A'), '... config provided role A overridden');
    ok(! $app->does('My::Role::FromConfig::B'), '... config provided role B overridden');
  }
};
