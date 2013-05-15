#!perl

#LOLTRIVIAL

use Digest::MD5 qw(md5_hex);
use Net::IRC;
use IO::File;
use Date::Format;
use strict;
use warnings;

my %honorable_phrases;

sub debug_print {
  my $message = shift;
  my $timestamp = time2str("%Y-%m-%d %H:%M:%S", time);
  my $ofh;
  open($ofh, ">>debug_log.txt");
  print $ofh "$timestamp - $message\n";
  close($ofh);
}

sub check_honor {
  my ($conn, $phrase, $target) = @_;
  debug_print("'$target' asked about '$phrase'");
  my $response;
  if (exists $honorable_phrases{lc $phrase}) {
    debug_print("Found '$phrase' in hash, using predetermined answer");
    if ($honorable_phrases{lc $phrase} eq "Honorable") {
      $response = "$phrase has honor.";
    } else {
       $response = "$phrase is without honor.";
    }
  } else {
    my $md5hash = md5_hex(lc $phrase);
    debug_print "Using hash '$md5hash' for phrase '$phrase'";
    if ($md5hash =~ /[0-7]$/) {
      $response = "$phrase has honor.";
    } else {
      $response = "$phrase is without honor.";
    }
  }
  $conn->privmsg($target, $response);
}

sub add_word {
  my ($word, $honor) = @_;
  $honorable_phrases{lc $word} = $honor;
}

sub join_channel {
  my ($conn, $channel) = @_;
  $conn->join($channel);
  $conn->privmsg($channel, 'I am WorfBot, son of MoghBot');
}

sub load_words {
  my $ifh;
  open($ifh, "<honorable_phrases.txt") or return;
  %honorable_phrases = ();
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
  foreach my $phrase (keys %honorable_phrases) {
    push(@lines, "$phrase:$honorable_phrases{$phrase}");
  }
  my $ofh;
  open($ofh, ">honorable_phrases.txt") or return;
  close($ofh);
}

#Run once, when WorfBot first connects to a server.
sub on_connect {
  my $conn = shift;
  my @channels;
  push(@channels, '#reddit-Christianity');
  my $message = "Joining channels: " . join(", ", @channels);
  debug_print($message);
  foreach my $channel (@channels) {
    join_channel($conn, $channel);
  }
  $conn->{connected} = 1;
}

#Run every time WorfBot sees a public message in a channel. Filter for commands here to avoid spamminess!
sub on_public {
  my ($conn, $event) = @_;
  my $text = $event->{args}[0];

  if ($text =~ /^\!honor (.+)/i) {
    check_honor($conn, $1, $event->{to}[0]);
  }
}

#Run every time WorfBot receives a private message.
sub on_msg {
  my ($conn, $event) = @_;
  my $text = $event->{args}[0];
  my $nick = $event->{nick};

  if ($text =~ /^load/i && $nick eq "mstark") {
    $conn->privmsg($nick, "Loading words...");
    load_words();
    $conn->privmsg($nick, "Loading complete.");
  } elsif ($text =~ /^save/i && $nick eq "mstark") {
    $conn->privmsg($nick, "Saving words...");
    save_words();
    $conn->privmsg($nick, "Saving complete.");
  } elsif ($text =~ /^add (.+):(.+)/i && $nick eq "mstark") {
    my ($word, $honorphrase) = ($1, $2);
    chomp($honorphrase);
    $conn->privmsg($nick, "Adding '$word' = '$honorphrase'");
    if ($honorphrase eq "Honorable") {
      add_word($word, "Honorable");
    } else {
      add_word($word, "Dishonorable");
    }
  } elsif ($text =~ /^help/i) {
    $conn->privmsg($nick, "You may ask me about which things have honor by typing '!honor <phrase>'\n");
  } elsif ($text =~ /^join (#.+)$/i && $nick eq "mstark") {
    my $channel = $1;
    $conn->join($channel);
    $conn->privmsg($channel, "I am WorfBot, son of MoghBot.");
  } elsif ($text =~ /^part (#.+)$/i && $nick eq "mstark") {
    my $channel = $1;
    $conn->privmsg($channel, "Today is a good day to die!");
    $conn->part($channel);
  } elsif ($text =~ /^\!honor (.+)/i) {
    check_honor($conn, $1, $nick);    
  }
}

# 'Main' function

# First, clear the debug log of previous contents. Each debug_log.txt is for 1 WorfBot session.
my $tmp;
open ($tmp, ">debug_log.txt");
close($tmp);
load_words();

# Now, create our IRC connection.
my $irc = new Net::IRC;
my $conn = $irc->newconn(
                         Server => 'irc.freenode.net',
                         Port => '6667',
                         Nick => 'WorfBot',
                         Ircname => 'WorfBot, son of MoghBot',
                         Username => 'WorfBot'
);

# Add listeners for various IRC signals
$conn->add_handler('376', \&on_connect);
$conn->add_handler('public', \&on_public);
$conn->add_handler('msg', \&on_msg);

# Go!
$irc->start();
