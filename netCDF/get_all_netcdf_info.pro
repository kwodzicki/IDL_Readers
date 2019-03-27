FUNCTION GET_ALL_netCDF_INFO, filename
;+
; Name:
;   GET_ALL_netCDF_INFO
; Purpose:
;   A function to get all information, including attributes,
;   from all variables in netCDF file(s).
; Inputs:
;   filename  : A string or array of strings that specifying the 
;               path to files to get information from.
; Outputs:
;   Returns a structure.
; Keywords:
;   None.
; Author and History:
;   Kyle R. Wodzicki     Created 17 Feb. 2016
;-
COMPILE_OPT IDL2

IF (N_PARAMS() NE 1) THEN MESSAGE, 'Incorrect number of inputs!'
out_data = {}                                                         ; Initialize output structure
FOR i = 0, N_ELEMENTS(filename)-1 DO BEGIN
  iid = NCDF_OPEN(filename[i])                                        ; Open the ith file
    iid_info = NCDF_INQUIRE(iid)                                      ; Inquire the ith file
    dim_info = {}                                                     ; Initialize structure to store dimension information
    FOR j = 0, iid_info.NDIMS-1 DO BEGIN                              ; Add all dimension information to the dim_info structure
      NCDF_DIMINQ, iid, j, name, data
      dim_info = CREATE_STRUCT(dim_info, '_'+STRTRIM(j,2), {NAME : name, SIZE : data})
    ENDFOR
    iid_info = CREATE_STRUCT(iid_info, 'DIMENSIONS', dim_info)        ; Append dimension info structure to iid_info structure
    all_vars = {}                                                     ; Initialize structure to store all variable data in
    FOR j = 0, iid_info.NVARS-1 DO BEGIN                              ; Iterate over all variables
      var_info = NCDF_VARINQ(iid, j)                                  ; Get information about the variable
      all_atts = {}                                                   ; Initialize structure to store all attribute information in
      FOR k = 0, var_info.NATTS-1 DO BEGIN                            ; Iterate over all variable attributes
        name = NCDF_ATTNAME(iid, j, k)                                ; Get name of kth attribute in jth variable
        att_info = NCDF_ATTINQ(iid, j, name)                          ; Get information about kth attribute in jth variable
        NCDF_ATTGET, iid, j, name, data                               ; Get the data from the kth attribute in jth variable
        IF (att_info.DataType EQ 'CHAR') THEN data = STRING(data)     ; Convert data to type string if netCDF type CHAR
        all_atts = CREATE_STRUCT(all_atts, '_'+STRTRIM(k,2), $        ; Append kth attribute in jth variable to all_atts structure
          {NAME : name, VALUES : data})
      ENDFOR                                                          ; END k
      var_info = CREATE_STRUCT(var_info, 'ATTS', all_atts)            ; Append attribute info to variable info
      all_vars = CREATE_STRUCT(all_vars, '_'+STRTRIM(j,2), var_info)  ; Append var_info structure to all_vars structure
  ENDFOR                                                              ; END j
  NCDF_CLOSE, iid                                                     ; Close the netCDF file
  iid_info = CREATE_STRUCT(iid_info, 'VARS', all_vars)                ; Append all variable info to iid_info
  out_data = CREATE_STRUCT(out_data, '_'+STRTRIM(i,2), iid_info)      ; Append all information from ith file to out_data structure
ENDFOR                                                                ; END i
RETURN, out_data                                                      ; Return the information
END