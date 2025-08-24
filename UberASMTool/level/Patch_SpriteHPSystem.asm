;This is a PATCH to be inserted via uberasm tool.
;Reason is so that you don't need a shared subroutine patch.

incsrc "../StatusBarDefines.asm"
incsrc "../EnemyHPMeterDefines.asm"
incsrc "../GraphicalBarDefines.asm"
incsrc "../NumberDisplayRoutinesDefines.asm"

pushpc
	;org $123456
	;JSL/JML LabelToFreespace

pullpc
	;LabelToFreespace: