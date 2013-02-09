package Bc125At::GUI::ProgressWindow;

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

#BEGIN { die if !exists($INC{'Gtk2.pm'}) }

use Gtk2;

use base 'Gtk2::Dialog';

sub new {
    my ($package, $title, $parent) = @_;
    my $self = do {
        no strict;
        Gtk2::Dialog->new($title, $parent, GTK_DIALOG_MODAL);
    };
    $self->{value} = 0;
    $self->{max} = 100;
    $self->{progressbar} = Gtk2::ProgressBar->new();
    $self->{progressbar}->set_size_request(300,30);
    $self->get_content_area->add($self->{progressbar});
    $self->show_all;
    return bless $self, $package;
}

# progress bar setting callback which must nudge the main gtk2 loop along while
# time-consuming work is happening elsewhere to keep the UI from freezing
sub set {
    my ($self, $value, $max) = @_;
    $self->{progressbar}->set_fraction($value / $max);
    my $gtk2_iter;
    Gtk2->main_iteration while Gtk2->events_pending && ++$gtk2_iter < 200;
}

sub done { $_[0]->destroy }

1;
