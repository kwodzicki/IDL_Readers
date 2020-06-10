PRO _READ_TMI_FILE_LOCAL, file, i, n, data, _EXTRA = _extra
;+
; Name:
;   _READ_TMI_FILE_LOCAL
; Purpose:
;   A 'local' procedure to read in data from RSS TMIv7 monthly files.
;   This procedure was created to make code in main function cleaner.
; Inputs:
;   file   : Full path of file to read
;   i      : Time indes of data for output arrays
;   n      : Number of timesteps
;   data   : Dictionary to store data in
; Keywords:
;   Any accepted by READ_TMI_AVERAGED_V7_KRW()
; Outputs:
;   data   : Same as input data, but updated with data read from file
;-
COMPILE_OPT IDL2, HIDDEN

tmp  = READ_TMI_AVERAGED_V7_KRW(file, AS_STRUCT = 0, _EXTRA = _extra)
dims = SIZE(tmp.LON.VALUES, /DIMENSIONS)
dims = [dims, n]

IF N_ELEMENTS(data) EQ 0 THEN data = RECURSIVE_COPY( tmp )
PRINT, file
FOREACH key, tmp.KEYS() DO $
  IF TOTAL(STRMATCH(['LON', 'LAT'], key, /FOLD_CASE), /INT) EQ 0 THEN BEGIN
    IF SIZE(data[key,'VALUES'], /N_DIMENSIONS) EQ 2 THEN $    
      data[key,'VALUES'] = MAKE_ARRAY(dims, VALUE=!Values.F_NaN)
    data[key,'VALUES',0,0,i] = tmp[key,'VALUES'] 
  ENDIF

END

FUNCTION READ_TMI_AVERAGED_V7_SPAN, startDate, endDate, _EXTRA = _extra
;+
; Name:
;   READ_TMI_AVERAGED_V7_SPAN
; Purpose:
;   Function to read in all monthly files with the timespan defined.
; Inputs:
;   startDate : JULDAY of start date to read; inclusive
;   endDate   : JULDAY of end date to read; inclusive
; Keywords:
;   variables : Scalar or array of strings of variables to read
;   NO_LAND   : If set, land values read in as NaN
;   LIMIT     : Geographical limit; [latMin, lonMin, latMax, lonMax]
;   RRDAY     : If set, rain rates returned in mm/day; default is mm/hr
; Outputs:
;   Returns structure containing data
;-

COMPILE_OPT IDL2

times = TIMEGEN(START=startDate, FINAL=endDate, UNITS='month')								; Generate times between start and end
JUL2GREG, times, mm, dd, yy																										; Get MM, DD, YYYY from dates

n    = N_ELEMENTS(mm)																													; Number of timesteps
FOR i = 0, n-1 DO BEGIN																												; Iterate over all time steps
  file = RSS_TMI_FILEPATH(yy[i], mm[i])																				; Path of file to read
  _READ_TMI_FILE_LOCAL, file, i, n, data, _EXTRA = _extra											; Read data
ENDFOR

RETURN, data																																	; Return data

END
