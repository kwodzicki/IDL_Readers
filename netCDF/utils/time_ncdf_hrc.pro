FUNCTION TIME_NCDF_HRC, time_in, JULIAN=julian

;+
; Name:
;		TIME_NCDF_HRC
; Purpose:
;		To determine the days since 1800-01-01-00 [yyyy-mm-dd-hh]
;		from a HRC data file
; Calling Sequence:
;		TIME_NETCDF(time_in)
; Inputs:
;		time_in		: Input time to determine year, month, day, and hour of
; Outputs:
;		out_time	: The year, month, day, and hour of the input time. 
;								Output is format [yyyy, mm, dd].
; Keywords:
;		JULIAN		: Set this to output in julian day format using JULDAY
; Author and History:
;		Kyle R. Wodzicki	Created 25 AUG 2014
;-

COMPILE_OPT IDL2																											;Set compile options

IF (N_TAGS(time_in) NE 0) THEN time_in=time_in.TIME										;If input is STRUCT, get time variable

IF (N_ELEMENTS(time_in) GT 1) THEN BEGIN															;If more than one input time
	out_time = MAKE_ARRAY(3,N_ELEMENTS(time_in), /LONG)									;Make array to store times
ENDIF ELSE BEGIN
	out_time = MAKE_ARRAY(3, /LONG)
ENDELSE

FOR h = 0, N_ELEMENTS(time_in)-1 DO BEGIN															;Iterate over all input times
	days_from = 0.0D00																									;Initialize hours_from 1900 to zero
	FOR i = 0, 250 DO BEGIN
		cur_year = 1800+i																									;The current year
		cur_days = JULIAN_DAY_MOD(cur_year)																;Days in current year
		FOR j= 1, 12 DO BEGIN																							;Iterate over each month
			days_from = days_from+cur_days[j]
			IF (days_from EQ time_in[h]) THEN BEGIN													;If found hour
				day   = 1
				month = j+1
				year  = cur_year
				IF (month GT 12) THEN BEGIN
					month=1 & year++
				ENDIF
				GOTO, FOUND																										;Jump to Return statement
			ENDIF
		
			IF (days_from GT time_in[h]) THEN BEGIN													;If overshot the hour then:
				days_from = days_from-cur_days[j]															;Subtract hours form current month
				FOR k = 1, cur_days[j] DO BEGIN																;Iterate over days in month
					IF (days_from+(k-1) EQ time_in[h]) THEN BEGIN
						day   = k
						month = j
						year  = cur_year
						GOTO, FOUND						;Jump to Return statement
					ENDIF
				ENDFOR										;End of `k' loop
			ENDIF
		ENDFOR												;End of `j' loop
	ENDFOR													;End of `i' loop

	FOUND: out_time[*, h] = [year, month, day]
ENDFOR

IF KEYWORD_SET(julian) THEN BEGIN
	out_time = JULDAY(out_time[1,*], out_time[2,*], $
						out_time[0,*])
ENDIF

RETURN, out_time

END