obj/perlmain.o:
(__TEXT,__text) section
_stabilizer_main:
0000000000000000	pushq	%rbp
0000000000000001	movq	%rsp,%rbp
0000000000000004	subq	$0x40,%rsp
0000000000000008	movq	$_stabilizer_main,%rax
0000000000000012	movl	$0x00000008,%ecx
0000000000000017	movq	$0x0000000000000001,%rdx
0000000000000021	movq	_stabilizer.dummy.main+0x00000050(%rip),%r8
0000000000000028	movl	$_stabilizer_main,(%r8)
000000000000002f	movl	%edi,0xfc(%rbp)
0000000000000032	movl	%ecx,%edi
0000000000000034	movq	%rsi,0xf0(%rbp)
0000000000000038	movq	%rdx,%rsi
000000000000003b	movq	%rax,0xe8(%rbp)
000000000000003f	call	*_stabilizer.dummy.main(%rip)
0000000000000045	movq	_stabilizer.dummy.main+0x00000058(%rip),%rdx
000000000000004c	movq	%rax,(%rdx)
000000000000004f	movq	_stabilizer.dummy.main+0x00000048(%rip),%rax
0000000000000056	cmpb	$_stabilizer_main,(%rax)
0000000000000059	movq	0xe8(%rbp),%rax
000000000000005d	movq	%rax,0xe0(%rbp)
0000000000000061	jne	0x000000a7
0000000000000067	call	*_stabilizer.dummy.main+0x00000008(%rip)
000000000000006d	cmpq	$_stabilizer_main,%eax
0000000000000073	movq	%rax,0xd8(%rbp)
0000000000000077	jne	0x00000088
000000000000007d	movl	$0x00000001,%edi
0000000000000082	call	*_stabilizer.dummy.main+0x00000010(%rip)
0000000000000088	movq	0xd8(%rbp),%rdi
000000000000008c	call	*_stabilizer.dummy.main+0x00000018(%rip)
0000000000000092	movq	_stabilizer.dummy.main+0x00000060(%rip),%rdi
0000000000000099	movl	$_stabilizer_main,(%rdi)
000000000000009f	movq	0xd8(%rbp),%rdi
00000000000000a3	movq	%rdi,0xe0(%rbp)
00000000000000a7	movq	0xe0(%rbp),%rax
00000000000000ab	movq	$_stabilizer_main,%r8
00000000000000b5	movq	_stabilizer.dummy.main+0x00000068(%rip),%rcx
00000000000000bc	movb	(%rcx),%dl
00000000000000be	orb	$0x02,%dl
00000000000000c1	movq	_stabilizer.dummy.main+0x00000068(%rip),%rcx
00000000000000c8	movb	%dl,(%rcx)
00000000000000ca	movq	_stabilizer.dummy.main+0x00000020(%rip),%rcx
00000000000000d1	movq	_stabilizer.dummy.main+0x00000028(%rip),%rsi
00000000000000d8	movq	%rax,%rdi
00000000000000db	movl	0xfc(%rbp),%edx
00000000000000de	movq	0xf0(%rbp),%r9
00000000000000e2	movq	%rcx,0xd0(%rbp)
00000000000000e6	movq	%r9,%rcx
00000000000000e9	movq	0xd0(%rbp),%r10
00000000000000ed	movq	%rax,0xc8(%rbp)
00000000000000f1	call	*%r10
00000000000000f4	cmpl	$_stabilizer_main,%eax
00000000000000f9	jne	0x0000010c
00000000000000ff	movq	0xc8(%rbp),%rdi
0000000000000103	call	*_stabilizer.dummy.main+0x00000030(%rip)
0000000000000109	movl	%eax,0xc4(%rbp)
000000000000010c	movq	0xc8(%rbp),%rdi
0000000000000110	call	*_stabilizer.dummy.main+0x00000038(%rip)
0000000000000116	movq	0xc8(%rbp),%rdi
000000000000011a	movl	%eax,0xc0(%rbp)
000000000000011d	call	*_stabilizer.dummy.main+0x00000040(%rip)
0000000000000123	movl	0xc0(%rbp),%edi
0000000000000126	call	*_stabilizer.dummy.main+0x00000010(%rip)
000000000000012c	nopl	%cs:_stabilizer_main(%rax,%rax)
000000000000013b	nop
000000000000013c	nop
000000000000013d	nop
000000000000013e	nop
000000000000013f	nop
_stabilizer.dummy.main:
0000000000000140	pushq	%rbp
0000000000000141	movq	%rsp,%rbp
0000000000000144	popq	%rbp
0000000000000145	ret
0000000000000146	nopw	%cs:_stabilizer_main(%rax,%rax)
_xs_init:
0000000000000150	pushq	%rbp
0000000000000151	movq	%rsp,%rbp
0000000000000154	subq	$0x00000080,%rsp
000000000000015b	movq	_stabilizer.dummy.xs_init(%rip),%rax
0000000000000162	movq	_stabilizer.dummy.xs_init+0x00000028(%rip),%rsi
0000000000000169	movq	_stabilizer.dummy.xs_init+0x00000070(%rip),%rdx
0000000000000170	movq	_stabilizer.dummy.xs_init+0x00000078(%rip),%rdi
0000000000000177	call	*%rax
0000000000000179	movq	_stabilizer.dummy.xs_init(%rip),%rdx
0000000000000180	movq	_stabilizer.dummy.xs_init+0x00000030(%rip),%rsi
0000000000000187	movq	_stabilizer.dummy.xs_init+0x00000070(%rip),%rdi
000000000000018e	movq	_stabilizer.dummy.xs_init+0x00000080(%rip),%rcx
0000000000000195	movq	%rdi,0xf8(%rbp)
0000000000000199	movq	%rcx,%rdi
000000000000019c	movq	0xf8(%rbp),%rcx
00000000000001a0	movq	%rdx,0xf0(%rbp)
00000000000001a4	movq	%rcx,%rdx
00000000000001a7	movq	0xf0(%rbp),%r8
00000000000001ab	movq	%rax,0xe8(%rbp)
00000000000001af	call	*%r8
00000000000001b2	movq	_stabilizer.dummy.xs_init(%rip),%rcx
00000000000001b9	movq	_stabilizer.dummy.xs_init+0x00000008(%rip),%rsi
00000000000001c0	movq	_stabilizer.dummy.xs_init+0x00000070(%rip),%rdx
00000000000001c7	movq	_stabilizer.dummy.xs_init+0x00000088(%rip),%rdi
00000000000001ce	movq	%rax,0xe0(%rbp)
00000000000001d2	call	*%rcx
00000000000001d4	movq	_stabilizer.dummy.xs_init(%rip),%rcx
00000000000001db	movq	_stabilizer.dummy.xs_init+0x00000010(%rip),%rsi
00000000000001e2	movq	_stabilizer.dummy.xs_init+0x00000070(%rip),%rdx
00000000000001e9	movq	_stabilizer.dummy.xs_init+0x00000090(%rip),%rdi
00000000000001f0	movq	%rax,0xd8(%rbp)
00000000000001f4	call	*%rcx
00000000000001f6	movq	_stabilizer.dummy.xs_init(%rip),%rcx
00000000000001fd	movq	_stabilizer.dummy.xs_init+0x00000018(%rip),%rsi
0000000000000204	movq	_stabilizer.dummy.xs_init+0x00000070(%rip),%rdx
000000000000020b	movq	_stabilizer.dummy.xs_init+0x00000098(%rip),%rdi
0000000000000212	movq	%rax,0xd0(%rbp)
0000000000000216	call	*%rcx
0000000000000218	movq	_stabilizer.dummy.xs_init(%rip),%rcx
000000000000021f	movq	_stabilizer.dummy.xs_init+0x00000020(%rip),%rsi
0000000000000226	movq	_stabilizer.dummy.xs_init+0x00000070(%rip),%rdx
000000000000022d	movq	_stabilizer.dummy.xs_init+0x000000a0(%rip),%rdi
0000000000000234	movq	%rax,0xc8(%rbp)
0000000000000238	call	*%rcx
000000000000023a	movq	_stabilizer.dummy.xs_init(%rip),%rcx
0000000000000241	movq	_stabilizer.dummy.xs_init+0x00000038(%rip),%rsi
0000000000000248	movq	_stabilizer.dummy.xs_init+0x00000070(%rip),%rdx
000000000000024f	movq	_stabilizer.dummy.xs_init+0x000000a8(%rip),%rdi
0000000000000256	movq	%rax,0xc0(%rbp)
000000000000025a	call	*%rcx
000000000000025c	movq	_stabilizer.dummy.xs_init(%rip),%rcx
0000000000000263	movq	_stabilizer.dummy.xs_init+0x00000040(%rip),%rsi
000000000000026a	movq	_stabilizer.dummy.xs_init+0x00000070(%rip),%rdx
0000000000000271	movq	_stabilizer.dummy.xs_init+0x000000b0(%rip),%rdi
0000000000000278	movq	%rax,0xb8(%rbp)
000000000000027c	call	*%rcx
000000000000027e	movq	_stabilizer.dummy.xs_init(%rip),%rcx
0000000000000285	movq	_stabilizer.dummy.xs_init+0x00000048(%rip),%rsi
000000000000028c	movq	_stabilizer.dummy.xs_init+0x00000070(%rip),%rdx
0000000000000293	movq	_stabilizer.dummy.xs_init+0x000000b8(%rip),%rdi
000000000000029a	movq	%rax,0xb0(%rbp)
000000000000029e	call	*%rcx
00000000000002a0	movq	_stabilizer.dummy.xs_init(%rip),%rcx
00000000000002a7	movq	_stabilizer.dummy.xs_init+0x00000050(%rip),%rsi
00000000000002ae	movq	_stabilizer.dummy.xs_init+0x00000070(%rip),%rdx
00000000000002b5	movq	_stabilizer.dummy.xs_init+0x000000c0(%rip),%rdi
00000000000002bc	movq	%rax,0xa8(%rbp)
00000000000002c0	call	*%rcx
00000000000002c2	movq	_stabilizer.dummy.xs_init(%rip),%rcx
00000000000002c9	movq	_stabilizer.dummy.xs_init+0x00000058(%rip),%rsi
00000000000002d0	movq	_stabilizer.dummy.xs_init+0x00000070(%rip),%rdx
00000000000002d7	movq	_stabilizer.dummy.xs_init+0x000000c8(%rip),%rdi
00000000000002de	movq	%rax,0xa0(%rbp)
00000000000002e2	call	*%rcx
00000000000002e4	movq	_stabilizer.dummy.xs_init(%rip),%rcx
00000000000002eb	movq	_stabilizer.dummy.xs_init+0x00000060(%rip),%rsi
00000000000002f2	movq	_stabilizer.dummy.xs_init+0x00000070(%rip),%rdx
00000000000002f9	movq	_stabilizer.dummy.xs_init+0x000000d0(%rip),%rdi
0000000000000300	movq	%rax,0x98(%rbp)
0000000000000304	call	*%rcx
0000000000000306	movq	_stabilizer.dummy.xs_init(%rip),%rcx
000000000000030d	movq	_stabilizer.dummy.xs_init+0x00000038(%rip),%rsi
0000000000000314	movq	_stabilizer.dummy.xs_init+0x00000070(%rip),%rdx
000000000000031b	movq	_stabilizer.dummy.xs_init+0x000000a8(%rip),%rdi
0000000000000322	movq	%rax,0x90(%rbp)
0000000000000326	call	*%rcx
0000000000000328	movq	_stabilizer.dummy.xs_init(%rip),%rcx
000000000000032f	movq	_stabilizer.dummy.xs_init+0x00000068(%rip),%rsi
0000000000000336	movq	_stabilizer.dummy.xs_init+0x00000070(%rip),%rdx
000000000000033d	movq	_stabilizer.dummy.xs_init+0x000000d8(%rip),%rdi
0000000000000344	movq	%rax,0x88(%rbp)
0000000000000348	call	*%rcx
000000000000034a	movq	%rax,0x80(%rbp)
000000000000034e	addq	$0x00000080,%rsp
0000000000000355	popq	%rbp
0000000000000356	ret
0000000000000357	nopl	%cs:_stabilizer_main(%rax,%rax)
0000000000000366	nop
0000000000000367	nop
0000000000000368	nop
0000000000000369	nop
000000000000036a	nop
000000000000036b	nop
000000000000036c	nop
000000000000036d	nop
000000000000036e	nop
000000000000036f	nop
0000000000000370	nop
0000000000000371	nop
0000000000000372	nop
0000000000000373	nop
0000000000000374	nop
0000000000000375	nop
0000000000000376	nop
0000000000000377	nop
0000000000000378	nop
0000000000000379	nop
000000000000037a	nop
000000000000037b	nop
000000000000037c	nop
000000000000037d	nop
000000000000037e	nop
000000000000037f	nop
_stabilizer.dummy.xs_init:
0000000000000380	pushq	%rbp
0000000000000381	movq	%rsp,%rbp
0000000000000384	popq	%rbp
0000000000000385	ret
0000000000000386	nopw	%cs:_stabilizer_main(%rax,%rax)
_stabilizer.module_ctor:
0000000000000390	pushq	%rbp
0000000000000391	movq	%rsp,%rbp
0000000000000394	subq	$0x10,%rsp
0000000000000398	leaq	_stabilizer_main(%rip),%rax
000000000000039f	leaq	_stabilizer.dummy.main(%rip),%rcx
00000000000003a6	leaq	_main.relocation_table(%rip),%rdx
00000000000003ad	movq	$_stabilizer_main,%rsi
00000000000003b7	addq	$0x00000008,%rsi
00000000000003be	imulq	$0x0000000e,%rsi,%rsi
00000000000003c5	movl	%esi,%edi
00000000000003c7	movl	$0x00000001,%r8d
00000000000003cd	movl	%edi,0xfc(%rbp)
00000000000003d0	movq	%rax,%rdi
00000000000003d3	movq	%rcx,%rsi
00000000000003d6	movl	0xfc(%rbp),%ecx
00000000000003d9	callq	_stabilizer_register_function
00000000000003de	leaq	_xs_init(%rip),%rax
00000000000003e5	leaq	_stabilizer.dummy.xs_init(%rip),%rdx
00000000000003ec	leaq	_xs_init.relocation_table(%rip),%rsi
00000000000003f3	movq	$_stabilizer_main,%rdi
00000000000003fd	addq	$0x00000008,%rdi
0000000000000404	imulq	$0x0000001c,%rdi,%rdi
000000000000040b	movl	%edi,%ecx
000000000000040d	movl	$0x00000001,%r8d
0000000000000413	movq	%rax,%rdi
0000000000000416	movq	%rsi,0xf0(%rbp)
000000000000041a	movq	%rdx,%rsi
000000000000041d	movq	0xf0(%rbp),%rdx
0000000000000421	callq	_stabilizer_register_function
0000000000000426	addq	$0x10,%rsp
000000000000042a	popq	%rbp
000000000000042b	ret
