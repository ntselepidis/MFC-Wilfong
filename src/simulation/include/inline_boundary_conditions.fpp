#:def GHOST_CELL_EXTRAPOLATION_BC(DIR, LOC)
    print*, "HERE", ${DIR}$, ${LOC}$
    #:if DIR == 1
        #:if LOC == -1
            ! Do something
        #:elif LOC == 1
            ! Do something else
        #:endif
    #:elif DIR == 2

    #:elif DIR == 3

    #:endif
#:enddef



