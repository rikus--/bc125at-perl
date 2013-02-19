package Bc125At::GUI::Auto;

=pod

An automated system for unattended scanning and searching which keeps
a record of the channels/frequencies on which activity is identified.
This may be used to construct a list of "most interesting" frequencies.

How it works:

Individually iterate through all channels, and after jumping to each one,
listen on /dev/dsp for audio. Give the received audio a kind of "score"
(using Bc125At::Heuristics) as to how likely it is to be traffic. Keep
a log of each timestamp, channel, and score, which may then be
postprocessed in order to construct a list of interesting channels.

=cut

BEGIN { die if !$INC{'Bc125At/GUI.pm'} }
use Bc125At::Heuristics;
use Bc125At::GUI::ErrorDialog 'do_or_alert';

use Gtk2;

use strict;
use warnings;

sub new {
     my ($package, $gui) = @_;
     my $self = {};
     $self->{gui} = $gui;
     $self->{window} = Gtk2::Window->new();
     $self->{parent} = $self->{gui}->{window};
     bless $self;
     $self->_setup_widgets;
     $self->{window}->show_all;
     return $self, $package;
}

sub _setup_widgets {
    my $self = shift;
    my $vbox = Gtk2::VBox->new;
    my $hbox = Gtk2::HBox->new;
    $hbox->add(Bc125At::GUI::_button("auto search", sub { $self->auto_search } ));
    $hbox->add(Bc125At::GUI::_button("auto scan", sub { $self->auto_scan } ));
    $hbox->add(Bc125At::GUI::_button("stop", sub { $self->stop } ));
    $hbox->set_size_request(400,25);
    my $hbox2 = Gtk2::HBox->new;
    my $hbox3 = Gtk2::HBox->new;
    my $hbox4 = Gtk2::HBox->new;

    $self->{dpbthreshold} = Gtk2::Entry->new();
    $self->{dpbthreshold}->set_text('1.25');
    $hbox2->add(Gtk2::Label->new("dpb threshold (min 0.0, max 127.0):"));
    $hbox2->add($self->{dpbthreshold});

    $self->{minsearchfreq} = Gtk2::Entry->new();
    $self->{minsearchfreq}->set_text('400.000');
    $hbox3->add(Gtk2::Label->new("min search freq:"));
    $hbox3->add($self->{minsearchfreq});

    $self->{maxsearchfreq} = Gtk2::Entry->new();
    $self->{maxsearchfreq}->set_text('480.000');
    $hbox3->add(Gtk2::Label->new("max search freq:"));
    $hbox3->add($self->{maxsearchfreq});

    $self->{freqstep} = Gtk2::Entry->new();
    $self->{freqstep}->set_text('0.00625');
    $hbox4->add(Gtk2::Label->new("freq step:"));
    $hbox4->add($self->{freqstep});

    $self->{randomfreqs} = Gtk2::CheckButton->new();
    $hbox4->add(Gtk2::Label->new("random freqs:"));
    $hbox4->add($self->{randomfreqs});

    my $status = Gtk2::Label->new();
    $vbox->add($hbox);
    $vbox->add($hbox2);
    $vbox->add($hbox3);
    $vbox->add($hbox4);
    $vbox->add($status);
    $self->{status} = $status;
    $self->{window}->add($vbox);
}

sub get_dpb_threshold {
    my $self = shift;
    return $self->{dpbthreshold}->get_text();
}

sub min_search_freq {
    my $self = shift;
    return $self->{minsearchfreq}->get_text();
}

sub max_search_freq {
    my $self = shift;
    return $self->{maxsearchfreq}->get_text();
}

sub freq_step {
    my $self = shift;
    return $self->{freqstep}->get_text();
}

sub random_freqs {
    my $self = shift;
    return $self->{randomfreqs}->get_active();
}

sub auto_scan {
    my $self = shift;
    my $info;
    do_or_alert {
        $info = $self->{gui}->harvest_table();
        die "Please load channels from scanner before running auto scan\n" if !$info->[0]{frq};
    } "Problem";

    $self->{info} = $info;
    #$self->{gui}->add_spare_time_action('autoscan', sub { $self->auto_scan_iteration() }); # works but results in slow scanning

    $self->auto_scan_iteration(1);
    $self->{autoscan} = 1;
    while ($self->{autoscan}){
        $self->auto_scan_iteration();
        _yield_to_gtk2();
    }
}

sub auto_scan_iteration {
    my ($self, $ch) = @_;
    my $t = time;
    if ($ch){
        $self->set_channel($ch) or return;
    }
    else {
        $self->next_channel or return;
    }

    select undef, undef, undef, 0.2; # avoid smearing channels together...

    #my $data = Bc125At::Heuristics::grab_persistent(3_000); # Doesn't work -- gets out of sync

    my $data = Bc125At::Heuristics::grab(3_000); # Slower, but works

    my $dpb = Bc125At::Heuristics::judge($data);
    my $report = [$t, $self->get_channel, $dpb];
    push @{$self->{history}}, $report if $dpb > $self->get_dpb_threshold();

# lazy sloppy output until I decide what kind of interface to add for this
use Data::Dumper;
print Dumper $self->{history};
open my $wr, '>>', 'auto_scan_report.txt';
print {$wr} join("\t", @$report) . "\n";
close $wr;

}

sub auto_search {
    my $self = shift;
    my $info;

    $self->auto_search_iteration($self->min_search_freq);
    $self->{autosearch} = 1;
    while ($self->{autosearch}){
        $self->auto_search_iteration();
        _yield_to_gtk2();
    }
}

sub auto_search_iteration {
    my ($self, $frq) = @_;
    my $t = time;
    if ($frq){
        $self->set_frequency($frq) or return;
    }
    elsif($self->random_freqs){
        $self->next_random_frequency or return;
    }
    else {
        $self->next_frequency or return;
    }

    select undef, undef, undef, 0.2; # avoid smearing frequencies together...

    my $data = Bc125At::Heuristics::grab(3_000); # Slower, but works

    my $dpb = Bc125At::Heuristics::judge($data);
    my $report = [$t, $self->get_frequency, $dpb];
    push @{$self->{search_history}}, $report if $dpb > $self->get_dpb_threshold();

use Data::Dumper;
print Dumper $self->{search_history};
open my $wr, '>>', 'auto_search_report.txt';
print {$wr} join("\t", @$report) . "\n";
close $wr;

}

sub set_frequency {
    my ($self, $frq) = @_;
    $self->{as_frq} = $frq;
    my $found = @{$self->{search_history} || []};

    # avoid alert box here in order to allow recovery during unattended operation
    eval {
        $self->{gui}{scanner}->jump_to_frequency(fmt_frq($frq));
    };
    my $err = $@;

    $self->set_status(
<<END
<b>
<span size="xx-large">
---------------------------
Searching...
@{[fmt_frq($frq)]} MHz

$found hits so far
---------------------------
</span>
</b>
$err
END
);
    if ($err){
        select undef, undef, undef, 0.4; # avoid looping too fast on failure
        return;
    }
    return 1;
}

sub set_channel {
    my ($self, $ch) = @_;
    $self->{as_ch} = $ch;
    my $freq = $self->{info}[$ch - 1]{frq} || '0.000';
    return if $freq == 0;
    my $name = $self->{info}[$ch - 1]{name} || '';
    my $found = @{$self->{history} || []};

    # avoid alert box here in order to allow recovery during unattended operation
    eval {
        $self->{gui}{scanner}->jump_to_channel($ch);
    };
    my $err = $@;

    $self->set_status(
<<END
<b>
<span size="xx-large">
---------------------------
Scanning...
Ch.$ch
$freq MHz
$name

$found hits so far
---------------------------
</span>
</b>
$err
END
);
    if ($err){
        select undef, undef, undef, 0.4; # avoid looping too fast on failure
        return;
    }
    return 1;
}

sub get_frequency {
    my $self = shift;
    return $self->{as_frq};
}

sub get_channel {
    my $self = shift;
    return $self->{as_ch};
}

sub next_frequency {
    my $self = shift;
    my $frq = $self->get_frequency;
    return $self->set_frequency($self->min_search_freq) if $frq >= $self->max_search_freq;  # TODO: Skip gaps between covered bands
    $frq += $self->freq_step;
    return $self->set_frequency($frq);  # TODO: Automatically use the correct per-band frequency step size instead
}

sub next_random_frequency {
    my $self = shift;
    my $new_frq;
    {
        $new_frq = $self->min_search_freq() + int(rand(($self->max_search_freq() - $self->min_search_freq()))) + $self->freq_step * int rand 1_000;
        redo if $new_frq > $self->max_search_freq();
    }
    return $self->set_frequency($new_frq);
}

sub next_channel {
    my $self = shift;
    my $ch = $self->get_channel;
    return $self->set_channel(1) if $ch == 500;
    return $self->set_channel($ch + 1);
}

sub set_status {
    my ($self, $text) = @_;
    $self->{status}->set_markup($text);
    _yield_to_gtk2();
}

sub _yield_to_gtk2 {
    my $gui_it;
    Gtk2->main_iteration while Gtk2->events_pending && ++$gui_it < 200;
}

sub fmt_frq { sprintf("%.4f", shift) }

sub stop {
    my $self = shift;
    delete $self->{autoscan};
    delete $self->{autosearch};
}

1;
