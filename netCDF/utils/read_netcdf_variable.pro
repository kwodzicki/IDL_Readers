FUNCTION READ_netCDF_VARIABLE, iid, vid, $
  SCALE_DATA = scale_data, $
  ADD_FIRST  = add_first, $
  FLOAT      = float, $
  _EXTRA     = _extra

;+
; Name:
;   READ_netCDF_VARIABLE
; Purpose:
;   Function to read a single variable from a netCDF file
; Inputs:
;   iid   : netCDF file or group handle OR path to file
;   vid   : Name or ID of the variable to read
; Keywords:
;   SCALE_DATA : Set to scale data based on scale_factor and add_offset.
;                 Default is to scale data
;   ADD_FIRST  : Set this to subtract the add_offset attribute from data and
;                 then scale. Used for MODIS data because they don't know how
;                 scale things.
;   FLOAT      : Set to force any double precision variables to single-precision
;                 to save memory.
;   _EXTRA     : Any valid keywords for the NCDF_VARGET procedure
; Returns:
;   Dictionary containing variable attributes and values
;-

COMPILE_OPT IDL2

IF ISA(iid, 'STRING') THEN BEGIN
  file = iid																																	; Set file to iid
  iid  = NCDF_OPEN(file, /NOWRITE)																						; Open file, setting iid to file id; ensure is in read-only mode
ENDIF

IF N_ELEMENTS(scale_data) EQ 0 THEN scale_data = 1B														; Scale data by default

var_data = GET_ATTRIBUTES(iid, vid, FLOAT = float)

NCDF_VARGET, iid, vid, data, _EXTRA = _extra

IF STRMATCH(var_data.NAME, 'TIME', /FOLD_CASE) THEN BEGIN
 IF var_data.HasKey('UNITS') THEN $
  julDate = var_data.HasKey('UNITS') ? NUM2DATE(data, var_data.UNITS) : data
  JUL2GREG, juldate, mm, dd, yy,  hr																					; Convert the julian date
  ;  Add the year, month, day, hour information to the dictionary
  var_data['Year'  ] = yy
  var_data['Month' ] = mm             
  var_data['Day'   ] = dd
  var_data['Hour'  ] = hr
  var_data['JULDAY'] = juldate
ENDIF ELSE IF KEYWORD_SET(scale_data) THEN BEGIN                              ; Scale the data if the keyword is set
  replace_id = LIST()
  IF var_data.HasKey('_FillValue') THEN BEGIN																	; If _fillvalue in dictionary
    id = WHERE(data EQ var_data['_FillValue'], cnt)														; Locate fill values
    IF (CNT GT 0) THEN replace_id.ADD, id																			; If values located, then append indices to replace_ids list
  ENDIF

  IF var_data.HasKey('missing_value') THEN BEGIN															; If missing_value in the dictionary
    id = WHERE(data EQ var_data['missing_value'], CNT)												; Locate missing values
    IF (CNT GT 0) THEN replace_id.ADD, id																			; If values located, then append indices to replace_ids list
  ENDIF

  IF var_data.HasKey('valid_range') THEN BEGIN																; If valide_range key is in the dictionary
    id = WHERE(data LT var_data['valid_range', 0] OR $												; Locate values outside of range
               data GT var_data['valid_range', 1], CNT)
    IF (CNT GT 0) THEN replace_id.ADD, id																			; If values located, then append indices to replace_ids list 
  ENDIF

  IF KEYWORD_SET(add_first) THEN BEGIN																				; If add first is set
    IF var_data.HasKey('add_offset') THEN $																		; Offset the data IF an offset was read in
      data = TEMPORARY(data) - var_data['add_offset']
    IF var_data.HasKey('scale_factor') THEN $																	; Scale the data IF a scale factor was read in
      data = TEMPORARY(data) * var_data['scale_factor']
  ENDIF ELSE BEGIN																														; Else
    IF var_data.HasKey('scale_factor') THEN $																	; Scale the data IF a scale factor was read in
      data = TEMPORARY(data) * var_data['scale_factor']
    IF var_data.HasKey('add_offset') THEN $																		; Offset the data IF an offset was read in
      data = TEMPORARY(data) + var_data['add_offset']
  ENDELSE

  ;=== Replace invalid data if any present
  IF (N_ELEMENTS(replace_id) GT 0) THEN BEGIN
    replace_id = replace_id.ToArray(DIMENSION=1, /No_Copy)										; Convert list to array
    type = SIZE(data, /TYPE)
    IF ((type LT 4) OR (type GT 6)) AND (type NE 9) THEN data = FLOAT(data)
    data[replace_id] = !Values.F_NaN
  ENDIF
ENDIF

var_data['SHAPE']  = SIZE(data, /DIMENSIONS)
var_data['VALUES'] = data																											; Add data to dictionary

IF N_ELEMENTS(file) EQ 1 THEN BEGIN																						; If file variable is defined
  NCDF_CLOSE, iid																															; Close iid
  iid = file																																	; Set iid back to input value
ENDIF

RETURN, var_data																															; Return dictionary

END 
