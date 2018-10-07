package Bc125At::Command;

# Copyright (c) 2013, Rikus Goodell.
#
# All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

use strict;
use warnings;

use Bc125At::Serial;
use Bc125At::ProgressBar;

=head1 NAME

Bc125At::Command

=head1 SYNOPSIS

my $scanner = Bc125At::Command->new();

$scanner->...

=head1 DOCUMENTED INTERFACE

These are the documented methods that may be used. There are also various
helper functions that I don't think are currently worth documenting.

=cut

sub new {
    my $self = {};
    my $ser = eval { Bc125At::Serial->new() };
    if (chomp(my $err = $@)) {
        die <<END;
Could not open serial port connection to scanner: $err

If you haven't already, try running

  bc125at-perl driver

(must be done as root)

Also, make sure the device in /dev (likely /dev/ttyACM0) is
readable/writable by the user you are running bc125at-perl as.

END
    }
    $ser->empty_buffer();    # clean out any lingering responses that will interfere with what we want to do
    $self->{serial} = $ser;
    return bless $self;
}

=head2 $scanner->begin_program()

Put the scanner into program mode.

=cut

sub begin_program {
    my ($self, $index) = @_;
    $self->{serial}->cmd('PRG');
}

=head2 $scanner->end_program()

Take the scanner out of program mode.

=cut

sub end_program {
    my ($self, $index) = @_;
    $self->{serial}->cmd('EPG');
}

sub get_channel_info {
    my ($self, $index) = @_;
    for my $try (1 .. 3) {
        my $channel_info = eval {
            my $ci = _parse_channel_info($self->{serial}->cmd('CIN,' . $index));
            _validate_info([$ci]);
            die "sanity failure: $ci->{index} != $index" if $ci->{'index'} != $index;
            $ci;
        };
        if ($@) {
            warn "\nchannel $index try $try/3: $@\n";
            next;
        }
        return $channel_info;
    }
    die "\nGave up on channel $index after 3 tries\n";
}

sub get_search_group_info {
    my ($self, $index) = @_;
    my $search_group_info = _parse_search_group_info($self->{serial}->cmd('CSP,' . $index));
    return $search_group_info;
}

sub run_cmds {
    my ($self, $cmds, $progress_callback) = @_;
    my $size = @$cmds;
    my $progress = Bc125At::ProgressBar->new(max => $size, redisplay => _max(int($size / 40), 1), callback => $progress_callback);
    my $failed;
    CMD:
    for my $cmd (@$cmds) {
        my $okay = 0;
        my $err;
        TRY: for my $try (1 .. 3) {
            my $ret = $self->{serial}->cmd($cmd);
            $err .= "$!\n" if $!;
            if (!$ret || $ret =~ /^(?:ERR|\w+,NG)/) {
                print "\nRunning '$cmd' failed: $ret\n";
                $err .= "$ret\n" if $ret;
            }
            else {
                $okay = 1;
                last TRY;
            }
        }
        die "gave up on '$cmd' after 3 tries:\n$err\n" unless $okay;
        $progress->more();
    }
    return 1;
}

=head2 $scanner->get_all_channel_info()

Query the scanner for the complete list of channels.
Returns an array ref of 500 hash refs each of which
describes one channel.

Optional boolean parameter may be set to enable
"impatient" mode.

=cut

sub get_all_channel_info {
    my ($self, $impatient, $progress_callback) = @_;
    my @info;
    my $zeros;
    print "Reading channnels from scanner ...\n";
    my $progress = Bc125At::ProgressBar->new(max => 500, redisplay => 12, callback => $progress_callback);
    for my $n (1 .. 500) {
        my $thischannel = $self->get_channel_info($n);
        if (_freq_is_unset($thischannel->{frq})) {
            last if ++$zeros == 10 && $impatient;
        }
        else {
            $zeros = 0;
        }
        $thischannel->{frq} = _human_freq($thischannel->{frq});
        $progress->more();
        push @info, $thischannel;
    }
    print "Done!\n";
    return \@info;
}

=head2 $scanner->get_all_search_group_info()

Query the scanner for the complete list of all search groups.
Returns an array ref of 10 hash refs, each of which describes
one search group.

=cut

sub get_all_search_group_info {
    my $self = shift;
    print "Reading search group info from scanner ...\n";
    my $progress = Bc125At::ProgressBar->new(max => 10, redisplay => 1);
    my $info = [
        map {
            my $sg = $self->get_search_group_info($_);
            $progress->more();
            $sg;
          } 1 .. 10
    ];
    print "Done!\n";
    return $info;
}

sub _freq_is_unset {
    return $_[0] eq '00000000' || $_[0] eq '0.000';
}

sub _parse_channel_info {
    my $unparsed = shift;    # CIN,400,,00000000,AUTO,0,2,1,0
    my %parsed;
    @parsed{ _keys('channel') } = split /,/, $unparsed;
    return \%parsed;
}

sub _parse_search_group_info {
    my $unparsed = shift;    # CSP,1,01180000,01400000
    my %parsed;
    @parsed{ _keys('search') } = split /,/, $unparsed;
    return \%parsed;
}

sub _keys {
    my $type = shift;
    return qw(cmd index name frq mod ctcss_dcs dly lout pri) if $type eq 'channel';
    return qw(cmd index frq_l frq_h)                         if $type eq 'search';
    die;
}

# Avoid depending on Data::Dumper, and allow more useful formatting
sub dumper {
    my ($file, $info, $type) = @_;
    open my $fh, '>', $file or die $!;
    print {$fh} "[\n";
    for my $h (@$info) {
        print {$fh} "    {\n" or die $!;
        for my $k (_keys($type)) {
            my $pad = ' ' x (9 - length($k));
            print {$fh} "        $pad$k => '$h->{$k}',\n";
        }
        print {$fh} "    },\n";
    }
    print {$fh} "]\n";
    close $fh or die $!;
}

sub undumper {
    my ($file) = shift;
    open my $fh, '<', $file or die $!;
    my $text;
    {
        local $/;
        defined($text = <$fh>) or die $!;
    }
    close $fh or die $!;
    my $info = eval $text or die $!;    # XXX insecure, so don't load files from untrusted sources
    return $info;
}

sub compose_multi_channel_info {
    my ($info) = @_;
    my @cmds;
    for my $h (@$info) {
        push @cmds, _compose_channel_info($h);
    }
    return \@cmds;
}

sub compose_multi_search_group_info {
    my ($info) = @_;
    my @cmds;
    for my $h (@$info) {
        push @cmds, _compose_search_group_info($h);
    }
    return \@cmds;
}

=head2 $scanner->write_channels('filename.txt')

Reads the specified file containing channel information
and writes the channels to the scanner. The file must
contain a serialized representation of the same type of
data structure returned by $scanner->get_all_channel_info().
(The easiest way to construct proper input for
write_channels is to get some sample output from
get_all_channel_info.)

=cut

sub write_channels {
    my ($self, $file, $info, $progress_callback) = @_;
    if (!$info) {
        $info = undumper($file);
    }
    _validate_info($info);
    my $cmds = compose_multi_channel_info($info);
    print "Writing channels to scanner ...\n";
    $self->run_cmds($cmds, $progress_callback);
    print "Done!\n";
}

=head2 $scanner->write_search_groups('filename.txt');

Reads the specified file containing search group information
and writes the search groups to the scanner. The file must
contain a serialized representation of the same type of data
structure returned by $scanner->get_all_search_group_info().

=cut

sub write_search_groups {
    my ($self, $file) = @_;
    my $info = undumper($file);
    my $cmds = compose_multi_search_group_info($info);
    print "Writing search groups to scanner ...\n";
    $self->run_cmds($cmds);
    print "Done!\n";
}

sub _validate_info {
    my $info = shift;
    for my $h (@$info) {
        for my $k (keys %$h) {
            if (!defined $h->{$k}) {
                die "$k is not defined; parsed channel info is corrupt\n";
            }
        }
        if (length($h->{name}) > 16) {
            die "Name $h->{name} is too long. Max length is 16.\n";
        }
    }
}

sub _human_freq {
    my $freq = shift;
    if ($freq =~ /^\d{4}\d{4}$/) {
        my $fmt = sprintf "%.4f", $freq / 10_000;
        $fmt =~ s/0$//;
        return $fmt;
    }
    die "input '$freq' was not as expected";
}

sub _nonhuman_freq {
    my $freq = shift;
    if (_is_human($freq)){
        return sprintf "%08d", $freq * 10_000;
    }
    die "input '$freq' was not as expected";
}

sub _compose_channel_info {
    my $parsed   = shift;
    my $massaged = _massage($parsed);
    my $composed = join ',', @$massaged{ _keys('channel') };
    return $composed;
}

sub _compose_search_group_info {
    my $parsed   = shift;
    my $massaged = _massage($parsed);
    my $composed = join ',', @$massaged{ _keys('search') };
    return $composed;
}

sub _massage {
    my $parsed   = shift;
    my $massaged = {%$parsed};
    for my $k (keys %$massaged) {
        if ($k eq 'name' && !$massaged->{$k}) {
            $massaged->{$k} = ' ' x 16;    # some amount of whitespace is apparently required to erase existing channel names
        }
        if ($k =~ m{^frq} && _is_human($massaged->{$k})){
            $massaged->{$k} = _nonhuman_freq($massaged->{$k});
        }
    }
    return $massaged;
}

sub _is_human { $_[0] =~ /^\d+\.\d+$/ or $_[0] =~ /^\d{1,4}$/ }

sub _max {
    my ($x, $y) = @_;
    return $x > $y ? $x : $y;
}

sub _empty_rowinfo {
    my @args = @_;
    return {
        cmd       => 'CIN',
        index     => undef,
        name      => ' ' x 16,
        frq       => '000.000',
        mod       => 'AUTO',
        ctcss_dcs => '0',
        dly       => '2',
        lout      => '1',
        pri       => '0',
        @args
    };
}

sub load_channels {
    my $file = shift;
    open my $fh, '<', $file;
    chomp(my $firstline = <$fh>);
    if ($firstline =~ /^\[$/){
        close $fh;
        return undumper($file);
    }
    elsif($firstline =~ /^\d+\.\d+$/){
        my @info = (_empty_rowinfo('index' => 1, frq => $firstline, lout => 0));
        for(my $index = 2; $index <= 500 && chomp(my $line = <$fh>); $index++){
            die "whoops, wasn't expecting that: $line\n" if $line !~ /^\d+\.\d+$/;
            push @info, _empty_rowinfo('index' => $index, frq => $line, lout => 0);
        }
        die "too much!\n" if @info > 500;
        return \@info;
    }
}

sub jump_to_channel {
    my ($self, $channel) = @_;
    my @channel_keys = split //, $channel;
    my @cmds = map {
        join(',', 'KEY', $_, 'P')
    } 'S', 'H', @channel_keys, 'H';
    $self->run_cmds(\@cmds);
}

sub jump_to_frequency {
    my ($self, $channel) = @_;
    my @channel_keys = split //, $channel;
    my @cmds = map {
        join(',', 'KEY', $_, 'P')
    } 'R', 'H', @channel_keys, 'H';
    $self->run_cmds(\@cmds);
}

1;
