

;; Legacy public input: index raw pattern once
(exec 0
    (, (INPUT PATTERN ($pattern $support)))
    (O
        (pure
            (isurp-old-pattern $indexed-copy $pattern $support)
            $indexed-copy
            (vars_to_indices
                (cdr-atom (' $pattern))))))


;; Scoped pattern input
(exec 0
    (, (INPUT SCOPED-PATTERN ($pattern-id $pattern $support)))
    (, (isurp-old-pattern $pattern-id $pattern $support)))



;; Compute DB-SIZE from the number of loaded database facts.
(exec 0
    (, (DB-FACT $fact))
    (O (count (INPUT DB-SIZE $size) $size $fact)))


;; Miner-integrated pattern input; use the support counted from DB-FACT rows.
(exec 1
    (, (INPUT SURP-MODE isurp-old)
       (isurp-pattern-support $indexed-pattern $support))
    (O
        (pure
            (isurp-old-pattern $indexed-pattern $pattern $support)
            $pattern
            (indices_to_vars
                (cons , (' $indexed-pattern))))))


;; Compute the number of conjunctive clauses in the pattern
(exec 2
    (, (isurp-old-pattern $ctx $pattern $support))
    (O
        (pure
            (isurp-num-of-conjuncts $ctx $pattern $count)
            $count
            (size-atom
                (cdr-atom (' $pattern))))))


;; Extract clause list from pattern
(exec 2
    (, (isurp-old-pattern $ctx $pattern $support))
    (O
        (pure
            (isurp-clause-list $ctx $clauses)
            $clauses
            (cdr-atom (' $pattern)))))



;; Compute total count denominator: N^(k) / k!
;; (falling factorial = N*(N-1)*...*(N-k+1), divide by k!)
(exec 3
    (, (INPUT DB-SIZE $n)
       (isurp-num-of-conjuncts $ctx $pattern $k))
    (O
        (pure
            (isurp-total-count-of $ctx $pattern $total)
            $total
            (i64_to_string
                (div_i64
                    (falling_factorial
                        (i64_from_string $n)
                        (i64_from_string $k))
                    (factorial
                        (i64_from_string $k)))))))


;; Compute empirical observed pattern probability: P(pattern) = support / total_count
(exec 4
    (, (isurp-old-pattern $ctx $pattern $support)
       (isurp-total-count-of $ctx $pattern $total))
    (O
        (pure
            (isurp-pattern-prob $ctx $prob)
            $prob
            (f64_to_string
                (div_f64
                    (f64_from_string $support)
                    (f64_from_string $total))))))



;; Generic singleton block support computed from DB-FACT rows matching class.
(exec 6
    (, (DB-FACT (Inheritance $entity $class)))
    (O
        (count
            (isurp-clause-support ((Inheritance (var 0) $class)) $support)
            $support
            $entity)))

;; Generic pair block support with independent variables.
(exec 6
    (, (DB-FACT (Inheritance $entity1 $c1))
       (DB-FACT (Inheritance $entity2 $c2)))
    (O
        (count
            (isurp-clause-support
                ((Inheritance (var 0) $c1)
                 (Inheritance (var 1) $c2)) $support)
            $support
            ($entity1 $entity2))))

;; Generic pair block support with shared variable.
(exec 6
    (, (DB-FACT (Inheritance $entity $c1))
       (DB-FACT (Inheritance $entity $c2)))
    (O
        (count
            (isurp-clause-support
                ((Inheritance (var 0) $c1)
                 (Inheritance (var 0) $c2)) $support)
            $support
            $entity)))

;; Map generic clause supports into block support for any partition context.
(exec 6
    (, (isurp-clause-support $block $support))
    (, (isurp-block-support $ctx $pid $block $support)))



;; Turn DB-derived block supports into probabilities using the full-pattern denominator.
(exec 7
    (, (isurp-block-support $ctx $pid $block $b_support)
       (isurp-total-count-of $ctx $pattern $total))
    (O
        (pure
            (isurp-block-prob $ctx $pid $block $b_prob)
            $b_prob
            (f64_to_string
                (div_f64
                    (f64_from_string $b_support)
                    (f64_from_string $total))))))




;; Use fprod to multiply all block probabilities for the same (ctx, pid) partition.
;; This correctly handles any number of blocks (1, 2, 3, ...) without hardcoding.
;;
;; fprod form: (fprod <output-template> <var-in-template> <float-value>)
;;   - output-template: (isurp-partition-prob $ctx $pid $pprob) — fact written to space
;;   - var-in-template: $pprob — gets bound to the product across all matching blocks
;;   - float-value: $bp — the per-block float probability string collected each time
;;
(exec 8
    (, (isurp-block-prob $ctx $pid $b $bp))
    (O
        (fprod (isurp-partition-prob $ctx $pid $pprob) $pprob $bp)))



;; Collect all partition probabilities and reduce to [E_min, E_max] per context.
;;
;; fmin form: (fmin <output-template> <var-in-template> <float-value>)
;;   - output-template: (isurp-emin $ctx $emin) — fact written to space
;;   - var-in-template: $emin — gets bound to minimum across all partition probs
;;   - float-value: $prob — the per-partition float probability string
;;
(exec 9
    (, (isurp-partition-prob $ctx $pid $prob))
    (O
        (fmin (isurp-emin $ctx $emin) $emin $prob)
        (fmax (isurp-emax $ctx $emax) $emax $prob)))



;; Combine emin and emax into a single interval fact
(exec 10
    (, (isurp-emin $ctx $emin)
       (isurp-emax $ctx $emax))
    (, (isurp-interval $ctx $emin $emax)))



;; Distance from P(pattern) to [E_min, E_max]: zero inside the interval,
;; E_min - P below it, and P - E_max above it.
;;
;; Implementation uses nested max_f64 and sub_f64 functions to compute piecewise distance:
;;   - max_f64: Returns maximum of multiple f64 values (built-in MM2 stdlib function)
;;   - sub_f64: Subtracts second f64 from first (built-in MM2 stdlib function)
;;
;; Mathematical formula: max((emin - p), max((p - emax), 0.0))
;; This implements:
;;   - If p < emin:         distance = emin - p    (positive distance below interval)
;;   - If emin ≤ p ≤ emax:  distance = 0.0        (inside interval, no distance)
;;   - If p > emax:         distance = p - emax    (positive distance above interval)


(exec 11
    (, (isurp-pattern-prob $ctx $p)
       (isurp-interval $ctx $emin $emax))
    (O
        (pure
            (isurp-distance $ctx $dst)
            $dst
            (f64_to_string
                (max_f64
                    (sub_f64
                        (f64_from_string $emin)
                        (f64_from_string $p))
                    (max_f64
                        (sub_f64
                            (f64_from_string $p)
                            (f64_from_string $emax))
                        (f64_from_string 0.0)))))))


;; Case 1: Normalization ENABLED
(exec 12
    (, (INPUT NORMALIZATION True)
       (isurp-distance $ctx $dst)
       (isurp-pattern-prob $ctx $p)
       (isurp-interval $ctx $emin $emax))
    (O
        (pure
            (OUTPUT ISURP-RESULT ($ctx $score))
            $score
            (f64_to_string
                (min_f64
                    (div_f64
                        (f64_from_string $dst)
                        (max_f64
                            (f64_from_string $emax)
                            (f64_from_string $p)))
                    (f64_from_string 1.0))))))

;; Case 2: Normalization DISABLED
(exec 12
    (, (INPUT NORMALIZATION False)
       (isurp-distance $ctx $dst))
    (O
        (pure
            (OUTPUT ISURP-RESULT ($ctx $score))
            $score
            (f64_to_string
                (min_f64
                    (f64_from_string $dst)
                    (f64_from_string 1.0))))))
