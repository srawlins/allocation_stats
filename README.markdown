Introduction
============

ObjectspaceStats is a gem that makes use of Ruby 2.1's new abilities to trace
allocations. This new feature was inspired by work that @tmm1 did at GitHub, as
described in
[this post](https://github.com/blog/1489-hey-judy-don-t-make-it-bad). It was
proposed as a feature in Ruby Core by @tmm1 in
[Ruby issue #8107](http://bugs.ruby-lang.org/issues/8107), and @ko1 wrote it
into MRI. He introduces the feature in his Ruby Kaigi 2013 presentation, on
slides 29 through 33
[[pdf](http://www.atdot.net/~ko1/activities/RubyKaigi2013-ko1.pdf)].

The new `#trace_allocations` method is very raw, and does not provide useful
information for large codebases. The data must be aggregated!
