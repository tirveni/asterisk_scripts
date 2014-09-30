#!/usr/bin/perl -w
#
#
#    Copyright (C) 2011, Tirveni Yadav <tirveni@udyansh.org>
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#
#
#
#
#TODO:
#Config file Need to parameter-ize so that this can be used at other centres.
#Functions: And create functions which can also be used.
#

use strict;
use warnings;

use Getopt::Long;
use POSIX;

=head1 pri_monitor.pl

This perl program get the status of each PRI.
Number of Outgoing & Dialing for each PRI.

Writes to the log /var/log/primonitor

=cut

=head2 Total channels in a PRI

PRI CHANNELS: EU Std.

30 B Channels : data/voice at bit rate of 64kbps

01 D Channel  : Control & Signalling info.

=cut

my $total_channels_in_a_pri=30;

=head2  Total PRI possible for each redfone

Total number of PRI  for each redfone

=cut

my $total_pri_in_redfone = 4;

=head1 OPTIONS

=over

=item B<<< --log logfile >>>

Append output to file I<logfile> instead of to STDOUT.

=item B<<< --sleep seconds >>>

Go into a loop, sleeping for I<seconds> seconds before re-examining
the Asterisk PRI status.

=end

=cut

my
  $log_file = undef;
my
  $sleep = 0;
GetOptions(
	   'log:s' => \$log_file,
	   'sleep:i' => \$sleep,
	  );
#
# Try to open the log file if specified, STDOUT otherwise.
#
my
  $LOG = \*STDOUT;
if( $log_file )
{
  open($LOG, ">$log_file")
    or die "$0: unable to open $log_file for writing: $!";
}
#
#Intitialize all the hashes and the arrays
my @all_pri_spans	= `asterisk -rnx 'pri show spans' `;
my $avail_total_pris	= @all_pri_spans; 
$avail_total_pris	= $avail_total_pris+1;

##Needed if a redfone has been disabled.                                                                                                                     
my $in_num_redfones =0;
$in_num_redfones = int($ARGV[0]) if($ARGV[0]);
#print  "REDFONEx:$in_num_redfones";                                                                                                                         

$avail_total_pris = ($in_num_redfones*4) if(int($in_num_redfones));


$| = 1;

#START WHILE
do
{
  my
    @time = localtime;
  my
    $date = strftime( '%F %T', @time[0..5]);
  #A. Get All the channels in verbose and store it in an array
  my @all_channels=`asterisk -rnx 'core show channels verbose'` ;
  #Array of  dialing and outgoing channels
  my @channels_dialing;
  my @channels_outgoing;
  #Calls filtered in these hashes(Outgoing, Dialing)
  my %calls_outgoing;
  my %calls_dialing;
  #
  my %pri_status_up;
  my @pri_list;
  foreach my $a( 1..($avail_total_pris - 1) )
  {
    $calls_outgoing{$a} = 0;
    $calls_dialing{$a} = 0;
    $pri_status_up{$a} = '-';
    push(@pri_list, $a);
  }
  #
  #PRI STATUS
  #
  my
    @all_pris = grep(/Active/, @all_pri_spans);
  my
    $active_pris = 0;
  #
  # Print PRI status
  foreach my $p( @all_pris )
  {
    $p =~ /PRI span (\d+)\/.*/;
    my
      $pri_number = $1;
    #
    # Get PRI status
    if( $p =~ /In Alarm/ )
    {
      $pri_status_up{$pri_number} = '-';
    }
    elsif( $p =~ /Down, Active/ )
    {
      $pri_status_up{$pri_number} = '.';
    }
    else
    {
      $pri_status_up{$pri_number} = '+';
      $active_pris++;
    }
  }
  #
  #OUTGOING CALLS: ACTIVE
  #
  my $outgoing_expr= "Outgoing";
  my @all_outgoing = grep(/$outgoing_expr/i, @all_channels);
  foreach my $call (@all_outgoing)
  {
    my @arr_a = split(/ /, $call);
    my $first_word = $arr_a[0];
    #       print "FW: $first_word ";

    my @arr_b = split(/\//, $first_word);
    my $s_w = $arr_b[1];
    #       print "SW: $s_w ";

    my @arr_c = split(/-/, $s_w);
    my $a = $arr_c[0];
    my $channel = 0;
    $channel = int($a)
      if ($a =~ /^\d+$/ );
    #       print "channel: $channel ";
    push(@channels_outgoing,$channel);

    my $pri = get_pri_from_channel($channel);
    #       print "PRI: $pri ";
    $calls_outgoing{$pri}++; 
    #       print " \n ";

  }
  #
  #DIALING
  #
  my $dialing_expr= "Dialing";
  my @all_dialing = grep(/$dialing_expr/i,@all_channels); 

  foreach my $call (@all_dialing)
  {
    my @arr_a = split(/ /, $call);
    my $first_word = $arr_a[0];
    #       print "FW: $first_word ";

    my @arr_b = split(/\//, $first_word);
    my $s_w = $arr_b[1];
    #       print "SW: $s_w ";

    my @arr_c = split(/-/, $s_w);
    my $a = $arr_c[0];
    my $channel = 0;
    $channel = int($a)
      if ($a =~ /^\d+$/ );
    #       print "channel: $channel ";
    push(@channels_dialing,$channel);

    my $pri = get_pri_from_channel($channel);
    #       print "PRI: $pri ";
    $calls_dialing{$pri}++; 
    #       print " \n ";
  }

=head2 DISPLAY SECTION: REPORT

=cut

  print $LOG "LEGENDS i:in-progress, d:dialing \n";

  #foreach my $pri (sort keys %calls_outgoing)
  my
    $text = '';
  my
    $rf_calls = 0;
  my
    $rf_dialing = 0;
  my
    $total_calls = 0;
  my
    $total_dialing = 0;
  my
    $active_pri_count = 0;
  foreach my $pri( @pri_list )
  {
    my $calls       = $calls_outgoing{$pri};
    my $dialing     = $calls_dialing{$pri} || 0;
    my $pri_status  = $pri_status_up{$pri};

    $pri = sprintf("%02d", $pri);
    $text .= sprintf( "$date $pri:$pri_status  i:%02d + d:%02d = %02d\n",
		      $calls, $dialing, $calls + $dialing);
    $active_pri_count++;
    $rf_calls += $calls;
    $rf_dialing += $dialing;

    my $redfone_device = int($pri/ $total_pri_in_redfone);
    if ( ($pri % $total_pri_in_redfone) == 0 )
    {
      print $LOG sprintf( "$date *** RF $redfone_device i:%03d + d:%03d = %03d\n",
			  $rf_calls, $rf_dialing,
			  $rf_calls + $rf_dialing);
      print $LOG $text;
      $text = '';
      $total_calls += $rf_calls;
      $total_dialing += $rf_dialing;
      $rf_calls = $rf_dialing = 0;
    }
  }
  #DISPLAY Total
  {
    print $LOG "-----------------------------------------\n";
    print $LOG "$date TOTAL:$active_pri_count \t ACTIVE:$active_pris" 
      ." \t i:$total_calls \t d:$total_dialing   \n";
  }

=head2 Problem Channels

Get the channels which are in Dialing and Outgoing both

=cut

  my @problem_channels = intersection (\@channels_dialing, \@channels_outgoing);
  my @sorted_problem_channels = sort_array(\@problem_channels);

  if (@sorted_problem_channels)
  {
    print $LOG "Channels(PRI): ";
    foreach my $ch (@sorted_problem_channels)
    {
      my $pri = get_pri_from_channel($ch); 
      print $LOG "$ch($pri), ";
    }
    print $LOG "   \n";
  }

  #END THE DISPLAY PART
  print $LOG "==========================================\n";

  #SLEEP
  sleep($sleep);
} while ( $sleep );
  #END WHILE LOOP

  #
  #Close the file handle for LOG
  close $LOG;

#
#------------------------------------------------------------------------
#

#
#Private Functions

=head2 get_pri_from_channel( $channel )

returns the PRI of the channel

=cut

sub get_pri_from_channel
{
	my $channel = shift;
	my $pri = int( ($channel / $total_channels_in_a_pri) + 1) ;

	return $pri;
}

=head2 intersection(\@a,\@b)

This Fn finds element which are in both arrays only.
Intersection of two arrays.

=cut

sub intersection 
{
  my $a     = shift;
  my $b     = shift;
  my %union = ();
  my %isect = ();

  my @intersect;
  foreach my $e (@$a)
  {
    $union{$e} = 1;
  }

  foreach my $e (@$b)
  {
    if ( $union{$e} )
    {
      $isect{$e} = 1;
    }
  }
  @intersect = keys %isect;

}

=head2 sort_array(\@array,[$reverse_sort])

This Fn returns an array Sorted .

=cut

sub sort_array 
{
  my $input   = shift;
  my $reverse = shift;
  my @sorted;

  if ($reverse)
  {
    @sorted = reverse sort { $a cmp $b } @$input;
  }
  else
  {
    @sorted = sort { $a cmp $b } @$input;
  }

  return @sorted;

}


