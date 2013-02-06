package Bc125At::Serial;

# Copyright (c) 2013 Rikus Goodell. All Rights Reserved.
# This software is distributed free of charge and comes with NO WARRANTY.

use strict;
use warnings;

my $have_io_select = eval {
	require IO::Select;
	1;
};
if ($@){
	warn "IO::Select is not available. That's odd.\n";
}
# Device::SerialPort is actually not necessary, and using a plain filehandle actually
# works more smoothly overall, so Device::SerialPort will not be used by default.
my $using_device_serialport = eval {
        return if $have_io_select && !$ENV{'USE_DEVICE_SERIALPORT'};
	require Device::SerialPort;
        1;
};
if ($@){
	warn "Device::SerialPort is not available... falling back to basic I/O.\n";
}

my $DEFAULT_TTY = '/dev/ttyUSB0';

sub new {
        my ($package, $tty) = @_;

	$tty ||= $DEFAULT_TTY;

	my ($device, $fh);

	if ($using_device_serialport){
		$device = Device::SerialPort->new($tty) or die $!;
		$device->baudrate(9600);
		$device->parity('none');
		$device->databits(8);
		$device->stopbits(2);
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
	if ($using_device_serialport){
		$self->{device}->write($cmd . "\r") or return;
	}
	else {
		print {$self->{fh}} $cmd . "\r" or return;
		$self->{fh}->flush;
	}
	return 1;
}

sub read_response {
	my $self = shift;
	my ($rdsize, $buf);
	if ($using_device_serialport){
            ($rdsize, $buf) = $self->{device}->read(4096);
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
	if ($using_device_serialport){
        	select undef, undef, undef, 0.05; # failing to wait results in out of sync reads
	}
        my $buf = $self->read_response();
        return $buf;
}

sub empty_buffer {
    my $self = shift;
    my $select;
    if (!$using_device_serialport){
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
