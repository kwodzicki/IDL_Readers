PRO READ_NETCDF_GROUP, iid, out_data, $
  VARIABLES  = variables,  $
  SCALE_DATA = scale_data, $
  ADD_FIRST  = add_first,  $
  FLOAT      = float,      $
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
;		out_data : A structure containing all the data form the file.
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
  IF N_ELEMENTS(out_data) EQ 0 THEN out_data = DICTIONARY()
	iid_info = NCDF_INQUIRE(iid)                                                  ; Get information from the netCDF file
  isGroup  = NCDF_GROUPPARENT(iid) NE -1

  gatts = GET_ATTRIBUTES(iid, INQUIRE=iid_info)
  IF isGroup THEN $
    tmp = DICTIONARY('global_atts', gatts) $
  ELSE $
    out_data['global_atts'] = gatts

	dimensions = GET_DIMENSIONS( iid )
  IF isGroup THEN tmp['dimensions'] = dimensions 
  IF out_data.HasKey('DIMENSIONS') THEN $
	  out_data['DIMENSIONS'] += dimensions $
  ELSE $
	  out_data['DIMENSIONS']  = dimensions

  ;=====================================================================
  ;===
  ;=== Obtain the location of variables in the netCDF file based on 
  ;=== input into the variables keyword. If no information is input
  ;=== into the keyword, then indices for all variables in the file
  ;=== are generated based on the number of variables in the file.
  ;===
  ;=====================================================================
	vars = DICTIONARY()
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
    var_data = READ_netCDF_VARIABLE(iid, var_ids[i], $
                 SCALE_DATA = scale_data, $
                 ADD_FIRST  = add_first, $
                 FLOAT      = float)

    dimNames = STRARR( var_data.NDIMS )
    FOR j = 0, var_data.NDIMS-1 DO $ 
      dimNames[j] = out_data['DIMENSIONS', var_data.DIM[j]].NAME
    var_data['dim_name'] = dimNames

		vars[var_data.NAME]  = var_data												; Append the var_data structure to the out_data structure
	ENDFOR
  vars = (N_ELEMENTS(vars) GT 0) ? vars : 0

  IF isGroup THEN BEGIN
	  tmp['Variables']  = vars
	  tmp['GROUP_NAME'] = NCDF_GROUPNAME( iid )           ; Append the name of the group to the group data structure
	  tmp['FULL_GROUP'] = NCDF_FULLGROUPNAME( iid )       ; Append the full path of the group to the group data structure
	  out_data['GROUPS', tmp.GROUP_NAME] = tmp                       ; Append the group data to the groups structure
  ENDIF ELSE $
	  out_data['Variables'] = vars

	!QUIET = old_Quiet

END
