package Bc125At::Detect;

# Copyright (c) 2013 Rikus Goodell. All Rights Reserved.
# This software is distributed free of charge and comes with NO WARRANTY.

sub detect {
    my ($devinfo, $vendor_hex, $product_hex, $found);
    for (`lsusb -v`) {
        if (/^Bus \d+ Device \d+/) {
            chomp($devinfo = $_);
            ($vendor_hex, $product_hex, $found) = (undef, undef, undef);
        }
        if (/idVendor\s*(0x\S+)/) {
            $vendor_hex = $1;
        }
        if (/idProduct\s*(0x\S+)/) {
            $product_hex = $1;
        }
        if (/iProduct\s*\S*\s*BC125AT/) {
            $found = 1;
        }

        if (   ($found && $vendor_hex && $product_hex)
            || ($vendor_hex eq '0x1965' && $product_hex eq '0x0017'))
        {
            warn "Found a BC125AT at $devinfo\n";
            return ($devinfo, $vendor_hex, $product_hex);
        }
    }
    warn "Couldn't find it. Sorry.\n";
    return;
}

sub setup_driver {
    my ($devinfo, $vendor_hex, $product_hex) = detect();
    return if !$devinfo;
    system "rmmod usbserial >/dev/null 2>&1";
    system "modprobe usbserial vendor=$vendor_hex product=$product_hex" and die;
    system "mknod /dev/ttyUSB0 c 188 0" if !-e "/dev/ttyUSB0";
    warn "Done setting up driver. Hope it works.\n";
}

#sub probe {
#    for my $tty (qw(/dev/ttyUSB0 /dev/ttyUSB1)){
#        #Bc125At::Serial->new(
#    }
#}

1;
