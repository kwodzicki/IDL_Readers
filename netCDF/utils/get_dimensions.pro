FUNCTION GET_DIMENSIONS, iid
;+
; Name:
;		LOCAL_READ_NETCDF_GROUP
; Purpose:
;		An IDL function to read in all the data from a netCDF file. 
;   Split from main function because main function also loops over groups.
; Calling Sequence:
;		result = READ_netCDF_FILE('/path/to/file.nc')
; Inputs:
;		fname	: File name to read in. MUST BE FULL PATH
; Outputs:
;		A structure containing all the data form the file.
; Keywords:
;   DIMID       : Offset for dimensions within groups as dimensions in the
;                  netCDF file are still order from oldest (0) to newest (n-1)
;                  globally and not within groups
; Author and History:
;		Kyle R. Wodzicki	Created 21 Sep. 2017
;-
  COMPILE_OPT IDL2, HIDDEN

  dims   = HASH()
  dimIDs = NCDF_DIMIDSINQ( iid )
  IF dimIDs[0] EQ -1 THEN RETURN, dims
	FOR i = 0, N_ELEMENTS(dimIDs)-1 DO BEGIN
    NCDF_DIMINQ, iid, dimIDs[i], dimName, dimSize
    dims[ dimIDs[i] ] = {NAME  : dimName,   SIZE : dimSize}
    dims[ dimName   ] = {ID    : dimIDs[i], SIZE : dimSize}
	ENDFOR

  RETURN, dims

END
