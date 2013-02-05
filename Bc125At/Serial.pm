package Bc125At::Serial;

# Copyright (c) 2013 Rikus Goodell. All Rights Reserved.
# This software is distributed free of charge and comes with NO WARRANTY.

use strict;
use warnings;

use Device::SerialPort;

my $TTY = '/dev/ttyUSB0';

sub new {
	my $device = Device::SerialPort->new($TTY) or die $!;
	$device->baudrate(9600);
	$device->parity('none');
	$device->databits(8);
	$device->stopbits(2);
        my $self = {};
        $self->{device} = $device;
        return bless $self;
}

sub cmd {
	my ($self, $cmd) = @_;
        my $wrsize = $self->{device}->write($cmd . "\r");
        die $! if !$wrsize;
        select undef, undef, undef, 0.05; # failing to wait results in out of sync reads
        my ($rdsize, $buf) = $self->{device}->read(4096);
        $buf =~ s/\r$//;
        return $buf;
}

__END__

=pod

Reference used:

http://info.uniden.com/twiki/pub/UnidenMan4/BC125AT/BC125AT_PC_Protocol_V1.01.pdf

=cut
