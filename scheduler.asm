;AT89C5131-Multitasker
;@author: Jan Hofmeier

;verwendete Speicheradressen:
;2fh: StackPointer Zwischenspeicher
;30h: frei (PSW Zwischenspeicher--> geht jetzt auf den stack)
;31h: zwischenspeicher
;32h: Sekunden-Timerverwendung
;33h: reload-AN/AUS
;34h-3Bh: 8-Bit timer 
;3Ch-43h: 8-Bit timer reload werte
;44h: Sekunden-TimerOverflows
;45h-4Dh: eventuell timer offsets
;4Eh: kernel aussetzter
;4Fh: Programm das als naechstes fortgesetzt wird
;50h: Anfang Stack Programm 1
;65h: Anfang Stack Programm 2
;08Oh-8Fh: Sicherung Register + SP Programm 1
;090h-9Fh: Sicherung Register + SP Programm 2; dreieckstausch waere Langsamer und hier ist genug frei


cseg at 0
;EXTERN Code lcd-up.LCDIni; Wie bindet man in dieser IDE andere Dateien ein?
jmp spl1; springe ueber die IR-Einspringadressen

org 000Bh ;Timer Interrupt Einsprungsadresse
;jmp ende
jmp kerneltimer


debug:; gibt die letzte Andresse auf dem Stack aus, 12 Bit reichen
pop ACC
RL A
RL A
RL A
RL A
cpl a
orl A,#00001111B
mov P0,A
pop P1
jmp ende



;org 0A0h
kerneltimer:
push PSW; PSW (flags) sichern
mov 2fh,SP; Stack zwischenspeichern
lcall increaseTimer; Timer für Programme
djnz 4Eh, weg ;scheduler soll einmal aussetzten, wenn er vorher schon durch syscll aufgerufen wurde
inc 4Eh; dec durch djnz rückgängig machen, djnz benötigt im gegensatz zu cjne rein register
mov SP,#0F0h; dritter Stack "um den Weg zurückt zu finden"
lcall scheduler; kontext und SP tauschen
mov SP,2fh; SP wiederherstellen
weg: pop PSW; PSW wiederherstellen
reti; hoffentlich an die Richtige stelle zurück ;)

spl1:
mov 3Ch,#20; Programmtimer Initialiseren
mov 34h,3Ch
mov 3Dh,#100
mov 35h,#3Dh
mov 4Eh,#1; Damit der scheduler beim nächten Timer Interrupt aufgerufen wird
mov SP,#0D1h ;adresse stack programm 1
lcall spl2; dient nur dazu die startadresse fuer Prg1 in den Stack zu schreiben, der rÃ¼cksprung wird dann vom kernel erledigt
jmp prg2; springe zu prg2


spl2:
mov 4Fh,#2; 2rogramm2 soll als nächtes gestartet werden
push PSW; PSW fuer PRG2 auf den Stack
mov 2fh,SP; SP von prg2 zwischenspeichern
mov SP,#0F0h
mov 31h,#0D0h; Adresse für die Kontextsicherung von prg2
lcall pushRegs; Kontext sichern
mov SP, #081h ; adresse stack programm2
;Aktiviere Interrupts
setb EX0; P3.2
setb IT0; P3.2 flankengesteuert
setb EX1; P3.3
setb IT1; P3.3 flankengestuert
setb ET0; Timer fuer den Scheduler
setb 0B8h; Erhoehe Priorität für P3.2 
mov 0B7h,#00000001B; hoechste Priorität für P3.2 damit er den Idle von P3.3 beenden kann.
setb EA; Aktivere Interrupts allgemein
mov TH0,#56;Initialisiere reload wert für Scheduler-Timer
mov TL0,#56;Startwert für Scheduler Timer
mov TMOD,#01010010B; Auto-reload Modus
setb TR0; Starte Timer
jmp prg1; Beginne mit der ausführung von prg1


;Hierueber kann ein Programm rechenzeit abgeben (soll spaeter auch Ausgabe etc bereitstellen)
; Auch fuer die demo von Kooperativen MT, idle muesste dafuer entfernt werden
syscll:
push PSW
mov 2Fh,SP
push ACC
mov ACC,4eh
inc 4Eh; zähle 1 hoch um den ST einmal aussetzten zu lassen
cjne A,#2, nicht; beide Programme haben ihre Zeit abgegeben
;inc 4Eh; nochmal aussetzten?
pop ACC
mov SP,#0F0h
lcall scheduler; Kontext vertauschen
mov SP,2fh
pop PSW
ret
nicht:; beide Programme haben nichts zu tun, CPU soll 2 Taktzyklen schlafen
lcall idle
lcall idle
pop ACC
pop PSW
ret

ende:jmp ende; loop, nichtmehr tun

idle: ;cpu soll ideln, verwendet Akku
mov A,PCON
orl A,#1
mov PCON,A
ret;

;Vertauscht sichert den einen Kontext und stellt den anderen wieder her
scheduler:; sollte auf keinen Fall unterbrochen werden!
mov 31h, R0; wird fuer die indirekte addressierung benötigt und wird deshalb zeischen gespeichert
djnz 4FH, stack2; welches Programm ist als naechstes dran?
mov 31h,#0D0h; Sicherungsadresse von prg2
lcall pushRegs; Sicher Kontext
mov 31h, #080h
mov 4FH, #2; nächstes mal ist das andere Programm da
jmp weiter
stack2:;siehe oben
mov 31h,#080h
lcall pushRegs
mov 31h,#0D0h
weiter:
mov R0,A; Akku enthält die adresse des ende der wiederherzustellenden Kontext-Sicherung
lcall popRegs; Kontext ausgehend von der Adresse in R0 wiederherstellen
ret;

increaseTimer:; noch nicht fertig //TODO
djnz 34h, notinc
mov 34h,3Ch
djnz 35h, notinc
mov 35h,3Dh
inc 39h
notinc:ret; Hier sollte code stehn

;Sichert den Kontext von in die andresse und folgende, die in R0 steht
;zu sichernder SP soll in 2fh sein, kopie von R0 
;(wird ja für die indirekte adressierung gebraucht) in 31H
pushRegs:
mov 30h,SP
mov SP,2fh
push ACC;
push B;
push 0;R0
push 1
push 2
push 3
push 4
push 5
push 6
push 7;R7
push DPL;
push DPH;
mov R0,31h
mov @R0,SP
mov SP,30h
ret;

;Stellt die Register in umgekehrter Reihenfolge wieder her, ausgehend von der Adresse in R0
; siehe push Regs
popRegs:
mov 30h, SP
mov R0,31h
mov SP, @R0
pop DPH
pop DPL
pop 7
pop 6
pop 5
pop 4
pop 3
pop 2
pop 1
pop 0
pop B
pop ACC
mov 2Fh,SP 
mov SP,30h
ret;



prg1:; Demo Programm, kopiert die Dip schalter auf die neg-Logik
mov A,P0
anl A,#00001111B
mov B,#8;
mul AB
mov TH0,A;

mov A,P0;
SWAP A
orl A,#00001111B; Maskieren
ausprg1:mov P0,A
;lcall syscll; unterbricht sich selbst
jmp prg1


; lässt die stellung der dip schlater+knoepfe auf P1 rotieren
prg2:;
mov R4,#1
loopprg2:
mov A,P0
lcall uprg2
W0prg2:mov R1,#50
W1prg2: mov R2,#255
W2prg2: ;lcall syscll; unterbricht sich selbst um zeit abzugeben
;mov A,P0
;cjne A, 7Fh, neu
;lcall syscll
djnz R2, W2prg2
djnz R1, W1prg2
inc R4
;mov A,#8
cjne R4,#8,loopprg2
jmp prg2
neu:
lcall uprg2
;call syscll
jmp W2prg2

uprg2:
mov R7,A
anl A,#00001111B
mov R6,A
mov A,P3
RL A
RL A
CPL A
anl A,#11110000B
orl A,R6
cjne R4,#1,Wprg2
jmp raus
wprg2:mov 7fh,R4
rotiereprg2: RL A
djnz 7fh,rotiereprg2
raus:mov P1,A
mov 7fh, R7
ret

end
