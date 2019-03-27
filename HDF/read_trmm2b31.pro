FUNCTION READ_TRMM2B31, filename

;+
; Name:
;		READ_HDF_NEW
; Purpose:
;		To read in a HDF file.
; Calling Sequence:
;		result = READ_HDF_NEW(filename, PARAMETERS=parameters)
; Inputs:
;		filename	: Name of file to read data in from.
; Outputs:
;		A structure containing all data, or data requested.
; Keywords:
;		PARAMETERS	: A string or string array containing the parameters
;						to obtain from the file.
; Author and History:
;		Kyle R. Wodzicki	Created 29 Apr. 2015
;-

COMPILE_OPT IDL2																											;Set compile options

IF FILE_TEST(filename[0]) EQ 0 THEN MESSAGE, 'FILE NOT FOUND!'				;Error if file NOT exist

fdata = {}																	                  				;Store file name in structure

sds_file_ID = HDF_SD_START(filename[0], /READ)												;Open file for reading
HDF_SD_FILEINFO, sds_file_ID, numSDS, numATT													;Get number of SD data sets

parameters= ['rrSurf', 'Longitude', 'Latitude', 'scLon', 'scLat', 'Year', 'Month', $
             'DayOfMonth', 'Hour', 'Minute', 'Second']
tag_names  = ['precip', 'lon', 'lat', 'scLon', 'scLat', 'year', 'month', 'day', 'hour', 'min', 'sec']

FOR i = 0, N_ELEMENTS(parameters)-1 DO BEGIN
  id     = HDF_SD_NAMETOINDEX(sds_file_ID, parameters[i])
  sds_id = HDF_SD_SELECT(sds_file_ID, id)
  HDF_SD_GETINFO, sds_id, NATTS=nAtts, NDIM=nDim, DIMS=dims		
  	
  scale = 1 & offset = 0 & missing = !Values.F_NaN & fill = !Values.F_NaN & range = 0
  FOR j = 0, nAtts-1 DO BEGIN
	  HDF_SD_AttrInfo, sds_id, j, NAME = attr_name, DATA = attr_data
		IF STRMATCH(attr_name, 'scale_factor', /FOLD_CASE) THEN scale   = attr_data[0]
		IF STRMATCH(attr_name, 'add_offset',   /FOLD_CASE) THEN offset  = attr_data[0]
		IF STRMATCH(attr_name, '*missing*',    /FOLD_CASE) THEN missing = attr_data[0]
		IF STRMATCH(attr_name, '_FillValue',   /FOLD_CASE) THEN fill    = attr_data[0]
		IF STRMATCH(attr_name, 'valid_range',  /FOLD_CASE) THEN range   = attr_data
	ENDFOR
	
	HDF_SD_GETDATA, sds_id, data
	IF (N_ELEMENTS(range) EQ 2) THEN BEGIN
    id = WHERE(data EQ missing  OR data EQ fill OR $
		           data LT range[0] OR data GT range[1] , CNT)
	ENDIF ELSE id = WHERE(data EQ missing OR data EQ fill, CNT)
	
	IF (CNT NE 0) THEN BEGIN
    IF TYPE(data) LT 4 THEN data = FLOAT(data)
		data[id] = !Values.F_NaN
	ENDIF
	id = WHERE(data LT -400, CNT)
	IF (CNT NE 0) THEN data[id] = !VALUES.F_NaN
	
	data = scale*(TEMPORARY(data) - offset)
	fdata = CREATE_STRUCT(fdata, tag_names[i], data)										;Add data to structure
ENDFOR
HDF_SD_END, sds_file_ID


RETURN, fdata																													;Return data structure

END