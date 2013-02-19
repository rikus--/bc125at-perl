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
    $self->{dpbthreshold} = Gtk2::Entry->new();
    $self->{dpbthreshold}->set_text('1.25');
    $hbox2->add(Gtk2::Label->new("dpb threshold (min 0.0, max 127.0):"));
    $hbox2->add($self->{dpbthreshold});
    my $status = Gtk2::Label->new();
    $vbox->add($hbox);
    $vbox->add($hbox2);
    $vbox->add($status);
    $self->{status} = $status;
    $self->{window}->add($vbox);
}

sub get_dpb_threshold {
    my $self = shift;
    return $self->{dpbthreshold}->get_text();
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

sub get_channel {
    my $self = shift;
    return $self->{as_ch};
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

sub stop {
    my $self = shift;
    delete $self->{autoscan};
    delete $self->{autosearch};
}

sub auto_search {
    do_or_alert { die "Not implemented yet\n" } "Oops";
}

1;
