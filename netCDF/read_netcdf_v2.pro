PRO READ_netCDF_LONGITUDE_INDICES, data, limit, read_offset, read_count, i, lon_wrap

lon_wrap = -1
IF (MIN(data) LT 0) THEN BEGIN
  IF (limit[1] GT 180) THEN limit[1] = limit[1]-360
	IF (limit[3] GT 180) THEN limit[3] = limit[3]-360
	IF (limit[1] LT limit[3]) THEN BEGIN
		lon_id = WHERE(data GE limit[1] AND data LE limit[3], LON_CNT)
		IF (LON_CNT GT 0) THEN BEGIN
			data = TEMPORARY(data[lon_id])
			read_offset[i,*] = lon_id[0]
			read_count[i,*]  = lon_id[-1] - lon_id[0] + 1
		ENDIF
	ENDIF ELSE BEGIN
	  lon_offset=360
		lon_cnt = 0 & lon_data = [] & lon_wrap = [0, 0]
		lon_id1 = WHERE(data GE limit[1], LON_CNT1)
		lon_id2 = WHERE(data LE limit[3], LON_CNT2)	            
		IF (LON_CNT1 GT 0) THEN BEGIN
			lon_wrap[0]=1
			lon_data = [lon_data, data[lon_id1]]
			read_offset[i,0] = lon_id1[0]
			read_count[i,0]  = lon_id1[-1] - lon_id1[0] + 1
			LON_CNT = lon_cnt + TEMPORARY(lon_CNT1)
		ENDIF
		IF (LON_CNT2 GT 0) THEN BEGIN
			lon_wrap[1]=1
			lon_data = [lon_data, data[lon_id2]+lon_offset]
			read_offset[i,1] = lon_id2[0]
			read_count[i,1]  = lon_id2[-1] - lon_id2[0] + 1
			LON_CNT = lon_CNT + TEMPORARY(LON_CNT2)
		ENDIF
		data = TEMPORARY(lon_data)
	ENDELSE
ENDIF ELSE BEGIN
	IF (limit[1] LT limit[3]) THEN BEGIN
		lon_id = WHERE(data GE limit[1] AND data LE limit[3], LON_CNT)
		IF (LON_CNT GT 0) THEN BEGIN
			data = TEMPORARY(data[lon_id])
			read_offset[i,*] = lon_id[0]
			read_count[i,*]  = lon_id[-1] - lon_id[0] + 1
		ENDIF
	ENDIF ELSE BEGIN
	  lon_offset = -360
		lon_cnt = 0 & lon_data = [] & lon_wrap = [0, 0]
		lon_id1 = WHERE(data GE limit[1], LON_CNT1)
		lon_id2 = WHERE(data LE limit[3], LON_CNT2)	            
		IF (LON_CNT1 GT 0) THEN BEGIN
			lon_wrap[0]=1
			lon_data = [lon_data, data[lon_id1]+lon_offset]
			read_offset[i,0] = lon_id1[0]
			read_count[i,0]  = lon_id1[-1] - lon_id1[0] + 1
			LON_CNT = lon_cnt + TEMPORARY(lon_CNT1)
		ENDIF
		IF (LON_CNT2 GT 0) THEN BEGIN
			lon_wrap[1]=1
			lon_data = [lon_data, data[lon_id2]]
			read_offset[i,1] = lon_id2[0]
			read_count[i,1]  = lon_id2[-1] - lon_id2[0] + 1
			LON_CNT = lon_CNT + TEMPORARY(LON_CNT2)
		ENDIF
		data = TEMPORARY(lon_data)
	ENDELSE
ENDELSE

END

FUNCTION READ_netCDF_V2, fname, $
								limit				= limit, $
								DIR					= dir, $
								PARAMETERS	= parameters,$
								GETUNITS		= getUnits, $
								GETLONGNAME	= getLongName, $
								VERBOSE			= verbose,     $
								X_OFFSET    = x_offset,    $
								Y_OFFSET    = y_offset,    $
								Z_OFFSET    = z_offset,    $
								T_OFFSET    = t_offset

;+
; Name:
;		READ_NCDF
; Purpose:
;		A function read in all the data from a NCDF file.
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
;		PARAMETER		: String of variables to get, if not set,
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

out_data = {}
iid = NCDF_OPEN(fname)                                                ;Open the NCDF file
	result = NCDF_INQUIRE(iid)                                          ;Get info from file
	
	read_offset = LONARR(result.NDIMS, 2)
	read_count  = LONARR(result.NDIMS, 2)
	
	;=== Get the variables indices for all data in the parameter
	;=== keyword. If the keyword is NOT set, then all data is read
	var_ids = []
	IF (N_ELEMENTS(parameters) NE 0) THEN BEGIN
		IF (parameters[0] NE ' ') THEN BEGIN
			FOR i = 0, N_ELEMENTS(parameters)-1 DO $
				var_ids = [var_ids, NCDF_VARID(iid, parameters[i])]
	
			;=== If there were parameters in the keyword, make sure that
			;=== all var_ids are valid (i.e., NE -1). If some variables
			;=== were NOT found, print out the variable names.
			;=== IF no parameters were input, then create variable ids using
			;=== INDGEN(NVARS).
			IF (N_ELEMENTS(var_ids) NE 0) THEN BEGIN
				id = WHERE(var_ids NE -1, CNT, COMPLEMENT=cID, NCOMPLEMENT=cCNT)
				var_ids = (CNT GT 0) ? var_ids[id] : INDGEN(result.NVARS)
				IF (cCNT NE 0) THEN BEGIN
					PRINT, 'The following parameters were NOT found in the file:'
					PRINT, '  ', STRJOIN(parameters[cid], ', ')
				ENDIF
			ENDIF ELSE var_ids = INDGEN(result.NVARS)
		ENDIF
  ENDIF
   
	;=== Get names of the dimensions
	FOR i = 0, result.NDIMS-1 DO BEGIN
	  NCDF_DIMINQ, iid, i, dim_name, dim_size
	  NCDF_VARGET, iid, dim_name, data
;	  NCDF_ATTGET, iid, dim_name, 'long_name', dim_name
;	  dim_name = STRING(TEMPORARY(dim_name))
	  read_count[i] = dim_size
	  ;=== If a subset of the data is to be read in
	  IF (N_ELEMENTS(limit) NE 0) THEN BEGIN
	    CASE STRUPCASE(dim_name) OF
	      'LONGITUDE' : READ_netCDF_LONGITUDE_INDICES, data, limit, $
	                      read_offset, read_count, i, lon_wrap
	      'LATITUDE'  : BEGIN
	          lat_id = WHERE(data GE limit[0] AND data LE limit[2], LAT_CNT)
	          IF (lat_CNT GT 0) THEN BEGIN
	            data = TEMPORARY(data[lat_id])
	            read_offset[i,*] = lat_id[0]
	            read_count[i,*]  = lat_id[-1] - lat_id[0] + 1
	          ENDIF
	                    END
	      ELSE        : read_count[i,*] = dim_size
	    ENDCASE
	  ENDIF ELSE lon_wrap = -1
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
    
    ;=== If data does NOT wrap around the date line
    IF (N_ELEMENTS(lon_wrap) EQ 1) THEN $
      NCDF_VARGET, iid, var_id, data, $                               ;Get data from variable
		    OFFSET=read_offset[[var_info.DIM],0], $
		    COUNT=read_count[[var_info.DIM],0] $
		ELSE BEGIN
			IF (lon_wrap[0] EQ 1) THEN BEGIN
				NCDF_VARGET, iid, var_id, data1, $                              ;Get data from variable
					OFFSET=read_offset[[var_info.DIM],0], $
					COUNT=read_count[[var_info.DIM],0]
			ENDIF
			IF (lon_wrap[1] EQ 1) THEN BEGIN
				NCDF_VARGET, iid, var_id, data2, $                               ;Get data from variable
					OFFSET=read_offset[[var_info.DIM],1], $
					COUNT=read_count[[var_info.DIM],1]
			ENDIF

			IF (N_ELEMENTS(data1) GT 0) AND (N_ELEMENTS(data2) GT 0) THEN BEGIN 
				data = LIST(TEMPORARY(data1), TEMPORARY(data2))
				data = (TEMPORARY(data)).ToArray(DIMENSION=1)
			ENDIF ELSE IF (N_ELEMENTS(data1) GT 0) THEN $
				data = TEMPORARY(data1) $
			ELSE $
				data = TEMPORARY(data2)
    ENDELSE
    		  
		
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