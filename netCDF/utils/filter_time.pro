PRO FILTER_TIME, data, tids
;+
; Name:
;   FILTER_TIME
; Purpose:
;   Procedure to filter data.VARIABES.TIME data
; Inputs:
;   data   : Dictionary or Structure containing data from netCDF
;   tids   : Indices to filter data
; Keywords:
;   None.
; Outputs:
;   Updates data variable
;-

COMPILE_OPT IDL2

; Convert to dictionary if not already
isStruct = ISA(data, 'STRUCT')
IF isStruct THEN data = DICTIONARY(data, /EXTRACT)

IF data.HasKey('TIME') THEN BEGIN																							; If time is in dictionary
  data['TIME','VALUES'] = data.TIME.VALUES[tids]															; Filter values to indices
  data['TIME','JULDAY'] = NUM2DATE(data.TIME.VALUES, data.TIME.UNITS)					; Compute julday from values
  JUL2GREG, data.TIME.JULDAY, mm, dd, yy, hr																	; Get gregorian date info
  data.TIME['YEAR' ] = yy																											; Update year, month, day, hour
  data.TIME['MONTH'] = mm
  data.TIME['DAY'  ] = dd
  data.TIME['HR'   ] = hr
ENDIF ELSE IF data.HasKey('VARIABLES') THEN BEGIN															; Else, if variables in dictionary
  FILTER_TIME, data.VARIABLES, tids																						; Recursive call to procedure passing in variables dictionary
ENDIF ELSE BEGIN																															; Else
  MESSAGE, "No 'time' variable found", /CONTINUE															; Warn that no time variable found
ENDELSE

IF isStruct THEN data = data.ToStruct(/No_Copy, /RECURSIVE)										; If input was structure, convert back to structure

END
