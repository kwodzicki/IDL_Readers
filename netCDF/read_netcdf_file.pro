FUNCTION READ_netCDF_FILE, fname, $
  VARIABLES  = variables, $
  SCALE_DATA = scale_data, $
  ADD_FIRST  = add_first, $
  FLOAT      = float
;+
; Name:
;       READ_NCDF
; Purpose:
;       A function read in all the data from a NCDF file.
; Calling Sequence:
;       result = READ_netCDF_FILE('/path/to/file.nc')
; Inputs:
;       fname   : File name to read in. MUST BE FULL PATH
; Outputs:
;       A structure containing all the data form the file.
; Keywords:
;       VARIABLES       : String of variables to get, if not set,
;                                     all variables returned. DO NOT include dimensions
;                   that have corresponding variables such as
;                   longitude, latitude, level, time when working
;                   with ERA-Interim files!
;   SCALE_DATA  : Set this keyword to use the scale_factor and
;                   add_offset attributes to scale the data while
;                   reading if. All attributes will still be
;                   returned in the structure. Default is to NOT scale.
;   ADD_FIRST   : Set this keywords to subtract the add_offset from the data
;                   before applying the scale factor. Convention from
;                   MODIS
;   FLOAT       : Set to scale data to float. Default is to scale to
;                   double. If this keyword is set, SCALE_DATA is
;                   automatically set.
; Author and History:
;       Kyle R. Wodzicki    Created 27 Jan. 2016
;
;       Modified 29 Jan. 2016 by Kyle R. Wodzicki
;         Add code to convert the time (given in hours since a
;         reference date) to calendar dates (i.e., year, month, day)
;       Modified 03 Jan. 2017 by Kyle R. Wodzicki
;         Changed the parameters keyword to variables
;      Modified 03 Jun. 2017 by Kyle R. Wodzicki
;         Added reading in of global attributes.
;      Modified 18 Feb. 2019 by Kyle R. Wodzicki
;        Added the ADD_FIRST keyword
;-

COMPILE_OPT IDL2                                                                ;Set Compile options

IF (N_PARAMS() NE 1) THEN MESSAGE, 'Incorrect number of inputs!'                ; Check the number of inputs
DLM_LOAD, 'ncdf'                                                                ; Load the netCDF module

IF KEYWORD_SET(float) THEN scale_data = 1

out_data = {}                                                                   ; Initialize empty structure for the data
iid = NCDF_OPEN(fname)                                                          ; Open the netCDF file

iid_info = NCDF_INQUIRE(iid)                                                    ; Get information from the netCDF file

FOR i = 0, iid_info.NGATTS-1 DO BEGIN                                           ; Iterate over all global attributes
  attName = NCDF_ATTNAME(iid, i, /GLOBAL)                                       ; Get the name of the ith global attribute
  attInfo = NCDF_ATTINQ(iid, attName, /GLOBAL)                                  ; Get the DataType and length of the attribute. String attributes must be converted, need this to determine if string.
  NCDF_ATTGET, iid, attName, attData, /GLOBAL                                   ; Get the attribute data
  IF (attInfo.DataType EQ 'CHAR') THEN attData = STRING(attData)                ; If the attribute is of type CHAR, then convert the attribute data to a string
  out_data = CREATE_STRUCT(out_data, attName, attData)                          ; Append the ith global attribute to the out_data structure
ENDFOR

NCDF_CONTROL, iid, /NOVERBOSE                                                   ; Suppress warning messages
dimensions = {}
FOR i = 0, iid_info.NDIMS-1 DO BEGIN
  NCDF_DIMINQ, iid, i, dimName, dimSize
  tmp = {NAME : dimName, SIZE : dimSize}
  vid = NCDF_VARID(iid, dimName)
  IF vid NE -1 THEN BEGIN
    NCDF_VARGET, iid, vid, dimData
    tmp = CREATE_STRUCT(tmp, 'Values', dimData)
  ENDIF
  dimensions = CREATE_STRUCT(dimensions, '_'+STRTRIM(i,2), tmp)
ENDFOR
NCDF_CONTROL, iid, /VERBOSE                                                     ; Enable warning messages

out_data = CREATE_STRUCT(out_data, 'Dimensions', dimensions)
;=====================================================================
;===
;=== Obtain the location of variables in the netCDF file based on
;=== input into the variables keyword. If no information is input
;=== into the keyword, then indices for all variables in the file
;=== are generated based on the number of variables in the file.
;===
;=====================================================================
IF (N_ELEMENTS(variables) NE 0) THEN BEGIN                                      ; Check for input into the variables keyword
  var_ids = []                                                                  ; Initialize empty array to store variable indices in

;  ;=== Obtain information about the various dimensions that may be in the netCDF file.
;  NCDF_CONTROL, iid, /NOVERBOSE                                                 ; Suppress warning messages
;  FOR i = 0, iid_info.NDIMS-1 DO BEGIN                                          ; Iterate over all dimensions in the netCDF file
;    NCDF_DIMINQ, iid, i, dim_name, dim_size                                     ; Obtain information about the ith dimension in the file
;    var_ids = [ var_ids, NCDF_VARID(iid, dim_name) ]                            ; Attempt to locate a variable with the same name as the ith dimension
;  ENDFOR                                                                        ; END i
  FOR i = 0, N_ELEMENTS(variables)-1 DO $                                       ; Iterate over all variables in the variables keyword
    var_ids = [var_ids, NCDF_VARID(iid, variables[i])]                          ; Determine the variable index based on the variable name and append it to the var_ids array
    id = WHERE(var_ids NE -1, CNT)                                              ; Locate valid variable indices in the var_id array (i.e., var_id NE -1 as NCDF_VARID returns -1 if variable NOT found)
    IF (CNT GT 0) THEN $                                                        ; If indices NE -1 are found, then those data are to be read in
        var_ids = var_ids[id] $                                                   ; Filter the variable indices to only the valid indices
    ELSE $                                                                      ; Print an error message if none of the variables were found
      MESSAGE, 'None of the requested variables were found!'
ENDIF ELSE $
  var_ids = INDGEN(iid_info.NVARS)                                              ; If the variables keyword was NOT used, generate all variables indices based on number of variables in file (i.e., iid_info.NVARS)

FOR i = 0, N_ELEMENTS(var_ids)-1 DO BEGIN                                       ; Iterate over all variable indices in the var_ids array
  var_id   = var_ids[i]                                                         ; Get the ith variable index
  var_data = NCDF_VARINQ(iid, var_id)
  FOR j = 0, var_data.NATTS-1 DO BEGIN                                          ; Iterate over all of the variables attributes
    attName = NCDF_ATTNAME(iid, var_id, j)                                      ; Get the name of the attribute jth attribute
    attInfo = NCDF_ATTINQ(iid,  var_id, attName)                                ; Get the DataType and length of the attribute. String attributes must be converted, need this to determine if string.
    NCDF_ATTGET, iid, var_id, attName, attData                                  ; Get the data for the attribute
    IF (attInfo.DataType EQ 'CHAR') THEN attData = STRING(attData)              ; If the attribute is of type CHAR, then convert the attribute data to a string
    var_data = CREATE_STRUCT(var_data, attName, attData)                        ; Append the attribute data to the var_data structure

    IF KEYWORD_SET(scale_data) THEN BEGIN                                       ; If the SCALE_DATA keyword is set, save some information needed to scale the data later
      IF STRMATCH(attName, '*FillValue', /FOLD_CASE) THEN $
        fill    = KEYWORD_SET(float) ? FLOAT(attData) : attData
      IF (attName EQ 'missing_value') THEN $
        missing = KEYWORD_SET(float) ? FLOAT(attData) : attData
      IF (attName EQ 'scale_factor')  THEN $
        scale   = KEYWORD_SET(float) ? FLOAT(attData) : attData
      IF (attName EQ 'add_offset')    THEN $
        offset  = KEYWORD_SET(float) ? FLOAT(attData) : attData
    ENDIF
  ENDFOR                                                                        ; END j

  NCDF_VARGET, iid, var_id, data                                                ; Get data from variable
  ;=== Get year, month, day, hour for time
  IF (STRUPCASE(var_data.NAME) EQ 'TIME') THEN BEGIN                            ; If the variable name is TIME
    tags = TAG_NAMES(var_data)                                                  ; Get the names of the attributes associated with time
    IF TOTAL(STRMATCH(tags, 'units', /FOLD_CASE), /INT) EQ 1 THEN BEGIN         ; Determine index of the units attribute of the time variable
      tmp = STRSPLIT(var_data.UNITS, ' ', /EXTRACT)                             ; Get the time units
      CASE STRLOWCASE(tmp[0]) OF
        'hours'   : new_data = data / 0.24000D2                                 ; If the units are hours since
        'minutes' : new_data = data / 0.14400D4                                 ; If the units are mintues since
        'seconds' : new_data = data / 0.86400D5                                 ; If the units are seconds since
        ELSE      : BEGIN
                      PRINT, 'Assuming time units are days since'               ; Else, print message
                      new_data = data
                    END
      ENDCASE
      yymmdd  = FLOAT(STRSPLIT(tmp[2],'-',/EXTRACT))
      hrmnsec = FLOAT(STRSPLIT(tmp[3],':',/EXTRACT))
      juldate = GREG2JUL(yymmdd[1], yymmdd[2], yymmdd[0], $
                           hrmnsec[0],hrmnsec[1],hrmnsec[2]) + new_data
;           ENDIF ELSE juldate = GREG2JUL(1, 1, 1900, 0, 0, 0) + data/24.0      ; Convert the gregorian reference date to a julian date and add the fractional julian days to it
    ENDIF ELSE juldate = data                                                   ; Assume the time is in IDL Juldate format
    JUL2GREG, juldate, mm, dd, yy,  hr, mn, sc                                  ; Convert the julian date back to the gregorian date
    var_data = CREATE_STRUCT(var_data, $                                        ; Append the year, month, day, hour, min, sec information to the variable's structure
            'JULDAY', juldate, $
    	    'YEAR',   yy, $
            'MONTH',  mm, $
            'DAY',    dd, $
            'HOUR',   hr, $
            'MINUTE', mn, $
            'SECOND', sc)
  ENDIF
  IF KEYWORD_SET(scale_data) THEN BEGIN                                         ; Scale the data if the keyword is set
    IF (N_ELEMENTS(fill) EQ 1) THEN $                                           ; If there is information in the fill variable, locate fill values in the data
      fill_id = WHERE(data EQ TEMPORARY(fill), fill_CNT) $
    ELSE $
    	fill_CNT = 0                                                            ; If there is NO information, then set the fill_CNT to zero
    IF (N_ELEMENTS(missing) EQ 1) THEN $                                        ; If there is information in the missing variable, locate missing values in the data
      miss_id = WHERE(data EQ TEMPORARY(missing), miss_CNT) $
    ELSE $
      miss_CNT = 0                                                              ; if there is NO information, then set the miss_CNT to zero

    IF KEYWORD_SET(add_first) THEN BEGIN                                        ; If the add_first keyword is set
      IF (N_ELEMENTS(offset) EQ 1) THEN $                                       ; If there is information in the offset variable, then offset the data ( data + offset )
        data = TEMPORARY(data) - TEMPORARY(offset)
      IF (N_ELEMENTS(scale) EQ 1) THEN $                                        ; If there is information in the scale variable, then scale the data ( data * scale )
        data = TEMPORARY(data) * TEMPORARY(scale)
    ENDIF ELSE BEGIN
      IF (N_ELEMENTS(scale) EQ 1) THEN $                                        ; If there is information in the scale variable, then scale the data ( data * scale )
        data = TEMPORARY(data) * TEMPORARY(scale)
      IF (N_ELEMENTS(offset) EQ 1) THEN $                                       ; If there is information in the offset variable, then offset the data ( data + offset )
        data = TEMPORARY(data) + TEMPORARY(offset)
    ENDELSE

    IF (fill_CNT GT 0) THEN BEGIN                                               ; If fill values were found in the data, then replace them with NaN characters
      IF (SIZE(data, /TYPE) LT 4) THEN data = FLOAT(data)                       ; If the data is not at least a float, convert it because only floats and doubles can use the NaN character
      data[fill_id] = !VALUES.F_NaN                                             ; Replace fill values with the NaN character
    ENDIF
    IF (miss_CNT GT 0) THEN BEGIN                                               ; If missing values were found in the data, then replace them with NaN characters
      IF (SIZE(data, /TYPE) LT 4) THEN data = FLOAT(data)                       ; If the data is not at least a float, convert it because only floats and doubles can use the NaN character
      data[miss_id] = !VALUES.F_NaN                                             ; Replace missing values with the NaN character
    ENDIF
  ENDIF
  var_data = CREATE_STRUCT(var_data, 'N',      SIZE(data, /DIMENSIONS))         ; Append data dimensions to the var_data structure
  var_data = CREATE_STRUCT(var_data, 'values', data)                            ; Append the variable data to the var_data structure
  out_data = CREATE_STRUCT(out_data, var_data.NAME, var_data)                   ; Append the var_data structure to the out_data structure
ENDFOR

NCDF_CLOSE, iid                                                                 ; Close NCDF File

RETURN, out_data                                                                ; Return the data

END
