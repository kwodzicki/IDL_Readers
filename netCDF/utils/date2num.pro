FUNCTION DATE2NUM, dates, units
;+
; Name:
;   DATE2NUM
; Purpose:
;   An IDL function to convert dates stored as IDL juldates to numbers
; Inputs:
;   dates   : Raw dates from netCDF file
;   units   : Units for the dates
; Keywords:
;   None.
; Returns:
;   dates from IDL juldays
;-

COMPILE_OPT IDL2

tmp     = STRSPLIT(units, ' ', /EXTRACT)
yymmdd  = FLOAT(STRSPLIT(tmp[2], '-', /EXTRACT))
hrmnsc  = FLOAT(STRSPLIT(tmp[3], ':', /EXTRACT))

new_dates = dates - GREG2JUL( yymmdd[1], yymmdd[2], yymmdd[0], $
                              hrmnsc[0], hrmnsc[1], hrmnsc[2] )

CASE STRLOWCASE(tmp[0]) OF
  'hours'   : RETURN, new_dates *    24.0D0
  'minutes' : RETURN, new_dates *  1440.0D0
  'seconds' : RETURN, new_dates * 86400.0D0
  ELSE      : RETURN, new_dates ;Assume in days since
ENDCASE

END 
