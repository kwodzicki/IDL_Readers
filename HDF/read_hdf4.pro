FUNCTION READ_HDF4, filename, VARIABLES=variables, CONVERT_LON = convert_lon

;+
; Name:
;		READ_HD4
; Purpose:
;		To read in a HDF 4 file. No data is scaled as scale factors, etc.
;   are read into data structure.
; Calling Sequence:
;		result = READ_HDF4(filename, PARAMETERS=variables)
; Inputs:
;		filename	: Name of file to read data in from.
; Outputs:
;		A structure containing all data, or data requested.
; Keywords:
;		VARIABLES 	: A string or string array containing the variables
;						to obtain from the file.
;   CONVERT_LON : Set to convert longitudes from 0-360 to -180-180 or
;                   vice versa based on the data being read.
; Author and History:
;		Kyle R. Wodzicki	Created 10 July 2015
;-

COMPILE_OPT IDL2																											; Set compile options

IF FILE_TEST(filename[0]) EQ 0 THEN $
  IF NOT STRMATCH(filename[0], '*http*', /FOLD_CASE) THEN $           ; Check if NOT URL
    MESSAGE, 'FILE NOT FOUND!'				                                ; Error if file NOT exist

;out_data = {filename: filename}																				; Store file name in structure
out_data = { }																				; Store file name in structure
splt     = '!@#$%^&*+=;:,./?()[]{}<>'
sds_file_ID = HDF_SD_START(filename[0], /READ)												; Open file for reading
HDF_SD_FILEINFO, sds_file_ID, numSDS, numATT													; Get number of SD data sets

;=== Get all data names from the file if no variables selected
IF (N_ELEMENTS(variables) EQ 0) THEN BEGIN
  variables = []
  FOR i = 0, numSDS - 1 DO BEGIN
    sds_id = HDF_SD_SELECT(sds_file_ID, i)
      HDF_SD_GETINFO, sds_id, NAME = name
      variables  = [variables, name]
    HDF_SD_ENDACCESS, sds_id
  ENDFOR
ENDIF

FOR i = 0, numSDS - 1 DO BEGIN																				; Iterate over all data sets
	sds_id = HDF_SD_SELECT(sds_file_ID, i)															; Select ith data entry
	HDF_SD_GETINFO, sds_id, NAME = name, NATTS = num_attributes, $      ; Get information about ith data entry
                  NDIM=num_dims, DIMS =dimvector

	FOR j = 0, N_ELEMENTS(variables)-1 DO BEGIN											  ; Iterate over all entries in variables
		tmp = {}                                                          ; Set up temporary array to store all data information
		IF ~STRMATCH(variables[j], name, /FOLD_CASE) THEN CONTINUE				; If current data set matches jth parameter
		HDF_SD_GETDATA, sds_id, data
		IF (name EQ 'LON')  AND KEYWORD_SET(convert_lon) THEN BEGIN       ; If data set is Longitude
		  IF (MIN(data, /NaN) LT 0) THEN BEGIN
			  index = WHERE(data LT 0, COUNT)															  ; Indicies of longitude < 0
			  IF (COUNT NE 0) THEN data[index]=data[index]+360						  ; If points exist, convert 0-360 range
			ENDIF ELSE BEGIN
			  index = WHERE(data GT 180, COUNT)															; Indicies of longitude < 0
			  IF (COUNT NE 0) THEN data[index]=data[index]-360						  ; If points exist, convert 0-360 range
			ENDELSE
		ENDIF

		FOR k = 0, num_Attributes-1 DO BEGIN
		  HDF_SD_AttrInfo, sds_id, k, NAME = attr_name, DATA = attr_data  ; Get kth attribute name and data
		  attr_name = STRJOIN( STRSPLIT(attr_name, splt, /EXTRACT), '_' )
		  IF (N_ELEMENTS(attr_data) EQ 1) THEN $
	      tmp = CREATE_STRUCT(tmp, attr_name, attr_data[0]) $           ; Append atributes to tmp data structure
	    ELSE $
	      tmp = CREATE_STRUCT(tmp, attr_name, attr_data)
		ENDFOR                                                            ; END k
    tmp  = CREATE_STRUCT(tmp, 'Values', data)                         ; Append actual data to tmp data structure

		;=== Filter out characters from tag name
		name = STRJOIN(STRSPLIT(name, ':', /EXTRACT), '_')                ; Skip variables with colon in the name
		name = STRJOIN(STRSPLIT(name, ' ', /EXTRACT), '_')
		name = STRJOIN(STRSPLIT(name, '.', /EXTRACT), '_')
		name = STRJOIN(STRSPLIT(name, '#', /EXTRACT), 'N')

		out_data = CREATE_STRUCT(out_data, name, tmp)											; Add data to structure
	ENDFOR                                                              ; END j
	HDF_SD_ENDACCESS, sds_id                                            ; End access to ith data set
ENDFOR                                                                ; END i
HDF_SD_END, sds_file_ID                                               ; Close the file

RETURN, out_data																										  ; Return data structure

END