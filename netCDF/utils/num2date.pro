FUNCTION NUM2DATE, dates, units
;+
; Name:
;   NUM2DATE
; Purpose:
;   An IDL function to convert dates stored as numbers to IDL juldates
; Inputs:
;   dates   : Raw dates from netCDF file
;   units   : Units for the dates
; Keywords:
;   None.
; Returns:
;   IDL juldaY from JUL2GREG function
;-

COMPILE_OPT IDL2

IF units.TYPECODE EQ 1 THEN units = STRING(units)

tmp = STRSPLIT(units, ' ', /EXTRACT)																					; Split units on space
CASE STRLOWCASE(tmp[0]) OF																										; Check first value for units
  'hours'   : new_dates = dates /    24.0D0																		; If hours, divide dates by 24 hr/day
  'minutes' : new_dates = dates /  1440.0D0																		; If minutes, divide by 1440 min/day
  'seconds' : new_dates = dates / 86400.0D0																		; If seconds, divide by 86400 sec/day
  ELSE      : new_dates = dates																								; Else, assume data in units of days since
ENDCASE
yymmdd  = FLOAT(STRSPLIT(tmp[2], '-', /EXTRACT))															; Get year, month, day from units
hrmnsc  = FLOAT(STRSPLIT(tmp[3], ':', /EXTRACT))															; Get hour, minute, seconds from units

RETURN, GREG2JUL( yymmdd[1], yymmdd[2], yymmdd[0], $													; Build IDL Julday values and return
                  hrmnsc[0], hrmnsc[1], hrmnsc[2] ) + new_dates

END 
