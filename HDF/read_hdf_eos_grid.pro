FUNCTION READ_HDF_EOS_GRID, fname, VARIABLES = variables
;+
; Name:
;   READ_HDF_EOS_GRID
; Purpose:
;   A function for readin in HDF-EOS files.
; Inputs:
;   fname  : Full path to the file to read in.
; Outputs:
;   Returns a structure of the data
; Keywords:
;   VARIABLES  : String or string array of variables to read in.
; Author and History:
;   Kyle R. Wodzicki     Created 29 Sep. 2016
;-
COMPILE_OPT IDL2

IF (N_PARAMS() NE 1) THEN MESSAGE, 'Incorrect number of inputs!'								; Error if no file input

gid    = EOS_GD_OPEN(fname)                                                     ; Open the file
status = EOS_EH_GETVERSION(gid, version)                                        ; Check if it is an EOS file

IF status EQ -1 THEN BEGIN                                                      ; If NOT an EOS file
  MESSAGE, 'Input file is not an EOS file!', /CONTINUE                          ; Print a message
  status = EOS_SW_CLOSE(gid)                                                    ; Close the file
  IF status NE 0 THEN MESSAGE, 'Failed to close the file', /CONTINUE            ; If failed to close file, print message
  RETURN, {}                                                                    ; Return empty structure
ENDIF

;=== Get Grid information
grid = {}
ngrid = EOS_GD_INQGRID(fname, gridlist)                                         ; Get the number of grids in the file
IF ngrid EQ 0 THEN BEGIN																												; If there are no grids found
  MESSAGE, 'No grids found in file!', /CONTINUE																	; Print and error message
  RETURN, {}																																		; Return empty structure
ENDIF

FOR i = 0, N_ELEMENTS(gridlist)-1 DO BEGIN                                      ; Iterate over the list of grids in the file
  status = EOS_GD_QUERY(fname, gridlist[i], info)                               ; Get information about the specified grid
  IF status EQ 1 THEN BEGIN
    tmp = {GRID_INFO : info}																										; Store the grid information in a new structure
    field_names = STRSPLIT(info.FIELD_NAMES, ',', /EXTRACT)											; Get field names for the grid
   	IF N_ELEMENTS(variables) NE 0 THEN BEGIN																		; If Variables keyword is set
   		tmp_fields = []
   		FOR j = 0, N_ELEMENTS(variables)-1 DO $
   		  IF TOTAL(STRMATCH(field_names,variables[j],/FOLD_CASE),/INT) EQ 1 THEN $
   		  	tmp_fields = [tmp_fields, variables[j]]
   	ENDIF
   	gridID   = EOS_GD_ATTACH(gid, gridlist[i])																		; Attach the ith grid from the grid list
    fields   = {}																	; Create new empty array for all the fields
;    status   = EOS_GD_INQATTRS(gridID, gridAtts);
;    PRINT, status
;    gridAtts = STRSPLIT(gridAtts, ',', /EXTRACT)
;    print, gridAtts
  	FOR j = 0, N_ELEMENTS(field_names)/10 DO BEGIN															; Iterate over all the field names
  		status = EOS_GD_READFIELD(gridID, field_names[j], data)										; Read in data from the jth field in the ith grid
  		IF status EQ 0 THEN $																											; Check that data is read in
  			fields = CREATE_STRUCT(fields, field_names[j], data) $									; Append the data to the fields structure
  		ELSE $																																		; If status is NOT 1
  			MESSAGE, 'Failed to read data: Grid - ' + gridlist[i] + $								; Print error message that data was not read in
  			         ', Field - ' + field_names[j], /CONTINUE
    ENDFOR																																			; END j
		status = EOS_GD_DETACH(gridID)
		IF status NE 0 THEN MESSAGE, 'Failed to detach grid', /CONTINUE  						; Print error if failed to detach grid
    grid = CREATE_STRUCT(grid, gridlist[i], {GRID_INFO : info, FIELDS : fields}); Append info to the grid structure
  ENDIF
ENDFOR																																					; END i

status = EOS_GD_CLOSE(gid)                                                   		; Close the file
IF status NE 0 THEN MESSAGE, 'Failed to close the file', /CONTINUE							;

RETURN, grid
END