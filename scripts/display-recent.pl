#!/usr/bin/perl -w

# this displays the last several unilang-client entries

use BOSS::Config;
use PerlLib::MySQL;

use Data::Dumper;

$specification = q(
	-n <depth>	Number or results to include in search
);

my $config =
  BOSS::Config->new
  (Spec => $specification);
my $conf = $config->CLIConfig;

my $number = $conf->{'-n'} || 50;
my $mysql = PerlLib::MySQL->new
  (DBName => "elog");
my $id = $mysql->GetHighestID(Table => "events");
if ($id) {
  my $ret = $mysql->Do
    (Statement => "select *,UNIX_TIMESTAMP(Date) from events where ID > ".($id - $number));
  foreach my $k1 (sort {$ret->{$a}->{'UNIX_TIMESTAMP(Date)'} <=>
			  $ret->{$b}->{'UNIX_TIMESTAMP(Date)'}} keys %$ret) {
      print "$k1\t".$ret->{$k1}->{Event}."\n";
  }
}
