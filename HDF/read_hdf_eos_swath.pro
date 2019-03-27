FUNCTION READ_HDF_EOS_SWATH, fileName 

;+
; Name:
;		READ_HDF_EOS_SWATH
; Purpose:
;		A function to read in all data from a HDF-EOS file and
;   and return the data as a structure. All global attributes, 
;   dimensions, fields and geo-fields are read into a sub-structures
;   that contain all attributes
; Calling Sequence:
;		Result = READ_HDF_EOS_SWATH('Path_To_File')
; Inputs:
;		fileName	: The full path to the HDF-EOS swath file
;	Outputs:
;		None.
; Keywords:
;		None.
; Author and History:
;		Kyle R. Wodzicki		Created 08 Sep. 2015
;-

COMPILE_OPT IDL2        																							;Set compile options

IF (NOT FILE_TEST(fileName)) THEN MESSAGE, 'NO FILE FOUND!'						;Check that file exits

all_data = {}
splt     = '!@#$%^&*+=;:,./?()[]{}<>'
;=====================================================================
;		GET GRIDDING INFORMATION FROM A GRIDDED TRMM FILE
file_ID	    = EOS_SW_OPEN(fileName, /READ)													  ; Open the HDF-EOS swath file for reading
nflds       = EOS_SW_INQSWATH(filename, swathlist, LENGTH=length)     ; Get the number of swaths in the file

FOR i = 0, nflds-1 DO BEGIN                                           ; Iterate over all the swaths in the file
  status  = EOS_SW_QUERY(Filename, swathlist[i], swath_info)          ; Get information about the ith swath
  IF (status EQ 0) THEN BEGIN                                         ; If no data in swath, print message and continue
    MESSAGE, 'NO swath information!!!', /CONTINUE 
    CONTINUE
  ENDIF
  swath_data = {}                                                     ; Initialize structure for ith swath data
  
  swathID = EOS_SW_ATTACH(file_id, swathlist[i])                      ; Attach the ith swath
  ;=== Read in global attributes
  att_names = STRSPLIT(swath_info.ATTRIBUTES, ',', /EXTRACT)          ; Split attribute names on comma
  IF (N_ELEMENTS(att_names) GT 0) THEN BEGIN                          ; If attributes are found
    global_atts = {}                                                  ; Initialize global attribute structure
    field_att_names = LIST()                                          ; Initialize field attribute name array
    id = WHERE(STRMATCH(att_names, '*.*'), CNT, $                     ; Find only global and field attributes
      COMPLEMENT=cID, NCOMPLEMENT=cCNT)                       
    FOR j = 0, cCNT-1 DO BEGIN                                        ; Iterate over all attributes WITHOUT a period in the name
      status = EOS_SW_READATTR(swathID, att_names[cid[j]], datbuf)
      IF (status EQ 0) THEN $
        global_atts = CREATE_STRUCT(global_atts, att_names[cid[j]], datbuf)
    ENDFOR
    FOR j = 0, CNT-1 DO field_att_names.ADD, att_names[id[j]]         ; Store all field attribute names
  ENDIF
  IF (N_ELEMENTS(global_atts) GT 0) THEN $
    swath_data = CREATE_STRUCT(swath_data, 'GLOBAL_ATTRIBUTES', global_atts)
  field_att_names = field_att_names.ToArray()                         ; Convert field attribute names to array
  
  ;=== Read in dimension data
  dim_names = STRSPLIT(swath_info.DIMENSION_NAMES, ',', /EXTRACT)
  IF (N_ELEMENTS(dim_names) GT 0) THEN BEGIN
    dims = {}
    FOR j = 0, N_ELEMENTS(dim_names)-1 DO BEGIN
    	CATCH, Error_status
    	IF Error_status NE 0 THEN BEGIN
    	  dim_names[j] = '_' + dim_names[j]
    	  CATCH, /CANCEL
    	ENDIF
  		name = STRJOIN( STRSPLIT(dim_names[j], splt, /EXTRACT), '_' )
      dims = CREATE_STRUCT(dims, name, swath_info.DIMENSION_SIZES[j])
    ENDFOR
  ENDIF
  swath_data = CREATE_STRUCT(swath_data, 'DIMENSIONS', dims)
  
  ;=== Read in field data
  field_names = STRSPLIT(swath_info.FIELD_NAMES, ',', /EXTRACT)       ; Split field names on comma
  IF (N_ELEMENTS(field_names) GT 0) THEN BEGIN                        ; Split fields are found
    all_fields = {}                                                   ; Initialize all fields structure
    FOR j = 0, N_ELEMENTS(field_names)-1 DO BEGIN                     ; Iterate over all fields
      field = {}                                                      ; Initialize structure for jth field
      status = EOS_SW_READFIELD(swathID, field_names[j], datbuf)      ; Read in the field data
      IF (status EQ 0) THEN $                                         ; Append values to jth field structure
        field = CREATE_STRUCT(field, 'values', datbuf)
      IF (N_ELEMENTS(field_att_names) GT 0) THEN BEGIN
				id = WHERE(STRMATCH(field_att_names, field_names[j]+'*', /FOLD_CASE), CNT) ; Find attribute names that contain the field name
				FOR k = 0, CNT-1 DO BEGIN                                       ; Iterate over all field attributes
					status = EOS_SW_READATTR(swathID, field_att_names[id[k]], datbuf); Read in the kth field attribute
					IF (status EQ 0) THEN BEGIN
						field_att = STRSPLIT(field_att_names[id[k]], '.', /EXTRACT) ; Split the attribute name on period
						field = CREATE_STRUCT(field, field_att[-1], datbuf)         ; Append attribute to jth field structure using string following period as tag name 
					ENDIF
				ENDFOR
      ENDIF
      all_fields = CREATE_STRUCT(all_fields, field_names[j], field)
    ENDFOR
  ENDIF
  swath_data = CREATE_STRUCT(swath_data, 'FIELDS', all_fields)
  
  ;=== Read in geo field data
  field_names = STRSPLIT(swath_info.GEO_FIELD_NAMES, ',', /EXTRACT)   ; Split field names on comma
  IF (N_ELEMENTS(field_names) GT 0) THEN BEGIN                        ; Split fields are found
    all_fields = {}                                                   ; Initialize all fields structure
    FOR j = 0, N_ELEMENTS(field_names)-1 DO BEGIN                     ; Iterate over all fields
      field = {}                                                      ; Initialize structure for jth field
      status = EOS_SW_READFIELD(swathID, field_names[j], datbuf)      ; Read in the field data
      IF (status EQ 0) THEN $                                         ; Append values to jth field structure
        field = CREATE_STRUCT(field, 'values', datbuf)
      IF (N_ELEMENTS(field_att_names) GT 0) THEN BEGIN
				id = WHERE(STRMATCH(field_att_names, field_names[j]+'*', /FOLD_CASE), CNT) ; Find attribute names that contain the field name
				FOR k = 0, CNT-1 DO BEGIN                                       ; Iterate over all field attributes
					status = EOS_SW_READATTR(swathID, field_att_names[id[k]], datbuf); Read in the kth field attribute
					IF (status EQ 0) THEN BEGIN
						field_att = STRSPLIT(field_att_names[id[k]], '.', /EXTRACT) ; Split the attribute name on period
						field = CREATE_STRUCT(field, field_att[-1], datbuf)         ; Append attribute to jth field structure using string following period as tag name 
					ENDIF
				ENDFOR
      ENDIF
      all_fields = CREATE_STRUCT(all_fields, field_names[j], field)
    ENDFOR
  ENDIF
  swath_data = CREATE_STRUCT(swath_data, 'GEO_FIELDS', all_fields)
  
  status = EOS_SW_DETACH(swathID)                                     ; Detach the ith swath
  IF (status EQ -1) THEN $                                            ; Message IF detach FAILED
    MESSAGE, 'Swath detach of '+swathlist[i]+ ' FAILED!!!', /CONTINUE
  
  tag_name = 'Swath_'+STRJOIN(STRSPLIT(swathlist[i], '-.', /EXTRACT), '_'); Create tag name for swath
  all_data = CREATE_STRUCT(all_data, tag_name, swath_data)            ; Append swath to all_data structure
ENDFOR
status = EOS_SW_CLOSE(file_ID)                                        ; Close the EOS Swath file
IF (status EQ -1) THEN $                                              ; Message IF detach FAILED
    MESSAGE, 'Swath close of '+swathlist[i]+ ' FAILED!!!', /CONTINUE
    
RETURN, all_data                                                      ; Return all the data
END