package Module::Build::XSHelper;
use 5.008005;
use strict;
use warnings;
use Config;
use Carp ();
use base 'Exporter';

our @EXPORT = qw(setup_xs_helper);

our $VERSION = "0.01";

sub import {
    my ($class, %args) = @_;
    
    require Module::Build;    
    my $orig = Module::Build->can('ACTION_build');
    if ($orig) {
        no strict 'refs';
        no warnings 'redefine', 'once';
        *Module::Build::ACTION_build = sub {
            my ($builder) = @_;

            unless ( $builder->have_c_compiler() ) {
                warn "This distribution requires a C compiler, but it's not available, stopped.\n";
                exit -1;
            }

            # cleanup options
            if ( $^O eq 'cygwin' ) {
                $builder->add_to_cleanup('*.stackdump');
            }

            # debugging options
            if ( $class->_xs_debugging($builder) ) {
                if ( $class->_is_msvc() ) {
                    $class->_add_extra_compiler_flags( $builder, '-Zi' );
                }
                else {
                    $class->_add_extra_compiler_flags( $builder, qw/-g -ggdb -g3/ );
                }
                $class->_add_extra_compiler_flags( $builder, '-DXS_ASSERT' );
            }

            # c++ options
            if ( $args{'c++'} ) {
                require ExtUtils::CBuilder;
                my $cbuilder = ExtUtils::CBuilder->new( quiet => 1 );
                $cbuilder->have_cplusplus or do {
                    warn "This environment does not have a C++ compiler(OS unsupported)\n";
                    exit 0;
                };
            }

            # c99 is required
            if ( $args{c99} ) {
                require Devel::CheckCompiler;
                Devel::CheckCompiler::check_c99_or_exit();
            }

            # CheckLib
            if ( my $chklib = $args{checklib} ) {
                my @chk;
                if(ref($chklib) && ref($chklib) eq 'ARRAY'){
                    @chk = @$chklib;
                }else{
                    push @chk, $chklib;
                }
                require Devel::CheckLib;
                for my $c (@chk) {
                    my %opts;
                    for my $key (qw/lib header incpath libpath header function/) {
                        if ( exists $c->{$key} ) {
                            $opts{$key} = $c->{$key};
                        }
                    }
                    Devel::CheckLib::check_lib_or_exit(%opts);
                }

            }

            # write xshelper.h
            if ( my $xshelper = $args{xshelper} ) {
                if ( $xshelper eq '1' ) {    # { xshelper => 1 }
                    $xshelper = 'xshelper.h';
                }
                File::Path::mkpath( File::Basename::dirname($xshelper) );
                require Devel::XSHelper;
                Devel::XSHelper::WriteFile($xshelper);

                # generate ppport.h to same directory automatically.
                unless ( defined $args{ppport} ) {
                    ( my $ppport = $xshelper ) =~ s!xshelper\.h$!ppport\.h!;
                    $args{ppport} = $ppport;
                }
            }

            if ( my $ppport = $args{ppport} ) {
                require Devel::PPPort;
                if ( $ppport eq '1' ) {
                    Devel::PPPort::WriteFile();
                }
                else {
                    Devel::PPPort::WriteFile($ppport);
                }
            }
            if ( $args{cc_warnings} ) {
                $class->_add_extra_compiler_flags( $builder, $class->_cc_warnings( \%args ) );
            }
            $orig->(@_);
        };
    }
}

sub _xs_debugging {
    my ($class, $builder) = @_;
    return $ENV{XS_DEBUG} || $builder->args('g');
}

sub _is_gcc {
    return $Config{gccversion};
}

# Microsoft Visual C++ Compiler (cl.exe)
sub _is_msvc {
    return $Config{cc} =~ /\A cl \b /xmsi;
}

sub _gcc_version {
    my $res = `$Config{cc} --version`;
    my ($version) = $res =~ /\(GCC\) ([0-9.]+)/;
    no warnings 'numeric', 'uninitialized';
    return sprintf '%g', $version;
}

sub _cc_warnings {
    my ( $class, $args ) = @_;

    my @flags;
    if ( $class->_is_gcc() ) {
        push @flags, qw(-Wall);

        my $gccversion = $class->_gcc_version();
        if ( $gccversion >= 4.0 ) {
            push @flags, qw(-Wextra);
            if ( !( $args->{c99} or $args->{'c++'} ) ) {

                # Note: MSVC++ doesn't support C99,
                # so -Wdeclaration-after-statement helps
                # ensure C89 specs.
                push @flags, qw(-Wdeclaration-after-statement);
            }
            if ( $gccversion >= 4.1 && !$args->{'c++'} ) {
                push @flags, qw(-Wc++-compat);
            }
        }
        else {
            push @flags, qw(-W -Wno-comment);
        }
    }
    elsif ( $class->_is_msvc() ) {
        push @flags, qw(-W3);
    }
    else {

        # TODO: support other compilers
    }

    return @flags;
}

sub _add_extra_compiler_flags {
    my ( $class, $builder, @flags ) = @_;
    $builder->extra_compiler_flags( @{ $builder->extra_compiler_flags }, @flags );
}

1;
__END__
 
=encoding utf-8
 
=head1 NAME
 
Module::Build::XSHelper - It's new $module
 
=head1 SYNOPSIS

    package builder::MyBuilder;
    use Module::Build;
    our @ISA = qw(Module::Build);
    use Module::Build::XSHelper (
        ppport => 1,
        c99 => 1,
        checklib => [
            {
                lib => 'crypto'
            },
        ],
    );
    
    1;
    
    
 
=head1 DESCRIPTION
 
Module::Build::XSHelper is ...
 
=head1 LICENSE
 
Copyright (C) Hideaki Ohno.
 
This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
 
=head1 AUTHOR
 
Hideaki Ohno E<lt>E<gt>
 
=cut
