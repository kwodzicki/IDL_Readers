FUNCTION READ_HadISST_netCDF, startDate, endDate, SEAICE=seaice
;+
; Name:
; Purpose:
; Inputs:
;   startDate : IDL Julday for startime of analysis
;   endDate   : IDL Julday for endtime of analysis
; Keywords:
;   SEAICE    : Set to zero (0) to leave sea ice value (-1000).
;                 Default is to change to NaN
;-

COMPILE_OPT IDL2

IF N_ELEMENTS(seaice) EQ 0 THEN seaice = 1B																		; Default value for seaice flag

var  = 'sst'																																	; Set variable name to read in
file = FILEPATH('HadISST_sst.nc', ROOT_DIR = !SST_Data)												; Set file path

data = READ_netCDF_FILE(file, VARIABLES='time_bnds', AS_STRUCT=0)							; Read in time bounds data
vars = data.VARIABLES																													; Get just variables
nLon = vars.LONGITUDE.N[0]
nLat = vars.LATITUDE.N[ 0]

time = REFORM(vars.TIME_BNDS.VALUES[0,*])																			; Get start date of time bounds
time = NUM2DATE(time, vars.TIME.UNITS)																				; Convert start date of time bound to julday

IF N_PARAMS() GE 1 THEN BEGIN
  IF N_ELEMENTS(startDate) EQ 2 THEN $
    id = WHERE(time GE startDate[0] AND time LE startDate[1], count) $
  ELSE $
    id = WHERE(time GE startDate AND time LE endDate, count)
  IF count GT 0 THEN BEGIN
    FILTER_TIME, vars, id
    offset = MIN(id)
  ENDIF ELSE $
    MESSAGE, 'No SST data in date range'
ENDIF ELSE BEGIN
  offset = 0
  count  = N_ELEMENTS(time)
ENDELSE

oid = NCDF_OPEN(file)																													; Ope file
vars[var] = DICTIONARY( NCDF_VARINQ(oid, var), /EXTRACT )											; Get information about variable, convert to dictionary, and store in vars dictioanry
FOR i = 0, vars[var].NATTS-1 DO BEGIN																					; Iterate over all the variable's attributes
  attName = NCDF_ATTNAME(oid, var, i)																					; Get attribute's name
  NCDF_ATTGET, oid, var, attName, attVal																			; Get attribute's value
  vars[var, attName] = attVal																									; Add attibute to the dictionary
ENDFOR																																				; End for
NCDF_VARGET, oid, var, data, OFFSET=[0, 0, offset], COUNT=[nLon, nLat, count]	; Read in data for times requested
NCDF_CLOSE, oid																																; Close the file

bad = (data EQ vars[var].missing_value) OR (data EQ vars[var]._FillValue)			; Create bad value mask
IF KEYWORD_SET(seaice) THEN bad = bad OR (data EQ -1000)											; If seaice key set, add sea ice to bad mask
bad = WHERE(bad EQ 1, nbad)																												; Get indices of bad values
IF nbad GT 0 THEN data[bad] = !Values.F_NaN																		; Convert bad values to NaN

vars[var,'values'] = data																											; Add data to dictionary
    
RETURN, vars																																	; Return Dictionary

END
