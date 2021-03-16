FUNCTION READ_netCDF_FILE, fname, $
  VARIABLES  = variables, $
  SCALE_DATA = scale_data, $
  ADD_FIRST  = add_first, $
  FLOAT      = float, $
  IID        = iid_in, $
  AS_STRUCT  = as_struct
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

IF (N_PARAMS() NE 1) AND (N_ELEMENTS(iid_in) EQ 0) THEN $
  MESSAGE, 'Incorrect number of inputs!'                ; Check the number of inputs

DLM_LOAD, 'ncdf'                                                                ; Load the netCDF module

IF N_ELEMENTS(as_struct)  EQ 0 THEN as_struct = 1B
IF N_ELEMENTS(scale_data) EQ 0 THEN $
	scale_data = 1 $
ELSE IF KEYWORD_SET(float) THEN $
	scale_data = 1                                       									; Set scale data keyword IF float is set


iid  = N_ELEMENTS(iid_in) EQ 0 ? NCDF_OPEN(fname) : iid_in                       ; Open the netCDF file if no IID was input
gids = GET_ALL_GIDS(iid)

READ_NETCDF_GROUP, iid, out_data, $                                     ; Get information from the netCDF file
	VARIABLES  = variables, $
	SCALE_DATA = scale_data, $
	ADD_FIRST  = add_first, $
	FLOAT      = float

	
IF N_ELEMENTS(gids) EQ 0 THEN $
	out_data['groups'] = 0 $                           ; Append groups tag to out data array with value of zero (0)
ELSE BEGIN                                                                    ; Else, groups were found
	groups = DICTIONARY()                                                       ; Initialize structure to store all group information in
	FOR i = 0, N_ELEMENTS(gids)-1 DO BEGIN                                      ; Iterate over all group ids
		READ_NETCDF_GROUP, gids[i], out_data, $                                  ; Get information from group
					VARIABLES  = variables,  $
					SCALE_DATA = scale_data, $
					FLOAT      = float,      $
					IID_INFO   = iid_info
	ENDFOR	
ENDELSE	

IF N_ELEMENTS(iid_in) EQ 0 THEN NCDF_CLOSE, iid                                 ;

IF KEYWORD_SET(as_struct) THEN $
  RETURN, out_data.ToStruct(/Recursive, /No_Copy) $                                                                ; Return the data
ELSE $
  RETURN, out_data
END
