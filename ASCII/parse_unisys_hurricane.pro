FUNCTION PARSE_UNISYS_HURRICANE 
;+
; Name:
;   PARSE_UNISYS_HURRICANE
; Purpose:
;   A procedure to parse information from the UNISYS Hurricane Database.
; Author and History:
;   Kyle R. Wodzicki     Created 01 Dec. 2016
;-
COMPILE_OPT IDL2

files = ['~/UNISYS_Hurricane_E_Pacific.txt', '~/UNISYS_Hurricane_W_Pacific.txt']
region = ['east','west']
a_fmt = '(I5,1X,A10,3X,I2,I3,6X,I4,1X,A12,5X,I1,5X,I1)'													; Formatting for Type A data
b_fmt = '(I5,1X,A5,4(A1,I3,I4,I4,I5),A1)'																				; Formatting for Type B data
c_fmt = '(I5,1X,A2)'																														; Formatting for Type C data
card=0L & date='' & days=0L  & snum=0L & tnum=0L & name='' & us_h=0B & HiUS=0B
line = '' & tp=''

data = {}
FOR k = 0, N_ELEMENTS(files)-1 DO BEGIN
	OPENR, lun, files[k], /GET_LUN
	WHILE NOT EOF(lun) DO BEGIN
		READF, lun, card,date,days,snum,tnum,name,us_h,HiUS,FORMAT=a_fmt							; Read Type A line
		tmp  = {CARD : card, 						$ ; Card Number
						DATE : date, 						$ ; Get date from the line; mm/dd/yyyy
						DAYS : days, 						$ ; Get number of days of data for the storm
						SNUM : snum, 						$ ; Get storm number for the year
						TNUM : tnum, 						$ ; Get total number of storms up to that point
						NAME : STRTRIM(name,2), $ ; Get name of the storm
						US_H : us_h, 						$ ; Get US Hit
						HiUS : HiUS}   						; Get Hi US Category
		nData = tmp.DAYS * 4
		cards = [] & mmdd = [] & type = [] & lat = [] & lon = []
		wind  = [] & pres = [] & time = []
		FOR i = 0, tmp.DAYS-1 DO BEGIN
			READF, lun, line      																										; Read Type B line(s)
			start = 11
			IF STRLEN(line) GE 29 THEN BEGIN
				cards = [cards, LONG(STRMID(line,0,5))]
				mmdd  = [mmdd,  STRMID(line,6,5)]
				type  = [type,  STRMID(line,start,1)] 			& start+=1
				lat   = [lat,   LONG(STRMID(line,start,3))]	& start+=3
				lon   = [lon,   LONG(STRMID(line,start,4))]	& start+=4
				wind  = [wind,  LONG(STRMID(line,start,4))] & start+=4
				pres  = [pres,  LONG(STRMID(line,start,5))]	& start+=5
				time  = [time, 0]
				IF STRLEN(line) GE 46 THEN BEGIN
					type  = [type,  STRMID(line,start,1)] 			& start+=1
					lat   = [lat,   LONG(STRMID(line,start,3))]	& start+=3
					lon   = [lon,   LONG(STRMID(line,start,4))]	& start+=4
					wind  = [wind,  LONG(STRMID(line,start,4))] & start+=4
					pres  = [pres,  LONG(STRMID(line,start,5))]	& start+=5
					time  = [time, 6]
					IF STRLEN(line) GE 63 THEN BEGIN
						type  = [type,  STRMID(line,start,1)] 			& start+=1
						lat   = [lat,   LONG(STRMID(line,start,3))]	& start+=3
						lon   = [lon,   LONG(STRMID(line,start,4))]	& start+=4
						wind  = [wind,  LONG(STRMID(line,start,4))] & start+=4
						pres  = [pres,  LONG(STRMID(line,start,5))]	& start+=5
						time  = [time, 12]
						IF STRLEN(line) EQ 80 THEN BEGIN
							type  = [type,  STRMID(line,start,1)] 			& start+=1
							lat   = [lat,   LONG(STRMID(line,start,3))]	& start+=3
							lon   = [lon,   LONG(STRMID(line,start,4))]	& start+=4
							wind  = [wind,  LONG(STRMID(line,start,4))] & start+=4
							pres  = [pres,  LONG(STRMID(line,start,5))]	& start+=5
							time  = [time, 18]
						ENDIF
					ENDIF
				ENDIF
			ENDIF
		ENDFOR
		tmp = CREATE_STRUCT(tmp, 'DATA', $
			{CARD : cards, MMDD : mmdd, TYPE : type, LAT : lat*0.1, LON : lon*0.1, $
			 WIND : wind,  PRES : pres, TIME : time})
		id = WHERE(tmp.DATA.LAT  EQ 0 AND tmp.DATA.LON  EQ 0 AND $
							 tmp.DATA.WIND EQ 0 AND tmp.DATA.PRES EQ 0, CNT)
		IF region[k] EQ 'east' THEN tmp.DATA.LON = -1 * tmp.DATA.LON
		IF region[k] EQ 'west' THEN tmp.DATA.LON = 360 - tmp.DATA.LON
		IF (CNT GT 0) THEN FOR i = 3, 6 DO tmp.DATA.(i)[id] = !Values.F_NaN
		READF, lun, card, tp, FORMAT=c_fmt																						; Read Type C line
		tmp = CREATE_STRUCT(tmp, 'TP', tp)
		tag = [STRSPLIT(tmp.NAME,'-',/EXTRACT), STRTRIM(tmp.CARD,2), region[k]]			; Get info to make a tag name
		data = CREATE_STRUCT(data, STRJOIN(tag,'_'), tmp)
	ENDWHILE
	FREE_LUN, lun
ENDFOR
RETURN, data
END