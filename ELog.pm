package ELog;

use BOSS::Config;
use MyFRDCSA;
use PerlLib::MySQL;
use PerlLib::SwissArmyKnife;

use Data::Dumper;
use DateTime;

use Class::MethodMaker
  new_with_init => 'new',
  get_set       =>
  [

   qw / Config MyMySQL /

  ];

sub init {
  my ($self,%args) = @_;
  $specification = "
	-r			List recent events

	-s <search>		Search events

	-d <date>		Cutoff Date

	-c			Condensed Format

	-u [<host> <port>]	Run as a UniLang agent
	-w			Require user input before exiting
";
  $UNIVERSAL::systemdir = ConcatDir(Dir("internal codebases"),"elog");
  $UNIVERSAL::agent->DoNotDaemonize(1);
  $self->Config(BOSS::Config->new
		(Spec => $specification,
		 ConfFile => ""));
  my $conf = $self->Config->CLIConfig;
  if (exists $conf->{'-u'}) {
    $UNIVERSAL::agent->Register
      (Host => defined $conf->{-u}->{'<host>'} ?
       $conf->{-u}->{'<host>'} : "localhost",
       Port => defined $conf->{-u}->{'<port>'} ?
       $conf->{-u}->{'<port>'} : "9000");
  }
  $self->MyMySQL
    (PerlLib::MySQL->new
     (DBName => "elog"));

  my $cutoffdate;
  if (exists $conf->{'-d'}) {
    $cutoffdate = $conf->{'-d'};
  } else {
    $cutoffdate =  `date "+%Y-%m-%d"`;
    chomp $cutoffdate;
  }
  if (exists $conf->{'-r'}) {
    print Dumper($self->GetRecentEvents
		 (
		  Condensed => (exists $conf->{'-c'}),
		  CutoffDate => $cutoffdate,
		 ));
  } elsif (exists $conf->{'-s'}) {
    print Dumper($self->SearchEvents
		 (
		  Query => $conf->{'-s'},
		  CutoffDate => $cutoffdate,
		 ));
  }
}

sub Execute {
  my ($self,%args) = @_;
  my $conf = $self->Config->CLIConfig;
  if (exists $conf->{'-u'}) {
    # enter in to a listening loop
    while (1) {
      $UNIVERSAL::agent->Listen(TimeOut => 10);
    }
  }
  if (exists $conf->{'-w'}) {
    Message(Message => "Press any key to quit...");
    my $t = <STDIN>;
  }
}

sub ProcessMessage {
  my ($self,%args) = (shift,@_);
  my $m = $args{Message};
  my $it = $m->Contents;
  if ($it) {
    if ($it =~ /^-e\s*(.*)/) {
      my $l = $1;
      my ($epoch,@mesg) = split /\,/, $l;
      my $com = join(",",@mesg);
      my $dt = DateTime->from_epoch
	(epoch => $epoch,
	 time_zone => 'America/New_York');
      my $datetime = $dt->ymd." ".$dt->hms;
      # convert that time to something more meaningful (float-time)
      my $s = "insert into events values (NULL,'Emacs-Client','ELog',".
	$self->MyMySQL->Quote($datetime).",".
	  $self->MyMySQL->Quote($com).");";
      # print "$s\n";
      $self->MyMySQL->Do
	(Statement => $s);
    } elsif ($it =~ /^get-last-closed-buffer/) {
      my $query = "select * from events where Event like 'closed::%' order by Date desc limit 1;";
      my $res = $self->MyMySQL->Do(Statement => $query);
      my $event = $res->{[keys %$res]->[0]}->{Event};
      if ($event =~ /^(.*)::(.*)::(.*)::(.*)$/) {
	my $filename = $2;
	print $filename."\n";
	$UNIVERSAL::agent->QueryAgentReply
	  (
	   Message => $m,
	   Data => {
		    _DoNotLog => 1,
		    Results => $filename,
		   },
	  );
      }
    } elsif ($it =~ /^(quit|exit)$/i) {
      $UNIVERSAL::agent->Deregister;
      exit(0);
    } else {
      my $s = "insert into events values (NULL,".
	$self->MyMySQL->Quote($m->Sender).",".
	  $self->MyMySQL->Quote($m->Receiver).",".
	    $self->MyMySQL->Quote($m->Date).",".
	      $self->MyMySQL->Quote($m->Contents).");";
      # print "$s\n";
      $self->MyMySQL->Do
	(Statement => $s);
    }
  }
  if (exists $m->Data->{Command}) {
    my $command = $m->Data->{Command};
    if ($command =~ /^list-recent$/i) {
      $UNIVERSAL::agent->QueryAgentReply
	(
	 Message => $m,
	 Data => {
		  _DoNotLog => 1,
		  Results => $self->GetRecentEvents(%{$m->Data}),
		 },
	);
    } elsif ($command =~ /^search-events$/i) {
      $UNIVERSAL::agent->QueryAgentReply
	(
	 Message => $m,
	 Data => {
		  _DoNotLog => 1,
		  Results => $self->SearchEvents(%{$m->Data}),
		 },
	);
    }
  }
}

sub GetRecentEvents {
  my ($self,%args) = @_;
  my $cutoffdate = $args{CutoffDate} || `date "+%Y-%m-%d"`;
  chomp $cutoffdate;
  if ($args{Condensed}) {
    my @res;
    foreach my $entry (@{$self->GetRecentEventsHelper(CutoffDate => $cutoffdate)}) {
      if ($entry->[4] =~ /^(.*)::(.*)::(.*)::(.*)$/) {
	push @res, $2;
      }
    }
    return \@res;
  } else {
    $self->GetRecentEventsHelper(CutoffDate => $cutoffdate);
  }
}

sub GetRecentEventsHelper {
  my ($self,%args) = @_;
  my $cutoffdate = $args{CutoffDate};
  print "CutoffDate: $cutoffdate\n";
  return $self->MyMySQL->Do
    (
     Statement => "select * from events where Date >= '$cutoffdate'",
     Array => 1,
    );
}

sub SearchEvents {
  my ($self,%args) = @_;
  my $cutoffdate = $args{CutoffDate} || '1971-1-1';
  print "CutoffDate: $cutoffdate\n";
  return $self->MyMySQL->Do
    (
     Statement => "select * from events where Event like '%".shell_quote($args{Query})."%' and Date >= '$cutoffdate' order by Date asc;",
     Array => 1,
    );
}

1;
