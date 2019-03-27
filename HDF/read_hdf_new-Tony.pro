FUNCTION READ_HDF_NEW, filename, PARAMETERS=parameters, VDATA=vdata, ADD_FILENAME=add_filename

;+
; Name:
;		READ_HDF_NEW
; Purpose:
;		To read in a HDF file.
; Calling Sequence:
;		result = READ_HDF_NEW(filename, PARAMETERS=parameters)
; Inputs:
;		filename   : Name of file to read data in from.
; Outputs:
;		A structure containing all data, or data requested.
; Keywords:
;		PARAMETERS : A string or string array containing the parameters
;						to obtain from the file.
;		VDATA      : If set, VData will be read and included in the output structure. 				
; Author and History:
;		Kyle R. Wodzicki	Created 03 July 2014 - Function is based off of
;													Chuntao's READ_PF_LEVEL2_HDF
;													procedure. There was also 
;													trouble with one element
;													string arrays for file name
;													and was fixed with filename[0].
;													
;		Tony Viramontez   Modified 03 June 2015 - Added support for HDF5 files.
;		
;		Tony Viramontez   Modified 07 September 2015 - Added the ability to read VData 
;											                             through use of an additional keyword.  
;                                                  Note - This does not currently work with 
;                                                  HDF5 files. 
;   
;   Tony Viramontez   Modified 29 September 2015 - Added keyword ADD_FILENAME to fix an issue 
;                                                  with multiple datasets including a filename string
;                                                  that would cause the program to return an error. Improved   
;                                                  support for multiple datasets within H5 files.                                                
;- 

COMPILE_OPT IDL2																											;Set compile options

H5_CLOSE

IF FILE_TEST(filename[0]) EQ 0 THEN MESSAGE, 'FILE NOT FOUND!'				;Error if file NOT exist

ishdf5 = H5F_IS_HDF5(filename[0])                                     ;Returns 1 if the file is an HDF5 file

IF ishdf5 EQ 0 THEN BEGIN
  
  fdata = {}
  IF n_elements(add_filename) GT 0 THEN fdata = {filename: filename}																					;Store file name in structure

  sds_file_ID = HDF_SD_START(filename[0], /READ)												;Open file for reading
  HDF_SD_FILEINFO, sds_file_ID, numSDS, numATT													;Get number of SD data sets

  data_names = []

  FOR i = 0, numSDS - 1 DO BEGIN
    sds_id = HDF_SD_SELECT(sds_file_ID, i)
      HDF_SD_GETINFO, sds_id, NAME = name	
      data_names  = [data_names, name]
      HDF_SD_ENDACCESS, sds_id
  ENDFOR

  IF (N_ELEMENTS(parameters) EQ 0) THEN parameters = data_names
  
  FOR i = 0, numSDS - 1 DO BEGIN																				;Iterate over all data sets
  	sds_id = HDF_SD_SELECT(sds_file_ID, i)															;Select ith data entry
  	HDF_SD_GETINFO, sds_id, NAME = name, NATTS = num_attributes, $ 
                    NDIM=num_dims, DIMS =dimvector																;Get the name of the data set
  	IF STRMATCH(name, '*:*') THEN CONTINUE
  	
  	FOR j = 0, N_ELEMENTS(parameters)-1 DO BEGIN											;Iterate over all entries in parameters
  		IF ~STRMATCH(parameters[j], name, /FOLD_CASE) THEN CONTINUE					;If current data set matches jth parameter
  		HDF_SD_GETDATA, sds_id, data
  		IF (name EQ 'LON') THEN BEGIN																	;If data set is Longitude
  			index = WHERE(data LT 0, COUNT)															;Indicies of longitude < 0
  			IF (COUNT NE 0) THEN data[index]=data[index]+360						;If points exist, convert 0-360 range
  		ENDIF
  		
  		scale = 1 & offset = 0 & missing = !Values.F_NaN & fill = !Values.F_NaN & range = 0
  		
  		FOR k = 0, num_Attributes-1 DO BEGIN
  		  HDF_SD_AttrInfo, sds_id, k, NAME = attr_name, DATA = attr_data
  		  IF STRMATCH(attr_name, 'scale_factor', /FOLD_CASE) THEN scale   = attr_data[0]
  		  IF STRMATCH(attr_name, 'add_offset',   /FOLD_CASE) THEN offset  = attr_data[0]
  		  IF STRMATCH(attr_name, '*missing*',    /FOLD_CASE) THEN missing = attr_data[0]
  		  IF STRMATCH(attr_name, '_FillValue',   /FOLD_CASE) THEN fill    = attr_data[0]
  		  IF STRMATCH(attr_name, 'valid_range',  /FOLD_CASE) THEN range   = attr_data
  		ENDFOR
  
  		IF (N_ELEMENTS(range) EQ 2) THEN BEGIN
  		  id = WHERE(data EQ missing  OR data EQ fill OR $
  		             data LT range[0] OR data GT range[1] , CNT)
  		ENDIF ELSE id = WHERE(data EQ missing OR data EQ fill, CNT)
  		
  		IF (CNT NE 0) THEN BEGIN
  		  IF SIZE(data, /TYPE) LT 4 THEN data = FLOAT(data)
  		  data[id] = !Values.F_NaN
  		ENDIF
  		
  		data = scale*(TEMPORARY(data) - offset)
  		name = STRJOIN(STRSPLIT(name, ' ', /EXTRACT), '_')
  		name = STRJOIN(STRSPLIT(name, '.', /EXTRACT), '_')
  		name = STRJOIN(STRSPLIT(name, '#', /EXTRACT), 'N')
  		fdata = CREATE_STRUCT(fdata, name, data)											;Add data to structure
  		
  	ENDFOR
  	HDF_SD_ENDACCESS, sds_id
  ENDFOR
  HDF_SD_END, sds_file_ID
  
  IF KEYWORD_SET(VDATA) THEN BEGIN
    result = READ_HDF_VDATA(filename[0])
    new = CREATE_STRUCT(fdata, result)
    RETURN, new
  ENDIF ELSE RETURN, fdata																													;Return data structure

ENDIF


IF ishdf5 EQ 1 THEN BEGIN
  
  fdata = {}
  IF n_elements(add_filename) GT 0 THEN fdata = {filename: filename}                                ;Store file name in structure
  sds_file_ID = H5F_OPEN(filename[0])                         ;Open file for reading
  
  version = !VERSION     ;Check idl version

  IF version.release GE 8.3 THEN BEGIN                        ;If IDL version is 8.3 or higher..
    H5_LIST, filename, OUTPUT=output                          ;returns a string array (named output) including all datasets within file
    dataset_names = output[1,1:*]
  ENDIF ELSE BEGIN                                            ;If IDL version is less than 8.3..
    output = H5_PARSE(filename)
    dataset_names = [OUTPUT.(6)._PATH + OUTPUT.(6)._NAME]
    tag_names = tag_names(output)
    id = WHERE(strmid(tag_names, 0,1) NE '_', cnt)
    IF cnt GE 1 THEN BEGIN
    ;  print, 'Multiple Datasets Found'
      dataset_names = strarr(n_elements(id))
      FOR i = 0, n_elements(id) - 1 DO BEGIN
        num = id[i]
        dataset_names[i] = [OUTPUT.(num)._PATH + OUTPUT.(num)._NAME]
      ENDFOR    
    ENDIF
  ENDELSE
    
  IF (N_ELEMENTS(parameters) EQ 0) THEN parameters = dataset_names
  numDS = n_elements(dataset_names)
  
  FOR i = 0, numDS - 1 DO BEGIN                                        ;Iterate over all data sets
    dataset_id = H5D_OPEN(sds_file_id, dataset_names[i])               ;Find dataset id for file
    num_Attributes = H5A_GET_NUM_ATTRS(dataset_id)                     ;Find the number of attributes in dataset 
    
    IF STRMATCH(dataset_names[i], '*:*') THEN CONTINUE

    FOR j = 0, N_ELEMENTS(parameters)-1 DO BEGIN                      ;Iterate over all entries in parameters
      IF ~STRMATCH(parameters[j], dataset_names[i], /FOLD_CASE) THEN CONTINUE         ;If current data set matches jth parameter
        data = H5D_READ(dataset_id) 
    
      ;Note - Had to remove longitude transformation

      scale = 1 & offset = 0 & missing = !Values.F_NaN & fill = !Values.F_NaN & range = 0

      FOR k = 0, num_Attributes-1 DO BEGIN
        attr_id = H5A_OPEN_IDX(dataset_id, k)
        attr_data = H5A_READ(attr_id)
        attr_name = H5A_GET_NAME(attr_id)
        IF STRMATCH(attr_name, 'scale_factor', /FOLD_CASE) THEN scale   = attr_data[0]
        IF STRMATCH(attr_name, 'add_offset',   /FOLD_CASE) THEN offset  = attr_data[0]
        IF STRMATCH(attr_name, '*missing*',    /FOLD_CASE) THEN missing = attr_data[0]
        IF STRMATCH(attr_name, '_FillValue',   /FOLD_CASE) THEN fill    = attr_data[0]
        IF STRMATCH(attr_name, 'valid_range',  /FOLD_CASE) THEN range   = attr_data
      ENDFOR

      code = SIZE(data, /TYPE) ;Find data type.. structure eq 8
      
      IF (N_ELEMENTS(range) EQ 2) THEN BEGIN
        id = WHERE(data EQ missing  OR data EQ fill OR $
          data LT range[0] OR data GT range[1] , CNT)
      ENDIF
      
      IF (N_ELEMENTS(range) NE 2) AND (code NE 8) THEN BEGIN
       id = WHERE(data EQ missing OR data EQ fill, CNT)
      ENDIF
      
      IF (code NE 8) THEN BEGIN      
        IF (CNT NE 0) THEN BEGIN
          IF SIZE(data, /TYPE) LT 4 THEN data = FLOAT(data)
          data[id] = !Values.F_NaN
        ENDIF
  
        IF (code NE 8) THEN BEGIN
          data = scale*(TEMPORARY(data) - offset)
        ENDIF
        
        ;Remove illegal or unwanted characters from dataset name
        dataset_names[i] = STRJOIN(STRSPLIT(dataset_names[i], ' ', /EXTRACT), '_')
        dataset_names[i] = STRJOIN(STRSPLIT(dataset_names[i], '.', /EXTRACT), '_')
        dataset_names[i] = STRJOIN(STRSPLIT(dataset_names[i], '-', /EXTRACT), '_')
        dataset_names[i] = STRJOIN(STRSPLIT(dataset_names[i], '/', /EXTRACT))
        dataset_names[i] = STRJOIN(STRSPLIT(dataset_names[i], '(', /EXTRACT), '_')
        dataset_names[i] = STRJOIN(STRSPLIT(dataset_names[i], ')', /EXTRACT), '_')
        dataset_names[i] = STRJOIN(STRSPLIT(dataset_names[i], '+', /EXTRACT), '_')
        dataset_names[i] = STRJOIN(STRSPLIT(dataset_names[i], '#', /EXTRACT), 'N')
                
        IF (STRMID(dataset_names[i], 0 , 1) EQ '0') OR (STRMID(dataset_names[i], 0 , 1) EQ '1') OR $
           (STRMID(dataset_names[i], 0 , 1) EQ '2') OR (STRMID(dataset_names[i], 0 , 1) EQ '3') OR $
           (STRMID(dataset_names[i], 0 , 1) EQ '4') OR (STRMID(dataset_names[i], 0 , 1) EQ  '5') OR $
           (STRMID(dataset_names[i], 0 , 1) EQ '6') OR (STRMID(dataset_names[i], 0 , 1) EQ '7') OR $
           (STRMID(dataset_names[i], 0 , 1) EQ '8') OR (STRMID(dataset_names[i], 0 , 1) EQ '9') $
        THEN dataset_names[i] = '_' + dataset_names[i]
              
        fdata = CREATE_STRUCT(fdata, dataset_names[i], data)                      ;Add data to structure  
      ENDIF

      IF (code EQ 8) THEN BEGIN 
        fdata = create_struct(fdata, data)
        ;fdata = data
      ENDIF
     
    ENDFOR
    
  ENDFOR
  
  RETURN, fdata                                                         ;Return data structure

ENDIF

H5_CLOSE

END