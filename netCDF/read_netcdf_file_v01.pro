FUNCTION READ_netCDF_FILE_V01, fname, $
  PARAMETERS = parameters, $
  SCALE_DATA = scale_data, $
  FLOAT      = float
;+
; Name:
;		READ_NCDF
; Purpose:
;		A function read in all the data from a NCDF file.
; Calling Sequence:
;		result = READ_netCDF_FILE('/path/to/file.nc')
; Inputs:
;		fname	: File name to read in. MUST BE FULL PATH
; Outputs:
;		A structure containing all the data form the file.
; Keywords:
;		PARAMETER		: String of variables to get, if not set,
;									  all variables returned. DO NOT include dimensions
;                   that have corresponding variables such as
;                   longitude, latitude, level, time when working
;                   with ERA-Interim files!
;   SCALE_DATA  : Set this keyword to use the scale_factor and 
;                   add_offset attributes to scale the data while
;                   reading if. All attributes will still be 
;                   returned in the structure. Default is to NOT scale.
;   FLOAT       : Set to scale data to float. Default is to scale to
;                   double. If this keyword is set, SCALE_DATA is
;                   automatically set.
; Author and History:
;		Kyle R. Wodzicki	Created 27 Jan. 2016
;
;       Modified 29 Jan. 2016 by Kyle R. Wodzicki
;         Add code to convert the time (given in hours since a 
;         reference date) to calendar dates (i.e., year, month, day)
;-

COMPILE_OPT	IDL2                                                      ;Set Compile options

IF (N_PARAMS() NE 1) THEN MESSAGE, 'Incorrect number of inputs!'      ; Check the number of inputs
DLM_LOAD, 'ncdf'                                                      ; Load the netCDF module

IF KEYWORD_SET(float) THEN scale_data = 1

out_data = {}                                                         ; Initialize empty structure for the data
iid = NCDF_OPEN(fname)                                                ; Open the netCDF file
	iid_info = NCDF_INQUIRE(iid)                                        ; Get information from the netCDF file

;=====================================================================
;===
;=== Obtain the location of variables in the netCDF file based on 
;=== input into the parameters keyword. If no information is input
;=== into the keyword, then indices for all variables in the file
;=== are generated based on the number of variables in the file.
;===
;=====================================================================
	IF (N_ELEMENTS(parameters) NE 0) THEN BEGIN                         ; Check for input into the parameters keyword
  	var_ids = []                                                      ; Initialize empty array to store variable indices in
		FOR i = 0, N_ELEMENTS(parameters)-1 DO $                          ; Iterate over all parameters in the parameters keyword
			var_ids = [var_ids, NCDF_VARID(iid, parameters[i])]             ; Determine the variable index based on the variable name and append it to the var_ids array
		id = WHERE(var_ids NE -1, CNT)                                    ; Locate valid variable indices in the var_id array (i.e., var_id NE -1 as NCDF_VARID returns -1 if variable NOT found) 
		IF (CNT GT 0) THEN $                                              ; If indices NE -1 are found, then those data are to be read in
			var_ids = var_ids[id] $                                         ; Filter the variable indices to only the valid indices
		ELSE $                                                            ; Print an error message if none of the parameters were found
		  MESSAGE, 'None of the requested variables were found!'
  ENDIF ELSE var_ids = INDGEN(iid_info.NVARS)                         ; If the parameters keyword was NOT used, generate all variables indices based on number of variables in file (i.e., iid_info.NVARS)

  FOR i = 0, N_ELEMENTS(var_ids)-1 DO BEGIN                           ; Iterate over all variable indices in the var_ids array
    var_data = {}                                                     ; Initialize structure to store all variable data and attributes in
    var_id   = var_ids[i]                                             ; Get the ith variable index
		var_info = NCDF_VARINQ(iid, var_id)                               ; Get information about the variable from NCDF_VARINQ
		FOR j = 0, var_info.NATTS-1 DO BEGIN                              ; Iterate over all of the variables attributes
		  attName = NCDF_ATTNAME(iid, var_id, j)                          ; Get the name of the attribute jth attribute
		  attInfo = NCDF_ATTINQ(iid,  var_id, attName)                    ; Get the DataType and length of the attribute. String attributes must be converted, need this to determine if string.
		  NCDF_ATTGET, iid, var_id, attName, attData                      ; Get the data for the attribute
      IF (attInfo.DataType EQ 'CHAR') THEN attData = STRING(attData)  ; If the attribute is of type CHAR, then convert the attribute data to a string
		  var_data = CREATE_STRUCT(var_data, attName, attData)            ; Append the attribute data to the var_data structure 
		  
		  IF KEYWORD_SET(scale_data) THEN BEGIN                           ; If the SCALE_DATA keyword is set, save some information needed to scale the data later
				IF (attName EQ '_FillValue')    THEN $
				  fill    = KEYWORD_SET(float) ? FLOAT(attData) : attData
				IF (attName EQ 'missing_value') THEN $
				  missing = KEYWORD_SET(float) ? FLOAT(attData) : attData
				IF (attName EQ 'scale_factor')  THEN $
				  scale   = KEYWORD_SET(float) ? FLOAT(attData) : attData
				IF (attName EQ 'add_offset')    THEN $
				  offset  = KEYWORD_SET(float) ? FLOAT(attData) : attData
				IF (attName EQ 'valid_range')    THEN $
				  range   = KEYWORD_SET(float) ? FLOAT(attData) : attData
      ENDIF
		ENDFOR                                                            ; END j		
    
    NCDF_VARGET, iid, var_id, data                                    ; Get data from variable
		
		replace_id = []
		IF (N_ELEMENTS(fill) EQ 1) THEN BEGIN                             ; If there is information in the fill variable, locate fill values in the data
		  id = WHERE(data EQ fill, CNT)
		  IF (CNT GT 0) THEN replace_id = [replace_id, id]
		  fill = !NULL
		ENDIF
		IF (N_ELEMENTS(missing) EQ 1) THEN BEGIN                            ; If there is information in the missing variable, locate missing values in the data        
		  id = WHERE(data EQ missing, CNT)
		  IF (CNT GT 0) THEN replace_id = [replace_id, id]                ; Replace missing values with the NaN character
		  missing = !NULL
		ENDIF 
		IF (N_ELEMENTS(range) EQ 2) THEN BEGIN                            ; If there is information in the missing variable, locate missing values in the data        
		  id = WHERE(data LT range[0] OR data GT range[1], CNT)
		  IF (CNT GT 0) THEN replace_id = [replace_id, id]                ; Replace missing values with the NaN character
		  range = !NULL
		ENDIF 
		
		IF KEYWORD_SET(scale_data) THEN BEGIN                             ; Scale the data if the keyword is set                                              ; If there is NO information, then set the fill_CNT to zero
      IF (N_ELEMENTS(scale) EQ 1) THEN $                              ; If there is information in the scale variable, then scale the data ( data * scale )
        data = TEMPORARY(data) * TEMPORARY(scale)
		  IF (N_ELEMENTS(offset) EQ 1) THEN $                             ; If there is information in the offset variable, then offset the data ( data + offset )
		    data = TEMPORARY(data) + TEMPORARY(offset)
		ENDIF
		
		IF (N_ELEMENTS(replace_id) GT 0) THEN data[replace_id] = !Values.F_NaN
		
		var_data = CREATE_STRUCT(var_data, 'values', data)                ; Append the variable data to the var_data structure							
		out_data = CREATE_STRUCT(out_data, var_info.NAME, var_data)       ; Append the var_data structure to the out_data structure
	ENDFOR
NCDF_CLOSE, iid                                                       ; Close NCDF File

RETURN, out_data                                                      ; Return the data

END