FUNCTION READ_HDF4, filename, $
  VARIABLES   = variables,  $
  SCALE_DATA  = scale_data, $
  ADD_FIRST   = add_first,  $
  CONVERT_LON = convert_lon

;+
; Name:
;   READ_HD4
; Purpose:
;   To read in a HDF 4 file. No data is scaled as scale factors, etc.
;   are read into data structure.
; Calling Sequence:
;   result = READ_HDF4(filename [, VARIABLES = value] [, /ADD_FIRST]
;              [, /SCALE_DATA] [, /CONVERT_LON] )
; Inputs:
;   filename	: Name of file to read data in from.
; Outputs:
;   A structure containing all data, or data requested.
; Keywords:
;   VARIABLES 	: A string or string array containing the variables
;                   to obtain from the file.
;   SCALE_DATA  : Set to scale data if scale_factor and add_offset attributes
;                   found.
;   ADD_FIRST   : Set to subtract add_offset from data before scaling;
;                   MODIS convention. MUST be used with SCALE_DATA
;   CONVERT_LON : Set to convert longitudes from 0-360 to -180-180 or
;                   vice versa based on the data being read.
; Author and History:
;   Kyle R. Wodzicki	Created 10 July 2015
;
;    Modified 27 Mar. 2019
;      Added the ADD_FIRST and SCALE_DATA keywords
;-

COMPILE_OPT IDL2																											; Set compile options

IF FILE_TEST(filename[0]) EQ 0 THEN $
  IF NOT STRMATCH(filename[0], '*http*', /FOLD_CASE) THEN $                     ; Check if NOT URL
    MESSAGE, 'FILE NOT FOUND!'                                                  ; Error if file NOT exist

IF N_ELEMENTS(scale_data) EQ 0 THEN scale_data = 1

;out_data = {filename: filename}                                                ; Store file name in structure
out_data = { }                                                                  ; Store file name in structure
splt     = '!@#$%^&*+=;:,./?()[]{}<>'                                           ; Characters not allowed in structure tags
sds_file_ID = HDF_SD_START(filename[0], /READ)                                  ; Open file for reading
HDF_SD_FILEINFO, sds_file_ID, numSDS, numATT                                    ; Get number of SD data sets

;=== Get all data names from the file if no variables selected
IF (N_ELEMENTS(variables) EQ 0) THEN BEGIN                                      ; If NO user requested specific variables
  variables = []                                                                ; Initialize empty array
  FOR i = 0, numSDS - 1 DO BEGIN                                                ; Iterate over all SD data
    sds_id = HDF_SD_SELECT(sds_file_ID, i)                                      ; Select the SD data
    HDF_SD_GETINFO, sds_id, NAME = name                                         ; Get information about data
    variables  = [variables, name]                                              ; Append name to variables array
    HDF_SD_ENDACCESS, sds_id                                                    ; De-select the SD data
  ENDFOR
ENDIF

FOR i = 0, numSDS - 1 DO BEGIN                                                  ; Iterate over all data sets
  sds_id = HDF_SD_SELECT(sds_file_ID, i)                                        ; Select ith data entry
  HDF_SD_GETINFO, sds_id,   $                                                   ; Get information about ith data entry
    NAME  = name,           $
    NATTS = num_attributes, $
    NDIM  = num_dims,       $
    DIMS  = dimvector

  FOR j = 0, N_ELEMENTS(variables)-1 DO BEGIN                                   ; Iterate over all entries in variables
    IF ~STRMATCH(variables[j], name, /FOLD_CASE) THEN CONTINUE				    ; If current data set matches jth parameter
    _fill  = !NULL                                                              ; Variable to store fill value if found
    _miss  = !NULL                                                              ; Variable to store missing value if found
    _scale = !NULL                                                              ; Variable to store scale factor if found
    _add   = !NULL                                                              ; Variable to store add offset if found
    tmp    = {}                                                                 ; Set up temporary array to store all data information
    HDF_SD_GETDATA, sds_id, data
    IF (name EQ 'LON')  AND KEYWORD_SET(convert_lon) THEN BEGIN                 ; If data set is Longitude
      IF (MIN(data, /NaN) LT 0) THEN BEGIN
        index = WHERE(data LT 0, COUNT)                                         ; Indicies of longitude < 0
        IF (COUNT NE 0) THEN data[index]=data[index]+360                        ; If points exist, convert 0-360 range
      ENDIF ELSE BEGIN
        index = WHERE(data GT 180, COUNT)                                       ; Indicies of longitude < 0
        IF (COUNT NE 0) THEN data[index]=data[index]-360                        ; If points exist, convert 0-360 range
      ENDELSE
  	ENDIF

  	;=== Attribute getting
  	FOR k = 0, num_Attributes-1 DO BEGIN
      HDF_SD_AttrInfo, sds_id, k, NAME = attr_name, DATA = attr_data            ; Get kth attribute name and data
      CASE STRUPCASE( attr_name ) OF                                            ; Check attribute name for some cases
        'SCALE_FACTOR'  : _scale = attr_data[0]                                 ; Attribute is scale factor
        'ADD_OFFSET'    : _add   = attr_data[0]                                 ; Attribute is add offset
        '_FILLVALUE'    : _fill  = attr_data[0]                                 ; Attribute is fill value
        'MISSING_VALUE' : _miss  = attr_data[0]                                 ; Attribute is missing value
        ELSE            : ; Do nothing
      ENDCASE

      attr_name = STRJOIN( STRSPLIT(attr_name, splt, /EXTRACT), '_' )           ; Split name on bad characters and join using underscore
      IF (N_ELEMENTS(attr_data) EQ 1) THEN $                                    ; If number of elements is only 1
        tmp = CREATE_STRUCT(tmp, attr_name, attr_data[0]) $                     ; Append attribute to tmp data structure as scalar
      ELSE $                                                                    ; Else
        tmp = CREATE_STRUCT(tmp, attr_name, attr_data)                          ; Append attribute to tmp data structure as array
  	ENDFOR                                                                      ; END k

    ;=== Data scaling
    IF KEYWORD_SET(scale_data) THEN BEGIN                                       ; If data is to be scaled
      bad = LIST()                                                              ; Initialize list for bad (i.e., missing, fill value) indices
      IF N_ELEMENTS(_fill) GT 0 THEN BEGIN                                      ; If there is a fill value defined
        ids = WHERE( data EQ _fill, CNT )                                       ; Locate all points that are fill value in data
        IF CNT GT 0 THEN bad.ADD, ids                                           ; If fill values found then append indices to bad list
      ENDIF
      IF N_ELEMENTS(_fill) GT 0 THEN BEGIN                                      ; If there is a missing value defined
        ids = WHERE( data EQ _miss, CNT )                                       ; Locate all points that are missing value in data
        IF CNT GT 0 THEN bad.ADD, ids                                           ; If missing values found then append indices to bad list
      ENDIF
      bad = bad.ToArray(DIMENSION = 1, /No_Copy)                                ; Convert bad list to array

      IF KEYWORD_SET(add_first) THEN BEGIN                                      ; If the add_first keywords is set
        IF N_ELEMENTS(_add)   EQ 1 THEN data -= _add                            ; If there is an add offset defined then subtract it from the data
        IF N_ELEMENTS(_scale) EQ 1 THEN data *= _scale                          ; If there is a scale factor defined then multiply data by scale factor
      ENDIF ELSE BEGIN                                                          ; Else
        IF N_ELEMENTS(_scale) EQ 1 THEN data *= _scale                          ; If there is a scale factor defined then multiply data by scale factor
        IF N_ELEMENTS(_add)   EQ 1 THEN data += _add                            ; If there is an add offset defined then subtract it from the data
      ENDELSE

      IF N_ELEMENTS(bad) GT 0 THEN BEGIN                                        ; If any missing or fill values found in data
        _type = SIZE( data, /TYPE )                                             ; Get data type
        IF (_type LT 4 OR _type GT 6) AND (_type NE 9) THEN data = FLOAT(data)  ; If the data is NOT a floating-point type then convert to float
        data[bad] = !Values.F_NaN                                               ; Set missing/fill values to NaN
      ENDIF
    ENDIF

    tmp  = CREATE_STRUCT(tmp, 'Values', data)                                   ; Append actual data to tmp data structure

    ;=== Filter out characters from tag name
    name = STRJOIN(STRSPLIT(name, ':', /EXTRACT), '_')                          ; Skip variables with colon in the name
    name = STRJOIN(STRSPLIT(name, ' ', /EXTRACT), '_')
    name = STRJOIN(STRSPLIT(name, '.', /EXTRACT), '_')
    name = STRJOIN(STRSPLIT(name, '#', /EXTRACT), 'N')

    out_data = CREATE_STRUCT(out_data, name, tmp)                               ; Add data to structure
  ENDFOR                                                                        ; END j
  HDF_SD_ENDACCESS, sds_id                                                      ; End access to ith data set
ENDFOR                                                                          ; END i
HDF_SD_END, sds_file_ID                                                         ; Close the file

RETURN, out_data                                                                ; Return data structure

END
