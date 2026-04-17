.global _start
_start:
    li x1, 10
    li x2, 20
    add x4, x1, x2 // x4 = 30
    li x3, 1       // Set Pass code
1:
    j 1b           // Halt
