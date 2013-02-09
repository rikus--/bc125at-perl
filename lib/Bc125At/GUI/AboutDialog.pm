package Bc125At::GUI::AboutDialog;

use Bc125At::GUI::ErrorDialog;
use Bc125At::Version;

# possible TODO: use Gtk2::AboutDialog

sub show_about_box {

my $window = shift;

my $label = Gtk2::Label->new();
$label->set_markup(
<<END_OF_ABOUT
<tt>
bc125at-perl version $Bc125At::Version::version &lt;http://www.rikus.org/bc125at-perl&gt;

Copyright (c) 2013, Rikus Goodell.

All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
</tt>
END_OF_ABOUT
);

my $box = Bc125At::GUI::ErrorDialog->new('About',
$label,
,
$window

);
$box->main;
}

1;
