#!/bin/false
# Time-stamp: "1999-02-02 21:42:11 MST" -*-Perl-*-

package ISA;
require 5;
use strict;
use vars qw(@ISA $Debug $VERSION);

@ISA = ();
$Debug = 0 unless defined $Debug;
$VERSION = "0.31";

use Carp;

# These are my'd so they'll be really private!
my %Frozen = ();
  # map of classes to whether they're frozen.
my %ISA_should_be = ();
  # map of classes to what I last left their @ISA contents as.
my @empties = keys(%ISA::_Be::_Empty::_Dammit::);
  # symbols to be found in an empty (cononically so) package.
  #  currently empty-list, but you never know
my %Already_used;
  # whether I've already used a given class, ever, for anything.
  #  (or determined it to have already been used somewhere, for anything)

=head1 NAME

ISA -- modify and/or freeze a class's @ISA at compile time

=head1 SYNOPSIS

  package Cat::Himalayan;
  use ISA qw(-use Cat::Persian Cat::Siamese);
  
  ...basically the same as:
    package Cat::Himalayan;
    BEGIN { push @ISA, 'Cat::Persian'; }
    use Cat::Persian;
    BEGIN { push @ISA, 'Cat::Siamese'; }
    use Cat::Siamese;

=head1 DESCRIPTION

A class's @ISA is a list of its superclasses (AKA base classes,
AKA generic classes).  See L<perlobj> or L<perltoot> for details.
ISA.pm is a simple module allowing you to manipulate your class's @ISA
list at compile-time.

=head1 OPTIONS

You call ISA.pm by saying "use ISA I<OPTION, OPTION, OPTION>;", for
example:

  use ISA 'Cat::Persian', 'Cat::Himalayan';

or, to represent the list another way, "use ISA qw(I<OPTION, OPTION,
OPTION>);", for example:

  use ISA qw(Cat::Persian Cat::Himalayan);

The most popular important options are "-use", "-freeze", and
I<CLASSNAME>.  But for the sake of completeness, these are B<all> the
possible options:

=over

=item CLASSNAME

A classname (basically anything non-null that doesn't begin with a "-"
or a "!") is interpreted as a classname to add to the @ISA for the
calling package.  The classname is added to the end, unless you've set
"-start".  If it's already in @ISA, it won't be added to the list,
unless you set "-force".

[Note that if you specify a classname with apostrophes (which is
obsolescent), like "Tree'DAG_Node", it is added to @ISA with
double-colons, like "Tree::DAG_Node".  Similarly, saying "::Foo::Bar"
is added as "main::Foo::Bar" -- but who'd ever have a class rooted
under "main", regardless of which way you refer to it?]

=item !CLASSNAME

This removes all instances of the given classname from the @ISA.

=item -use

This turns on the "automagical use" mode (which is off by default),
which is effective for just this line, like force mode (see below).
In "automagical use" mode, for each classname you ask ISA.pm to add to
the @ISA list, ISA.pm will try to "use" that class if it looks like it
hasn't been used yet.  In other words, this:

    package Tree::Palm;
    use ISA qw(-use Tree::DAG_Node);

is basically the same as saying:

    package Tree::Palm;
    BEGIN { push @ISA, 'Tree::DAG_Node'; }
    BEGIN { eval "package Tree::Palm; use Tree::DAG_Node;" }

Note that you shouldn't use this mode except with modules that never
export any symbols (and a class generally shouldn't!).  Note also that
automagical use mode does a simple "use Foo::Bar" -- there's no way to
have it say "use Foo::Bar 1.10" or "use Foo::Bar qw(pati pata)".  If
you want that, use an explicit C<use> instead:

    use Foo::Bar qw(pati pata);
    use ISA qw(Foo::Bar);

If ISA.pm tries to automagically use a class, but fails, this will
cause a fatal error.

Note also that when ISA checks to see whether a class has been used
yet, it doesn't care what package or context it was used in.  But
that's irrelevant for classes that don't export anything.

=item -!use

This turns "automagical use" mode back off.

=item -freeze

This freezes the contents of @ISA.  Any subsequent attempts to alter
it again thru "use ISA ..." result in a fatal error.

In future versions of ISA.pm, "-freeze" will (hopefully!) make the
given @ISA unalterable, such that attempts to change it will result in
a fatal error.  For the time being, however, ISA.pm uses an END block
to check that all frozen @ISAs have the same contents as what they had
when they were frozen; any changes will be noted as pesky C<warn>ings.

Once you freeze an @ISA list, you can't unfreeze it.

Why freeze @ISA?  Because the list of what your class's superclasses
are is a basic fact about the class, not something you should go
changing after your code has started running.  Consider -freeze to be
a sanity checker.

=item -clear

Clears the contents of @ISA.

=item -start

Normally, requesting that a classname be added to @ISA will (if it's
not already in there) add it to the B<end> of the list.  However, if
you want it added to the B<beginning> (assuming it's not already in
there), use '-start'.  This is effective only for the given call.  For
example:

    use ISA qw(Foo);             # line 1
    use ISA qw(-start Bar Ziz);  # line 2
    use ISA qw(Baz);             # line 3

This will leave an @ISA of C<qw(Bar Ziz Foo Baz)>, because "-start" is
effective only for line 2.

=item -end

This cancels a preceding "-start", so that subsequently adding a
classname to @ISA will (if it's not already in there) add it to the
end of the list.

=item -force

This puts ISA.pm in "force mode".  In force mode, trying to add a
class name to @ISA will always add it, regardless of whether it's
already there.  By default, force mode is off.

This leaves force mode on for just this call to ISA.pm.  For example:

    use ISA qw(Foo::Bar Foo::Quux);           # line 1
    use ISA qw(-force Foo::Bar Zaz::Zoo);     # line 2
    use ISA qw(Foo::Quux);                    # line 3

Here, the "-force" in line 2 is effective for just that call to @ISA
-- so that "Foo::Bar" is added to @ISA again.  ("Zaz::Zoo" is added,
too, just as it would be normally.)  However, in line 3, we're back to
the default no-force mode, and so "Foo::Quux" isn't added to @ISA again,
since it's already there.

Force mode is useful in combination with "-start", to forcedly move a
class name to the start of @ISA, regardless of whether it's in there
already:

    use ISA qw(-force -start Thing::Prime);

However, you could just as easily do effectively the same thing by
removing the class in question from @ISA, then restoring it at the
beginning, like so:

    use ISA qw(!Thing::Prime -start Thing::Prime);

=item -!force

This turns force mode back off.

=item -debug

This puts puts ISA.pm in "debug mode" -- just like setting $ISA::Debug
to 1.  This makes ISA.pm spew lots of verbose garbage useful for
diagnosing bugs in (or relating to) ISA.pm.

=item -!debug

This turns off ISA.pm's debug mode.

=back

=head1 NOTES

Note that ISA.pm and C<Class::ISA> are different things.

Thanks to Eric Watt (Arkuat) Forste for the idea of tying @ISA.

Thanks to Tim Bunce for writing lib.pm, and to whoever wrote
Exporter.pm -- these were both useful precedents to ISA.pm.

=head1 COPYRIGHT

Copyright (c) 1999 Sean M. Burke. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Sean M. Burke C<sburke@netadventure.net>

=cut

###########################################################################

sub canonize_package_name { # a useful function
  my $name = $_[0];
  $name =~ s<'><::>sg;
  $name =~ s<^::><main::>sg;
  $name =~ s<::$><>sg; # useful?
  return $name;
}

#--------------------------------------------------------------------------

sub import { # The main routine
  shift;
  my @list = @_;
  print "ISA::Import called with list ", join(' ', map("<$_>", @list)), ".\n"
   if $Debug;
  my $caller = &canonize_package_name(scalar(caller));
  my $isar;
  {
    no strict 'refs';
    $isar = \@{"$caller\::ISA"};
  }

  # init if necessary.
  $ISA_should_be{$caller} = [] unless exists $ISA_should_be{$caller};
  $Frozen{$caller} = 0 unless exists $Frozen{$caller};
  my $start_mode = 0;
  my $force_mode = 0;
  my $use_mode = 0;

  foreach my $i (@list) {
    next unless defined $i and length $i;
    if($i =~ /^-(.+)/s) { # it's a directive
      my $d = $1;

      if($d eq 'clear') {
        print "Clearing $caller\'s \@ISA list\n" if $Debug;
        @$isar = ();
      } elsif($d eq 'freeze') {
        # resurrect once tied arrays work right
        #tie @$isar, 'ISA::_Frozen', @$isar;
        # In the meantime:
        $Frozen{$caller} = 1;

      #No point in freezing if you can just unfreeze later!
      #} elsif($d eq '!freeze') {
      #  # resurrect once tied arrays work right
      #  #untie @$isar;
      #  $Frozen{$caller} = 0;

      } elsif($d eq 'start')  { $start_mode = 1;
      } elsif($d eq 'end')    { $start_mode = 0;
      } elsif($d eq 'debug')  { $Debug = 1;
      } elsif($d eq '!debug') { $Debug = 0;
      } elsif($d eq 'force')  { $force_mode = 1;
      } elsif($d eq '!force') { $force_mode = 0;
      } elsif($d eq 'use')    { $use_mode = 1;
      } elsif($d eq '!use')   { $use_mode = 0;
      } else { croak "Unknown directive $i to ISA.pm\n";
      }

    } elsif($i =~ /^(!?)(.*)/s) { # add/remove this class
      my $remove = ($1 eq '!');
      my $c = &canonize_package_name($2);
      next unless length $c;

      croak "You can't modify $caller\'s \@ISA: it's frozen!\n"
       if $Frozen{$caller};

      if($remove) {
        print " Removing $c from $caller\'s \@ISA list, if present\n"
         if $Debug;
        @$isar = grep {$_ ne $c} @$isar;
      } else {
        print " Putting $c into $caller\'s \@ISA list\n" if $Debug;
        if(!$force_mode && grep {$_ eq $c} @$isar) {
          print " It's already there.\n" if $Debug;
        } else {
          if($start_mode) { # add to start
            print " Adding at start\n" if $Debug;
            unshift @$isar, $c;
          } else {  # add to end (normal)
            print " Adding at end\n" if $Debug;
            push @$isar, $c;
          }
          if($use_mode && !$Already_used{ &canonize_package_name($c) }++) {
            no strict 'refs';
            my %symtable_copy; # Lookit package $c's symbol table
            @symtable_copy{ keys( %{"$c\::"} )} = ();
            delete @symtable_copy{ @empties } if @empties;
            if(keys(%symtable_copy)) {
              print
               " No need to use $c -- it's got a non-empty symbol table\n"
               if $Debug; 
            } else {
              print
               " $c has an empty symbol table -- will auto-use\n"
               if $Debug;
              eval("package $caller ;\n use $c ;\n");
              die
               "ISA.pm hit an error while trying to use $c for $caller: $@\n"
               if $@;
            }
          } else {
            print " Won't use $c -- either already used, or -use is off\n"
             if $Debug;
          }
        }
      }
      @{$ISA_should_be{$caller}} = @$isar; # copy back.

    } else { # should never make it here
      croak "Unknown ISA.pm directive \'$i\'\n";
    }
  }
  return;  
}
#--------------------------------------------------------------------------

# Retire this END block if/when we get tying working right

END {
  no strict 'refs';
  foreach my $class (grep($Frozen{$_}, keys %Frozen)) {
    # scan frozen keys
    print "ISA.pm: Checking class $class\'s \@ISA list.\n" if $Debug;
    my @isa = @{"$class\::ISA"};
    if(@isa == @{$ISA_should_be{$class}}
       and join(' ', @isa) eq join(' ', @{$ISA_should_be{$class}})
    ) {
      print " ISA.pm: It checks out.\n" if $Debug;
    } else {
      warn
       "$class\'s \@ISA has been changed after being frozen, from (" .
       join(",", @{$ISA_should_be{$class}}) .
       ") to (" . join(",", @{"$class\::ISA"}) . ")\n";
    }
  }
}

###########################################################################
1;

__END__

# To be resurrected when tied arrays start working:

package ISA::_Frozen; # a tie class.  see perltie
use Carp;
$ISA::_Frozen::VERSION = $ISA::VERSION;
@ISA::_Frozen::ISA = ();
sub TIEARRAY {
  my($class, @contents) = @_;
  print ">> Blessing list [", join(',', @contents), "] into class $class\n"
   if $ISA::Debug;
  return bless \@contents, $class;
}

sub FETCH {
  my($this, $idx) = @_;
  print ">> returning item $idx of ISA list $this [", join(',', @$this), "]\n"
   if $ISA::Debug;
  return $this->[$idx];
}

sub STORE {
  print ">>Fneh!\n" if $ISA::Debug;
  die "!!!!! Modification of a frozen ISA attempted.";
}

