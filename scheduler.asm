;AT89C5131-Multitasker
;@author: Jan Hofmeier

;verwendete Speicheradressen:
;2fh: StackPointer Zwischenspeicher
;30h: Scheduler-StackPointer zwischenspeicher
;31h: Parameter für push/pop Regs
;4Eh: Scheduler aussetzter
;4Fh: Prozess das als naechstes fortgesetzt wird
;80h: SP-Sicherung Prozess 1
;81h: Anfang Stack Prozess 1
;0D0h Sp_sicherung Prozess 2
;0D1h: Anfang Stack Prozess 2




cseg at 0
jmp spl1; springe ueber die IR-Einspringadressen

org 000Bh ;Timer Interrupt Einsprungsadresse
jmp kerneltimer

;Fuer den Aufruf per Timer:
; welchselt den Prozess falls 4Eh==1
kerneltimer:
push PSW; PSW (flags) sichern
mov 2fh,SP; Stack zwischenspeichern
djnz 4Eh, weg ;Scheduler soll einmal aussetzten, wenn er vorher schon durch syscll aufgerufen wurde
inc 4Eh; dec durch djnz rückgängig machen, djnz benötigt im gegensatz zu cjne rein register
mov SP,#0F0h; dritter Stack "um den Weg zurück zu finden"
lcall scheduler; Kontext und SP tauschen
mov SP,2fh; SP wiederherstellen
weg: pop PSW; PSW wiederherstellen
reti; hoffentlich an die Richtige stelle zurück ;)

; Zum Starten des ganzen
; Stack fuer Prozess 2 2erstelle
; und PC durch "lcall" darauf legen
spl1:
mov 4Eh,#1; Damit der Scheduler beim nächten Timer Interrupt aufgerufen wird
mov SP,#0D1h ;Adresse stack prozess 2
lcall spl2; dient nur dazu die startadresse fuer Prg1 in den Stack zu schreiben, der rÃ¼cksprung wird dann vom kernel erledigt
jmp prg2; springe zu prg2

;Restliche Kontextsicherung fuer Prozess 2
;Timer + Interrupt Initialisieren;
;Prozess 1 starten
spl2:
mov 4Fh,#2;prozess 2 soll als nächtes gestartet werden
push PSW; PSW fuer prozess 2 auf den Stack
mov 2fh,SP; SP von prozess 2 zwischenspeichern
mov SP,#0F0h; Zusatzstack
mov 31h,#0D0h; Adresse für die Kontextsicherung von prozess 2
lcall pushRegs; Kontext sichern
mov SP, #081h ; Adresse stack prozess 1
;Aktiviere Interrupts
setb ET0; Timer fuer den Scheduler
setb EA; Aktivere Interrupts allgemein
mov TH0,#56;Initialisiere reload wert für Scheduler-Timer
mov TL0,#56;Startwert für Scheduler Timer
mov TMOD,#01010010B; Auto-reload Modus
setb TR0; Starte Timer
jmp prg1; Beginne mit der ausführung von prg1


;Hierueber kann ein Prozess Rechenzeit abgeben (soll spaeter auch Ausgabe etc bereitstellen)
; Auch fuer die demo von Kooperativen MT, idle muesste dafuer entfernt werden
syscll:
push PSW; PSW auf den Stack bevor es verfaelscht wird
mov 2Fh,SP; Prozess SP fuer die Sicherung nach 2Fh
push ACC; Akku auf den Stack (er wird für cjne benoetigt)
inc 4Eh; zähle 1 hoch um den Scheduler einmal aussetzten zu lassen
mov A,4eh; cjne kann nur mit Registern vergleichen
cjne A,#2, nicht; beide Prozesse haben ihre Zeit abgegeben
pop ACC; Akku inhalt wiederherstellen
mov SP,#0F0h; SchedulerStack anlegen
lcall scheduler; Kontext vertauschen
mov SP,2fh; (den anderen) Prozess SP wiederherstellen
pop PSW; PSW vom Stack holen
ret; Ruecksprung, zum anderen Prozess
nicht:; beide Prozesse haben nichts zu tun, CPU soll bis in (Timer)-Interrupts schlafen
lcall idle
lcall idle
pop ACC; Akku wiedherstellen
pop PSW; PSWO wiederherstllen
ret

;fuer den rein kooperativen Betrieb. ACHTUNG: nicht mit dem praeemptiven Modus kombinieren
;Wechselt den Prozess
koop:
push PSW; schnell das PSW sichern bevor es verfaelscht wird
mov 2Fh,SP; Prozess SP sichern
mov SP,#0F0h; Scheduler-Stack anlegen
lcall scheduler; Kontext vertauschen
mov SP,2fh; (den anderen)Prozess SP laden;
pop PSW; PSW vom Stack holen
ret

idle: ;cpu soll idlen, verwendet Akku
mov A,PCON
orl A,#1
mov PCON,A
ret;

;Vertauscht: sichert den einen Kontext und stellt den anderen wieder her
; 4Fh speichert welcher Prozess als naechses dran ist
scheduler:; sollte auf keinen Fall unterbrochen werden!
mov 31h, R0; wird fuer die indirekte addressierung benötigt und wird deshalb zeischen gespeichert
djnz 4FH, stack2; welcher Prozess ist als naechstes dran?
mov 31h,#0D0h; Sicherungsadresse von SP von Prozess 2
lcall pushRegs; Sicherung des Kontext
mov 31h, #080h; SP-Sicherung laden
mov 4FH, #2; nächstes mal ist der andere Prozess da
jmp weiter
stack2:;siehe oben
mov 31h,#080h; SP-Sicherungs Adresse
lcall pushRegs; Sicherung des Kontextes
mov 31h,#0D0h; SP-Sicherung laden
weiter:
lcall popRegs; Kontext wiederherstellen (31h als Parameter)
ret;

;Parameter: 31h: Adresse für Prozess SP Sicherung, 2Fh: Prozess SP
;Verwended 30h zum Zwischenspeichern	
;Pusht die Register auf den Stack von dem SP in 2Fh und speichert dann den SP in der Adresse
; die in 31H steht
pushRegs:
mov 30h,SP; Scheduler SP zwischenspeichern
mov SP,2fh; Prozess SP aktivieren, hierauf soll ja gesichert werden
push ACC; Sichere Akku
push B; Sichere B-Hilfsregister
;Register R0-R7:
push 0;R0
push 1
push 2
push 3; loopunwinding aus Performence gruenden
push 4
push 5
push 6
push 7;R7
push DPL; DatenPointer-Low 
push DPH; Datenpointer High
mov R0,31h; R0, wird fuer die Indireke Adressierung benötigt
mov @R0,SP; Sicher den SP in der Adresse aus 31h bzw R0
mov SP,30h; verwende wieder den Scheduler SP
ret;

;Parameter: 31h: enthaelt die Adresse aus der der Prozess-SP geladen werden soll
;returnt in 2Fh den Prozess SP
;Stellt den Prozess-Kontext aus dem Stack des geladenen SPs wieder her.
popRegs:
mov 30h, SP; Scheduler SP zwischenspeichern
mov R0,31h; R0 fuer indirekte Adressierung
mov SP, @R0; Prozess SP aus der uebergebenen Adresse laden
; Stelle alle Gegister in umgekehter Reihenfolge zu pushRegs wiederher (vom Stack))
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
mov 2Fh,SP; Prozess SP in 2Fh zwischenspeichern
mov SP,30h; Scheduler Stack reaktivieren
ret;


prg1:; Demo Programm, kopiert die Dip schalter auf die neg-Logik
mov A,P0;
SWAP A
orl A,#00001111B; Maskieren
mov P0,A
jmp prg1

;Rotiere die Stellung der DIP schalter auf P1,
;lese DIP-Schalter nur einmal pro kompletter Rotation ein
prg2:
mov R1,#7
mov A,P0
anl A,#11110000B
loopprg2:
mov P1,A
call warte;
RL A;
djnz R1, loopprg2
jmp prg2

; verwendet Register: R5, R6, R7
warte:
mov R5, #2
W0prg2:mov R6,#255
W1prg2: mov R7,#255
W2prg2: ;lcall koop; syscll; unterbricht sich selbst um Zeit abzugeben
djnz R7, W2prg2
djnz R6, W1prg2
djnz R5, W0prg2
ret

end
