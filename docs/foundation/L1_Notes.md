# Notes

- Positional value -- Because combining elements (concatenation) isn't inherently unique, the system cannot rely on raw structure alone to determine value. It uses this strict "lowest address wins" filter to purge duplicates, ensuring every valid spelling has exactly one unique mathematical owner.
- Bounded transfinitude -- In short, while combining raw patterns can theoretically cause the language's complexity to compound exponentially, the strict tie-breaker rule acts as a geometric filter. In some cases, it leaves the infinite structure intact ($\omega^2$); in highly ambiguous cases without distinct boundary markers, it aggressively flattens the structure back down to a simpler, finite-multiply sequence ($\omega \cdot k$).
- Fixpoints -- The & token acts as an anonymous self-reference macro. It represents "the innermost brace expression it sits inside." When evaluating it, the system unrolls the expression recursively.
