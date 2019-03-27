FUNCTION READ_NCDF_ITCZ, in_year, in_month, $
								limit				= limit,       $
								VERBOSE			= verbose,     $
								GETUNITS		= getUnits,    $
								GETLONGNAME	= getLongName, $
								MERRA       = merra
;+
; Name:
;		READ_NCDF_ITCZ
; Purpose:
;		A function to read in data from the ITCZ dataset netCDF file
;   containing the ERA variables required to locate the ITCZ 
;   based on they method used by Berry and Reeder (2014).
;   This function will read in only one time, i.e., the time
;   of intereste based on the user input year and month.
; Calling Sequence:
;		result = READ_NCDF_ITCZ(1997, 12)
; Inputs:
;		in_year	 : Year of data to read in
;   in_month : Month of data to read in
; Outputs:
;		A structure containing all the data form the file.
; Keywords:
;		LIMIT				: If data in a certain domain is to be selected, set this.
;					 				 Array must be south, west, north, east limits.
;		VERBOSE			: Set to get info about files that are being 
;									processed.
;		GETUNITS		: If set, will get units and place after data in
;									returned structure.
;		GETLONGNAME	: If set, will get longname and place after data in
;									returned structure. If getunits also set, this 
;									will be below the units tag.
;    MERRA      : Set to locate ITCZ using MERRA variables.
;                  Only valid from Dec. 1997-Dec. 2012
; Author and History:
;		Kyle R. Wodzicki     Created 16 Oct. 2014
;-

COMPILE_OPT	IDL2                                                      ;Set Compile options

data = {}
vars = []

;fname = !ERA_Data+'Month_Means_For_ITCZ.nc'                          ;Read in ERA dataset
IF ~KEYWORD_SET(merra) THEN BEGIN
  fname = !ERA_Data+'Month_Means_For_ITCZ_79-14.nc'                   ;Read in ERA dataset
ENDIF ELSE BEGIN
  fname = !MERRA_Data+'Month_Means_For_ITCZ_MERRA.nc'                 ;Read in Merra dataset
ENDELSE

IF KEYWORD_SET(verbose) THEN BEGIN																		;If verbose output, print following.
	PRINT, ''	
	PRINT, 'Retriving data from file:'                                  ;Print some info
	PRINT, '   ', fname
	PRINT, ''
ENDIF

iid = NCDF_OPEN(fname)                                                ;Open the NCDF file

	result = NCDF_INQUIRE(iid)                                          ;Get info from file
	FOR i = 0, result.NVARS-1 DO BEGIN                                  ;Iterate over all variables
		var_info = NCDF_VARINQ(iid, i)                                    ;Get info from variable
		vars = [vars, var_info.NAME]                                      ;Save name of variable
		CASE STRUPCASE(var_info.NAME) OF
			'LONGITUDE'	: BEGIN
											NCDF_VARGET, iid, var_info.NAME, lon            ;Get data from longitude
											nLon = N_ELEMENTS(lon)                          ;Get size of longitude array
											IF KEYWORD_SET(limit) THEN $
												lon_index=WHERE(lon GE limit[1] AND $
																				lon LE limit[3], lon_cnt) $
											ELSE lon_cnt = 0
						  			END
			'LATITUDE'	: BEGIN
											NCDF_VARGET, iid, var_info.NAME, lat            ;Get data from latitude
											nLat = N_ELEMENTS(lat)                          ;Get size of latitude array
											IF KEYWORD_SET(limit) THEN $
												lat_index=WHERE(lat GE limit[0] AND $
																				lat LE limit[2], lat_cnt) $
											ELSE lat_cnt = 0
						  			END
			'TIME'	    : BEGIN
											NCDF_VARGET, iid, var_info.NAME, time           ;Read in time
						  			END
			ELSE		    : ;DO NOTHING
		ENDCASE
	ENDFOR                                                              ;END i
	
	CALDAT, time, month, day, year                                      ;Convert julian date to month, day, year
	time_id = WHERE(month EQ in_month AND year EQ in_year, CNT)         ;Find index of data to read in
	
	IF (CNT EQ 0) THEN $
	  MESSAGE, 'Requested year and month are NOT in dataset!'
	
	FOR i = 0, N_ELEMENTS(vars)-1 DO BEGIN                              ;Iterate over all variable names
		IF STRMATCH(vars[i], 'longitude', /FOLD_CASE) THEN BEGIN $        ;Filter lon by index
		  NCDF_VARGET, iid, vars[i], result                               ;Get data from variable
			IF (lon_cnt NE 0) THEN result=result[lon_index]
		ENDIF ELSE $
		IF STRMATCH(vars[i], 'latitude', /FOLD_CASE)	THEN BEGIN          ;Filter lat by index
			NCDF_VARGET, iid, vars[i], result                                ;Get data from variable
			IF (lat_cnt NE 0) THEN result=result[lat_index]
		ENDIF ELSE $
		IF STRMATCH(vars[i], 'time', /FOLD_CASE) THEN BEGIN
  		NCDF_VARGET, iid, vars[i], result, $                            ;Get data from variable
                   OFFSET=[time_id], COUNT=[1]                        ;Read time for give month
    ENDIF ELSE BEGIN
	    NCDF_VARGET, iid, vars[i], result, $                            ;Get data from variable
	                 OFFSET=[0,0,time_id], COUNT=[nLon, nLat, 1]        ;Only read in data for given month
	 ENDELSE

		IF KEYWORD_SET(getUnits) THEN BEGIN																;If getUnits keyword set
				NCDF_ATTGET, iid, vars[i], 'units', units		       				    ;Get units value
				units = STRING(units)																					;Convert units to string
		ENDIF
		IF KEYWORD_SET(getLongName) THEN BEGIN														;If getLongName keyword set
				NCDF_ATTGET, iid, vars[i], 'long_name', longname		       		;Get longname value
				longname = STRING(longname)																		;Convert longname to string
		ENDIF
		
		IF (SIZE(result, /N_DIMENSIONS) NE 1) THEN BEGIN                  ;If more than on dimension
			IF (lon_cnt NE 0) THEN result = result[lon_index,*,*,*]         ;Filter by longitude
			IF (lat_cnt NE 0) THEN result = result[*,lat_index,*,*]         ;Filter by latitude
		ENDIF
														
		data = CREATE_STRUCT(data, vars[i], result)                       ;Create struct of all data
		
		IF KEYWORD_SET(getUnits) THEN $															    	;If getUnits set
			data = CREATE_STRUCT(data, vars[i]+'_units', units)							;Append to returned structure
		IF KEYWORD_SET(getLongName) THEN $    														;If getLongName Set
			data = CREATE_STRUCT(data, vars[i]+'_longname', longname)				;Append to returned structure
	ENDFOR
NCDF_CLOSE, iid                                                       ;Close NCDF File

RETURN, data                                                          ;Return data

END