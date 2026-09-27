;; TEST-AUX src/freq/components/candidate-patterns.metta

(INPUT MIN-SUPPORT 2)

(FACT (Inheritance Alice (Evaluation likes soda)))
(FACT (Inheritance Bob (Evaluation likes juice)))
(FACT (Inheritance Carol (Evaluation prefers soda)))

(run-iterative-miner nested-iterative-test (Inheritance (var 0) (var 1)))

(exec (freq f001 call-nested-iterative-miner)
  (, (run-iterative-miner nested-iterative-test (Inheritance (var 0) (var 1)))
     (DEF iterative-miner-fn $iter-p $iter-t))
  (O (+ (exec (freq f002 run-nested-iterative-miner) $iter-p $iter-t))))

(EXPECTED-RESULT nested-candidate-recursed (iterative-recursive-candidate nested-iterative-test (Inheritance (var 0) (var 1)) (Inheritance (var 0) (Evaluation (var 1) (var 2))) 3))
