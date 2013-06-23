package Module::Build::XSUtil;
use 5.008005;
use strict;
use warnings;
use Config;
use Module::Build;
our @ISA = qw(Module::Build);

our $VERSION = "0.01";

sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my %args     = @_;

    my $self = $class->SUPER::new(%args);

    unless ( $self->have_c_compiler() ) {
        warn "This distribution requires a C compiler, but it's not available, stopped.\n";
        exit -1;
    }

    # cleanup options
    if ( $^O eq 'cygwin' ) {
        $self->add_to_cleanup('*.stackdump');
    }

    # debugging options
    if ( $self->_xs_debugging() ) {
        if ( $self->_is_msvc() ) {
            $self->_add_extra_compiler_flags('-Zi');
        }
        else {
            $self->_add_extra_compiler_flags(qw/-g -ggdb -g3/);
        }
        $self->_add_extra_compiler_flags('-DXS_ASSERT');
    }

    # c++ options
    if ( $args{needs_compiler_cpp} ) {
        require ExtUtils::CBuilder;
        my $cbuilder = ExtUtils::CBuilder->new( quiet => 1 );
        $cbuilder->have_cplusplus or do {
            warn "This environment does not have a C++ compiler(OS unsupported)\n";
            exit 0;
        };
        if($self->_is_gcc){
            $self->_add_extra_compiler_flags('-xc++');
            $self->_add_extra_linker_flags('-lstdc++');
            $self->_add_extra_compiler_flags('-D_FILE_OFFSET_BITS=64') if $Config::Config{ccflags} =~ /-D_FILE_OFFSET_BITS=64/;
            $self->_add_extra_linker_flags('-lgcc_s') if $^O eq 'netbsd' && !grep{/\-lgcc_s/} @{ $self->extra_linker_flags };
        }
        if($self->_is_msvc){
            $self->add_extra_compiler_flags('-TP -EHsc');
            $self->_add_extra_linker_flags('msvcprt.lib');
        }
    }

    # c99 is required
    if ( $args{needs_compiler_c99} ) {
        require Devel::CheckCompiler;
        Devel::CheckCompiler::check_c99_or_exit();
    }

    # write xshelper.h
    if ( my $xshelper = $args{generate_xshelper_h} ) {
        if ( $xshelper eq '1' ) {    # { xshelper => 1 }
            $xshelper = 'xshelper.h';
        }
        File::Path::mkpath( File::Basename::dirname($xshelper) );
        require Devel::XSHelper;
        Devel::XSHelper::WriteFile($xshelper);
        $self->add_to_cleanup($xshelper);

        #my $safe = quotemeta($xshelper);
        #$builder->_append_maniskip("^$safe\$");
        # generate ppport.h to same directory automatically.
        unless ( defined $args{generate_ppport_h} ) {
            ( my $ppport = $xshelper ) =~ s!xshelper\.h$!ppport\.h!;
            $args{generate_ppport_h} = $ppport;
        }
    }

    if ( my $ppport = $args{generate_ppport_h} ) {
        if ( $ppport eq '1' ) {
            $ppport = 'ppport.h';
        }
        File::Path::mkpath( File::Basename::dirname($ppport) );
        require Devel::PPPort;
        Devel::PPPort::WriteFile($ppport);
        $self->add_to_cleanup($ppport);

        #my $safe = quotemeta($ppport);
        #$builder->_append_maniskip("^$safe\$");
    }
    if ( $args{cc_warnings} ) {
        $self->_add_extra_compiler_flags( $self->_cc_warnings( \%args ) );
    }
    
    return $self;
}

sub auto_require {
  my ($self) = @_;
  my $p = $self->{properties};
 
  if ($self->dist_name ne 'Module-Build-XSUtil'
      and $self->auto_configure_requires)
  {
    if (not exists $p->{configure_requires}{'Module::Build::XSUtil'}) {
      (my $ver = $VERSION) =~ s/^(\d+\.\d\d).*$/$1/; # last major release only
      $self->_add_prereq('configure_requires', 'Module::Build::XSUtil', $ver);
    }
  }
 
  $self->SUPER::auto_require();
 
  return;
}

sub _xs_debugging {
    my ($self) = @_;
    return $ENV{XS_DEBUG} || $self->args('g');
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
    my ( $self, $args ) = @_;

    my @flags;
    if ( $self->_is_gcc() ) {
        push @flags, qw(-Wall);

        my $gccversion = $self->_gcc_version();
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
    elsif ( $self->_is_msvc() ) {
        push @flags, qw(-W3);
    }
    else {

        # TODO: support other compilers
    }

    return @flags;
}

sub _add_extra_compiler_flags {
    my ( $self, @flags ) = @_;
    $self->extra_compiler_flags( @{ $self->extra_compiler_flags }, @flags );
}

sub _add_extra_linker_flags {
    my ( $self, @flags ) = @_;
    $self->extra_linker_flags( @{ $self->extra_linker_flags }, @flags );
}

1;
__END__
 
=encoding utf-8
 
=head1 NAME
 
Module::Build::XSUtil - A Module::Build class for building XS modules
 
=head1 SYNOPSIS

Use in your Build.PL

    use strict;
    use warnings;
    use Module::Build::XSUtil;
    
    my $builder = Module::Build::XSUtil->new(
        dist_name            => 'Your-XS-Module',
        license              => 'perl',
        dist_author          => 'Your Name <yourname@example.com>',
        dist_version_from    => 'lib/Your/XS/Module',
        generate_ppport_h    => 'lib/Your/XS/ppport.h',
        generate_xs_helper_h => 'lib/Your/XS/xshelper.h',
        needs_compiler_c99   => 1,
    );
    
    $builder->create_build_script();

Use in custom builder module.

    pakcage builder::MyBuilder;
    use strict;
    use warnings;
    use base 'Module::Build::XSUtil';
    
    sub new {
        my ($class, %args) = @_;
        my $self = $class->SUPER::new(
            %args,
            generate_ppport_h    => 'lib/Your/XS/ppport.h',
            generate_xs_helper_h => 'lib/Your/XS/xshelper.h',
            needs_compiler_c99   => 1,
        );
        return $self;
    }
    
    1;


=head1 DESCRIPTION
 
Module::Build::XSUtil is subclass of L<Module::Build> for support building XS modules.

This is a list of a new parameters in the Module::Build::new method:

=over

=item needs_compiler_c99

This option checks C99 compiler's availability. If it's not available, Build.PL exits by 0.

=item needs_compiler_cpp

This option checks C++ compiler's availability. If it's not available, Build.PL exits by 0.
In addition, append 'extra_compiler_flags' and 'extra_linker_flags' for C++.

=item generate_ppport_h

Genereate ppport.h by L<Devel::PPPort>.

=item generate_xshelper_h

Genereate xshelper.h by L<Devel::XSHelper>.

=item cc_warnings

Enable compiler warnings flag. It is enable by default. 

=back

=head1 SEE ALOS

L<Module::Install::XSUtil>

=head1 LICENSE
 
Copyright (C) Hideaki Ohno.
 
This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
 
=head1 AUTHOR
 
Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>
 
=cut
