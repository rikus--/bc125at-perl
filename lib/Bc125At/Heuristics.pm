package Bc125At::Heuristics;

use strict;
use warnings;

=head1 NAME

Bc125At::Heuristics

=head1 DESCRIPTION

A polite way of saying "stupid analysis"

=head1 SUBROUTINES

=head2 judge()

Accepts one scalar ref: Points to a string containing raw oss dsp data from /dev/dsp. This
data may be of any length, but I expect that about 1/8 to 1/4 of a second worth of data
would be the ideal amount.

Returns an arbitrary but comparable numeric value which which may be used to determine how "non-silent"
a signal is. This is NOT a squelch function, but rather a crude way of detecting when the squelch has
been opened. The higher the value, the more likely that a signal is being detected. It cannot, however,
distinguish between noise/interference and meaningful signals; it relies on the scanner's squelch
setting to silence noise.

=cut

sub judge {
    my $data_ref = shift;
    ref $data_ref eq 'SCALAR' or die;
    my $sum = 0;
    for (split //, $$data_ref){
        my $c = ord $_;
        my $value = abs($c - 127);
        $sum += $value;
    }
    my $depth_per_byte = $sum / length($$data_ref);
    return $depth_per_byte;
}

=head2 grab()

Grab a certain amount of raw oss dsp data from /dev/dsp. Takes an optional scalar value
indicating how many bytes to grab. Defaults to 20,000. Returns the data as a scalar ref.

=cut

sub grab {
    my $howmuch = shift;
    $howmuch ||= 20_000;
    open my $dsp, '<', '/dev/dsp' or warn "Couldn't open /dev/dsp: $!" and return;
    my $data;
    read $dsp, $data, $howmuch;
    close $dsp;
    return \$data;
}

# Need to figure out: Does this still do what I want it to if the device is left open, or does it get out of
# sync with the present time if reads fall behind? From some basic testing, it seems like the answer is that
# no, it doesn't stay in sync, so I will have to use the plain grab() function above, which is considerably
# slower from having to re-open the device every time.
my $persist_dspdev;
sub grab_persistent {
    my $howmuch = shift;
    $howmuch ||= 20_000;
    if (!$persist_dspdev){
        open $persist_dspdev, '<', '/dev/dsp' or warn "Couldn't open /dev/dsp: $!" and return;
    }
    my $data;
    read $persist_dspdev, $data, $howmuch;
    return \$data;
}

1;
