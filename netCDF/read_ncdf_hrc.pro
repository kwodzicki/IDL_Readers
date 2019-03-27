FUNCTION READ_NCDF_HRC, fname, BOUND=bound, DIR=dir, $
											PARAMETERS=parameters,$
											GETUNITS=getUnits, $
											GETLONGNAME=getLongName, $
											VERBOSE=verbose

;+
; Name:
;		READ_NCDF_HRC
; Purpose:
;		A function to read in files from the Highly Reflective Cloud (HRC)
;		dataset
; Calling Sequence:
;		result = READ_NCDF_ERA('File_name')
; Inputs:
;		fname	: File name to read in. Can be full path to a file, OR
;					just the file name of a file in:
; Outputs:
;		A structure containing all the data form the file.
; Keywords:
;		BOUND				: If data in a certain domain is to be selected, set this.
;					 				 Array must be west, south, east, north bounds.
;		VERBOSE			: Set to get info about files that are being 
;									processed.
; Author and History:
;		Kyle R. Wodzicki	Created 28 Aug. 2014
;-

COMPILE_OPT	IDL2                                                      ;Set Compile options

IF ~FILE_TEST(fname) THEN MESSAGE, 'FILE DOES NOT EXIST!'							;Check if file exist

IF (KEYWORD_SET(bound) EQ 0) THEN bound=[0.0,-90.0,360.0,90.0]        ;Default boundary		
data = {}
vars = []

iid = NCDF_OPEN(fname)                                                ;Open the NCDF file

	result = NCDF_INQUIRE(iid)                                          ;Get info from file
	FOR i = 0, result.NVARS-1 DO BEGIN                                  ;Iterate over all variables
		var_info = NCDF_VARINQ(iid, i)                                    ;Get info from variable
		vars = [vars, var_info.NAME]                                      ;Save name of variable
		CASE var_info.NAME OF
			'lon'	: BEGIN
							NCDF_VARGET, iid, var_info.NAME, lon                    ;Get data from longitude
							lon_index=WHERE(lon GE bound[0] AND $
											lon LE bound[2], count)
						  END
			'lat'	: BEGIN
							NCDF_VARGET, iid, var_info.NAME, lat                    ;Get data from latitude
							lat_index=WHERE(lat GE bound[1] AND $
											lat LE bound[3], count)
						  END
			ELSE		: ;DO NOTHING
		ENDCASE
	ENDFOR
	
	FOR i = 0, N_ELEMENTS(vars)-1 DO BEGIN                              ;Iterate over all variable names
		NCDF_VARGET, iid, vars[i], result                                 ;Get data from variable
		IF (vars[i] NE 'time' AND $                                       ;If not time, lat, or lon...
				vars[i] NE 'lon' AND $
				vars[i] NE 'lat') THEN BEGIN	
			IF KEYWORD_SET(parameters) THEN BEGIN
				index = WHERE(STRMATCH(parameters,vars[i],/FOLD_CASE),COUNT)
				IF (COUNT NE 1) THEN CONTINUE																	;If current var not in parameter, skip 
			ENDIF
			
			NCDF_ATTGET, iid, vars[i], 'missing_value',	missing             ;Get missing value
			
			index = WHERE(result EQ missing, COUNT)                         ;Get missing data indicies
			IF (COUNT NE 0) THEN BEGIN                                      ;If missing data
				result	= FLOAT(result)                                       ;Convert to float
				result[index] = !VALUES.F_NAN                                 ;Set missing to nan
			ENDIF
			
		ENDIF
		
		IF (vars[i] EQ 'lon') THEN result=result[lon_index]         ;Filter lon by index
		IF (vars[i] EQ 'lat')	THEN result=result[lat_index]         ;Filter lat by index
																			
		data = CREATE_STRUCT(data, vars[i], result)                       ;Create struct of all data

	ENDFOR
NCDF_CLOSE, iid                                                       ;Close NCDF File

RETURN, data                                                          ;Return data

END