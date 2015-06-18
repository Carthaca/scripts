#!/usr/bin/env perl
use warnings;
use strict;
use 5.010;

use Carp;
use Data::Dumper;

use Net::LastFM;
use Hash::Merge qw(merge);
# pretty print utf8
use open qw/:std :utf8/;
# utf8 in hash keys
use utf8;

### PRE ###

my $USER = $ENV{'LAST_FM_USER'} // confess('ENV $LAST_FM_USER missing!');

confess('$LAST_FM_API_KEY missing!') unless $ENV{'LAST_FM_API_KEY'};
confess('$LAST_FM_API_SECRET missing!') unless $ENV{'LAST_FM_API_SECRET'};
my $lastfm = Net::LastFM->new(
    api_key    => $ENV{'LAST_FM_API_KEY'},
    api_secret => $ENV{'LAST_FM_API_SECRET'},
);

### MAIN ###

my ($artist, $location) = count_artists_and_locations();

say 'Top Venues:';
say '-' x 50;
sort_desc_and_print($location);
say '-' x 50;
say 'Top Seen Live:';
say '-' x 50;
sort_desc_and_print($artist);

### SUBS ###

sub sort_desc_and_print{
   my $hash = shift;

	foreach my $key (sort { $hash->{$b} <=> $hash->{$a} } keys(%{$hash})){
	    say $key .': '. $hash->{$key};
	}
}

sub single_last_request{
   my $params = shift;
   croak 'method parameter missing' unless $params->{method};

   return $lastfm->request_signed(
      method   => $params->{method},
      user     => $params->{user}   ? $params->{user}    : $USER,
      page     => $params->{page}   ? $params->{page}    : 1,
      limit    => $params->{limit}  ? $params->{limit}   : 50
   );
}

sub last_request{
   my $params  = shift;
   my $return  = {};
   my $page    = 1;

   my ($pages, $data);

   while (42){
      $data    = single_last_request({%{$params}, page => $page});
      $return  = merge($return, $data);
      unless ($pages){
         # to access the @attr key for the total Pages
	      # we need to go into the first (and probably only) key
	      my $first_key = (keys %{$data})[0];
	      $pages = $data->{$first_key}->{'@attr'}->{totalPages};
      }

      last if $page == $pages;
      $page++;
   }

   return $return;
}

my %IS_ALLOWED_ARTIST;

sub is_allowed_artist{
   my $artist = shift;
   unless (exists $IS_ALLOWED_ARTIST{$artist}){
      $IS_ALLOWED_ARTIST{$artist} = grep {$artist eq $_} @{get_allowed_artists()};
   }
   return $IS_ALLOWED_ARTIST{$artist};
}

my $ALLOWED_ARTISTS;

sub get_allowed_artists{
   my @artists;

   unless ($ALLOWED_ARTISTS){
	   # only allow top1000 artist to count as seen live
	   # maybe later make a white/black list approach
	    my $top_artists = single_last_request({
	        method  => 'user.getTopArtists',
	        limit   => 1000
	    });

	    foreach my $top (@{$top_artists->{topartists}->{artist}}){
	        push @artists, $top->{name};
	    }

	    $ALLOWED_ARTISTS = \@artists;
   }

	return $ALLOWED_ARTISTS;
}

sub count_artists_and_locations{
   my (%location, %artist);

	my $events = last_request({
	    method    => 'user.getPastEvents',
	});

	foreach my $event (@{$events->{events}->{event}}){
	    # status '0' means attended
	    next if $event->{'@attr'}->{status};

	    # multiple artists
	    if (ref $event->{artists}->{artist} eq ref []){
	        foreach my $artist (@{$event->{artists}->{artist}}){
	            $artist{$artist}++ if is_allowed_artist($artist);
	        }
	    # just one
	    }else{
	        my $artist = $event->{artists}->{artist};
	        $artist{$artist}++ if is_allowed_artist($artist);
	    }

	    # TODO: build some kind of filter for special events
	    # die Dumper($event) if $event->{venue}->{name} eq 'Red Bull Arena';

	    $location{"$event->{venue}->{name} ($event->{venue}->{location}->{city})"}++;
	}

	return (\%artist, \%location);
}

# TODO:
# 1. separation between main and support acts
# 2. filter functions (f.i. for artists/locations)
# 3. blacklist for artists (better: artists at special event) to not be counted
__END__
