#!perl
use AnyLoader qw(Digest::MD5 IO::File Date::Format Data::Dumper);
use Bot::BasicBot;
use warnings;
use strict;

package WorfBot;

my %honorablePhrases;

################################################################################
#                            Utility Functions                                 #
################################################################################

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
  $lcPhrase =~ s/^\s+|\s+$//g;
  print "Using phrase \"$lcPhrase\"\n";
  if (exists $honorablePhrases{$lcPhrase}) {
    #debug_print("Found '$phrase' in hash, using predetermined answer");
    if ($honorablePhrases{$lcPhrase} eq "Honorable") {
      return "$phrase has honor.";
    } else {
      return "$phrase is without honor.";
    }
  } else {
    my $md5hash = md5_hex($lcPhrase);
    #debug_print "Using hash '$md5hash' for phrase '$phrase'";
    if ($md5hash =~ /[0-7]$/) {
      return "$phrase has honor.";
    } else {
      return "$phrase is without honor.";
    }
  }
}

sub add_word {
  my ($word, $honor) = @_;
  $honorablePhrases{lc $word} = $honor;
}

sub join_channel {
  my ($conn, $channel) = @_;
  $conn->join($channel);
  $conn->privmsg($channel, 'I am WorfBot, son of MoghBot');
}

sub part_channel {
  my ($conn, $channel) = @_;
  $conn->privmsg($channel, "Today is a good day to die!");
  $conn->part($channel);
}

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
Usage: perl WorfBot2.pl <server address> [channel1 channel2 channel3 ...]
  e.g. perl WorfBot2.pl irc.freenode.net #reddit-Christianity
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
}

sub said {
  # Recieves hashref with the following fields:
  #   who: Nick who said the message
  #   channel: The channel in which it was said, or 'msg' if a private message
  #   body: The actual text
  my ($self, $inforef) = @_;
  my ($nick, $channel, $text) = ($inforef->{'who'}, $inforef->{'channel'}, $inforef->{'body'});
  if (!defined $nick || !defined $channel || !defined $text) {
    return undef;
  }
  print "nick: $nick, channel: $channel, text: \"$text\"\n";
  if ($channel eq 'msg') {
    # Private Message
#    if ($body =~ /^load/i && user_is_authed($nick)) {
#      load_words();
#      return "Loading complete.";
#    } elsif ($body =~ /^save/i && user_is_authed($nick)) {
#      save_words();
#      return "Saving complete.";
#    } elsif ($body =~ /^add (.+):(.+)/i && user_is_authed($nick)) {
#      my ($word, $honorphrase) = ($1, $2);
#      chomp($honorphrase);
#      if ($honorphrase eq "Honorable") {
#        add_word($word, "Honorable");
#      } else {
#        add_word($word, "Dishonorable");
#      }
#      return "Added '$word' = '$honorphrase'";
#    } elsif ($body =~ /^help/i) {
#      return get_help_string();
#    } elsif ($body =~ /^join (#.+)$/i && user_is_authed($nick)) {
#      my $channel = $1;
#      join_channel($conn, $channel);
#    } elsif ($body =~ /^part (#.+)$/i && user_is_authed($nick)) {
#      my $channel = $1;
#      part_channel($conn, $channel);
#    } elsif ($body =~ /^hono(?:u)?r (.+)/i) {
#      return check_honor($1);    
#    } elsif ($body =~ /^auth (.+)/i && user_is_authed($nick)) {
#    }
    if ($text =~ /^help/i) {
      return get_help_string();
    } elsif ($text =~ /^hono(?:u)?r (.+)/i) {
      return check_honor($1);    
    }
  } else {
    # Public Message
    if ($text =~ /^\!hono(?:u)?r (.+)/i) {
      check_honor($1);
    } elsif ($text =~ /^\!help/i) {
      return get_help_string();
    }
  }
  # If we haven't processed the message already, ignore it.
  return undef;
}

sub help {
  return get_help_string();
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
  nick      => 'WorfBot2',
  alt_nicks => [ 'WorfBot3', 'KernBot', 'KernBot2' ],
  username  => 'WorfBot2',
  name      => 'WorfBot, son of MoghBot'
);

# Go!
$WorfBot->run();