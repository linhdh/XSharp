; namespace DebugStub

; Caller's Registers
; var CallerEBP
; var CallerEIP
; var CallerESP

; Tracing: 0=Off, 1=On
; var TraceMode
; enum Status
; var DebugStatus
; Pointer to the push all data. It points to the bottom after PushAll.
; Walk up to find the 8 x 32 bit registers.
; var PushAllPtr
; If set non 0, on next trace a break will occur
; var DebugBreakOnNextTrace
; For step out and over this is used to determine where the initial request was made
; EBP is logged when the trace is started and can be used to determine
; what level we are "at" relative to the original step start location.
; var BreakEBP
; Command ID of last command received
; var CommandID

; Sets a breakpoint
; Serial Params:
; 1: x32 - EIP to break on, or 0 to disable breakpoint.
; function BreakOnAddress {
	; +All
	PushAD 
    ; BP Address
    ; ComReadEAX()
    ; ECX = EAX
    Mov ECX, EAX

    ; BP ID Number
    ; BP ID Number is sent after BP Address, because
    ; reading BP address uses AL (EAX).
    ; EAX = 0
    Mov EAX, 0x0
    ; ComReadAL()

    ; Push EAX so we preserve it for later
	; +EAX
	Push EAX

	; Calculate location in table
    ; Mov [EBX + EAX * 4], ECX would be better, but our X# doesn't handle this yet
	; EBX = @.DebugBPs
	Mov EBX, DebugStub_Var_DebugBPs
    ; EAX << 2
    ; EBX += EAX

	; if ECX = 0 {
		; This is a BP removal

		; EDI = [EBX]
		Mov EDI, DWORD [EBX]
		; AL = $90
		Mov AL, 0x90
		; [EDI] = AL
		Mov BYTE [EDI], AL

		; goto DontSetBP
	; }

    ; [EBX] = ECX
    Mov DWORD [EBX], ECX
	; EDI = [EBX]
	Mov EDI, DWORD [EBX]
	; AL = $CC
	Mov AL, 0xCC
	; [EDI] = AL
	Mov BYTE [EDI], AL

; DontSetBP:

	; Restore EAX - the BP Id
	; -EAX
	Pop EAX

	; Re-scan for max BP Id
	; We _could_ try and work it out based on what happened...but my attempts to do so
	; proved futile...so I just programmed it to re-scan and find highest BP Id every time.

	; Scan to find our highest BP Id
	; ECX = 256
	Mov ECX, 0x100
	; Scan backwards to find the highest BP Id
; FindBPLoop:
	; ECX--
	Dec ECX

	; Load the current BP Id we are testing against
	; EBX = @.DebugBPs
	Mov EBX, DebugStub_Var_DebugBPs
	; EAX = ECX
	Mov EAX, ECX
	; 4 bytes per Id
	; EAX << 2
	; EBX += EAX

	; Set EAX to be the value at the address stored by EAX
	; I.e. the ASM address of the BP with BP Id of ECX (if there is one - it will be 0 if no BP at this BP Id)
	; EAX = [EBX]
	Mov EAX, DWORD [EBX]
	; If it isn't 0 there must be a BP at this address
	; if EAX != 0 {

		; BP found
		; Add 1 to the Id because the old searching loop (see Executing()) started at 256 so i guess we should allow for that.
		; Plus it means 0 can indicate no BPs
		; ECX++
		Inc ECX
		; .MaxBPId = ECX
		Mov DWORD [DebugStub_Var_MaxBPId], ECX
		; goto Continue
	; }
	; Has our count reached 0? If so, exit the loop as no BPs found...
	; if ECX = 0 {
		; goto FindBPLoopExit
	; }
	; goto FindBPLoop

; FindBPLoopExit:
	; No BPs found
	; 0 indicates no BPs - see comment above
	; .MaxBPId = 0
	Mov DWORD [DebugStub_Var_MaxBPId], 0x0

; Continue:
; Exit:
	; -All
	PopAD 
; }

; function SetINT3 {
	; +All
	PushAD 

    ; BP Address
    ; ComReadEAX()
	; Set to INT3 ($CC)
    ; EDI = EAX
    Mov EDI, EAX
	; AL = $CC
	Mov AL, 0xCC
	; [EDI] = AL
	Mov BYTE [EDI], AL

; Exit:
	; -All
	PopAD 
; }
; function ClearINT3 {
	; +All
	PushAD 

	; BP Address
    ; ComReadEAX()
	; Clear to NOP ($90)
    ; EDI = EAX
    Mov EDI, EAX
	; AL = $90
	Mov AL, 0x90
	; [EDI] = AL
	Mov BYTE [EDI], AL

; Exit:
	; -All
	PopAD 
; }

; function Executing {
	; This is the secondary stub routine. After the primary has decided we should do some debug
	; activities, this one is called.
	; Each of these checks a flag, and if it processes then it jumps to .Normal.

	; Check whether this call is result of (i.e. after) INT1
	 ; //! MOV EAX, DR6
	 MOV EAX, DR6
	 ; EAX & $4000
	 ; if EAX = $4000 {
	   ; This was INT1

	   ; Reset the debug register
	   ; EAX & $BFFF
	   ; //! MOV DR6, EAX
	   MOV DR6, EAX

	   ; ResetINT1_TrapFLAG()

	   ; Break()
	   ; goto Normal
	 ; }

    ; CheckForAsmBreak must come before CheckForBreakpoint. They could exist for the same EIP.
	; Check for asm break
    ; EAX = .CallerEIP
    Mov EAX, DWORD [DebugStub_Var_CallerEIP]
    ; AsmBreakEIP is 0 when disabled, but EIP can never be 0 so we dont need a separate check.
	; if EAX = .AsmBreakEIP {
		; DoAsmBreak()
  		; goto Normal
	; }

	; Check for breakpoint
    ; Look for a possible matching BP
    ; TODO: This is slow on every Int3...
    ; -Find a faster way - a list of 256 straight compares and code modifation?
    ; -Move this scan earlier - Have to set a global flag when anything (StepTriggers, etc below) is going on at all
    ; A selective disable of the DS

	; If there are 0 BPs, skip scan - easy and should have a good increase
    ; EAX = .MaxBPId
    Mov EAX, DWORD [DebugStub_Var_MaxBPId]
	; if EAX = 0 {
		; goto SkipBPScan
	; }

	; Only search backwards from the maximum BP Id - no point searching for before that
	; EAX = .CallerEIP
	Mov EAX, DWORD [DebugStub_Var_CallerEIP]
    ; EDI = @.DebugBPs
    Mov EDI, DebugStub_Var_DebugBPs
    ; ECX = .MaxBPId
    Mov ECX, DWORD [DebugStub_Var_MaxBPId]
	; //! repne scasd
	repne scasd
	; if = {
		; Break()
		; goto Normal
	; }
; SkipBPScan:

    ; Only one of the following can be active at a time (F10, F11, ShiftF11)

	; F11 - Must check first
	; If F11, stop on next C# line that executes.
    ; if dword .DebugBreakOnNextTrace = #StepTrigger_Into {
		; Break()
		; goto Normal
	; }

	; .CallerEBP is the stack on method entry.
	; EAX = .CallerEBP
	Mov EAX, DWORD [DebugStub_Var_CallerEBP]

	; F10
    ; if dword .DebugBreakOnNextTrace = #StepTrigger_Over {
		; If EAX = .BreakEBP then we are in same method.
		; If EAX > .BreakEBP then our method has returned and we are in the caller.
		; if EAX >= .BreakEBP {
			; Break()
		; }
		; goto Normal
	; }

	; Shift-F11
    ; if dword .DebugBreakOnNextTrace = #StepTrigger_Out {
		; If EAX > .BreakEBP then our method has returned and we are in the caller.
		; if EAX > .BreakEBP {
			; Break()
		; }
		; goto Normal
	; }

; Normal:
    ; If tracing is on, send a trace message.
    ; Tracing isnt really used any more, was used by the old stand alone debugger. Might be upgraded
    ; and resused in the future.
	; if dword .TraceMode = #Tracing_On {
		; SendTrace()
	; }

    ; Is there a new incoming command? We dont want to wait for one
    ; if there isn't one already here. This is a non blocking check.
; CheckForCmd:
	  ; DX = 5
	  Mov DX, 0x5
    ; ReadRegister()
    ; AL test 1
    Test AL, 0x1
    ; If a command is waiting, process it and then check for another.
    ; If no command waiting, break from loop.
	; if !0 {
		; ProcessCommand()
		; See if there are more commands waiting
		; goto CheckForCmd
	; }
; }

; function Break {
    ; Should only be called internally by DebugStub. Has a lot of preconditions.
    ; Externals should use BreakOnNextTrace instead.
    ; Reset request in case we are currently responding to one or we hit a fixed breakpoint
    ; before our request could be serviced (if one existed)
    ; .DebugBreakOnNextTrace = #StepTrigger_None
    Mov [DebugStub_Var_DebugBreakOnNextTrace], DebugStub_Const_StepTrigger_None
    ; .BreakEBP = 0
    Mov DWORD [DebugStub_Var_BreakEBP], 0x0
    ; Set break status
    ; .DebugStatus = #Status_Break
    Mov [DebugStub_Var_DebugStatus], DebugStub_Const_Status_Break
    ; SendTrace()

    ; Wait for a command
; WaitCmd:
    ; Check for common commands first
    ; ProcessCommand()

    ; Now check for commands that are only valid in break state or commands that require special handling while in break state.

    ; if AL = #Vs2Ds_Continue goto Done

	; If Asm step into, we need to continue execution
	; if AL = #Vs2Ds_AsmStepInto {
		; SetINT1_TrapFLAG()
		; goto Done
	; }

    ; if AL = #Vs2Ds_SetAsmBreak {
        ; SetAsmBreak()
	    ; AckCommand()
	    ; goto WaitCmd
	; }

    ; if AL = #Vs2Ds_StepInto {
        ; .DebugBreakOnNextTrace = #StepTrigger_Into
        Mov [DebugStub_Var_DebugBreakOnNextTrace], DebugStub_Const_StepTrigger_Into
		; Not used, but set for consistency
        ; .BreakEBP = EAX
        Mov DWORD [DebugStub_Var_BreakEBP], EAX
	    ; goto Done
	; }

    ; if AL = #Vs2Ds_StepOver {
        ; .DebugBreakOnNextTrace = #StepTrigger_Over
        Mov [DebugStub_Var_DebugBreakOnNextTrace], DebugStub_Const_StepTrigger_Over
        ; EAX = .CallerEBP
        Mov EAX, DWORD [DebugStub_Var_CallerEBP]
        ; .BreakEBP = EAX
        Mov DWORD [DebugStub_Var_BreakEBP], EAX
	    ; goto Done
	; }

    ; if AL = #Vs2Ds_StepOut {
        ; .DebugBreakOnNextTrace = #StepTrigger_Out
        Mov [DebugStub_Var_DebugBreakOnNextTrace], DebugStub_Const_StepTrigger_Out
        ; EAX = .CallerEBP
        Mov EAX, DWORD [DebugStub_Var_CallerEBP]
        ; .BreakEBP = EAX
        Mov DWORD [DebugStub_Var_BreakEBP], EAX
	    ; goto Done
	; }

    ; Loop around and wait for another command
    ; goto WaitCmd

; Done:
    ; AckCommand()
    ; .DebugStatus = #Status_Run
    Mov [DebugStub_Var_DebugStatus], DebugStub_Const_Status_Run
; }

