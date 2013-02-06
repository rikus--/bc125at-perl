package Bc125At::Command;

# Copyright (c) 2013 Rikus Goodell. All Rights Reserved.
# This software is distributed free of charge and comes with NO WARRANTY.

use strict;
use warnings;

use Bc125At::Serial;
use Bc125At::ProgressBar;

sub new {
    my $self = {};
    my $ser = Bc125At::Serial->new();
    $ser->empty_buffer(); # clean out any lingering responses that will interfere with what we want to do
    $self->{serial} = $ser;
    return bless $self;
}

sub begin_program {
    my ($self, $index) = @_;
    $self->{serial}->cmd('PRG');
}

sub end_program {
    my ($self, $index) = @_;
    $self->{serial}->cmd('EPG');
}

sub get_channel_info {
    my ($self, $index) = @_;
    my $channel_info = _parse_channel_info($self->{serial}->cmd('CIN,' . $index));
    _validate_info([$channel_info]);
    return $channel_info;
}

sub run_cmds {
    my ($self, $cmds) = @_;
    my $size = @$cmds;
    my $progress = Bc125At::ProgressBar->new(max => $size, redisplay => $size / 20);
    my $failed;
    for my $cmd (@$cmds){
        my $ret = $self->{serial}->cmd($cmd);
        if ($ret =~ /^ERR/){
            print "\n\n $ret\n\n";
            $failed++;
	}
	$progress->more();
    }
    return $failed ? (0, "$failed / $size commands failed\n") : (1, "All $size operations succeeded");
}

sub get_all_channel_info {
    my ($self, $impatient) = @_;
    my @info;
    my $zeros;
    print "Reading channnels from scanner ...\n";
    my $progress = Bc125At::ProgressBar->new(max => 500, redisplay => 25);
    for my $n (1 .. 500){
        my $thischannel = $self->get_channel_info($n);
        if ($thischannel->{frq} eq '00000000'){
            last if ++$zeros == 10 && $impatient;
        }
        else {
            $zeros = 0;
        }
	$progress->more();
        push @info, $thischannel;
    }
    print "Done!\n";
    return \@info;
}

sub _parse_channel_info {
    my $unparsed = shift; # CIN,400,,00000000,AUTO,0,2,1,0
    my %parsed;
    @parsed{qw(cmd index name frq mod ctcss_dcs dly lout pri)} = split /,/, $unparsed;
    return \%parsed;
}

# Avoid depending on Data::Dumper, and allow more useful formatting 
sub dumper {
    my ($file, $info) = @_;
    open my $fh, '>', $file or die $!;
    print {$fh} "[\n";
    for my $h (@$info){
        print {$fh} "    {\n";
        for my $k (qw(cmd index name frq mod ctcss_dcs dly lout pri)){
            my $pad = ' ' x (9 - length($k));
            my $addl = $k eq 'frq' ? ' # ' . _human_freq($h->{$k}) : '';
            print {$fh} "        $pad$k => '$h->{$k}',$addl\n";
        }
        print {$fh} "    },\n";
    }
    print {$fh} "]\n";
}

sub undumper {
        my ($file) = shift;
        open my $fh, '<', $file or die $!;
        my $text;
        {
            local $/;
            $text = <$fh>;
        }
        close $fh;
        my $info = eval $text; # XXX insecure, so don't load files from untrusted sources
        warn $@ and return if $@;
        return $info;
}

sub compose_multi_channel_info {
    my ($info) = @_;
    my @cmds;
    for my $h (@$info){
        push @cmds, _compose_channel_info($h);
    }
    return \@cmds;
}

sub write_channels {
    my ($self, $file) = @_;
    my $info = undumper($file);
    _validate_info($info);
    my $cmds = compose_multi_channel_info($info);
    print "Writing channels to scanner ...\n";
    my ($status, $msg) = $self->run_cmds($cmds);
    print "Done! $msg\n";
}

sub _validate_info {
    my $info = shift;
    for my $h (@$info){
        for my $k (keys %$h){
		if (!defined $h->{$k}){
			die "$k is not defined; parsed channel info is corrupt\n";
		}
	}
        if (length($h->{name}) > 16){
            die "Name $h->{name} is too long. Max length is 16.\n";
        }
    }
}

sub _human_freq {
    my $freq = shift;
    if ($freq =~ /^\d{4}\d{4}$/){
        my $fmt = sprintf "%.4f", $freq / 10_000;
        $fmt =~ s/0$//;
        return $fmt;
    }
    return;
}

sub _compose_channel_info {
    my $parsed = shift;
    my $composed = join ',', @$parsed{qw(cmd index name frq mod ctcss_dcs dly lout pri)};
    return $composed;
}

1;
