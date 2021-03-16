FUNCTION GET_ATTRIBUTES, iid, vid, $
  INQUIRE = inquire, $
  FLOAT   = float
;+
; Function to get all global attributes stored under NCDF Handle
;
; Inputs:
;   iid     : NCDF file or group handle to read from.
;   vid     : (Optional) Variable handle, will read all attributes for
;             variable. Omission of this argument sets the /GLOBAL flag
;             in NCDF_ATTNAME and other related funcs/pros
; Keywords:
;   inquire : (Optional) Information returned from previous call to 
;              NCDF_INQUIRE(iid)
; Returns:
;   Dictionary where keys are attribute names, values are attribute values
;-
COMPILE_OPT IDL2, HIDDEN

IF N_ELEMENTS(inquire) EQ 0 THEN BEGIN
  CASE N_PARAMS() OF
    1    : inquire = NCDF_INQUIRE(iid)
    2    : inquire = NCDF_VARINQ( iid, vid)
    ELSE : MESSAGE, 'Incorrect number of arguments'
  ENDCASE
ENDIF


IF N_PARAMS() EQ 1 THEN BEGIN
  atts = DICTIONARY()
  FOR i = 0, inquire.NGATTS-1 DO BEGIN																				; Iterate over all global
    attName = NCDF_ATTNAME(iid,       i, /GLOBAL)															; Get the name of the ith
    attInfo = NCDF_ATTINQ( iid, attName, /GLOBAL)															; Get the DataType and le
    NCDF_ATTGET, iid, attName, attData,  /GLOBAL                        			; Get the attribute data
    IF (attInfo.DataType EQ 'CHAR') THEN attData = STRING(attData)            ; If the attribute is of
    atts[attName] = attData                                                   ; Append the ith global a
  ENDFOR
ENDIF ELSE BEGIN
  atts = DICTIONARY(inquire, /EXTRACT)
  FOR i = 0, inquire.NATTS-1 DO BEGIN																					; Iterate over all of the
    attName = NCDF_ATTNAME(iid, vid, i)																				; Get the name of the att
    attInfo = NCDF_ATTINQ(iid,  vid, attName)																	; Get the DataType and le
    NCDF_ATTGET, iid, vid, attName, attData                                		; Get the data for the at
    convert = 0B
    IF (attInfo.DataType EQ 'CHAR') THEN BEGIN
      attData = STRING(attData)                                               ; If the attribute is of
    ENDIF ELSE IF STRMATCH(attName, '*FillValue', /FOLD_CASE) THEN BEGIN
      attName = '_FillValue'
      convert = 1B
    ENDIF ELSE IF STRMATCH(attName, 'missing_value', /FOLD_CASE) THEN BEGIN
      attName = 'missing_value'
      convert = 1B
    ENDIF ELSE IF STRMATCH(attName, 'scale_factor', /FOLD_CASE) THEN BEGIN
      attName = 'scale_factor'
      convert = 1B
    ENDIF ELSE IF STRMATCH(attName, 'add_offset', /FOLD_CASE) THEN BEGIN
      attName = 'add_offset'
      convert = 1B
    ENDIF ELSE IF STRMATCH(attName, 'valid_range', /FOLD_CASE) THEN BEGIN
      IF N_ELEMENTS(attData) NE 2 THEN CONTINUE																; If there are not 2 values in the valid_range, then skip it
      attName = 'valid_range'
      convert = 1B
    ENDIF      
    IF KEYWORD_SET(float) AND convert THEN attData = FLOAT(attData)

    atts[attName] = attData                      ; Append the attribute data to the var_data struct

  ENDFOR                                                                      ; END i
ENDELSE

RETURN, (N_ELEMENTS(atts) GT 0) ? atts : 0

END 
