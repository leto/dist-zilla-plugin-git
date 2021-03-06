#!perl

use strict;
use warnings;

use Dist::Zilla     1.093250;
use Test::DZil qw{ Builder simple_ini };
use File::Temp qw{ tempdir };
use File::pushd qw{ pushd };
use Git::Wrapper;
use Test::More 0.88 tests => 42; # done_testing
use Test::Fatal qw( lives_ok );

use t::Util qw( throws_ok );

# Mock HOME to avoid ~/.gitexcludes from causing problems
$ENV{HOME} = tempdir( CLEANUP => 1 );

my ($zilla, $git, $pushd);

sub new_tzil
{
  undef $pushd;             # Restore original directory, if necessary

  # build fake repository
  $zilla = Builder->from_config(
    { dist_root => 'corpus/check' },
    {
      add_files => {
        'source/dist.ini' => simple_ini(
          [ 'Git::Check' => { @_ } ],
          'FakeRelease',
        ),
        'source/.gitignore' => "DZT-Sample-*\n",
      },
    },
  );

  $pushd = pushd($zilla->tempdir->subdir('source'));
  print "# ";                   # Comment output of git init
  system "git init";
  $git   = Git::Wrapper->new('.');
  $git->config( 'user.name'  => 'dzp-git test' );
  $git->config( 'user.email' => 'dzp-git@test' );

  # create initial commit
  #   Don't use --force, because only -f works before git 1.5.6
  $git->add( -f => '.gitignore');
  $git->commit( { message=>'ignore file for git' } );
} # end new_tzil

#---------------------------------------------------------------------
# Test with default config:

new_tzil();

# untracked files
throws_ok { $zilla->release } qr/untracked files/, 'untracked files';
our_messages_are(<<'', 'lists untracked files');
[Git::Check] branch master has some untracked files:
[Git::Check] 	Changes
[Git::Check] 	dist.ini
[Git::Check] 	foobar

# index not clean
$git->add( qw{ dist.ini Changes foobar } );
throws_ok { $zilla->release } qr/some changes staged/, 'index not clean';
our_messages_are(<<'', 'lists staged files');
[Git::Check] branch master has some changes staged for commit:
[Git::Check] 	A	Changes
[Git::Check] 	A	dist.ini
[Git::Check] 	A	foobar

$git->commit( { message => 'initial commit' } );

# modified files
append_to_file('foobar', 'Foo-*');
throws_ok { $zilla->release } qr/uncommitted files/, 'uncommitted files';
our_messages_are(<<'', 'lists uncommitted files');
[Git::Check] branch master has some uncommitted files:
[Git::Check] 	foobar

$git->checkout( 'foobar' );

# changelog and dist.ini can be modified
append_to_file('Changes',  "\n");
append_to_file('dist.ini', "\n");
lives_ok { $zilla->release } 'Changes and dist.ini can be modified';
our_messages_are(<<'', 'reports master in clean state');
[Git::Check] branch master is in a clean state

# ensure dist.ini does not match dist_ini
append_to_file('dist_ini', 'Hello');
$git->add( qw{ dist_ini } );
$git->commit( { message => 'add dist_ini' } );
append_to_file('dist_ini', 'World');

throws_ok { $zilla->release } qr/uncommitted files/,
    'dist_ini must not be modified';
our_messages_are(<<'', 'lists uncommitted dist_ini');
[Git::Check] branch master has some uncommitted files:
[Git::Check] 	dist_ini

#---------------------------------------------------------------------
# Test with no dirty files allowed at all:

new_tzil(allow_dirty => '');

# untracked files
throws_ok { $zilla->release } qr/untracked files/,
    'untracked files with allow_dirty = ""';
our_messages_are(<<'', 'lists untracked files');
[Git::Check] branch master has some untracked files:
[Git::Check] 	Changes
[Git::Check] 	dist.ini
[Git::Check] 	foobar

# index not clean
$git->add( qw{ dist.ini Changes foobar } );
throws_ok { $zilla->release } qr/some changes staged/,
    'index not clean with allow_dirty = ""';
our_messages_are(<<'', 'lists staged files');
[Git::Check] branch master has some changes staged for commit:
[Git::Check] 	A	Changes
[Git::Check] 	A	dist.ini
[Git::Check] 	A	foobar

$git->commit( { message => 'initial commit' } );

# modified files
append_to_file('foobar', 'Foo-*');
throws_ok { $zilla->release } qr/uncommitted files/,
    'uncommitted files with allow_dirty = ""';
our_messages_are(<<'', 'lists uncommitted files');
[Git::Check] branch master has some uncommitted files:
[Git::Check] 	foobar

$git->checkout( 'foobar' );

# changelog cannot be modified
append_to_file('Changes', "\n");
throws_ok { $zilla->release } qr/uncommitted files/,
    'Changes must not be modified';
our_messages_are(<<'', 'lists uncommitted Changes file');
[Git::Check] branch master has some uncommitted files:
[Git::Check] 	Changes

$git->checkout( 'Changes' );

# dist.ini cannot be modified
append_to_file('dist.ini', "\n");
throws_ok { $zilla->release } qr/uncommitted files/,
    'dist.ini must not be modified';
our_messages_are(<<'', 'lists uncommitted dist.ini');
[Git::Check] branch master has some uncommitted files:
[Git::Check] 	dist.ini

$git->checkout( 'dist.ini' );

lives_ok { $zilla->release } 'Changes and dist.ini are unmodified';
our_messages_are(<<'', 'reports master in clean state');
[Git::Check] branch master is in a clean state

#---------------------------------------------------------------------
# Test with untracked_files = warn:

new_tzil(untracked_files => 'warn');

# untracked files
lives_ok { $zilla->release } 'untracked files are ok';
our_messages_are(<<'', 'warns about untracked files');
[Git::Check] branch master has some untracked files:
[Git::Check] 	Changes
[Git::Check] 	dist.ini
[Git::Check] 	foobar
[Git::Check] branch master has 3 untracked files

# index not clean
$git->add( qw{ dist.ini Changes foobar } );
throws_ok { $zilla->release } qr/some changes staged/, 'index not clean';
our_messages_are(<<'', 'lists staged files');
[Git::Check] branch master has some changes staged for commit:
[Git::Check] 	A	Changes
[Git::Check] 	A	dist.ini
[Git::Check] 	A	foobar

$git->commit( { message => 'initial commit' } );

# modified files
append_to_file('foobar', 'Foo-*');
throws_ok { $zilla->release } qr/uncommitted files/, 'uncommitted files';
our_messages_are(<<'', 'lists uncommitted files');
[Git::Check] branch master has some uncommitted files:
[Git::Check] 	foobar

$git->checkout( 'foobar' );

# changelog and dist.ini can be modified
append_to_file('Changes',  "\n");
append_to_file('dist.ini', "\n");
lives_ok { $zilla->release } 'Changes and dist.ini can be modified';
our_messages_are(<<'', 'reports master in clean state');
[Git::Check] branch master is in a clean state

# ensure dist.ini does not match dist_ini
append_to_file('dist_ini', 'Hello');
$git->add( qw{ dist_ini } );
$git->commit( { message => 'add dist_ini' } );
append_to_file('dist_ini', 'World');
throws_ok { $zilla->release } qr/uncommitted files/,
    'dist_ini must not be modified';
our_messages_are(<<'', 'lists dist_ini as uncommitted');
[Git::Check] branch master has some uncommitted files:
[Git::Check] 	dist_ini

#---------------------------------------------------------------------
# Test with untracked_files = ignore:

new_tzil(untracked_files => 'ignore');

# untracked files
lives_ok { $zilla->release } 'untracked files are ok';
our_messages_are(<<'', 'counts untracked files');
[Git::Check] branch master has 3 untracked files

# index not clean
$git->add( qw{ dist.ini Changes foobar } );
throws_ok { $zilla->release } qr/some changes staged/, 'index not clean';
our_messages_are(<<'', 'lists staged files');
[Git::Check] branch master has some changes staged for commit:
[Git::Check] 	A	Changes
[Git::Check] 	A	dist.ini
[Git::Check] 	A	foobar

$git->commit( { message => 'initial commit' } );

# modified files
append_to_file('foobar', 'Foo-*');
throws_ok { $zilla->release } qr/uncommitted files/, 'uncommitted files';
our_messages_are(<<'', 'lists foobar as uncommitted');
[Git::Check] branch master has some uncommitted files:
[Git::Check] 	foobar

$git->checkout( 'foobar' );

# changelog and dist.ini can be modified
append_to_file('Changes',  "\n");
append_to_file('dist.ini', "\n");
lives_ok { $zilla->release } 'Changes and dist.ini can be modified';
our_messages_are(<<'', 'reports master in clean state');
[Git::Check] branch master is in a clean state

# ensure dist.ini does not match dist_ini
append_to_file('dist_ini', 'Hello');
$git->add( qw{ dist_ini } );
$git->commit( { message => 'add dist_ini' } );
append_to_file('dist_ini', 'World');
throws_ok { $zilla->release } qr/uncommitted files/,
    'dist_ini must not be modified';
our_messages_are(<<'', 'lists dist_ini as uncommitted');
[Git::Check] branch master has some uncommitted files:
[Git::Check] 	dist_ini

#---------------------------------------------------------------------
sub append_to_file {
    my ($file, @lines) = @_;
    open my $fh, '>>', $file or die "can't open $file: $!";
    print $fh @lines;
    close $fh;
}

#---------------------------------------------------------------------
sub our_messages_are
{
  my ($expected, $name) = @_;

  my $got = join("\n", grep { /^\Q[Git::Check]\E/ } @{ $zilla->log_messages });
  $got =~ s/\s*\z/\n/;

  local $Test::Builder::Level = $Test::Builder::Level + 1;
  is( $got, $expected, $name);

  $zilla->clear_log_events;
}

done_testing;
