FUNCTION FILTER_NETCDF_BY_TIME, data, times, PRECISION = precision
;+
; Name:
;   FILTER_NETCDF_BY_TIME
; Purpose:
;   IDL function to filter data from netCDF file based on
;   time.
; Inputs:
;   data  : struct or dict returned by call to READ_netCDF_FILE()
;   times : scalar or array of IDL JULDAY times
; Keywords:
;   PERCISION : float specifying precision of time difference for matching
;                times in seconds. Default is 1 second
; Returns:
;   Updated structure or dictionary filtered by date. Return type
;   matches input type
;-
COMPILE_OPT IDL2

IF N_ELEMENTS(precision) EQ 0 THEN precision = 1.0D0													; Set precision to 1 second by default
precision /= 86400.D0																													; Convert to julday units (per day)
 
tid = data.DIMENSIONS.TIME.ID																									; Get time dimension number from netCDF file
ids = []																																			; Initialize list of indices to filter by
FOR i = 0, N_ELEMENTS(times)-1 DO BEGIN																				; Iterate over all times
  dt = MIN( ABS(data.VARIABLES.TIME.JULDAY - times[i]), id )									; Compute difference between data times and requested time, take absolute value, then get minimum difference and index of minimum
  IF dt LT precision THEN ids = [ids, id]																			; If time difference minimum is less than precision, then add id to ids list
ENDFOR

IF N_ELEMENTS(ids) EQ 0 THEN BEGIN																						; If no values in ids
  MESSAGE, 'Requested times NOT in data!', /CONTINUE													; Warn user
  RETURN, data																																; Return data unfiltered
ENDIF

isStruct = ISA(data, 'STRUCT')																								; Test for data is structure
IF isStruct EQ 1 THEN data = DICTIONARY(data, /EXTRACT)												; If structure, convert to dictionary

FOREACH var, data.VARIABLES DO BEGIN																					; Iterate over all variables
  id = WHERE(var.DIM EQ tid, cnt)																							; Locate time dimension in the variable
  IF cnt EQ 1 THEN BEGIN																											; If variable contains time dimension
    CASE id[0] OF																															; Case for which dimension to filter over
      0    : var['VALUES'] = var.VALUES[ids,  *,  *,  *,  *,  *,  *,  *] 
      1    : var['VALUES'] = var.VALUES[  *,ids,  *,  *,  *,  *,  *,  *] 
      2    : var['VALUES'] = var.VALUES[  *,  *,ids,  *,  *,  *,  *,  *] 
      3    : var['VALUES'] = var.VALUES[  *,  *,  *,ids,  *,  *,  *,  *] 
      4    : var['VALUES'] = var.VALUES[  *,  *,  *,  *,ids,  *,  *,  *] 
      5    : var['VALUES'] = var.VALUES[  *,  *,  *,  *,  *,ids,  *,  *] 
      6    : var['VALUES'] = var.VALUES[  *,  *,  *,  *,  *,  *,ids,  *] 
      7    : var['VALUES'] = var.VALUES[  *,  *,  *,  *,  *,  *,  *,ids] 
      ELSE : MESSAGE, 'Can only have 8 dimensions!'														; Throw error if id is not 0-7
    ENDCASE
  ENDIF
ENDFOREACH																																		; End iteration over variables

data.VARIABLES.TIME['JULDAY'] = NUM2DATE(data.VARIABLES.TIME.VALUES, data.VARIABLES.TIME.UNITS); Update JULDAY tag

JUL2GREG, data.VARIABLES.TIME.JULDAY, mm, dd, yy, hr													; Get month, day, year, hour
data.VARIABLES.TIME['YEAR' ] = yy																							; Update year list
data.VARIABLES.TIME['MONTH'] = mm
data.VARIABLES.TIME['DAY'  ] = dd
data.VARIABLES.TIME['HOUR' ] = hr

IF isStruct EQ 1 THEN data = data.ToStruct(/No_Copy, /RECURSIVE)							; If input was structure, convert dictionary back to structure

RETURN, data																																	; Return filtered data

END
