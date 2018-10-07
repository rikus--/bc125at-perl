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
    if (`lsusb` =~ m{ ^(.* (1965):(0017) \s+ Uniden .* )$ }xm){
        ($devinfo, $vendor_hex, $product_hex) = ($1, $2, $3);
        return ($devinfo, $vendor_hex, $product_hex);
    }
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

        # Fix for https://github.com/rikus--/bc125at-perl/issues/1
        system "echo 1965 0017 2 076d 0006 > /sys/bus/usb/drivers/cdc_acm/new_id";
    }
    print "Done setting up driver. Hope it works.\n";
}

1;
