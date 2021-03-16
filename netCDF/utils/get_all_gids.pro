FUNCTION GET_ALL_GIDS, iid
;+
; Name:
;   GET_ALL_GIDS
; Purpose:
;   IDL function to recursively get all the group IDs in a netCDF file
; Inputs:
;   iid   : NCDF handle to open file
; Keywords:
;   None.
; Returns:
;   Array containing group IDs
;-
COMPILE_OPT IDL2, HIDDEN

ngids = 0                                                                     ; Set number of group ids to zero by default
gids  = LIST( NCDF_GROUPSINQ(iid) )                                           ; Get list of group ids in file

IF SIZE(gids[0], /N_DIMENSIONS) GT 0 THEN BEGIN                               ; If NO groups are found
  WHILE ngids NE N_ELEMENTS(gids) DO BEGIN                                    ; While the number of group ids does NOT match ngids
    ngids   = N_ELEMENTS(gids)                                                ; Reset the number of group ids
    new_ids = []                                                              ; Initialize empty array to store sub group ids in
    FOR i = 0, N_ELEMENTS(gids[-1])-1 DO BEGIN                                ; Iterate over the group ids
      tmp = NCDF_GROUPSINQ(gids[-1,i])                                        ; Get any group ids within a given group id
      IF SIZE(tmp, /N_DIMENSIONS) NE 0 THEN new_ids = [new_ids, tmp]          ; If sub group ids found, append them to the group ids list
   ENDFOR
    IF N_ELEMENTS(new_ids) GT 0 THEN gids.ADD, new_ids                        ; If the new_ids array is NOT empty, add it to the gids list
  ENDWHILE                                                                    ; END while
  RETURN, gids.ToARRAY(/No_COPY, DIMENSION=1)                                ; Convert list to array
ENDIF

RETURN, []

END
