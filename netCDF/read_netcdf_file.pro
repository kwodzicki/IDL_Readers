FUNCTION LOCAL_READ_NETCDF_GROUP, iid, $
  VARIABLES  = variables,  $
  SCALE_DATA = scale_data, $
  FLOAT      = float,      $
  DIMID      = dimID,      $
  IID_INFO   = iid_info
;+
; Name:
;		LOCAL_READ_NETCDF_GROUP
; Purpose:
;		An IDL function to read in all the data from a netCDF file. 
;   Split from main function because main function also loops over groups.
; Calling Sequence:
;		result = READ_netCDF_FILE('/path/to/file.nc')
; Inputs:
;		fname	: File name to read in. MUST BE FULL PATH
; Outputs:
;		A structure containing all the data form the file.
; Keywords:
;		VARIABLES		: String of variables to get, if not set,
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
;   DIMID       : Offset for dimensions within groups as dimensions in the
;                  netCDF file are still order from oldest (0) to newest (n-1)
;                  globally and not within groups
;   IID_INFO    : Set to a named variable to return the result of NCDF_INQUIRE
; Author and History:
;		Kyle R. Wodzicki	Created 21 Sep. 2017
;-
  COMPILE_OPT IDL2, HIDDEN
	old_Quiet = !QUIET
	!QUIET = 1
  CATCH, err
  IF err NE 0 THEN CATCH, /CANCEL

;	IF N_ELEMENTS(variables) GT 0 THEN PRINT, variables
	out_data = {}                                                                 ; Initialize empty structure for the data
	iid_info = NCDF_INQUIRE(iid)                                                  ; Get information from the netCDF file

	gatts = {}
	FOR i = 0, iid_info.NGATTS-1 DO BEGIN                                         ; Iterate over all global attributes
		attName = NCDF_ATTNAME(iid, i, /GLOBAL)                                     ; Get the name of the ith global attribute
		attInfo = NCDF_ATTINQ(iid, attName, /GLOBAL)                                ; Get the DataType and length of the attribute. String attributes must be converted, need this to determine if string.
		NCDF_ATTGET, iid, attName, attData, /GLOBAL                                 ; Get the attribute data
		IF (attInfo.DataType EQ 'CHAR') THEN attData = STRING(attData)              ; If the attribute is of type CHAR, then convert the attribute data to a string 
		gatts = CREATE_STRUCT(gatts, attName, attData)                              ; Append the ith global attribute to the out_data structure
	ENDFOR
	out_data = CREATE_STRUCT(out_data, 'global_atts', $
		N_TAGS(gatts) GT 0 ? gatts : 0)

	dimensions = {}
	dimStart = 0
	dimEnd   = iid_info.NDIMS-1
	IF N_ELEMENTS(dimID) NE 0 THEN BEGIN
		dimStart += dimID
		dimEND   += dimID
	ENDIF
	
	FOR i = dimStart, dimEnd DO BEGIN
		NCDF_DIMINQ, iid, i, dimName, dimSize
		tmp = {NAME : dimName, SIZE : dimSize}
;		vid = NCDF_VARID(iid, dimName)
;		IF vid NE -1 THEN BEGIN
;			NCDF_VARGET, iid, vid, dimData
;			tmp = CREATE_STRUCT(tmp, 'Values', dimData)
;		ENDIF
		dimensions = CREATE_STRUCT(dimensions, '_'+STRTRIM(i,2), tmp)
	ENDFOR
	out_data = CREATE_STRUCT(out_data, 'Dimensions', $
		N_TAGS(dimensions) GT 0 ? dimensions : 0)			

;=====================================================================
;===
;=== Obtain the location of variables in the netCDF file based on 
;=== input into the variables keyword. If no information is input
;=== into the keyword, then indices for all variables in the file
;=== are generated based on the number of variables in the file.
;===
;=====================================================================
	vars = {}
	IF (N_ELEMENTS(variables) NE 0) THEN BEGIN                                    ; Check for input into the variables keyword
		var_ids = []                                                                ; Initialize empty array to store variable indices in

		;=== Obtain information about the various dimensions that may 
		;=== be in the netCDF file. 
		FOR i = 0, iid_info.NDIMS-1 DO BEGIN                                        ; Iterate over all dimensions in the netCDF file
			NCDF_DIMINQ, iid, i, dim_name, dim_size                                   ; Obtain information about the ith dimension in the file
			var_ids = [ var_ids, NCDF_VARID(iid, dim_name) ]                          ; Attempt to locate a variable with the same name as the ith dimension
		ENDFOR                                                                      ; END i

		FOR i = 0, N_ELEMENTS(variables)-1 DO $                                     ; Iterate over all variables in the variables keyword
			var_ids = [var_ids, NCDF_VARID(iid, variables[i])]                        ; Determine the variable index based on the variable name and append it to the var_ids array
		id = WHERE(var_ids NE -1, CNT)                                              ; Locate valid variable indices in the var_id array (i.e., var_id NE -1 as NCDF_VARID returns -1 if variable NOT found) 
		IF (CNT GT 0) THEN $                                                        ; If indices NE -1 are found, then those data are to be read in
			var_ids = var_ids[id] $                                                   ; Filter the variable indices to only the valid indices
		ELSE BEGIN                                                                  ; Print an error message if none of the variables were found
;			MESSAGE, 'None of the requested variables were found!', /Continue
			var_ids = []
		ENDELSE
	ENDIF ELSE IF iid_info.NVARS GT 0 THEN $
	  var_ids = INDGEN(iid_info.NVARS) $                                          ; If the variables keyword was NOT used, generate all variables indices based on number of variables in file (i.e., iid_info.NVARS)
	ELSE $
	  var_ids = []

	IF N_ELEMENTS(var_ids) GT 1 THEN $															;If there is more than one (1) element in the array
		var_ids = var_ids[ UNIQ(var_ids, SORT(var_ids) ) ]									;Subset by only unique variable IDs

	FOR i = 0, N_ELEMENTS(var_ids)-1 DO BEGIN                                     ; Iterate over all variable indices in the var_ids array
		var_id   = var_ids[i]                                                       ; Get the ith variable index
		var_data = NCDF_VARINQ(iid, var_id)
		FOR j = 0, var_data.NATTS-1 DO BEGIN                                        ; Iterate over all of the variables attributes
			attName = NCDF_ATTNAME(iid, var_id, j)                                    ; Get the name of the attribute jth attribute
			attInfo = NCDF_ATTINQ(iid,  var_id, attName)                              ; Get the DataType and length of the attribute. String attributes must be converted, need this to determine if string.
			NCDF_ATTGET, iid, var_id, attName, attData                                ; Get the data for the attribute
			IF (attInfo.DataType EQ 'CHAR') THEN attData = STRING(attData)            ; If the attribute is of type CHAR, then convert the attribute data to a string
			var_data = CREATE_STRUCT(var_data, attName, attData)                      ; Append the attribute data to the var_data structure 
		
			IF KEYWORD_SET(scale_data) THEN BEGIN                                     ; If the SCALE_DATA keyword is set, save some information needed to scale the data later
				IF STRMATCH(attName, '*FillValue', /FOLD_CASE) THEN $
					fill    = KEYWORD_SET(float) ? FLOAT(attData) : attData
				IF (attName EQ 'missing_value') THEN $
					missing = KEYWORD_SET(float) ? FLOAT(attData) : attData
				IF (attName EQ 'scale_factor')  THEN $
					scale   = KEYWORD_SET(float) ? FLOAT(attData) : attData
				IF (attName EQ 'add_offset')    THEN $
					offset  = KEYWORD_SET(float) ? FLOAT(attData) : attData
		    IF STRMATCH(attName, 'valid_range', /FOLD_CASE) THEN $                  ; Get valid range
					range   = KEYWORD_SET(float) ? FLOAT(attData) : attData
			ENDIF
		ENDFOR                                                                      ; END j		
	
		NCDF_VARGET, iid, var_id, data                                              ; Get data from variable
	
		;=== Get year, month, day, hour for time
		IF (STRUPCASE(var_data.NAME) EQ 'TIME') THEN BEGIN                          ; If the variable name is TIME
			tags = TAG_NAMES(var_data)																			          ; Get the names of the attributes associated with time
			IF TOTAL(STRMATCH(tags, 'units', /FOLD_CASE), /INT) EQ 1 THEN BEGIN       ; Determine index of the units attribute of the time variable
				tmp = STRSPLIT(var_data.UNITS, ' ', /EXTRACT)														; Get the time units
				CASE STRLOWCASE(tmp[0]) OF
					'hours'   : new_data = data/24.0																			; If the units are hours since
					'minutes' : new_data = data/1440.0																		; If the units are mintues since
					'seconds' : new_data = data/86400.0																		; If the units are seconds since
					ELSE      : BEGIN
												PRINT, 'Assuming time units are days since'             ; Else, print message
												new_data = data
											END
				ENDCASE
				yymmdd  = FLOAT(STRSPLIT(tmp[2],'-',/EXTRACT))
				hrmnsec = FLOAT(STRSPLIT(tmp[3],':',/EXTRACT))
				juldate = GREG2JUL(yymmdd[1], yymmdd[2], yymmdd[0], $
													 hrmnsec[0],hrmnsec[1],hrmnsec[2]) + new_data
;			ENDIF ELSE juldate = GREG2JUL(1, 1, 1900, 0, 0, 0) + data/24.0            ; Convert the gregorian reference date to a julian date and add the fractional julian days to it
			ENDIF ELSE juldate = data                                                 ; Assume the time is in IDL Juldate format
			JUL2GREG, juldate, mm, dd, yy,  hr                                        ; Convert the julian date back to the gregorian date
			var_data = CREATE_STRUCT(var_data, 'Year', yy, 'Month', mm, $             ; Append the year, month, day, hour information to the variable's structure
																					'Day',  dd, 'Hour',  hr)
		ENDIF
		IF KEYWORD_SET(scale_data) THEN BEGIN                                       ; Scale the data if the keyword is set
			replace_id = []
			IF (N_ELEMENTS(fill) NE 0) THEN BEGIN
				id = WHERE(data EQ fill, CNT)
				IF (CNT GT 0) THEN replace_id = [replace_id, id]
				fill = !NULL
			ENDIF

			IF (N_ELEMENTS(missing) NE 0) THEN BEGIN
				id = WHERE(data EQ missing, CNT)
				IF (CNT GT 0) THEN replace_id = [replace_id, id]
				missing = !NULL
			ENDIF

			IF (N_ELEMENTS(range) EQ 2) THEN BEGIN
				id = WHERE(data LT range[0] OR data GT range[1], CNT)
				IF (CNT GT 0) THEN replace_id = [replace_id, id]
				range    = !NULL
			ENDIF

			;=== Scale the data IF a scale factor was read in
			IF (N_ELEMENTS(scale) EQ 1) THEN BEGIN
				IF KEYWORD_SET(float) THEN scale = FLOAT(scale)
				data = TEMPORARY(data) * scale
				scale  = !NULL
			ENDIF
			;=== Offset the data IF an offset was read in
			IF (N_ELEMENTS(offset) EQ 1) THEN BEGIN
				IF KEYWORD_SET(float) THEN offset = FLOAT(offset)
				data = TEMPORARY(data) + offset
				offset = !NULL
			ENDIF

			;=== Replace invalid data if any present
			IF (N_ELEMENTS(replace_id) GT 0) THEN BEGIN
				type = SIZE(data, /TYPE)
				IF (type EQ 4) OR (type EQ 5) THEN data = FLOAT(data)
				data[replace_id] = !Values.F_NaN
			ENDIF 
		ENDIF
		var_data  = CREATE_STRUCT(var_data, 'values', data)                         ; Append the variable data to the var_data structure							
		vars      = CREATE_STRUCT(vars, var_data.NAME, var_data)                    ; Append the var_data structure to the out_data structure
	ENDFOR
	out_data = CREATE_STRUCT(out_data, 'Variables', $
		N_TAGS(vars) GT 0 ? vars : 0) 
	!QUIET = old_Quiet
	RETURN, out_data                                                                ; Return the data
END

FUNCTION READ_netCDF_FILE, fname, $
  VARIABLES  = variables, $
  SCALE_DATA = scale_data, $
  FLOAT      = float, $
  IID        = iid_in
;+
; Name:
;		READ_netCDF_FILE_V02
; Purpose:
;		A function read in all the data from a NCDF file.
; Calling Sequence:
;		result = READ_netCDF_FILE('/path/to/file.nc')
; Inputs:
;		fname	: File name to read in. MUST BE FULL PATH
; Outputs:
;		A structure containing all the data form the file.
; Keywords:
;		VARIABLES		: String of variables to get, if not set,
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
;   IID         : Set to a file handle that has already be opened.
;                  WARNING -> If this keyword IS set, the file will NOT
;                  be closed when this function finishes. IT WILL REMAIN OPEN!
; Author and History:
;		Kyle R. Wodzicki	Created 27 Jan. 2016
;
;     VERSION 02 Notes:
;       Works to make the layout of structure better. Also adds support for
;       groups.
;-

COMPILE_OPT	IDL2                                                                ;Set Compile options

IF (N_PARAMS() NE 1) THEN MESSAGE, 'Incorrect number of inputs!'                ; Check the number of inputs

DLM_LOAD, 'ncdf'                                                                ; Load the netCDF module

IF N_ELEMENTS(scale_data) EQ 0 THEN $
	scale_data = 1 $
ELSE IF KEYWORD_SET(float) THEN $
	scale_data = 1                                       									; Set scale data keyword IF float is set


iid = N_ELEMENTS(iid_in) EQ 0 ? NCDF_OPEN(fname) : iid_in                       ; Open the netCDF file if no IID was input

fileInfo = NCDF_INQUIRE(iid)																		;Get information about the file
out_data = LOCAL_READ_NETCDF_GROUP(iid, $                                     ; Get information from the netCDF file
	VARIABLES  = variables, $
	SCALE_DATA = scale_data, $
	FLOAT      = float)
	
ngids = 0                                                                     ; Set number of group ids to zero by default
gids  = LIST( NCDF_GROUPSINQ(iid) )                                           ; Get list of group ids in file

IF SIZE(gids[0], /N_DIMENSIONS) EQ 0 THEN $                                   ; If NO groups are found
	out_data = CREATE_STRUCT(out_data, 'groups', 0) $                           ; Append groups tag to out data array with value of zero (0)
ELSE BEGIN                                                                    ; Else, groups were found
	WHILE ngids NE N_ELEMENTS(gids) DO BEGIN                                    ; While the number of group ids does NOT match ngids
		ngids   = N_ELEMENTS(gids)                                                ; Reset the number of group ids
		new_ids = []                                                              ; Initialize empty array to store sub group ids in
		FOR i = 0, N_ELEMENTS(gids[-1])-1 DO BEGIN                                ; Iterate over the group ids
			tmp = NCDF_GROUPSINQ(gids[-1,i])                                        ; Get any group ids within a given group id
			IF SIZE(tmp, /N_DIMENSIONS) NE 0 THEN new_ids = [new_ids, tmp]          ; If sub group ids found, append them to the group ids list
		ENDFOR
		IF N_ELEMENTS(new_ids) GT 0 THEN gids.ADD, new_ids                        ; If the new_ids array is NOT empty, add it to the gids list
	ENDWHILE                                                                    ; END while
	gids = gids.ToARRAY(/No_COPY, DIMENSION=1)                                  ; Convert list to array
	groups = {}                                                                 ; Initialize structure to store all group information in
	dimID  = 0                                                                  ; Initialize dimension offset
	FOR i = 0, N_ELEMENTS(gids)-1 DO BEGIN                                      ; Iterate over all group ids
		tmp = LOCAL_READ_NETCDF_GROUP(gids[i], $                                  ; Get information from group
					VARIABLES  = variables,  $
					SCALE_DATA = scale_data, $
					FLOAT      = float,      $
					DIMID      = dimID,      $
					IID_INFO   = iid_info)
		IF N_TAGS(tmp) EQ 0 THEN CONTINUE                                         ; If NO information returned, then continue
		tmp = CREATE_STRUCT(tmp, 'GROUP_NAME', NCDF_GROUPNAME(gids[i]))           ; Append the name of the group to the group data structure
		tmp = CREATE_STRUCT(tmp, 'FULL_GROUP', NCDF_FULLGROUPNAME(gids[i]))       ; Append the full path of the group to the group data structure
		groups = CREATE_STRUCT(groups, tmp.GROUP_NAME, tmp)                       ; Append the group data to the groups structure
		dimID += iid_info.NDIMS                                                   ; Increment the dimension offset based on the number of dimensions in the group
	ENDFOR	
	out_data = $
	  CREATE_STRUCT(out_data, 'GROUPS', N_TAGS(groups) GT 0 ? groups : 0)
ENDELSE	

IF N_ELEMENTS(iid_in) EQ 0 THEN NCDF_CLOSE, iid                                 ;

RETURN, out_data                                                                ; Return the data

END
