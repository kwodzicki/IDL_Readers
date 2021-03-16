FUNCTION GET_TIME_UNITS, refTime, units
;+
; Name:
;   GET_TIME_UNITS
; Purpose:
;   Function to generate string containg units for time variable in 
;   netCDF files.
; Inputs:
;   refTime : Reference time in IDL julian time
;   units   : The offset units, some standards are days, months, etc.
; Keywords:
;   None.
; Returns:
;   String containg time unit information
;-
COMPILE_OPT IDL2

format = "(A,' since ',I04,'-',I02,'-',I02,1X,I02,':',I02,':',F06.3)"						; Format for unit string

JUL2GREG, refTime, mm, dd, yy, hr, mn, sc																				; Get gregorian time

RETURN, STRING(STRLOWCASE(units), yy, mm, dd, hr, mn, sc, FORMAT=format)				; Return string

END
