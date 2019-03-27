FUNCTION READ_HDF5, filename, VARIABLES = variables
;+
; Name:
;   READ_GPM_HDF5
; Purpose:
;   A function to read in and return data from a HDF5 file.
;   Function returns -1 on error.
; Inputs;
;   filename
; Outputs:
;   None.
; Keywords:
;   VARIABLES   : String or string array of variables to read in
;                  from file.
; Author and History:
;   Kyle R. Wodzicki     Created 10 June 2015
;
; Note: Not exhaustively tested for bugs and does NOT apply
;       scaling factors or add offsets yet!!!
;-
COMPILE_OPT IDL2

IF (H5F_IS_HDF5(filename) EQ 0) THEN BEGIN
  MESSAGE, 'Requested file is NOT HDF5 format!', /CONTINUE
  RETURN, -1
ENDIF

file_id = H5F_OPEN(filename)                                          ; Open the HDF5 file

H5_LIST, filename, OUTPUT=var_list                                    ; Get list of all datasets, groups, etc. in file
var_list = REFORM(var_list[1,1:*])                                    ; Filter var_list to only variable names
  
;print, var_list
;STOP
IF (N_ELEMENTS(variables) NE 0) THEN BEGIN                            ; If variables keyword has data in it
  requested_var_ids = []                                              ; Initialize empty array for indices of matching variable names
  FOR i = 0, N_ELEMENTS(variables)-1 DO BEGIN                         ; Iterate over all variable names input by user
    id = WHERE(STRMATCH(FILE_BASENAME(var_list), variables[i], $      ; Find where variable names match
               /FOLD_CASE), CNT)
    IF (CNT NE 0) THEN requested_var_ids = [requested_var_ids, id]    ; Append indices to list of all indices
  ENDFOR                                                              ; END i
  IF (N_ELEMENTS(requested_var_ids) NE 0) THEN BEGIN                  ; If indices found for matches
    var_list = var_list[requested_var_ids]
  ENDIF ELSE BEGIN                                                    ; If NO indices found for matches
    MESSAGE, 'Variable(s) requested NOT found, returning all data!', $
      /CONTINUE
  ENDELSE
ENDIF 


FOR i = 0, N_ELEMENTS(var_list)-1 DO BEGIN                            ; Iterate over var_list to determine paths to data sets
  obj_info = H5G_GET_OBJINFO(file_id, var_list[i])                    ; Get information about the ith object
  IF ( obj_info.TYPE NE 'DATASET' ) THEN var_list[i] = ''             ; If the object is NOT a dataset, write empty string
ENDFOR                                                                ; END i

id = WHERE(STRMATCH(var_list, '') EQ 0, CNT)                          ; Find all strings that are NOT empty
IF (CNT NE 0) THEN var_list = var_list[id]                            ; Take only NOT empty strings

out_data   = {}                                                       ; Initialize structure to store data

FOR i = 0, N_ELEMENTS(var_list)-1 DO BEGIN                            ; Iterate over var_list to read in
	tmp_data  = {}                                                      ; Initialize empty structure for ith data
	data_id   = H5D_OPEN(file_id, var_list[i])                          ; Open the ith dataset for reading
	data_size = H5D_GET_STORAGE_SIZE(data_id)
	IF (data_size EQ 0) THEN BEGIN
	  H5D_CLOSE, data_id
	  H5F_CLOSE, file_id
	  RETURN, {FAIL : -1}                                               ; If no data, close file and return
	ENDIF
	
	data      = H5D_READ(data_id)                                       ; Read in the ith dataset
	nAtts     = H5A_GET_NUM_ATTRS(data_id)                              ; Get the number of attributes in the ith data set

	n = 0                                                               ; Number to add to attribute names if error is thrown
	FOR j = 0, nAtts-1 DO BEGIN                                         ; Iterate over the attributes in ith dataset
		att_id = H5A_OPEN_IDX(data_id, j)                                 ; Open the jth attribute
			att_name = H5A_GET_NAME(att_id)                                 ; Get the name of the jth attribute
			att_data = H5A_READ(att_id)
			IF STRMATCH(att_name, '*missing*', /FOLD_CASE) THEN BEGIN       ; If attribute name contains missing
				att_data = FIX(att_data)
				id = WHERE(data EQ att_data, CNT)                             ; Find indices of data that may be missing
				IF (CNT NE 0) THEN BEGIN
				  IF (SIZE(data, /TYPE) LE 3) THEN data = FLOAT(data)         ; Conver to float if integer
				  data[id] = !VALUES.F_NaN                                    ; Replace with NaN characters
			  ENDIF
			ENDIF
		H5A_CLOSE, att_id                                                 ; Close the jth attribute
		
		CATCH, Error_status
		IF Error_status NE 0 THEN BEGIN
			n += 1
			att_name += STRTRIM(n,2)
			CATCH, /CANCEL
		ENDIF
		
		tmp_data = CREATE_STRUCT(tmp_data, att_name, att_data)
		n = 0                                                             ; Number to add to attribute names if error is thrown
	ENDFOR                                                              ; END j
	H5D_CLOSE, data_id                                                  ; CLose the ith data set
 	tmp_data = CREATE_STRUCT(tmp_data, 'VALUES', data)
	tag = STRJOIN(STRSPLIT(var_list[i], '/', /EXTRACT), '_')            ; Replace all '/' in new tag with '_'
;	IF (STRLEN(tag) GT 10) THEN tag = 'Data_'+STRTRIM(i,2)
	IF STRMATCH(tag[0], '[0-9]') THEN tag = '_'+tag
	out_data = CREATE_STRUCT(out_data, tag, tmp_data)                   ; Append data to structure
ENDFOR                                                                ; END i

H5F_CLOSE, file_id                                                    ; Close the HDF5 file

RETURN, out_data                                                      ; Return the data
END