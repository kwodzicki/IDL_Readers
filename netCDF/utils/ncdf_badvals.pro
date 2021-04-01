FUNCTION NCDF_BADVALS, data, var_data
;+
; Name:
;   NCDF_BADVALS
; Inputs:
;   var_data (hash) : A hash containing netCDF variable attributes to use
;     for determining bad values in data
; Keywords:
;   None.
; Returns:
;   array of indices of bad data
;-

COMPILE_OPT IDL2

replace_id = LIST()

fillVal    = NCDF_FILLVAL( data )
missVal    = NCDF_FILLVAL( data )

IF var_data.HasKey('_FillValue') THEN $                                       ; If _fillva
  fillVal = var_data['_FillValue']
id = WHERE(data EQ FillVal, cnt)                                              ; Locate fil
IF (CNT GT 0) THEN replace_id.ADD, id                                         ; If values

IF var_data.HasKey('missing_value') THEN $                                    ; If missing
  missVal = var_data['missing_value']
id = WHERE(data EQ missVal, CNT)                                              ; Locate mis
IF (CNT GT 0) THEN replace_id.ADD, id                                         ; If values

IF var_data.HasKey('valid_range') THEN BEGIN                                  ; If valide_
  id = WHERE(data LT var_data['valid_range', 0] OR $                          ; Locate val
             data GT var_data['valid_range', 1], CNT)
  IF (CNT GT 0) THEN replace_id.ADD, id                                       ; If values
ENDIF

IF N_ELEMENTS(replace_id) GT 0 THEN BEGIN
  replace_id = replace_id.ToArray(DIMENSION=1, /No_Copy)
  uu         = UNIQ(replace_id, SORT(replace_id))
  RETURN, replace_id[uu]
ENDIF ELSE $
  RETURN, !NULL

END
