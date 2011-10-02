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
				_processing => 0,
				_user => '',
				_pwd => '',
				_authWnd => '',
				_mailCnt => 0
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
	
	$w->setup()if(!Auth->getData());
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

sub user
{
	my ($self, $v) = @_;
	$self->{_user} = $v if defined($v);
	return $self->{_user};
}

sub pwd
{
	my ($self, $v) = @_;
	$self->{_pwd} = $v if defined($v);
	return $self->{_pwd};
}

sub authWnd
{
	my ($self, $v) = @_;
	$self->{_authWnd} = $v if defined($v);
	return $self->{_authWnd};
}

sub mailCnt
{
	my ($self, $v) = @_;
	$self->{_mailCnt} = $v if defined($v);
	return $self->{_mailCnt};
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
	
	return if !defined($mapp->user()) || $mapp->user() eq '';
	
	my $socket = IO::Socket::SSL->new(
			PeerAddr => 'imap.gmail.com',
			PeerPort => 993,
		)
		or die "Can't create connection - socket(): $@";

	my $client = Mail::IMAPClient->new(
			Socket   => $socket,
			User     => $mapp->user,
			Password => $mapp->pwd,
		)
		or die "Can't connect - new(): $@";

	$client->select('INBOX');

	print "Checking\n";

	my @unread = $client->unseen;
	$self->{_cnt} = $client->unseen_count;
	$mapp->mailCnt($self->{_cnt});
	
	if($self->{_cnt} != 0)
	{
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
use QtCore4::isa qw(Qt::TextEdit);
use QtCore4::slots
		timerEvent => [],
		setup => [],
		check => [],
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
	Qt::Timer::singleShot(1000, this, SLOT 'timerEvent()');
	
	my $menu = Qt::Menu;
	my $acCheck = Qt::Action('Check now!', $menu);
	my $acSetup = Qt::Action('Setup', $menu);
	my $acQuit = Qt::Action('Quit', $menu);
	my $trayIcon = Qt::SystemTrayIcon(Qt::Icon('iconwait.png'));
	
	this->connect($acCheck, SIGNAL 'triggered()', this, SLOT 'check()');
	this->connect($acSetup, SIGNAL 'triggered()', this, SLOT 'setup()');
	this->connect($acQuit, SIGNAL 'triggered()', qApp, SLOT 'quit()');
	this->connect($trayIcon, SIGNAL 'activated(QSystemTrayIcon::ActivationReason)', this, SLOT 'showHide(QSystemTrayIcon::ActivationReason)');
	
	$menu->addAction($acCheck);
	$menu->addAction($acSetup);
	$menu->addAction($acQuit);
	$trayIcon->setContextMenu($menu);
	
	$trayIcon->setToolTip('Initialising...');
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
	my $mapp = MApp->new;
	$mapp->wnd->tray->setToolTip('Checking mails...');
	
	die 'No credentials' if !Auth->getData();
	
	my $im = new Imap;
	$im->check;
	$mapp->wnd->tray->setToolTip('Unread: '.$im->cnt());

	my $txt = '';
	for(my $i = $im->cnt()-1; $i >= 0; $i--)
	{
		my $bd = $im->body($i);
		$bd =~ s/<.*?>//g;
		$bd = substr($bd,0,70);
		$txt .= '<b>'.$im->subject($i).'</b> <i style="font-size: 20%">'.$im->author($i).'</i><br>'.$bd.'<br><br><hr>';
	}
	
	if($im->cnt())
	{
		$mapp->wnd->tray->setIcon(Qt::Icon('icon.png'));
	}
	else
	{
		$mapp->wnd->tray->setIcon(Qt::Icon('iconno.png'));
	}

	setText($txt);
}

sub showHide
{
	setVisible(isHidden()) if($_[0] == 3);
	my $mapp = MApp->new;
	setVisible(0) if($mapp->mailCnt == 0);
}

sub check
{
	timerEvent();
}

sub setup
{
	my $mapp = MApp->new;
	my $aw = Auth->new;
	$mapp->authWnd($aw);
}

###########################################################################################
package Auth;

use Net::DBus qw(:typing);
use QtCore4;
use QtGui4;
use QtCore4::isa qw(Qt::Widget);
use QtCore4::slots
		save => [],
		closeWnd => [];
		
use QtCore4::debug qw(ambiguous);

sub new
{
	my $class = shift;
	$class->SUPER::NEW(@_);
	
	my $mapp = MApp->new;

	$mapp->authWnd(this);

	resize(200, 100);
	
	my $ok = Qt::PushButton('OK');
	my $cancel = Qt::PushButton('Cancel');
	my $login = Qt::LineEdit($mapp->user);
	my $pwd = Qt::LineEdit($mapp->pwd);
	$pwd->setEchoMode(2);

	my $mainLayout = Qt::VBoxLayout();

	$mainLayout->addWidget(Qt::Label('Login:'));
	$mainLayout->addWidget($login);
	$mainLayout->addWidget(Qt::Label('Password:'));
	$mainLayout->addWidget($pwd);
	
	my $barLayout = Qt::HBoxLayout();
	
	$barLayout->addWidget($ok);
	$barLayout->addWidget($cancel);
	
	$mainLayout->addLayout($barLayout);
	this->setLayout($mainLayout);
	
	this->connect($ok, SIGNAL 'clicked()', this, SLOT 'save()');
	this->connect($cancel, SIGNAL 'clicked()', this, SLOT 'closeWnd()');

	my $self = {
			_login => $login,
			_pwd => $pwd
		};
	bless $self, $class;
	
	show();
	return $self;
}

sub getData
{
	my $mapp = MApp->new;
	
	my $app_name = 'kgmail';
	my $bus = Net::DBus->find() or die "Can't find DBus";
	my $kwallet_service = $bus->get_service('org.kde.kwalletd') or die "Can't get kwallet";

	my $KWallet = $kwallet_service->get_object('/modules/kwalletd', 'org.kde.KWallet') or die "Can't find networkWallet";
	my $kwallet_handle = $KWallet->open($KWallet->networkWallet(), 0, $app_name);
	
	if($KWallet->hasFolder($kwallet_handle, $app_name, $app_name))
	{
		my $u = $KWallet->readPassword($kwallet_handle, $app_name, 'User', $app_name);
		my $p = $KWallet->readPassword($kwallet_handle, $app_name, 'Password', $app_name);
		$mapp->user($u);
		$mapp->pwd($p);
		
		return 1;
	}
	
	return 0;
}

sub save
{
	my $mapp = MApp->new;
	
	my $app_name = 'kgmail';
	my $bus = Net::DBus->find() or die "Can't find DBus";
	my $kwallet_service = $bus->get_service('org.kde.kwalletd') or die "Can't get kwallet";

	my $KWallet = $kwallet_service->get_object('/modules/kwalletd', 'org.kde.KWallet') or die "Can't find networkWallet";
	my $kwallet_handle = $KWallet->open($KWallet->networkWallet(), 0, $app_name);
	
	if($KWallet->hasFolder($kwallet_handle, $app_name, $app_name))
	{
		$KWallet->createFolder($kwallet_handle, $app_name, $app_name);
	}
	
	$KWallet->writePassword($kwallet_handle, $app_name, 'User', $mapp->authWnd->{_login}->text, $app_name);
	$KWallet->writePassword($kwallet_handle, $app_name, 'Password', $mapp->authWnd->{_pwd}->text, $app_name);
	$mapp->user($mapp->authWnd->{_login}->text);
	$mapp->pwd($mapp->authWnd->{_pwd}->text);
	
	$mapp->wnd->check();
	hide();
}

sub closeWnd
{
	hide();
	my $mapp = MApp->new;
	$mapp->wnd->check();
}

###########################################################################################
package main;

use QtCore4;

my $a = Qt::Application(\@ARGV);

my $mapp = MApp->new;
$mapp->init;

exit $a->exec;

# connect(trayIcon, SIGNAL(activated(QSystemTrayIcon::ActivationReason)), this, SLOT(iconActivated(QSystemTrayIcon::ActivationReason)));

