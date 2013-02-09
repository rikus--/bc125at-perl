package Bc125At::GUI::ErrorDialog;

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

use Gtk2;

use base 'Gtk2::Dialog';

sub new {
    my ($package, $title, $content, $parent) = @_;
    no strict 'subs';
    my $self = do {
        no strict 'subs';
        Gtk2::Dialog->new($title, $parent, GTK_DIALOG_MODAL);
    };
    if (ref $content && $content->isa('Gtk2::Widget')){
        $self->get_content_area->add($content);
    }
    else {
        $self->get_content_area->add( Gtk2::Label->new($content) );
    }
    $self->add_button('OK', GTK_RESPONSE_OK);
    return bless $self, $package;
}

sub main {
    my $self = shift;
    $self->show_all;
    $self->show;
    $self->run;
    $self->destroy;
}

1;
