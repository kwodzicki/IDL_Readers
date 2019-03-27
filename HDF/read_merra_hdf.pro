FUNCTION READ_MERRA_HDF, filename, VARIABLES=variables, DOMAIN = domain

;+
; Name:
;		READ_MERRA_HDF
; Purpose:
;		A function to read in MERRA files that are in HDF4 format.
; Calling Sequence:
;		result = READ_MERRA_HDF(filename, PARAMETERS=variables)
; Inputs:
;		filename	: Name of file to read data in from. MUST BE FULL PATH!
; Outputs:
;		A structure containing all data, or data requested.
; Keywords:
;		VARIABLES	: A string or string array containing the variables
;						      to obtain from the file.
;   DOMAIN    : Domain limits for sub sample of data to read in.
;                [West, South, North, East] in degrees.
; Author and History:
;		Kyle R. Wodzicki	Created 04 June 2015
;-

COMPILE_OPT IDL2																											;Set compile options

IF (N_PARAMS() EQ 0) THEN MESSAGE, 'Must input file name!'            ; Check that a file name is input
IF FILE_TEST(filename[0]) EQ 0 THEN MESSAGE, 'FILE NOT FOUND!'				; Error if file does NOT exist

sds_file_ID = HDF_SD_START(filename[0], /READ)												; Open file for reading
HDF_SD_FILEINFO, sds_file_ID, numSDS, numATT													; Get number of SD data sets

;=== Loop over all SD datasets to get their names
data_names = []                                                       ; Initialize an array to store the names of all the variables in the file
FOR i = 0, numSDS - 1 DO BEGIN
  sds_id = HDF_SD_SELECT(sds_file_ID, i)                              ; Select the ith data set
    HDF_SD_GETINFO, sds_id, NAME = name	                              ; Get the name of the ith data set
    data_names  = [data_names, name]                                  ; Append the name of the ith data set to the data_names array
  HDF_SD_ENDACCESS, sds_id                                            ; De-select the ith data set
ENDFOR                                                                ; END i

IF (N_ELEMENTS(variables) EQ 0) THEN variables = data_names           ; If no specific variables are desired, then all data will be read in.

fdata = {}                                                            ; Initialize structure to store all data
FOR i = 0, numSDS - 1 DO BEGIN																				; Iterate over all data sets
	sds_id = HDF_SD_SELECT(sds_file_ID, i)															; Select ith data set
	HDF_SD_GETINFO, sds_id, NAME = name, NATTS = num_attributes, $      ; Get information about the data set
                  NDIM=num_dims, DIMS =dimvector	
	IF STRMATCH(name, '*EOSGRID*', /FOLD_CASE) THEN CONTINUE            ; If name contains EOSGRID, then skip the data set
	FOR j = 0, N_ELEMENTS(variables)-1 DO BEGIN											    ; Iterate over all entries in the variables array to determine which data to read in
		IF ~STRMATCH(variables[j], name, /FOLD_CASE) THEN CONTINUE				; If the name of the ith data set does not match the jth variable name, skip to next variable name
		HDF_SD_GETDATA, sds_id, data                                      ; Read in the data from the ith data set
    
    ;=== Convert longitudes to 0-360 range
    IF (name EQ 'XDim') THEN BEGIN
      id = WHERE(data LT 0, CNT)
      IF (CNT NE 0) THEN data[id] = data[id]+360
    ENDIF
    
		;=== Initialize variables for data scaling, missing values, etc.
		scale = 1 & offset = 0 & missing = !Values.F_NaN
		fill  = !Values.F_NaN & range = 0 & units = ''
		
		;=== Iterate over all the dataset attributes to get various information
		FOR k = 0, num_Attributes-1 DO BEGIN
		  HDF_SD_AttrInfo, sds_id, k, NAME = attr_name, DATA = attr_data  ; Get data from the kth attribute
		  IF STRMATCH(attr_name, 'units',        /FOLD_CASE) THEN units   = attr_data[0]
		  IF STRMATCH(attr_name, 'scale_factor', /FOLD_CASE) THEN scale   = attr_data[0] ; Set scaling factor if attribute name matches
		  IF STRMATCH(attr_name, 'add_offset',   /FOLD_CASE) THEN offset  = attr_data[0] ; Set add offset     if attribute name matches
		  IF STRMATCH(attr_name, '*missing*',    /FOLD_CASE) THEN missing = attr_data[0] ; Set missing value  if attribute name matches
		  IF STRMATCH(attr_name, '_FillValue',   /FOLD_CASE) THEN fill    = attr_data[0] ; Set fill value     if attribute name matches
		  IF STRMATCH(attr_name, 'valid_range',  /FOLD_CASE) THEN range   = attr_data    ; Set valid range    if attribute name matches
		ENDFOR                                                            ; END k

    ;=== Set any data outside of range or missing to NaN characters
		IF (N_ELEMENTS(range) EQ 2) THEN BEGIN                            ; If range has 2 elements, then data was read in
		  id = WHERE(data EQ missing  OR data EQ fill OR $
		             data LT range[0] OR data GT range[1] , CNT)
		ENDIF ELSE id = WHERE(data EQ missing OR data EQ fill, CNT)       ; Else there is no range information
		
		;=== If data points were found in the where statements directly
		;=== above, set those points to NaN
		IF (CNT NE 0) THEN BEGIN
		  IF (TYPE(data) LT 4) THEN data = FLOAT(data)                    ; Convert data to float before writing NaN
		  data[id] = !Values.F_NaN
		ENDIF
		
		data = scale*(TEMPORARY(data) - offset)                           ; Scale the data
		
		;=== Replace some characters in the variable names if they exist
		name = STRJOIN(STRSPLIT(name, ':', /EXTRACT), '_')
		name = STRJOIN(STRSPLIT(name, ' ', /EXTRACT), '_')
		name = STRJOIN(STRSPLIT(name, '.', /EXTRACT), '_')
		name = STRJOIN(STRSPLIT(name, '#', /EXTRACT), 'N')
		fdata = CREATE_STRUCT(fdata, name, data, name+'_units', units)    ; Add data to structure
	ENDFOR                                                              ; END j
	HDF_SD_ENDACCESS, sds_id                                            ; De-select the ith data set
ENDFOR                                                                ; END i
HDF_SD_END, sds_file_ID                                               ; Close the HDF file

IF (N_ELEMENTS(domain) EQ 4) THEN BEGIN                               ; Filter data to domain
  IF (domain[1] LT 0) THEN doamin[1] = domain[1]+360                  ; Convert longitudes in domain to 0-360 range
  IF (domain[3] LT 0) THEN doamin[3] = domain[3]+360
  
  lon_id = WHERE(fdata.XDIM GE domain[1] AND $                        ; Find points in longitude range
                 fdata.XDIM LE domain[3], lon_CNT)
  lat_id = WHERE(fdata.YDIM GE domain[0] AND $                        ; Find points in latitude range
                 fdata.YDIM LE domain[2], lat_CNT)
  IF (lon_CNT EQ 0) OR (lat_CNT EQ 0) THEN BEGIN                      ; If no data found in domain, return all data
    MESSAGE, 'No data found in domain, returning all data!'
    RETURN, fdata
  ENDIF
  
  flt_data = {}                                                       ; Create new filtered data array
  tags = TAG_NAMES(fdata)                                             ; Get tag names in fdata structure
  FOR i = 0, N_TAGS(fdata)-1 DO BEGIN                                 ; Iterate over all data in fdata structured
    CASE tags[i] OF
      'XDIM'   : flt_data = CREATE_STRUCT(flt_data, tags[i], fdata.(i)[lon_id])
      'YDIM'   : flt_data = CREATE_STRUCT(flt_data, tags[i], fdata.(i)[lat_id])
      'HEIGHT' : flt_data = CREATE_STRUCT(flt_data, tags[i], fdata.(i))
      'TIME'   : flt_data = CREATE_STRUCT(flt_data, tags[i], fdata.(i))
      ELSE     : flt_data = CREATE_STRUCT(flt_data, tags[i], fdata.(i)[lon_id, lat_id, *, *])
    ENDCASE
  ENDFOR                                                              ; END i
ENDIF
RETURN, fdata																													; Return data structure

END