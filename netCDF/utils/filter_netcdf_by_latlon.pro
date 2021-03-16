FUNCTION FILTER_NETCDF_BY_LATLON, data, limit
;+
; Name:
;   FILTER_NETCDF_BY_LATLON
; Purpose:
;   IDL function to filter data from netCDF file based on
;   latitude/longitude
; Inputs:
;   data  : struct or dict returned by call to READ_netCDF_FILE()
;   limit : 4-element integer or floating array of format 
;            [latMin, lonMin, latMax, lonMax]
; Keywords:
;   None.
; Returns:
;   Updated structure or dictionary filtered by date. Return type
;   matches input type
;-
COMPILE_OPT IDL2

 
lonDim = data.DIMENSIONS['longitude'].ID																					; Get time dimension number from netCDF file
latDim = data.DIMENSIONS['latitude'].ID																						; Get time dimension number from netCDF file

IF limit[1] LT limit[3] THEN $
  lonIDs = WHERE(data.VARIABLES.LONGITUDE.VALUES GE limit[1] AND $
                 data.VARIABLES.LONGITUDE.VALUES LE limit[3], lonCNT) $
ELSE $
  lonIDs = WHERE(data.VARIABLES.LONGITUDE.VALUES GE limit[1] OR $
                 data.VARIABLES.LONGITUDE.VALUES LE limit[3], lonCNT)

IF lonCNT EQ 0 THEN BEGIN
  MESSAGE, 'Requested longitude limits NOT in data!', /CONTINUE													; Warn user
  RETURN, data
ENDIF

latIDs = WHERE(data.VARIABLES.LATITUDE.VALUES GE limit[0] AND $
               data.VARIABLES.LATITUDE.VALUES LE limit[2], latCNT)
IF latCNT EQ 0 THEN BEGIN 
  MESSAGE, 'Requested latitude limits NOT in data!', /CONTINUE													; Warn user
  RETURN, data
ENDIF

isStruct = ISA(data, 'STRUCT')																								; Test for data is structure
IF isStruct EQ 1 THEN $																												; If data is a structure
  tmp = DICTIONARY(data, /EXTRACT) $																					; Convert it to a dictionary in tmp variable
ELSE $																																				; Else, assume is dictionary
  tmp = RECURSIVE_COPY( data )																								; Recursviely copy the dictionary to tmp variable

FOREACH var, tmp.VARIABLES DO BEGIN																						; Iterate over all variables
  id = WHERE(var.DIM EQ latDim, cnt)																				  ; Locate time dimension in the variable
  IF cnt EQ 1 THEN BEGIN																											; If variable contains time dimension
    CASE id[0] OF																															; Case for which dimension to filter over
      0    : var['VALUES'] = var.VALUES[latIDs,     *,     *,     *,     *,     *,     *,     *] 
      1    : var['VALUES'] = var.VALUES[     *,latIDs,     *,     *,     *,     *,     *,     *] 
      2    : var['VALUES'] = var.VALUES[     *,     *,latIDs,     *,     *,     *,     *,     *] 
      3    : var['VALUES'] = var.VALUES[     *,     *,     *,latIDs,     *,     *,     *,     *] 
      4    : var['VALUES'] = var.VALUES[     *,     *,     *,     *,latIDs,     *,     *,     *] 
      5    : var['VALUES'] = var.VALUES[     *,     *,     *,     *,     *,latIDs,     *,     *] 
      6    : var['VALUES'] = var.VALUES[     *,     *,     *,     *,     *,     *,latIDs,     *] 
      7    : var['VALUES'] = var.VALUES[     *,     *,     *,     *,     *,     *,     *,latIDs] 
      ELSE : MESSAGE, 'Can only have 8 dimensions!'														; Throw error if id is not 0-7
    ENDCASE
  ENDIF
  id = WHERE(var.DIM EQ lonDim, cnt)																				  ; Locate time dimension in the variable
  IF cnt EQ 1 THEN BEGIN																											; If variable contains time dimension
    CASE id[0] OF																															; Case for which dimension to filter over
      0    : var['VALUES'] = var.VALUES[lonIDs,     *,     *,     *,     *,     *,     *,     *] 
      1    : var['VALUES'] = var.VALUES[     *,lonIDs,     *,     *,     *,     *,     *,     *] 
      2    : var['VALUES'] = var.VALUES[     *,     *,lonIDs,     *,     *,     *,     *,     *] 
      3    : var['VALUES'] = var.VALUES[     *,     *,     *,lonIDs,     *,     *,     *,     *] 
      4    : var['VALUES'] = var.VALUES[     *,     *,     *,     *,lonIDs,     *,     *,     *] 
      5    : var['VALUES'] = var.VALUES[     *,     *,     *,     *,     *,lonIDs,     *,     *] 
      6    : var['VALUES'] = var.VALUES[     *,     *,     *,     *,     *,     *,lonIDs,     *] 
      7    : var['VALUES'] = var.VALUES[     *,     *,     *,     *,     *,     *,     *,lonIDs] 
      ELSE : MESSAGE, 'Can only have 8 dimensions!'														; Throw error if id is not 0-7
    ENDCASE
  ENDIF
ENDFOREACH																																		; End iteration over variables

IF isStruct EQ 1 THEN tmp = tmp.ToStruct(/No_Copy, /RECURSIVE)								; If input was structure, convert dictionary back to structure

RETURN, tmp																																		; Return filtered data

END
