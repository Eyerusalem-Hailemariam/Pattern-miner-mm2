;; TEST-AUX data/ugly-sodaDrinker.metta
;; TEST-AUX src/common-utils/utils.metta
;; TEST-AUX src/surp/isurp-old-mm2.metta


(INPUT DB db)
(INPUT SURP-MODE isurp-old)
(INPUT NORMALIZATION True)

;; Transform raw Inheritance facts into DB-FACT format
(exec (test-setup transform-db-facts)
    (, (Inheritance $entity $class))
    (O (+ (DB-FACT (Inheritance $entity $class)))))

(INPUT PATTERN ((,  (Inheritance $x man) (Inheritance $x ugly) (Inheritance $x sodaDrinker)) 5))

;; Expected result for the isurp-old-mm2 implementation
(EXPECTED-RESULT isurp-old-mm2-basic (OUTPUT ISURP-RESULT (((Inheritance (var 0) man) (Inheritance (var 0) ugly) (Inheritance (var 0) sodaDrinker)) 0.9988310929281121)))
