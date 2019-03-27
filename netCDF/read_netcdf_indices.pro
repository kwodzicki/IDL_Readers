FUNCTION READ_netCDF_INDICES, fname, $
  x_offset, y_offset, z_offset, t_offset, $
  limit				= limit, $
  DIR					= dir, $
  VARIABLES		= variables,$
  GETUNITS		= getUnits, $
  GETLONGNAME	= getLongName, $
  VERBOSE			= verbose

;+
; Name:
;		READ_netCDF_INDICES
; Purpose:
;		A function to read in only those data points that are 
;   provided by the indicies variables.
; Calling Sequence:
;		result = READ_NCDF('File_name')
; Inputs:
;		fname	: File name to read in. MUST BE FULL PATH
; Outputs:
;		A structure containing all the data form the file.
; Keywords:
;		LIMIT				: If data in a certain domain is to be selected, set this.
;					 				 Array must be south, west, north, east limits.
;		DIR					: Set this to the directory data is located in.
;									Default is - /Volumes/Data_Rapp/Wodzicki/ERA_Interim/.
;		VARIABLES		: String of variables to get, if not set,
;									all variables returned. DO NOT include dimensions!
;		GETUNITS		: If set, will get units and place after data in
;									returned structure.
;		GETLONGNAME	: If set, will get longname and place after data in
;									returned structure. If getunits also set, this 
;									will be below the units tag.
;		VERBOSE			: Set to get info about files that are being 
;									processed.
; Author and History:
;		Kyle R. Wodzicki	Created 07 Oct. 2014
;
;     Modified 19 Dec. 2016 - Changed parameters keyword to variables.
;-

COMPILE_OPT	IDL2                                                      ;Set Compile options

DLM_LOAD, 'ncdf'

IF KEYWORD_SET(verbose) THEN BEGIN																		;If verbose output, print following.
	PRINT, ''	
	PRINT, 'Retriving data from file:'                                  ;Print some info
	PRINT, '   ', fname
	PRINT, ''
ENDIF

IF (N_ELEMENTS(x_offset) NE N_ELEMENTS(y_offset)) OR $
   (N_ELEMENTS(x_offset) NE N_ELEMENTS(z_offset)) OR $
   (N_ELEMENTS(x_offset) NE N_ELEMENTS(t_offset)) THEN $
   MESSAGE, 'Offsets must be same size!'

offsets = [ [x_offset], [y_offset], [z_offset], [t_offset] ]
print, SIZE(offsets, /DIMENSIONS)
out_data = {}
iid = NCDF_OPEN(fname)                                                ;Open the NCDF file
	result = NCDF_INQUIRE(iid)                                          ;Get info from file
	
	read_offset = LONARR(result.NDIMS, 2)
	read_count  = LONARR(result.NDIMS, 2)
	
	;=== Get the variables indices for all data in the parameter
	;=== keyword. If the keyword is NOT set, then all data is read
	var_ids = []
	IF (N_ELEMENTS(variables) NE 0) THEN BEGIN
		IF (variables[0] NE ' ') THEN BEGIN
			FOR i = 0, N_ELEMENTS(variables)-1 DO $
				var_ids = [var_ids, NCDF_VARID(iid, variables[i])]
	
			;=== If there were variables in the keyword, make sure that
			;=== all var_ids are valid (i.e., NE -1). If some variables
			;=== were NOT found, print out the variable names.
			;=== IF no variables were input, then create variable ids using
			;=== INDGEN(NVARS).
			IF (N_ELEMENTS(var_ids) NE 0) THEN BEGIN
				id = WHERE(var_ids NE -1, CNT, COMPLEMENT=cID, NCOMPLEMENT=cCNT)
				var_ids = (CNT GT 0) ? var_ids[id] : INDGEN(result.NVARS)
				IF (cCNT NE 0) THEN BEGIN
					PRINT, 'The following variables were NOT found in the file:'
					PRINT, '  ', STRJOIN(variables[cid], ', ')
				ENDIF
			ENDIF ELSE var_ids = INDGEN(result.NVARS)
		ENDIF
  ENDIF
   
	;=== Get names of the dimensions
	FOR i = 0, result.NDIMS-1 DO BEGIN
	  NCDF_DIMINQ, iid, i, dim_name, dim_size
	  tmp = LIST()
	  FOR j = 0, N_ELEMENTS(x_offset)-1 DO BEGIN
	  	print, offsets[j,i]
	    NCDF_VARGET, iid, dim_name, data, OFFSET=offsets[j,i], COUNT=[1]
	    tmp.ADD, data, /NO_COPY
	  ENDFOR
	  help, tmp
    data = tmp.ToARRAY(DIMENSION=1, /NO_COPY)
;	  NCDF_ATTGET, iid, dim_name, 'long_name', dim_name
;	  dim_name = STRING(TEMPORARY(dim_name))
	  read_count[i] = dim_size
	  ;=== Append the data to the out_data structure
	  out_data  = CREATE_STRUCT(out_data, dim_name, TEMPORARY(data))
	  ;=== Filter out dimension variables from variable indices
	  IF (N_ELEMENTS(var_id) NE 0) THEN BEGIN
	    id = WHERE(var_ids NE i, CNT)
	    IF (CNT GT 0) THEN var_ids = TEMPORARY(var_ids[id])
	  ENDIF
	ENDFOR

  FOR i = 0, N_ELEMENTS(var_ids)-1 DO BEGIN
    var_id   = var_ids[i]
		var_info = NCDF_VARINQ(iid, var_id)                               ;Get variable information
		exist    = STRMATCH(TAG_NAMES(out_data), var_info.NAME, /FOLD_CASE)
		IF (TOTAL(exist) GT 0) THEN CONTINUE
		FOR j = 0, var_info.NATTS-1 DO BEGIN                              ;Iterate over attributes
		  attName = NCDF_ATTNAME(iid, var_id, j)                          ;Get name of the attribute
		  IF STRMATCH(attName, '*fill*', /FOLD_CASE) THEN $               ;Get fill value
		    NCDF_ATTGET, iid, var_id, attName, fill
		  IF STRMATCH(attName, '*missing*', /FOLD_CASE) THEN $            ;Get missing value
		    NCDF_ATTGET, iid, var_id, attName, missing
		  IF STRMATCH(attName, 'scale_factor', /FOLD_CASE) THEN $         ;Get fill value
		    NCDF_ATTGET, iid, var_id, attName, scale
		  IF STRMATCH(attName, 'add_offset', /FOLD_CASE) THEN $           ;Get fill value
		    NCDF_ATTGET, iid, var_id, attName, offset
		ENDFOR                                                            ;END j		
    
    tmp = LIST()
    FOR j = 0, x_offset-1 DO BEGIN
      var_offset = [ REPLICATE(j, var_info.NDIMS), var_info.DIM ]
      NCDF_VARGET, iid, var_id, data, $                               ;Get data from variable
		    OFFSET = var_offset, $
		    COUNT  = BYTARR(var_info.NDIMS)+1B
		ENDFOR
		data = tmp.ToArray(/TRANSPOSE, /NO_COPY)
		
		IF (N_ELEMENTS(fill) NE 0) THEN $
		  fill_id = WHERE(data EQ TEMPORARY(fill), fill_CNT)
		IF (N_ELEMENTS(missing) NE 0) THEN $
		  miss_id = WHERE(data EQ TEMPORARY(missing), miss_CNT)
    IF (N_ELEMENTS(scale) NE 0) THEN $
      data = TEMPORARY(data) * TEMPORARY(scale)
		IF (N_ELEMENTS(offset) NE 0) THEN $
		  data = TEMPORARY(data) + TEMPORARY(offset)
				
		IF (N_ELEMENTS(fill_CNT) GT 0) THEN BEGIN
		  IF (SIZE(data, /type) LT 4) AND (fill_CNT GT 0) THEN $
		    data = FLOAT(TEMPORARY(data))
		  data[TEMPORARY(fill_id)] = !VALUES.F_NaN
		ENDIF 
		
		IF (N_ELEMENTS(miss_CNT) GT 0) THEN BEGIN
		  IF (SIZE(data, /type) LT 4) AND (miss_CNT GT 0) THEN $
		    data = FLOAT(TEMPORARY(data))
		  data[TEMPORARY(miss_id)] = !VALUES.F_NaN
		ENDIF
        		
		IF KEYWORD_SET(getUnits) THEN BEGIN																;If getUnits keyword set
				NCDF_ATTGET, iid, vars[i], 'units', units		       				    ;Get units value
				units = STRING(units)																					;Convert units to string
		ENDIF
		IF KEYWORD_SET(getLongName) THEN BEGIN														;If getLongName keyword set
				NCDF_ATTGET, iid, vars[i], 'long_name', longname		       		;Get longname value
				longname = STRING(longname)																		;Convert longname to string
		ENDIF
														
		out_data = CREATE_STRUCT(out_data, var_info.NAME, data)         ;Create struct of all data
		
		IF KEYWORD_SET(getUnits) THEN $															    	;If getUnits set
			data = CREATE_STRUCT(data, vars[i]+'_units', units)							;Append to returned structure
		IF KEYWORD_SET(getLongName) THEN $    														;If getLongName Set
			data = CREATE_STRUCT(data, vars[i]+'_longname', longname)				;Append to returned structure
	ENDFOR
NCDF_CLOSE, iid                                                       ;Close NCDF File

RETURN, out_data                                                          ;Return data

END