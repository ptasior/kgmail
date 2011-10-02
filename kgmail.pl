#!/usr/bin/perl

use strict;
use warnings;

###########################################################################################
package MApp;
use feature 'state';

# Don't ask why. Slots don't know what class instance are they called from, so it's a kind of a workaround

sub new
{
	my $class = shift;
	state $instance;

	if (!defined $instance) 
	{
		my $self = {
				_wnd => 0,
				_processing => 0
			};
		$instance = bless $self, $class;
	}
	return $instance;
}

sub init
{
	my ($self) = @_;
	my $w = Wnd->new;
	$self->{_wnd} = $w;
	$w->timerEvent;
}

sub wnd
{
	my ($self) = @_;
	return $self->{_wnd};
}

sub processing
{
	my ($self, $v) = @_;
	$self->{_processing} = $v if defined($v);
	return $self->{_processing};
}

###########################################################################################
package Imap;

use Mail::IMAPClient;
use IO::Socket::SSL;

sub new
{
	my $class = shift;
	my $self = {
			_cnt => 0,
			_subject => [],
			_author => [],
			_body => []
		};
		
	bless $self, $class;
	return $self;
}

sub cnt
{
	my ($self) = @_;
	return $self->{_cnt};
}

sub subject
{
	my ($self, $no) = @_;
	return @{$self->{_subject}}[$no];
}

sub author
{
	my ($self, $no) = @_;
	return @{$self->{_author}}[$no];
}

sub body
{
	my ($self, $no) = @_;
	return @{$self->{_body}}[$no];
}

sub check
{
	my ($self) = @_;
	
	my $mapp = MApp->new;
	return if($mapp->processing() == 1);
	$mapp->processing(1);
	
	my $socket = IO::Socket::SSL->new(
			PeerAddr => 'imap.gmail.com',
			PeerPort => 993,
		)
		or die "socket(): $@";

	my $client = Mail::IMAPClient->new(
			Socket   => $socket,
			User     => 'user',
			Password => 'pwd',
		)
		or die "new(): $@";

	$client->select('INBOX');

# 	print "connected\n";
	
	my @unread = $client->unseen;
	$self->{_cnt} = $client->unseen_count;
	
	if($self->{_cnt} != 0)
	{
# 		print 'unread: '.join(', ', @unread);
		foreach my $msg (@unread)
		{
			push @{$self->{_subject}}, $client->subject($msg) or die "Couldn't get message subject\n";
			push @{$self->{_body}}, $client->body_string($msg) or die "Couldn't get message body\n";
			push @{$self->{_author}}, $client->get_header($msg, "From") or die "Couldn't get message sender\n";
		}
		$client->unset_flag("Seen", @unread) or die "Could not mark as unseen: $@\n";
# 		$client->deny_seeing( scalar(@unread) ) or die "Could not deny_seeing: $@\n";
	}
	
	$client->logout();
	$mapp->processing(0);
}

###########################################################################################
package Wnd;

use QtCore4;
use QtGui4;
use QtCore4::isa qw(Qt::TextBrowser);
use QtCore4::slots
		timerEvent => [],
		showHide => ['QSystemTrayIcon::ActivationReason'];
		
use QtCore4::debug qw(ambiguous);

sub new
{
	my $class = shift;
	$class->SUPER::NEW(@_);
	
	setGeometry(qApp->desktop()->screenGeometry()->width()-200, qApp->desktop()->screenGeometry()->height()-200, 200, 200);
	setWindowFlags(0x00000800);

	my $timer = Qt::Timer(this);
	this->connect($timer, SIGNAL 'timeout()', this, SLOT 'timerEvent()');
	this->connect(this, SIGNAL 'selectionChanged()', this, SLOT 'hide()');
	$timer->start(100000);
	
	my $menu = Qt::Menu;
	my $acQuit= Qt::Action(Qt::Icon('icon.png'), 'Quit', $menu);
	my $trayIcon = Qt::SystemTrayIcon(Qt::Icon('icon.png'));
	
	this->connect($acQuit, SIGNAL 'triggered()', qApp, SLOT 'quit()');
	this->connect($trayIcon, SIGNAL 'activated(QSystemTrayIcon::ActivationReason)', this, SLOT 'showHide(QSystemTrayIcon::ActivationReason)');
	
	$menu->addAction($acQuit);
	$trayIcon->setContextMenu($menu);
	
	$trayIcon->show;
	
	my $self = {
			_tray => $trayIcon
		};
		
	bless $self, $class;
	return $self;
}

sub tray
{
	my ( $self, $o ) = @_;
	$self->{_tray} = $o if defined($o);
	return $self->{_tray};
}

sub timerEvent
{
	my $im = new Imap;
	$im->check;
	my $mapp = MApp->new;
	$mapp->wnd->tray->setToolTip('Unread: '.$im->cnt());

	my $txt;
	for(my $i = 0; $i < $im->cnt(); $i++)
	{
		my $bd = $im->body($i);
		$bd =~ s/<.*?>//g;
		$bd = substr($bd,0,70);
		$txt .= '<b>'.$im->subject($i).'</b> <i style="font-size: 20%">'.$im->author($i).'</i><br>'.$bd.'<br><br><hr>';
	}

	setText($txt);
}

sub showHide
{
	setVisible(isHidden()) if($_[0] == 3);
}

###########################################################################################
package main;

use QtCore4;

my $a = Qt::Application(\@ARGV);

our $mapp = MApp->new;
$mapp->init();

exit $a->exec;


# connect(trayIcon, SIGNAL(activated(QSystemTrayIcon::ActivationReason)), this, SLOT(iconActivated(QSystemTrayIcon::ActivationReason)));

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
