package Bc125At::ProgressBar;

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

=head1 CONSTRUCTION

Bc125At::ProgressBar->new( ... )

=head1 OPTIONS

=over 3

=item * value - startign value (defaults to 0)

=item * max - value at end of progress bar (defaults to 100)

=item * redisplay - redisplay interval (defaults to 5)

=item * callback - subroutine to call on progress bar updates (optional, defaults to nothing)

=back

=cut

sub new {
    my ($package, @args) = @_;
    my $self = {
        value     => 0,
        max       => 100,
        redisplay => 5,
        @args
    };
    return bless $self;
}

sub more {
    my ($self, $newvalue) = @_;
    if (defined $newvalue) {
        $self->{value} = $newvalue;
    }
    else {
        $self->{value}++;
    }
    $self->display()
      if $self->{value} == 0
          or $self->{value} % $self->{redisplay} == 0
          or $self->{value} == $self->{max};
}

sub display {
    my $self = shift;
    local $| = 1;
    my $frac = $self->{value} / $self->{max};
    print "\r|" . ("-" x 50) . "|" . " $self->{value} / $self->{max}" . (" " x 10) . "\r" . "|" . ("#" x (50 * $frac));
    print "\n" if $self->{value} >= $self->{max};
    $self->{callback}->(@$self{qw(value max)}) if $self->{callback};
}

1;
