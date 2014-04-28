use Test::More;
use Config;
use File::Spec::Functions;
use Cwd qw( abs_path );
use IPC::Open3;

my $perl = $Config{perlpath};
my @perl = ($perl, map { "-I".abs_path($_) } @INC);

chdir catdir(qw/eg Foo/);

run_cmd(1, @perl, "Build.PL");
run_cmd(1, @perl, "Build");
run_cmd(1, @perl, "Build", 'test');
run_cmd(1, @perl, "Build", 'distclean');

done_testing;

##############################

sub run_cmd {
  my ($should_pass, @cmd) = @_;
  my $pid = open3(my ($in, $out, undef), "@cmd");
  last if wait == -1;
  ok ( ($should_pass && ! $?) || (!$should_pass && $?), ($should_pass ? "passed " : "failed ") . $cmd[-1] ) or do {
    read($out, my $error, 9999) or die "could not read from file: $!";
    diag $error;
  }
}
__END__
