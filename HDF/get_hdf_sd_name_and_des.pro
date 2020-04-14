FUNCTION GET_HDF_SD_NAME_AND_DES, file 
;+
; Name:
;   GET_HDF_SD_NAME_AND_DES
; Purpose:
;   A function to iterate through all SD data in a HDF file and 
;   return a structure that contains the name and attributes of
;   of each data set.
; Inputs:
;   file : The full path to the file to parse.
; Outputs:
;   None.
; Keywords:
;   None.
; Author and History:
;   Kyle R. Wodzicki     Created 07 Aug. 2015
;-
	COMPILE_OPT IDL2
	all_info = {}
	sds_file_id = HDF_SD_START(file, /READ) 
		HDF_SD_FILEINFO, sds_file_id, numsds, numatt
		FOR i = 0, numsds - 1 DO BEGIN																			;Iterate to find data we want
			sds_id = HDF_SD_SELECT(sds_file_id, i)														;Select the SD data set for reading (k value)
				HDF_SD_GETINFO, sds_id, NAME=name, NATTS=natts, LABEL=label, $	;Get all info for variable
												HDF_TYPE=hdf_type, NDIMS=ndims
				hdf_typeCode = HDF_TYPE2CODE(HDF_TYPE2CODE(hdf_type))     			 ;Get data type code
				sd_info = {NAME : name, DATA_TYPE : hdf_typeCode, N_DIMS : ndims}
				FOR j = 0, natts-1 DO BEGIN
					HDF_SD_ATTRINFO, sds_id, j, DATA=data, NAME=att_name
					sd_info = CREATE_STRUCT(sd_info, att_name, data)
				ENDFOR
			HDF_SD_ENDACCESS, sds_id
			all_info = CREATE_STRUCT(all_info, '_'+STRTRIM(i,2), sd_info)
		ENDFOR
	HDF_SD_END, sds_file_id																							;Close ORIGINAL SD file	
	RETURN, all_info
END