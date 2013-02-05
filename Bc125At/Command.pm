package Bc125At::Command;

# Copyright (c) 2013 Rikus Goodell. All Rights Reserved.
# This software is distributed free of charge and comes with NO WARRANTY.

use strict;
use warnings;

use Bc125At::Serial;

sub new {
    my $self = {};
    my $ser = Bc125At::Serial->new();
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
    return _parse_channel_info($self->{serial}->cmd('CIN,' . $index));
}

sub run_cmds {
    my ($self, $cmds) = @_;
    for my $cmd (@$cmds){
        print "$cmd ...";
        my $ret = $self->{serial}->cmd($cmd);
        print " $ret\n";
    }
}

sub get_all_channel_info {
    my ($self, $impatient) = @_;
    my @info;
    my $zeros;
    for my $n (1 .. 500){
        local $| = 1;
        print STDERR ".";
        print STDERR "\n" if $n % 50 == 0;
        my $thischannel = $self->get_channel_info($n);
        if ($thischannel->{frq} eq '00000000'){
            last if ++$zeros == 10 && $impatient;
        }
        else {
            $zeros = 0;
        }
        push @info, $thischannel;
    }
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
    $self->run_cmds($cmds);
}

sub _validate_info {
    my $info = shift;
    for my $h (@$info){
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
