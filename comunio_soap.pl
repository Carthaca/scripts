#!/usr/bin/env perl
use warnings;
use strict;
use 5.010;
use Data::Dumper;
use Carp;

# uncomment to use authed calls
###############################
# confess('$COMUNIO_USERNAME missing!') unless $ENV{'COMUNIO_USERNAME'};
# confess('$COMUNIO_PASSWORD missing!') unless $ENV{'COMUNIO_PASSWORD'};
# sub SOAP::Transport::HTTP::Client::get_basic_credentials {
#    return $ENV{'COMUNIO_USERNAME'} => $ENV{'COMUNIO_PASSWORD'};
#  }

use SOAP::Lite service => 'http://www.comunio.de/soapservice.php?wsdl';

# uncomment to get a list of available methods
##############################################
#no strict 'refs';
#my @methods = grep { defined &{$_} } keys %::;
#say Dumper(@methods);
#use strict 'refs';

my $community_id = $ENV{'COMUNIO_COMMUNITY_ID'} // confess('ENV $COMUNIO_COMMUNITY_ID missing!');

my $user_ids = getuserids($community_id);

for my $user_id (@{$user_ids}){
   my $name = getusersname($user_id);
   my $size = getteamsize($user_id) // 0;
   my $perm = checkPermissions($user_id);

   print "$name:";
   if ($perm){
      say  "$size players";
   } else {
      say "no access";
   }
}
