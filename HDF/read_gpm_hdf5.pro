FUNCTION READ_GPM_HDF5, filename
;+
; Name:
;   READ_GPM_HDF5
; Purpose:
;   A function to read in and return data from a GPM HDF5 file.
; Inputs;
;   filename
; Outputs:
;   None.
; Keywords:
;   PARAMETERS   : String or string array of variables to read in
;                  from file.
; Author and History:
;   Kyle R. Wodzicki     Created 21 Apr. 2015
;-
COMPILE_OPT IDL2

parameters = 'MS/' + ['surfPrecipTotRate', 'Longitude', 'Latitude']
nav_parms  = 'MS/navigation/' + ['scLon', 'scLat']
time_parms = 'MS/ScanTime/' + ['Year', 'Month', 'DayOfMonth', 'Hour', 'Minute', 'Second']
parameters = [parameters, nav_parms, time_parms]
tag_names  = ['precip', 'lon', 'lat', 'scLon', 'scLat', 'year', 'month', 'day', 'hour', 'min', 'sec']
out_data   = {}

file_id = H5F_OPEN(filename)                                          ; Open HDF5 file for reading

FOR i = 0, N_ELEMENTS(parameters)-1 DO BEGIN                          ; Iterate over parameters to read in
	data_id   = H5D_OPEN(file_id, parameters[i])                        ; Open the ith dataset for reading
	data_size = H5D_GET_STORAGE_SIZE(data_id)
	IF (data_size EQ 0) THEN BEGIN
	  H5D_CLOSE, data_id
	  H5F_CLOSE, file_id
	  RETURN, {FAIL : -1}                                               ; If no data, close file and return
	ENDIF
	
	data      = H5D_READ(data_id)                                       ; Read in the ith dataset
	nAtts     = H5A_GET_NUM_ATTRS(data_id)                              ; Get the number of attributes in the ith data set

	FOR j = 0, nAtts-1 DO BEGIN                                         ; Iterate over the attributes in ith dataset
		att_id = H5A_OPEN_IDX(data_id, j)                                 ; Open the jth attribute
			att_name = H5A_GET_NAME(att_id)                                 ; Get the name of the jth attribute
			IF STRMATCH(att_name, '*missing*', /FOLD_CASE) THEN BEGIN       ; If attribute name contains missing
				missing = H5A_READ(att_id)                                    ; Read in the missing value
				id = WHERE(data EQ missing, CNT)                              ; Find indices of data that may be missing
				IF (CNT NE 0) THEN data[id] = !VALUES.F_NaN                   ; Replace with NaN characters
			ENDIF
		H5A_CLOSE, att_id                                                 ; Close the jth attribute
	ENDFOR                                                              ; END j
	H5D_CLOSE, data_id                                                  ; CLose the ith data set
	out_data = CREATE_STRUCT(out_data, tag_names[i], data)              ; Append data to structure
ENDFOR                                                                ; END i

H5F_CLOSE, file_id                                                    ; Close the HDF5 file

RETURN, out_data                                                      ; Return the data
END