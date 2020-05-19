PRO CONVERT_LONGITUDE_netCDF, data, MODEL = model
;+
; Name:
;   CONVERT_LONGITUDE_netCDF
; Purpose:
;   Procedure for converting/shifting data from netcdf to new longitude
;   system.
; Inputs:
;   data  : Dictionary or structure in READ_netCDF_FILE format
; Keywords:
;   MODEL  : Converts from -180 to 180 to 0 to 360 (model) convention.
;              This is the default. Set MODEL=0 to convert to -180 to 180.
; Outputs:
;   Updates data variable.
;-
COMPILE_OPT IDL2

IF N_ELEMENTS(model) EQ 0 THEN model = 1B

isStruct = ISA(data, 'STRUCT')
IF isStruct THEN data = DICTIONARY(data, /EXTRACT)

key = 'LONGITUDE'																															; Key for longitude variable

IF data.HasKey( key ) THEN BEGIN
  dimID = data[key].DIM																												; netCDF dimension for longitude
  lon   = data[key].VALUES
  IF KEYWORD_SET(model) THEN BEGIN																						; If model keyword is set
    id = WHERE(lon LT 0, cnt)																									; Locate values less than zero
    IF cnt GT 0 THEN lon[id] += 360
  ENDIF ELSE BEGIN																														; Else
    id = WHERE(lon GT 180, cnt)																								; Locate values greater than 180
    if cnt GT 0 THEN lon[id] -= 360
  ENDELSE

  IF cnt GT 0 THEN BEGIN																											; If data matching criteria
    sid = SORT(lon)																														; Get indices for sorting longitude from low to high
    data[key,'VALUES'] = lon[sid]																							; Sort longitudes and update values in data dictionary
    FOREACH tag, data.KEYS() DO $																							; Iterate over all varaibles
      IF ~STRMATCH(tag, key, /FOLD_CASE) THEN BEGIN														; If data is NOT longitude
        id = WHERE(data[tag].DIM EQ dimID, cnt)																; Locate dimension of longitude in variable
        CASE id[0] OF 
          0    : data[tag,'VALUES'] = data[tag].VALUES[sid,   *,   *,   *,   *,   *,   *,   *] 
          1    : data[tag,'VALUES'] = data[tag].VALUES[  *, sid,   *,   *,   *,   *,   *,   *] 
          2    : data[tag,'VALUES'] = data[tag].VALUES[  *,   *, sid,   *,   *,   *,   *,   *] 
          3    : data[tag,'VALUES'] = data[tag].VALUES[  *,   *,   *, sid,   *,   *,   *,   *] 
          4    : data[tag,'VALUES'] = data[tag].VALUES[  *,   *,   *,   *, sid,   *,   *,   *] 
          5    : data[tag,'VALUES'] = data[tag].VALUES[  *,   *,   *,   *,   *, sid,   *,   *] 
          6    : data[tag,'VALUES'] = data[tag].VALUES[  *,   *,   *,   *,   *,   *, sid,   *] 
          7    : data[tag,'VALUES'] = data[tag].VALUES[  *,   *,   *,   *,   *,   *,   *, sid] 
          ELSE : ; Fail silently; if id is -1 (no longitude)
        ENDCASE
      ENDIF
  ENDIF
ENDIF ELSE IF data.HasKey('VARIABLES') THEN BEGIN															; Else, if has VARIABLES key
  CONVERT_LONGITUDE_netCDF, data.VARIABLES, MODEL = model											; Recursive call to procedure passing in variables dictionary
ENDIF ELSE $																																	; Else
  MESSAGE, "No 'longitude' variable in data!", /CONTINUE											; Pring message

IF isStruct THEN data = data.ToStruct(/No_Copy, /RECURSIVE)										; Maybe convert back to structure

END
