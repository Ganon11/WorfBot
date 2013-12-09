#!perl
package WorfBot;
use AnyLoader qw(Digest::MD5 IO::File Date::Format JSON Data::Dumper);
use warnings;
use strict;

my %honorablePhrases;
my $biblesOrgAPIKey;
my %versionInfo;
#my %authedUsers;

################################################################################
#                            Utility Functions                                 #
################################################################################

sub load_versions {
  my $versionFH;
  open($versionFH, "<versions.json");
  my $versionString = <$versionFH>;
  close($versionFH);
  my $hashref = decode_json($versionString);
  %versionInfo = %$hashref;
  print Dumper(\%versionInfo);
}

sub debug_print {
  my $message = shift;
  my $timestamp = time2str("%Y-%m-%d %H:%M:%S", time);
  my $ofh;
  open($ofh, ">>debug_log.txt");
  print $ofh "$timestamp - $message\n";
  close($ofh);
}

sub check_honor {
  my $phrase = shift;
  my $lcPhrase = lc($phrase);
  if (exists $honorablePhrases{$lcPhrase}) {
    debug_print("Found '$phrase' in hash, using predetermined answer");
    if ($honorablePhrases{$lcPhrase} eq "Honorable") {
      return "$phrase has honor.";
    } else {
      return "$phrase is without honor.";
    }
  } else {
    my $md5hash = md5_hex($lcPhrase);
    debug_print "Using hash '$md5hash' for phrase '$phrase'";
    if ($md5hash =~ /[0-7]$/) {
      return "$phrase has honor.";
    } else {
      return "$phrase is without honor.";
    }
  }
}

sub quote_bible {
  my ($reference, $version) = @_;
  $reference =~ /(\d+)?([a-zA-Z]+)(?:(\d+))(?::(\d+))?(?:-(\d+))?/i;
  my ($booknum, $book, $chapter, $verse, $verseEnd) = ($1, $2, $3, $4, $5);
  print "$booknum " if defined $booknum;
  print "$book " if defined $book;
  print "$chapter:" if defined $chapter;
  print "$verse" if defined $verse;
  print "-$verseEnd" if defined $verseEnd;
  print "\n";
}

sub add_word {
  my ($word, $honor) = @_;
  $honorablePhrases{lc $word} = $honor;
}

# sub join_channel {
  # my ($conn, $channel) = @_;
  # $conn->join($channel);
  # $conn->privmsg($channel, 'I am WorfBot, son of MoghBot');
# }

# sub part_channel {
  # my ($conn, $channel) = @_;
  # $conn->privmsg($channel, "Today is a good day to die!");
  # $conn->part($channel);
# }

sub load_words {
  my $ifh;
  open($ifh, "<honorable_phrases.txt") or debug_print("Error - could not open honorable_phrases.txt for read ($!)");
  %honorablePhrases = ();
  while (<$ifh>) {
    my $line = $_;
    chomp($line);
    my ($word1, $word2) = split(/:/, $line);
    if ($word2 ne "Honorable") {
      $word2 = "Dishonorable";
    }
    add_word($word1, $word2);
  }
  close($ifh);
}

sub save_words {
  my @lines;
  foreach my $phrase (keys %honorablePhrases) {
    push(@lines, "$phrase:$honorablePhrases{$phrase}");
  }
  my $ofh;
  open($ofh, ">honorable_phrases.txt") or debug_print("Could not open honorable_phrases.txt for write ($!)");
  print $ofh join("\n", @lines);
  close($ofh);
}

sub get_help_string {
  return "You may ask me about which things have honor by typing '!honor <phrase>'\n";
}

sub get_usage_string {
  my $usage = <<END;
Usage: perl WorfBot.pl <server address> [channel1 channel2 channel3 ...]
  e.g. perl WorfBot.pl irc.freenode.net #Channel1 #OtherChannel
END
  return $usage;
}

################################################################################
#                              IRC Functions                                   #
################################################################################
use base qw(Bot::BasicBot);

sub init {
  # Initial Load
  load_words();

  # Clear the debug log of previous contents. Each debug_log.txt is for 1 WorfBot session.
  my $tmp;
  open($tmp, ">debug_log.txt");
  close($tmp);

  # Next, initialize our API key from bibles.org
  open($tmp, "<BiblesOrgAPIKey.dat");
  $biblesOrgAPIKey = <$tmp>;
  close($tmp);
}

sub said {
  # Recieves hashref with the following fields:
  #   who: Nick who said the message
  #   channel: The channel in which it was said, or 'msg' if a private message
  #   body: The actual text
  my $argref = shift;
  my %args = %$argref;
  print "Received:\n";
  foreach my $key (keys %args) {
    print "\t$key - $args{$key}\n";
  }
  my @otherArgs = @_;
  if (defined @otherArgs) print "@otherArgs";
  my ($nick, $channel, $body) = ($args{'nick'}, $args{'channel'}, $args{'body'});
  if (!defined $nick || !defined $channel || !defined $body) return undef;
  print "nick: $nick, channel: $channel, body: $body";
  if ($channel eq 'msg') {
    # Private Message
    if ($body =~ /^load/i && user_is_authed($nick)) {
      load_words();
      return "Loading complete.";
    } elsif ($body =~ /^save/i && user_is_authed($nick)) {
      save_words();
      return "Saving complete.";
    } elsif ($body =~ /^add (.+):(.+)/i && user_is_authed($nick)) {
      my ($word, $honorphrase) = ($1, $2);
      chomp($honorphrase);
      if ($honorphrase eq "Honorable") {
        add_word($word, "Honorable");
      } else {
        add_word($word, "Dishonorable");
      }
      return "Added '$word' = '$honorphrase'";
    } elsif ($body =~ /^help/i) {
      return get_help_string();
    } elsif ($body =~ /^join (#.+)$/i && user_is_authed($nick)) {
      my $channel = $1;
      join_channel($conn, $channel);
    } elsif ($body =~ /^part (#.+)$/i && user_is_authed($nick)) {
      my $channel = $1;
      part_channel($conn, $channel);
    } elsif ($body =~ /^hono(?:u)?r (.+)/i) {
      return check_honor($1);    
    } elsif ($body =~ /^auth (.+)/i && user_is_authed($nick)) {
    
    }
  } else {
    # Public Message
    if ($body =~ /^\!hono(?:u)?r (.+)/i) {
      check_honor($1);
    } elsif ($body =~ /^\!help/i) {
      return get_help_string();
    }
  }
  # If we haven't processed the message already, ignore it.
  return undef;
}

sub chanpart {
  my $argref = shift;
  my %args = %$argref;
  # Take care of de-authing a user we can't see anymore.
}

sub nick_change {
  my $argref = shift;
  my %args = %$argref;
  # Track authed users changing their nicks
}

sub kicked {
  my $argref = shift;
  my %args = %$argref;
  # Take care of de-authing a user we can't see anymore.
}

sub help {
  return get_help_string();
}

sub userquit {
  my $argref = shift;
  my %args = %$argref;
  # Immediately de-auth a user
}

################################################################################
#                                Main Prog                                     #
#          Args - server_address [channel1 channel2 channel3 ...]              #
################################################################################
if (scalar(@ARGV) < 1) {
  die get_usage_string();
}
my $server_addr = shift(@ARGV);
my @channels = @ARGV;

# Now, create our IRC connection.
my $WorfBot = WorfBot->new(
  server    => $server_addr,
  channels  => @channels,
  nick      => 'WorfBot',
  alt_nicks => [ 'WorfBot2', 'KernBot', 'KernBot2' ],
  username  => 'WorfBot',
  name      => 'WorfBot, son of MoghBot'
);

# Go!
$WorfBot->run();