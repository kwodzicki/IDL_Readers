FUNCTION READ_netCDF, fname, $
  LIMIT      = limit, $
  VARIABLES  = variables,$
  FLOAT      = float, $
  SCALE_DATA = scale_data, $
  ADD_FIRST  = add_first, $
  VERBOSE    = verbose, $
  SILENT     = silent

;+
; Name:
;   READ_NCDF
; Purpose:
;   A function read in all the data from a NCDF file.
; Calling Sequence:
;   result = READ_NCDF('File_name')
; Inputs:
;   fname   : File name to read in. MUST BE FULL PATH!
; Outputs:
;   A structure containing all the data form the file.
; Keywords:
;   LIMIT      : If data in a certain domain is to be selected, set this.
;                   Array must be south, west, north, east limits.
;   VARIABLES  : String of variables to get, if not set,
;                   all variables returned. DO NOT include standard
;                   parameters such as Time, Latitude, Longitude, and
;                   levels, as there are always returned. Strings MUST match
;                   case of variables in the netCDF file.
;   FLOAT      : Set to force scale factors to be FLOATS
;   ADD_FIRST  : Set this keywords to subtract the add_offset from the data
;                   before applying the scale factor. Convention from
;                   MODIS
;   VERBOSE    : Set to get info about files that are being processed.
;   SILENT     : Set to not print errors
; Author and History:
;       Kyle R. Wodzicki    Created 07 Oct. 2014
;
;   Modified 14 Jun. 2016 by Kyle R. Wodzicki
;     Removed DIR keyword.
;   Modified 12 Feb. 2018 bye Kyle R. Wodzicki
;     Added the add_first keyword
;-

COMPILE_OPT IDL2                                                                ; Set Compile options

IF KEYWORD_SET(verbose) THEN BEGIN                                                                                ; If verbose output, print following.
    PRINT, ''
    PRINT, 'Retriving data from file:'                                          ; Print some info
    PRINT, '   ', fname
    PRINT, ''
ENDIF
IF N_ELEMENTS(scale_data) EQ 0 THEN scale_data = 1

data         = {}                                                               ; Initialize empty structure to store all data in
all_var_info = {}                                                               ; Initialize empty structure to store all variable info in
iid = NCDF_OPEN(fname)                                                          ; Open the NCDF file
ngids = 0                                                                       ; Set number of group ids to zero by default
gids  = LIST( NCDF_GROUPSINQ(iid) )                                             ; Get list of group ids in file
IF SIZE(gids[0], /N_DIMENSIONS) EQ 0 THEN BEGIN                                 ; If NO groups are found
  info = NCDF_INQUIRE(iid)                                                      ; Get information about file variables, attributes, dimensions, etc.
  FOR i = 0, info.NVARS-1 DO BEGIN                                              ; Iterate over all variables in the file
    varinfo      = NCDF_VARINQ(iid, i)                                          ; Get information about the variable
    varinfo      = CREATE_STRUCT(varinfo, 'cdfid', iid)                         ; Append cdfid to the varinfo structure
    tag          = STRJOIN( STRSPLIT(varinfo.NAME, '.', /EXTRACT), '_' )        ; Set tag variable to variable name; replacing periods with underscore
    all_var_info = CREATE_STRUCT(all_var_info, tag, varinfo)                    ; Append the variable info to the all_var_info structure
  ENDFOR                                                                        ; ENDFOR i
ENDIF ELSE BEGIN                                                                ; If there ARE groups in the netCDF file
  WHILE ngids NE N_ELEMENTS(gids) DO BEGIN                                      ; While the number of group ids does NOT match ngids
    ngids   = N_ELEMENTS(gids)                                                  ; Reset the number of group ids
    new_ids = []                                                                ; Initialize empty array to store sub group ids in
    FOR i = 0, N_ELEMENTS(gids[-1])-1 DO BEGIN                                  ; Iterate over the group ids
      tmp = NCDF_GROUPSINQ(gids[-1,i])                                          ; Get any group ids within a given group id
      IF SIZE(tmp, /N_DIMENSIONS) NE 0 THEN new_ids = [new_ids, tmp]            ; If sub group ids found, append them to the group ids list
    ENDFOR                                                                      ; ENDFOR i
    IF N_ELEMENTS(new_ids) GT 0 THEN gids.ADD, new_ids                          ; If the new_ids array is NOT empty, add it to the gids list
  ENDWHILE                                                                      ; END while
  gids = gids.ToARRAY(/No_COPY, DIMENSION=1)                                    ; Convert list to array
  FOR i = 0, N_ELEMENTS(gids)-1 DO BEGIN                                        ; Iterate over all group ids
    info = NCDF_INQUIRE(gids[i])                                                ; Get information about the group
    FOR j = 0, info.NVARS-1 DO BEGIN                                            ; Iterate over all the variables in the group
      varinfo      = NCDF_VARINQ(gids[i], j)                                    ; Get information about the jth variable in the ith group
      varinfo      = CREATE_STRUCT(varinfo, 'cdfid', gids[i])                   ; Append cdfid to the variable info structure
      all_var_info = CREATE_STRUCT(all_var_info, $                              ; Append the variable info to the all_var_info structure
                                   varinfo.NAME+'_'+STRTRIM(i,2), varinfo)
    ENDFOR                                                                      ; ENDFOR j
  ENDFOR                                                                        ; ENDFOR i
ENDELSE

IF (N_ELEMENTS(variables) GT 0) THEN BEGIN                                      ; If the variables keyword is set, attempt to read in requested variables
  tmp  = {}                                                                     ; Initialize an empty, temporary structure
  tags = TAG_NAMES(all_var_info)                                                ; Get all tag names in the all_var_info structure
  FOR i = 0, N_ELEMENTS(variables)-1 DO $                                       ; For each variable name in the variables string array
    FOR j = 0, N_TAGS(all_var_info)-1 DO $                                      ; For each tag in the all_var_info structure
      IF STRMATCH(all_var_info.(j).NAME, variables[i]) THEN $                   ; IF the variable name matches the tag name then
        tmp = CREATE_STRUCT(tmp, tags[j], all_var_info.(j))                     ; Add the variable inform to the tmp array
  all_var_info = tmp                                                            ; Set all_var_info to the tmp array
ENDIF

IF (N_ELEMENTS(limit) EQ 4) THEN $                                              ; If the limit keyword is set...
  FOR i = 0, N_TAGS(all_var_info)-1 DO $                                        ; Iterate over all variables that are to be read in
    CASE STRUPCASE(all_var_info.(i).NAME) OF                                    ; See if the variable name matches 'LONGITUDE' or 'LATITUDE'
      'LONGITUDE' : NCDF_VARGET, all_var_info.(i).CDFID, all_var_info.(i).NAME, lon ; Read in the longitude data IF variable name matches
      'LATITUDE'  : NCDF_VARGET, all_var_info.(i).CDFID, all_var_info.(i).NAME, lat ; Read in the latitude data IF variable name matches
      ELSE        : ; DO NOTHING
    ENDCASE

IF (N_ELEMENTS(lon) GT 0) THEN BEGIN                                            ; IF longitude data was read in
  id = WHERE(lon LT 0, CNT)                                                     ; Located longitudes that are LESS than zero.
  IF (CNT GT 0) THEN lon[id] = lon[id] + 360                                    ; Convert longitude ranges to 0-360 for checking
  lon_index=WHERE(lon GE limit[1] AND lon LE limit[3], lon_cnt)                 ; Find indices of data within the longitude domain
ENDIF ELSE $
  lon_cnt = 0                                                                   ; Set lon_cnt to zero if NO longitude data read in
IF (N_ELEMENTS(lat) GT 0) THEN $
  lon_index=WHERE(lat GE limit[0] AND lat LE limit[2], lat_cnt) $               ; Find indices of data within the latitude domain
ELSE $
  lat_cnt = 0                                                                   ; Set lat_cnt to zero if NO latitude data read in

FOR i = 0, N_TAGS(all_var_info)-1 DO BEGIN                                      ; Iterate over all variable names in the var array;
  CATCH, Error_status
  ;This statement begins the error handler:
  IF Error_status NE 0 THEN BEGIN
    IF KEYWORD_SET(silent) EQ 0 THEN BEGIN
      PRINT, 'Error index: ', Error_status
      PRINT, 'Error message: ', !ERROR_STATE.MSG
      PRINT, '  Failed to read variable: '+all_var_info.(i).NAME
    ENDIF
    CATCH, /CANCEL
    CONTINUE
  ENDIF

  FOR j = 0, all_var_info.(i).NATTS-1 DO BEGIN                                  ; Iterate over all attributes
    attName = NCDF_ATTNAME(all_var_info.(i).CDFID, all_var_info.(i).NAME, j)    ; Get name of the attribute
    IF STRMATCH(attName, '*fill*', /FOLD_CASE) THEN $                           ; Get fill value
      NCDF_ATTGET, all_var_info.(i).CDFID, all_var_info.(i).NAME, attName, fill
    IF STRMATCH(attName, '*missing*', /FOLD_CASE) THEN $                        ; Get missing value
      NCDF_ATTGET, all_var_info.(i).CDFID, all_var_info.(i).NAME, attName, missing
    IF STRMATCH(attName, 'scale_factor', /FOLD_CASE) THEN $                     ; Get fill value
      NCDF_ATTGET, all_var_info.(i).CDFID, all_var_info.(i).NAME, attName, scale
    IF STRMATCH(attName, 'add_offset', /FOLD_CASE) THEN $                       ; Get fill value
      NCDF_ATTGET, all_var_info.(i).CDFID, all_var_info.(i).NAME, attName, offset
    IF STRMATCH(attName, 'valid_range', /FOLD_CASE) THEN $                      ; Get fill value
      NCDF_ATTGET, all_var_info.(i).CDFID, all_var_info.(i).NAME, attName, range
  ENDFOR                                                                        ; END j
  NCDF_VARGET, all_var_info.(i).CDFID, all_var_info.(i).NAME, result            ; Get data from variable
  IF all_var_info.(i).DATATYPE EQ 'CHAR' THEN BEGIN                             ; If the data type of the variable is CHAR
    result = STRING(result)                                                     ; Convert data to string type
    IF N_ELEMENTS(fill) NE 0 THEN fill = STRING(fill)                           ; If there is a fill value, then convert the fill value to a string
  ENDIF

  IF KEYWORD_SET(scale_data) THEN BEGIN
    replace_id = []
    ;=== Check for fill values
    IF (N_ELEMENTS(fill) NE 0) THEN BEGIN
      id = WHERE(result EQ fill, CNT)
      IF (CNT GT 0) THEN replace_id = [replace_id, id]
      fill = !NULL
    ENDIF

    IF (N_ELEMENTS(missing) NE 0) THEN BEGIN
      id = WHERE(result EQ missing, CNT)
      IF (CNT GT 0) THEN replace_id = [replace_id, id]
      missing = !NULL
    ENDIF

    IF (N_ELEMENTS(range) EQ 2) THEN BEGIN
      id = WHERE(result LT range[0] OR result GT range[1], CNT)
      IF (CNT GT 0) THEN replace_id = [replace_id, id]
      range    = !NULL
    ENDIF

    ;=== Data scaling
    IF KEYWORD_SET(add_first) THEN BEGIN
      ;=== Offset the data IF an offset was read in
      IF (N_ELEMENTS(offset) EQ 1) THEN BEGIN
        IF KEYWORD_SET(float) THEN offset = FLOAT(offset)
        result = TEMPORARY(result) - offset
        offset = !NULL
      ENDIF
      ;=== Scale the data IF a scale factor was read in
      IF (N_ELEMENTS(scale) EQ 1) THEN BEGIN
        IF KEYWORD_SET(float) THEN scale = FLOAT(scale)
        result = TEMPORARY(result) * scale
        scale  = !NULL
      ENDIF
    ENDIF ELSE BEGIN
      ;=== Scale the data IF a scale factor was read in
      IF (N_ELEMENTS(scale) EQ 1) THEN BEGIN
        IF KEYWORD_SET(float) THEN scale = FLOAT(scale)
        result = TEMPORARY(result) * scale
        scale  = !NULL
      ENDIF
      ;=== Offset the data IF an offset was read in
      IF (N_ELEMENTS(offset) EQ 1) THEN BEGIN
        IF KEYWORD_SET(float) THEN offset = FLOAT(offset)
        result = TEMPORARY(result) + offset
        offset = !NULL
      ENDIF
    ENDELSE

    ;=== Replace invalid data if any present
    IF (N_ELEMENTS(replace_id) GT 0) THEN BEGIN
      type = SIZE(result, /TYPE)
      IF (type NE 4) AND (type NE 5) THEN result = FLOAT(result)
      result[replace_id] = !Values.F_NaN
    ENDIF
  ENDIF

  IF KEYWORD_SET(float) AND SIZE(result, /TYPE) EQ 5 THEN $                     ; If the float keyword IS set and the data type of result IS double, force to float
    result = FLOAT(result)

  IF (lon_cnt GT 0) AND (lat_cnt GT 0) THEN $
    IF STRMATCH(all_var_info.(i).NAME, 'longitude', /FOLD_CASE) THEN $          ; Filter longitude by index
      result = result[lon_index] $
    ELSE IF STRMATCH(all_var_info.(i).NAME, 'latitude', /FOLD_CASE)   THEN $    ; Filter lat by index
      result = result[lat_index] $
    ELSE IF (SIZE(result, /N_DIMENSIONS) GT 1) THEN BEGIN
      result = result[lon_index,*,*,*,*,*,*,*]
      result = result[*,lat_index,*,*,*,*,*,*]
  ENDIF
  tag  = STRJOIN( STRSPLIT(all_var_info.(i).NAME, '.', /EXTRACT), '_' )
  data = CREATE_STRUCT(data, all_var_info.(i).NAME, result)                     ; Create struct of all data
ENDFOR
NCDF_CLOSE, iid                                                                 ; Close NCDF File

RETURN, data                                                                    ; Return data

END
