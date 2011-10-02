 
#!/usr/bin/perl

# use strict;
use warnings;

# use Mail::IMAPClient;
# use IO::Socket::SSL;
# 
# 
# # Connect to the IMAP server via SSL
# my $socket = IO::Socket::SSL->new(
# 		PeerAddr => 'imap.gmail.com',
# 		PeerPort => 993,
# 	)
# 	or die "socket(): $@";
# 
# # Build up a client attached to the SSL socket.
# # Login is automatic as usual when we provide User and Password
# my $client = Mail::IMAPClient->new(
# 		Socket   => $socket,
# 		User     => 'user',
# 		Password => 'pwd',
# 	)
# 	or die "new(): $@";
# 
# # Do something just to see that it's all ok
# print "I'm authenticated\n" if $client->IsAuthenticated();
# my @folders = $client->folders();
# print join("\n* ", 'Folders:', @folders), "\n";
# 
# $client->select('INBOX');
# 
# my @unread = $client->unseen;
# # print join ', ', @unread;
# 
# # Loop over the messages and store in file
# foreach my $msg (@unread)
# {
# 	my $txt = $client->subject($msg) or die "Couldn't get all messages\n";
# 	my $txt = $client->body_string($msg) or die "Couldn't get all messages\n";
# 	print $txt, "\n";
# }
#    
# $client->deny_seeing( scalar(@unread) ) or die "Could not deny_seeing: $@\n";
# 
# # Say bye
# $client->logout();

use QtCore4;
use QtGui4;

my $a = Qt::Application(\@ARGV);
my $icon = Qt::Icon('icon.png'); 
my $trayIcon = Qt::SystemTrayIcon($icon);
$trayIcon->show;


my $hello = Qt::PushButton("Hello World!", undef);
$hello->resize(160, 25);
$hello->show;
exit $a->exec;


# use v5.12;
# 
# use strict;
# use warnings;
# use Data::Dump qw(dump);
# 
# use Net::DBus qw(:typing);
# my $app_name = "password-extract-in-perl";
# 
# my $bus = Net::DBus->find() or die "Can't find DBus";
# 
# my $kwallet_service = $bus->get_service('org.kde.kwalletd') or die "Ca
# +n't get kwallet";
# 
# my $KWallet = $kwallet_service->get_object('/modules/kwalletd', 'org.k
# +de.KWallet') or die "Can't find networkWallet";
# my $networkWallet = $KWallet->networkWallet();
# say "Network Wallet = $networkWallet";
# 
# my $kwallet_handle = $KWallet->open($networkWallet, 0, $app_name);
# say "Opened = $kwallet_handle";
# 
# my $folders = $KWallet->folderList($kwallet_handle,$app_name);
# say "Folders = ", dump($folders);
# 
# my $u = $KWallet->readPassword($kwallet_handle, 'MyFolder','Some_Useri
# +d_Key', $app_name);
# my $p = $KWallet->readPassword($kwallet_handle, 'MyFolder','Some_Passw
# +ord_Key', $app_name);
# say "User ID  = ", dump($u);
# say "Password = ", dump($p);
