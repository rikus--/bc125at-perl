package Bc125At::Detect;

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

sub detect {
    my ($devinfo, $vendor_hex, $product_hex, $found);
    open my $devices, '<', '/proc/bus/usb/devices' or warn "couldn't open USB device list: $!\n";
    while(<$devices>){
        if (/^T:/){
            chomp($devinfo = $_);
            ($vendor_hex, $product_hex, $found) = (undef, undef, undef);
        }
        if (/Vendor=(\S+)/) {
            $vendor_hex = "0x$1";
        }
        if (/ProdID=(\S+)/) {
            $product_hex = "0x$1";
        }
        if (/Product=BC125AT/) {
            $found = 1;
        }

        if (   ($found && $vendor_hex && $product_hex)
            || ($vendor_hex eq '0x1965' && $product_hex eq '0x0017'))
        {
            #warn "Found a BC125AT at $devinfo\n";
            return ($devinfo, $vendor_hex, $product_hex);
        }
    }
    #warn "Couldn't find it. Sorry.\n";
    return;
}

sub setup_driver {
    if (-x '/usr/local/bin/bc125at-perl-driver-helper'){   # setuid helper program
        system '/usr/local/bin/bc125at-perl-driver-helper';
        $? == 0 or die sprintf "bc125at-perl-driver-helper exited nonzero (%d)\n", $? >> 8;
    }
    else {
        my ($devinfo, $vendor_hex, $product_hex) = detect();
        return if !$devinfo;
        system "rmmod usbserial >/dev/null 2>&1";
        system "modprobe usbserial vendor=$vendor_hex product=$product_hex" and die;
        system "mknod /dev/ttyUSB0 c 188 0" if !-e "/dev/ttyUSB0";
    }
    print "Done setting up driver. Hope it works.\n";
}

#sub probe {
#    for my $tty (qw(/dev/ttyUSB0 /dev/ttyUSB1)){
#        #Bc125At::Serial->new(
#    }
#}

1;
