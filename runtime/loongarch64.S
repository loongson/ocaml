 /**************************************************************************/
 /*                                                                        */
 /*                                 OCaml                                  */
 /*                                                                        */
 /*                yala <zhaojunchao@loongson.cn>                          */
 /*                                                                        */
 /*               Copyright © 2008-2023 LOONGSON                           */
 /*                                                                        */
 /*   All rights reserved.  This file is distributed under the terms of    */
 /*   the GNU Lesser General Public License version 2.1, with the          */
 /*   special exception on linking described in the file LICENSE.          */
 /*                                                                        */
 /**************************************************************************/

/* Asm part of the runtime system, loongarch64 processor, 64-bit mode */
/* Must be preprocessed by cpp */

#include "caml/m.h"

#define ARG_DOMAIN_STATE_PTR $t0
#define DOMAIN_STATE_PTR $s8
#define TRAP_PTR $s1
#define ALLOC_PTR $s7
#define TMP $t1
#define ARG $t2

#define STORE st.d
#define LOAD ld.d

#undef ASM_CFI_SUPPORTED
#if defined(ASM_CFI_SUPPORTED)
#define CFI_STARTPROC .cfi_startproc
#define CFI_ENDPROC .cfi_endproc
#define CFI_ADJUST(n) .cfi_adjust_cfa_offset n
#define CFI_REGISTER(r1,r2) .cfi_register r1,r2
#define CFI_OFFSET(r,n) .cfi_offset r,n
#else
#define CFI_STARTPROC
#define CFI_ENDPROC
#define CFI_ADJUST(n)
#define CFI_REGISTER(r1,r2)
#define CFI_OFFSET(r,n)
#endif

        .set    domain_curr_field, 0
        .set    domain_curr_cnt, 0
#define DOMAIN_STATE(c_type, name) \
        .equ    domain_field_caml_##name, domain_curr_field ; \
        .set    domain_curr_cnt, domain_curr_cnt + 1;    \
        .set    domain_curr_field, domain_curr_cnt*8
#include "../runtime/caml/domain_state.tbl"
#undef DOMAIN_STATE

#define Caml_state(var)  DOMAIN_STATE_PTR, domain_field_caml_##var

#define FUNCTION(name) \
        .align 2; \
        .globl name; \
        .type name, @function; \
name:; \
        CFI_STARTPROC

#define END_FUNCTION(name) \
        CFI_ENDPROC; \
        .size name, .-name

#if defined(__PIC__)
#define PLT(r) %plt(r)
#else
#define PLT(r) r
#endif

        .section        .text
/* Invoke the garbage collector. */

        .globl  caml_system__code_begin
caml_system__code_begin:

FUNCTION(caml_call_gc)
.Lcaml_call_gc:
        /* Record return address */
        STORE   $ra, Caml_state(last_return_address)
        /* Record lowest stack address */
        STORE   $sp, Caml_state(bottom_of_stack)
        /* Set up stack space, saving return address */
        /* (1 reg for RA, 1 reg for FP, 23 allocatable int regs,
            20 caller-save float regs) * 8 */
        /* + 1 for alignment */
        addi.d    $sp, $sp, -0x180
        CFI_ADJUST(0x180)
		STORE   $ra, $sp, 0x8
        CFI_OFFSET(ra, -0x180+8)
        /* Save allocatable integer registers on the stack,
           in the order given in proc.ml */
		STORE   $a0, $sp, 0x10
		STORE   $a1, $sp, 0x18
		STORE   $a2, $sp, 0x20
		STORE   $a3, $sp, 0x28
		STORE   $a4, $sp, 0x30
		STORE   $a5, $sp, 0x38
		STORE   $a6, $sp, 0x40
		STORE   $a7, $sp, 0x48
		STORE   $s2, $sp, 0x50
		STORE   $s3, $sp, 0x58
		STORE   $s4, $sp, 0x60
		STORE   $s5, $sp, 0x68
		STORE   $s6, $sp, 0x70
		STORE   $t2, $sp, 0x78
		STORE   $t3, $sp, 0x80
		STORE   $t4, $sp, 0x88
		STORE   $t5, $sp, 0x90
		STORE   $t6, $sp, 0x98
		STORE   $t7, $sp, 0xa0
		STORE   $t8, $sp, 0xa8
		STORE   $s0, $sp, 0xb0
        /* Save caller-save floating-point registers on the stack
           (callee-saves are preserved by caml_garbage_collection) */
		fst.d     $ft0, $sp, 0xb8
		fst.d     $ft1, $sp, 0xc0
		fst.d     $ft2, $sp, 0xc8
		fst.d     $ft3, $sp, 0xd0
		fst.d     $ft4, $sp, 0xd8
		fst.d     $ft5, $sp, 0xe0
		fst.d     $ft6, $sp, 0xe8
		fst.d     $ft7, $sp, 0xf0
		fst.d     $fa0, $sp, 0xf8
		fst.d     $fa1, $sp, 0x100
		fst.d     $fa2, $sp, 0x108
		fst.d     $fa3, $sp, 0x110
		fst.d     $fa4, $sp, 0x118
		fst.d     $fa5, $sp, 0x120
		fst.d     $fa6, $sp, 0x128
		fst.d     $fa7, $sp, 0x130
		fst.d     $ft8, $sp, 0x138
		fst.d     $ft9, $sp, 0x140
		fst.d     $ft10, $sp, 0x148
		fst.d     $ft11, $sp, 0x150
		fst.d     $ft12, $sp, 0x158
		fst.d     $ft13, $sp, 0x160
		fst.d     $ft14, $sp, 0x168
		fst.d     $ft15, $sp, 0x170
        /* Store pointer to saved integer registers in caml_gc_regs */
        addi.d    TMP, $sp, 0x10
        STORE   TMP, Caml_state(gc_regs)
        /* Save current allocation pointer for debugging purposes */
        STORE   ALLOC_PTR, Caml_state(young_ptr)
        /* Save trap pointer in case an exception is raised during GC */
        STORE   TRAP_PTR, Caml_state(exception_pointer)
        /* Call the garbage collector */
        bl    PLT(caml_garbage_collection)
        /* Restore registers */
		LOAD   $a0, $sp, 0x10
		LOAD   $a1, $sp, 0x18
		LOAD   $a2, $sp, 0x20
		LOAD   $a3, $sp, 0x28
		LOAD   $a4, $sp, 0x30
		LOAD   $a5, $sp, 0x38
		LOAD   $a6, $sp, 0x40
		LOAD   $a7, $sp, 0x48
		LOAD   $s2, $sp, 0x50
		LOAD   $s3, $sp, 0x58
		LOAD   $s4, $sp, 0x60
		LOAD   $s5, $sp, 0x68
		LOAD   $s6, $sp, 0x70
		LOAD   $t2, $sp, 0x78
		LOAD   $t3, $sp, 0x80
		LOAD   $t4, $sp, 0x88
		LOAD   $t5, $sp, 0x90
		LOAD   $t6, $sp, 0x98
		LOAD   $t7, $sp, 0xa0
		LOAD   $t8, $sp, 0xa8
		LOAD   $s0, $sp, 0xb0
		fld.d     $ft0, $sp, 0xb8
		fld.d     $ft1, $sp, 0xc0
		fld.d     $ft2, $sp, 0xc8
		fld.d     $ft3, $sp, 0xd0
		fld.d     $ft4, $sp, 0xd8
		fld.d     $ft5, $sp, 0xe0
		fld.d     $ft6, $sp, 0xe8
		fld.d     $ft7, $sp, 0xf0
		fld.d     $fa0, $sp, 0xf8
		fld.d     $fa1, $sp, 0x100
		fld.d     $fa2, $sp, 0x108
		fld.d     $fa3, $sp, 0x110
		fld.d     $fa4, $sp, 0x118
		fld.d     $fa5, $sp, 0x120
		fld.d     $fa6, $sp, 0x128
		fld.d     $fa7, $sp, 0x130
		fld.d     $ft8, $sp, 0x138
		fld.d     $ft9, $sp, 0x140
		fld.d     $ft10, $sp, 0x148
		fld.d     $ft11, $sp, 0x150
		fld.d     $ft12, $sp, 0x158
		fld.d     $ft13, $sp, 0x160
		fld.d     $ft14, $sp, 0x168
		fld.d     $ft15, $sp, 0x170
        /* Reload new allocation pointer */
        LOAD    ALLOC_PTR, Caml_state(young_ptr)
        /* Free stack space and return to caller */
		LOAD    $ra, $sp, 0x8
        addi.d    $sp, $sp, 0x180
        CFI_ADJUST(-0x180)
        jr    $ra
END_FUNCTION(caml_call_gc)

/* Call a C function from OCaml */
/* Function to bl is in ARG */

FUNCTION(caml_c_call)
        /* Preserve return address in callee-save register s2 */
        move      $s2, $ra
        CFI_REGISTER(ra, s2)
        /* Record lowest stack address and return address */
        STORE   $ra, Caml_state(last_return_address)
        STORE   $sp, Caml_state(bottom_of_stack)
        /* Make the exception handler alloc ptr available to the C code */
        STORE   ALLOC_PTR, Caml_state(young_ptr)
        STORE   TRAP_PTR, Caml_state(exception_pointer)
        /* Call the function */
        jirl    $ra, ARG, 0
        /* Reload alloc ptr */
        LOAD    ALLOC_PTR, Caml_state(young_ptr)
        /* Return */
        jr      $s2
END_FUNCTION(caml_c_call)

/* Raise an exception from OCaml */
FUNCTION(caml_raise_exn)
        /* Test if backtrace is active */
        LOAD    TMP, Caml_state(backtrace_active)
        bnez    TMP, 2f
1:      /* Cut stack at current trap handler */
        move      $sp, TRAP_PTR
        /* Pop previous handler and jump to it */
        LOAD    TMP, $sp, 8
        LOAD    TRAP_PTR, $sp, 0
        addi.d    $sp, $sp, 16
        CFI_ADJUST(-16)
        jr      TMP
2:      /* Preserve exception bucket in callee-save register s2 */
        move      $s2, $a0
        /* Stash the backtrace */
        move      $a1, $ra
        move      $a2, $sp
        move      $a3, TRAP_PTR
        bl    PLT(caml_stash_backtrace)
        /* Restore exception bucket and raise */
        move      $a0, $s2
        b       1b
END_FUNCTION(caml_raise_exn)

        .globl  caml_reraise_exn
        .type   caml_reraise_exn, @function

/* Raise an exception from C */

FUNCTION(caml_raise_exception)
        move      DOMAIN_STATE_PTR, $a0
        move      $a0, $a1
        LOAD    TRAP_PTR, Caml_state(exception_pointer)
        LOAD    ALLOC_PTR, Caml_state(young_ptr)
        LOAD    TMP, Caml_state(backtrace_active)
        bnez    TMP, 2f
1:      /* Cut stack at current trap handler */
        move      $sp, TRAP_PTR
        LOAD    TMP, $sp, 8
        LOAD    TRAP_PTR, $sp, 0
        addi.d    $sp, $sp, 16
        CFI_ADJUST(-16)
        jr      TMP
2:      /* Preserve exception bucket in callee-save register s2 */
        move      $s2, $a0
        LOAD    $a1, Caml_state(last_return_address)
        LOAD    $a2, Caml_state(bottom_of_stack)
        move      $a3, TRAP_PTR
        bl    PLT(caml_stash_backtrace)
        move      $a0, $s2
        b       1b
END_FUNCTION(caml_raise_exception)

/* Start the OCaml program */

FUNCTION(caml_start_program)
        move      ARG_DOMAIN_STATE_PTR, $a0
        la.global      ARG, caml_program
        /* Code shared with caml_callback* */
        /* Address of OCaml code to bl is in ARG */
        /* Arguments to the OCaml code are in a0 ... a7 */
.Ljump_to_caml:
        /* Set up stack frame and save callee-save registers */
        addi.d    $sp, $sp, -0xa0
        CFI_ADJUST(0xa0)
		STORE   $ra, $sp, 0x90
        CFI_OFFSET(ra, -0xa0+0xb0)
		STORE   $s0, $sp, 0x0
		STORE   $s1, $sp, 0x8
		STORE   $s2, $sp, 0x10
		STORE   $s3, $sp, 0x18
		STORE   $s4, $sp, 0x20
		STORE   $s5, $sp, 0x28
		STORE   $s6, $sp, 0x30
		STORE   $s7, $sp, 0x38
		STORE   $s8, $sp, 0x40
		fst.d     $fs0, $sp, 0x48
		fst.d     $fs1, $sp, 0x50
		fst.d     $fs2, $sp, 0x58
		fst.d     $fs3, $sp, 0x60
		fst.d     $fs4, $sp, 0x68
		fst.d     $fs5, $sp, 0x70
		fst.d     $fs6, $sp, 0x78
		fst.d     $fs7, $sp, 0x80
        addi.d    $sp, $sp, -32
        CFI_ADJUST(32)
        /* Load domain state pointer from argument */
        move      DOMAIN_STATE_PTR, ARG_DOMAIN_STATE_PTR
        /* Setup a callback link on the stack */
        LOAD    TMP, Caml_state(bottom_of_stack)
        STORE   TMP, $sp, 0
        LOAD    TMP, Caml_state(last_return_address)
        STORE   TMP, $sp, 8
        LOAD    TMP, Caml_state(gc_regs)
        STORE   TMP, $sp, 16
        /* set up a trap frame */
        addi.d    $sp, $sp, -16
        CFI_ADJUST(16)
        LOAD    TMP, Caml_state(exception_pointer)
        STORE   TMP, $sp, 0
        la.local     TMP, .Ltrap_handler
        STORE   TMP, $sp, 8
        move      TRAP_PTR, $sp
        LOAD    ALLOC_PTR, Caml_state(young_ptr)
        STORE   $zero, Caml_state(last_return_address)
        jirl    $ra, ARG, 0
.Lcaml_retaddr:         /* pop trap frame, restoring caml_exception_pointer */
        LOAD    TMP, $sp, 0
        STORE   TMP, Caml_state(exception_pointer)
        addi.d    $sp, $sp, 16
        CFI_ADJUST(-16)
.Lreturn_result:        /* pop callback link, restoring global variables */
        LOAD    TMP, $sp, 0
        STORE   TMP, Caml_state(bottom_of_stack)
        LOAD    TMP, $sp, 8
        STORE   TMP, Caml_state(last_return_address)
        LOAD    TMP, $sp, 16
        STORE   TMP, Caml_state(gc_regs)
        addi.d    $sp, $sp, 32
        CFI_ADJUST(-32)
        /* Update allocation pointer */
        STORE   ALLOC_PTR, Caml_state(young_ptr)
        /* reload callee-save registers and return */
		LOAD    $ra, $sp, 0x90
		LOAD    $s0, $sp, 0x0
		LOAD    $s1, $sp, 0x8
		LOAD    $s2, $sp, 0x10
		LOAD    $s3, $sp, 0x18
		LOAD    $s4, $sp, 0x20
		LOAD    $s5, $sp, 0x28
		LOAD    $s6, $sp, 0x30
		LOAD    $s7, $sp, 0x38
		LOAD    $s8, $sp, 0x40
		fld.d     $fs0, $sp, 0x48
		fld.d     $fs1, $sp, 0x50
		fld.d     $fs2, $sp, 0x58
		fld.d     $fs3, $sp, 0x60
		fld.d     $fs4, $sp, 0x68
		fld.d     $fs5, $sp, 0x70
		fld.d     $fs6, $sp, 0x78
		fld.d     $fs7, $sp, 0x80
        addi.d    $sp, $sp, 0xa0
        CFI_ADJUST(-0xa0)
        jr    $ra
        .type   .Lcaml_retaddr, @function
        .size   .Lcaml_retaddr, .-.Lcaml_retaddr
END_FUNCTION(caml_start_program)

        .align  2
.Ltrap_handler:
        CFI_STARTPROC
        STORE   TRAP_PTR, Caml_state(exception_pointer)
        ori     $a0, $a0, 2
        b       .Lreturn_result
        .type   .Ltrap_handler, @function
END_FUNCTION(.Ltrap_handler)

/* Callback from C to OCaml */

FUNCTION(caml_callback_asm)
        /* Initial shuffling of arguments */
        /* a0 = Caml_state, a1 = closure, (a2) = args */
        move      ARG_DOMAIN_STATE_PTR, $a0
        LOAD    $a0, $a2, 0   /* a0 = first arg */
                            /* a1 = closure environment */
        LOAD    ARG, $a1, 0  /* code pointer */
        b       .Ljump_to_caml
END_FUNCTION(caml_callback_asm)

FUNCTION(caml_callback2_asm)
        /* Initial shuffling of arguments */
        /* a0 = Caml_state, a1 = closure, (a2) = args */
        move      ARG_DOMAIN_STATE_PTR, $a0
        move      TMP, $a1
        LOAD    $a0, $a2, 0
        LOAD    $a1, $a2, 8
        move      $a2, TMP
        la.global      ARG, caml_apply2
        b       .Ljump_to_caml
END_FUNCTION(caml_callback2_asm)

FUNCTION(caml_callback3_asm)
        /* Initial shuffling of arguments */
        /* a0 = Caml_state, a1 = closure, (a2) = args */
        move      ARG_DOMAIN_STATE_PTR, $a0
        move      $a3, $a1
        LOAD    $a0, $a2, 0
        LOAD    $a1, $a2, 8
        LOAD    $a2, $a2, 16
        la.global      ARG, caml_apply3
        b       .Ljump_to_caml
END_FUNCTION(caml_callback3_asm)

FUNCTION(caml_ml_array_bound_error)
        /* Load address of [caml_array_bound_error] in ARG */
        la.global      ARG, caml_array_bound_error
        /* Call that function */
        b    caml_c_call
END_FUNCTION(caml_ml_array_bound_error)

        .globl  caml_system__code_end
caml_system__code_end:

/* GC roots for callback */

        .section .data
        .align  3
        .globl  caml_system__frametable
        .type   caml_system__frametable, @object
caml_system__frametable:
        .quad   1               /* one descriptor */
        .quad   .Lcaml_retaddr  /* return address into callback */
        .short  -1              /* negative frame size => use callback link */
        .short  0               /* no roots */
        .align  3
        .size   caml_system__frametable, .-caml_system__frametable
