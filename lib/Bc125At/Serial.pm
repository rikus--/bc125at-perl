package Bc125At::Serial;

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

# FIXME: This use line should be deleted and Device::SerialPort loaded only
# if available, but right now I don't have serial I/O working properly when
# not using Device::SerialPort, so I will force Bc125At::Serial to depend on
# it until I have a reliable alternative.
use Device::SerialPort;

my $have_io_select = eval {
    require IO::Select;
    1;
};
if ($@) {
    warn "IO::Select is not available. That's odd.\n";
}

# Device::SerialPort is actually not necessary, but it can help with some things.
my $using_device_serialport = eval {
    require Device::SerialPort;
    1;
};
if ($@) {
    warn "Device::SerialPort is not available... falling back to basic I/O.\n";
}

my $DEFAULT_TTY = '/dev/ttyACM0';

sub new {
    my ($package, $tty) = @_;

    $tty ||= $DEFAULT_TTY;

    my ($device, $fh);

    if ($using_device_serialport) {
        $device = Device::SerialPort->new($tty) or die $!;
        $device->baudrate(9600);
        $device->parity('none');
        $device->databits(8);
        $device->stopbits(2);
        $device->are_match("\r");
    }
    else {
        require IO::Handle;
        open $fh, '+<', $tty or die "couldn't open $tty\n";
    }
    my $self = {
        tty    => $tty,
        device => $device,
        fh     => $fh,
    };
    return bless $self;
}

sub write_cmd {
    my ($self, $cmd) = @_;
    if ($using_device_serialport) {
        $self->{device}->lookclear;
        $self->{device}->write($cmd . "\r") or return;
    }
    else {
        print { $self->{fh} } $cmd . "\r" or return;
        $self->{fh}->flush;
    }
    return 1;
}

sub read_response {
    my $self = shift;
    my ($rdsize, $buf) = (undef, '');
    if ($using_device_serialport) {

        #select undef, undef, undef, 0.015;
        for (1 .. 50) {

            #($rdsize, $buf) = $self->{device}->read(4096);
            $buf = $self->{device}->lookfor;
            if ($buf) { last }
            elsif (defined $buf && !$buf) {
                select undef, undef, undef, 0.001;
            }
        }
    }
    else {
        local $/ = "\r";
        $buf = readline($self->{fh});
    }
    $buf =~ s/\r$//;
    return $buf;
}

sub cmd {
    my ($self, $cmd) = @_;
    $self->write_cmd($cmd) or die $!;
    my $buf = $self->read_response();
    return $buf;
}

sub empty_buffer {
    my $self = shift;
    my $select;
    if (!$using_device_serialport) {
        $select = IO::Select->new($self->{fh});
    }
    {
        last if $select && !$select->can_read(0.1);
        my $buf = $self->read_response();
    }
}

__END__

=pod

Reference used:

http://info.uniden.com/twiki/pub/UnidenMan4/BC125AT/BC125AT_PC_Protocol_V1.01.pdf

=cut
