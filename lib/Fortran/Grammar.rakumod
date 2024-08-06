use v6;
# use Grammar::Tracer;

unit module Fortran::Grammar;

# basic Fortran structures
our grammar FortranBasic {

    # ignorable whitespace
    token comment { "!" \N* $$ }
    token ws {
        <!ww>
        \h*
        ["&" \h* [ <comment>? <nl> ] + \h* "&" \h*] ?
        <comment> ?
    }
    token nl { \n+ }

    # fortran primitives
    token name { :i <[a..z0..9_]>+ }
    token precision-spec { _ <name> }
    token digits { \d+ }
    token integer { <digits> <precision-spec> ? }
    token float { <digits> \. <digits>  <precision-spec> ? }
    token number { <sign>? [ <float> || <integer> ] }
    rule  string { [ '"' <-["]>* '"' ] || [ "'" <-[']>* "'" ] }
    rule  sign { <[-+]> }

    proto rule boolean { * }
    rule boolean:sym<true>  { :i <logical-prefix-operator> ? '.true.' }
    rule boolean:sym<false> { :i <logical-prefix-operator> ? '.false.' }

    token atomic { <boolean> || <number> || <strings> }

    rule  in-place-array { \( \/ [ <booleans> || <strings> || <numbers> ] \/ \) }
    token array-index-region { <value-returning-code> ? \: <value-returning-code> ? }
    token in-place { <atomic> || <in-place-array> }
    rule  strings { <string> [ \, <string> ] * }
    rule  numbers { <number> [ \, <number> ] * }
    rule  booleans { <boolean> [ \, <boolean> ] * }

    token array-index { <array-index-region> || <integer> || <name> }
    rule  array-indices { <array-index> [ \, <array-index> ] *  }
    rule  indexed-array { <name> \( <array-indices> \) }
    rule  accessed-variable { <sign>? [ <indexed-array> || <name> ] }

    proto token arithmetic-operator { * }
    token arithmetic-operator:sym<addition>        { '+'  }
    token arithmetic-operator:sym<subtraction>     { '-'  }
    token arithmetic-operator:sym<multiplication>  { '*'  }
    token arithmetic-operator:sym<division>        { '/'  }
    token arithmetic-operator:sym<power>           { '**' }

    proto token relational-operator { * }
    token relational-operator:sym<equality>      { :i '==' | '.eq.' }
    token relational-operator:sym<inequality>    { :i '/=' | '.ne.' }
    token relational-operator:sym<less>          { :i '<'  | '.lt.' }
    token relational-operator:sym<greater>       { :i '<'  | '.lt.' }
    token relational-operator:sym<less-equal>    { :i '<=' | '.le.' }
    token relational-operator:sym<greater-equal> { :i '>=' | '.ge.' }

    proto token logical-operator { * }
    token logical-operator:sym<and>            { :i '.and.'   }
    token logical-operator:sym<or>             { :i '.or.'    }
    token logical-operator:sym<equivalent>     { :i '.eqv.'   }
    token logical-operator:sym<non-equivalent> { :i '.neqv.'  }

    proto token logical-prefix-operator { * }
    token logical-prefix-operator:sym<not> { :i '.not.'   }

    proto rule logical-value-returning-code { * }
    rule logical-value-returning-code:sym<relational-statement> {
        <logical-prefix-operator> ? <relational-statement>
    }
    rule logical-value-returning-code:sym<boolean-atomic> {
        <boolean>
    }
    rule logical-value-returning-code:sym<function-call> {
        <function-call>
    }
    rule logical-value-returning-code:sym<accessed-variable> {
        <accessed-variable>
    }

    # TODO all of the statements are only very basic and need improvement
    rule arithmetic-statement {
        <value-returning-code> [ <arithmetic-operator> <value-returning-code> ] *
    }
    rule relational-statement {
        <arithmetic-statement> <relational-operator> <arithmetic-statement>
    }
    rule logical-statement {
        <logical-value-returning-code>
        [ <logical-operator> <logical-value-returning-code> ] *
    }

    rule assignment { <accessed-variable> '=' <value-returning-code> }

    token argument { <value-returning-code> } # any value returning code can be an argument
    rule  arguments { <argument> [ \, <argument> ] * } # a list of arguments

    rule  function-call { <name> \( <arguments> ? \) }
    rule  subroutine-call { :i call <name> [ \( <arguments> ? \) ] ? }

    rule  value-returning-code {
           <function-call>
        || <in-place>
        || <accessed-variable>
    }
}

=begin pod

=head1 NAME

Fortran::Grammar - Grammar to parse FORTRAN source code

=head1 SYNOPSIS

=begin code :lang<raku>

use Fortran::Grammar;

=end code

=head1 DESCRIPTION

B<Note>: This module is still in very early development.

=head1 MOTIVATION

Working on large Fortran projects with lots of code that you haven't
written yourself and try to understand/debug, I found it to be very
handy to have a text filter that scans the source code and automatically
wraps C<write(*,*) ...> statements around specific codelines, e.g.
specific MPI subroutine calls. To get information on this code and fill
the C<write (*,*) ...> statements with useful information, it has to
be parsed.

I initially wrote a Perl script to do this by parsing the source code
line-by-line. Parsing became more and more ugly the stranger the code
became ( a lot of nested arguments, Fortran-style line continuation
with C<& \n &>, the code of interest enclosed in C<IF>-oneliners, etc...).

When I discovered Raku Grammars, I immediately wanted to implement
this :-)

The main goal of this module is not to provide a Fortran
syntax-checker (although with a lot of work it could become one...)
but to give painless access to the structural components of Fortran
statements - e.g. the subroutine name of a subroutine call, its
arguments (which may contain function calls or calculations), etc...

=head1 Usage

Use it like any grammar in Raku

=begin code :lang<raku>

use Fortran::Grammar; # use the module

# some simple Fortran code
my Str $fortran = q:to/EOT/;
call sub( array(1:2), sin(1.234_prec), & ! Fortran-style linebreak / comment
    & (/ 1.23, 3.45, 6.78 /), "Hello World!" )
EOT

# parse the Fortran code
my $parsed = Fortran::Grammar::FortranBasic.parse: $fortran.chomp,
                rule => "subroutine-call";

say "### input ###";
say $fortran;
say "### parsed ###";
say $parsed;

=end code

Output:

=begin output

### input ###
call sub( array(1:2), sin(1.234_prec), & ! Fortran-style linebreak / comment
    & (/ 1.23, 3.45, 6.78 /), "Hello World!" )

### parsed ###
｢call sub( array(1:2), sin(1.234_prec), & ! Fortran-style linebreak / comment
    & (/ 1.23, 3.45, 6.78 /), "Hello World!" )｣
 name => ｢sub｣
 arguments => ｢array(1:2), sin(1.234_prec), & ! Fortran-style linebreak / comment
    & (/ 1.23, 3.45, 6.78 /), "Hello World!" ｣
  argument => ｢array(1:2)｣
   value-returning-code => ｢array(1:2)｣
    accessed-variable => ｢array(1:2)｣
     indexed-array => ｢array(1:2)｣
      name => ｢array｣
      array-indices => ｢1:2｣
       array-index => ｢1:2｣
        array-index-region => ｢1:2｣
         value-returning-code => ｢1｣
          in-place => ｢1｣
           atomic => ｢1｣
            number => ｢1｣
             integer => ｢1｣
              digits => ｢1｣
         value-returning-code => ｢2｣
          in-place => ｢2｣
           atomic => ｢2｣
            number => ｢2｣
             integer => ｢2｣
              digits => ｢2｣
  argument => ｢sin(1.234_prec)｣
   value-returning-code => ｢sin(1.234_prec)｣
    function-call => ｢sin(1.234_prec)｣
     name => ｢sin｣
     arguments => ｢1.234_prec｣
      argument => ｢1.234_prec｣
       value-returning-code => ｢1.234_prec｣
        in-place => ｢1.234_prec｣
         atomic => ｢1.234_prec｣
          number => ｢1.234_prec｣
           float => ｢1.234_prec｣
            digits => ｢1｣
            digits => ｢234｣
            precision-spec => ｢_prec｣
             name => ｢prec｣
  argument => ｢(/ 1.23, 3.45, 6.78 /)｣
   value-returning-code => ｢(/ 1.23, 3.45, 6.78 /)｣
    in-place => ｢(/ 1.23, 3.45, 6.78 /)｣
     in-place-array => ｢(/ 1.23, 3.45, 6.78 /)｣
      numbers => ｢1.23, 3.45, 6.78 ｣
       number => ｢1.23｣
        float => ｢1.23｣
         digits => ｢1｣
         digits => ｢23｣
       number => ｢3.45｣
        float => ｢3.45｣
         digits => ｢3｣
         digits => ｢45｣
       number => ｢6.78｣
        float => ｢6.78｣
         digits => ｢6｣
         digits => ｢78｣
  argument => ｢"Hello World!" ｣
   value-returning-code => ｢"Hello World!" ｣
    in-place => ｢"Hello World!" ｣
     atomic => ｢"Hello World!" ｣
      string => ｢"Hello World!" ｣

=end output

=head2 Special thanks

C<smls> on L<StackOverflow.com|http://stackoverflow.com/a/42039566/5433146>
for an Action object C<FALLBACK> method that converts a C<Match> object
to a JSON-serializable C<Hash>.

=head1 AUTHORS

=item Yann Büchau
=item Raku Community

=head1 COPYRIGHT AND LICENSE

Copyright 2017 Yann Büchau

Copyright 2024 Raku Community

This library is free software; you can redistribute it and/or modify it
under the GNU GENERAL PUBLIC LICENSE, Version 3

=end pod

# vim: expandtab shiftwidth=4
