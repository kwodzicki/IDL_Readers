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

tmp = STRSPLIT(units, ' ', /EXTRACT)
CASE STRLOWCASE(tmp[0]) OF
  'hours'   : new_dates = dates /    24.0D0
  'minutes' : new_dates = dates /  1440.0D0
  'seconds' : new_dates = dates / 86400.0D0
  ELSE      : new_dates = dates
ENDCASE
yymmdd  = FLOAT(STRSPLIT(tmp[2], '-', /EXTRACT))
hrmnsc  = FLOAT(STRSPLIT(tmp[3], ':', /EXTRACT))

RETURN, GREG2JUL( yymmdd[1], yymmdd[2], yymmdd[0], $
                  hrmnsc[0], hrmnsc[1], hrmnsc[2] ) + new_dates

END 
