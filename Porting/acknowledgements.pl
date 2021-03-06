#!perl

=head1 NAME

Porting/acknowledgements.pl - Generate perldelta acknowledgements text

=head1 SYNOPSIS

  perl Porting/acknowledgements.pl v5.15.0..HEAD
  
=head1 DESCRIPTION

This generates the text which goes in the Acknowledgements section in
a perldelta. You pass in the previous version and it guesses the next
version, fetches information from the repository and outputs the
text.

=cut

use strict;
use warnings;
use autodie;
use POSIX qw(ceil);
use Text::Wrap;
use Time::Piece;
use Time::Seconds;
use version;
$Text::Wrap::columns = 80;

my $since_until = shift;

my ( $since, $until ) = split '\.\.', $since_until;

die "Usage: perl Porting/acknowledgements.pl v5.15.0..HEAD"
    unless $since_until && $since && $until;

my $previous_version = previous_version();
my $next_version     = next_version();
my $development_time = development_time();

my ( $changes, $files ) = changes_files();
my $formatted_changes = commify( round($changes) );
my $formatted_files   = commify( round($files) );

my $authors = authors();
my $nauthors = $authors =~ tr/,/,/;
$nauthors++;

my $text
    = "Perl $next_version represents approximately $development_time of development
since Perl $previous_version and contains approximately $formatted_changes
lines of changes across $formatted_files files from $nauthors authors.

Perl continues to flourish into its third decade thanks to a vibrant
community of users and developers. The following people are known to
have contributed the improvements that became Perl $next_version:

$authors
The list above is almost certainly incomplete as it is automatically
generated from version control history. In particular, it does not
include the names of the (very much appreciated) contributors who
reported issues to the Perl bug tracker.

Many of the changes included in this version originated in the CPAN
modules included in Perl's core. We're grateful to the entire CPAN
community for helping Perl to flourish.

For a more complete list of all of Perl's historical contributors,
please see the F<AUTHORS> file in the Perl source distribution.";

my $wrapped = fill( '', '', $text );
print "$wrapped\n";

# return the previous Perl version, eg 5.15.0
sub previous_version {
    my $version = version->new($since);
    $version =~ s/^v//;
    return $version;
}

# returns the upcoming release Perl version, eg 5.15.1
sub next_version {
    my $version = version->new($since);
    ( $version->{version}->[-1] )++;
    return version->new( join( '.', @{ $version->{version} } ) );
}

# returns the development time since the previous version in weeks
# or months
sub development_time {
    my $dates = qx(git log --pretty=format:%ct --summary $since_until);
    my $first_timestamp;
    foreach my $line ( split $/, $dates ) {
        next unless $line;
        next unless $line =~ /^\d+$/;
        $first_timestamp = $line;
    }

    die "Missing first timestamp" unless $first_timestamp;

    my $now     = localtime;
    my $then    = localtime($first_timestamp);
    my $seconds = $now - $then;
    my $weeks   = ceil( $seconds / ONE_WEEK );
    my $months  = ceil( $seconds / ONE_MONTH );

    my $development_time;
    if ( $months < 2 ) {
        return "$weeks weeks";
    } else {
        return "$months months";
    }
}

# returns the number of changed lines and files since the previous
# version
sub changes_files {
    my $output = qx(git diff --shortstat $since_until);

    # 585 files changed, 156329 insertions(+), 53586 deletions(-)
    my ( $files, $insertions, $deletions )
        = $output
        =~ /(\d+) files changed, (\d+) insertions\(\+\), (\d+) deletions\(-\)/;
    my $changes = $insertions + $deletions;
    return ( $changes, $files );
}

# rounds an integer to two significant figures
sub round {
    my $int     = shift;
    my $length  = length($int);
    my $divisor = 10**( $length - 2 );
    return ceil( $int / $divisor ) * $divisor;
}

# adds commas to a number at thousands, millions
sub commify {
    local $_ = shift;
    1 while s/^([-+]?\d+)(\d{3})/$1,$2/;
    return $_;
}

# returns a list of the authors
sub authors {
    return
        qx(git log --pretty=fuller $since_until | $^X Porting/checkAUTHORS.pl --who -);
}
