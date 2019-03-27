FUNCTION READ_MEI_DATA, start_date, end_date
;+
; Name:
;   READ_MEI_DATA
; Purpose:
;   A Function to read in the MEI data ASCII file and return the
;   data in a nice structure.
; Inputs:
;   start_date  : First year (and month) of data to return. If
;                   supplying year and month must be of format
;                   YYYYMM.
;   end_date    : Last year (and month) of data to return. If
;                   supplying year and month must be of format
;                   YYYYMM.
; Outputs:
;   None.
; Keywords:
;   None.
; Author and History:
;   Kyle R. Wodzicki     Created 16 June 2015
;     MODIFIED 17 June 2016 by K.R.W.
;       Added start and end year inputs
;-
  COMPILE_OPT IDL2

  data = READ_ASCII('/Volumes/Data_Rapp/Wodzicki/ENSO/MEI_Data.txt')
  dims = SIZE(data.(0), /DIMENSIONS)

  mei = [] & year = [] & month = []
  FOR j = 1, dims[1]-1 DO BEGIN                                         ; Iterate over years
    FOR i = 1, 12 DO BEGIN                                              ; Iterate over months
      mei   = [ mei,   data.(0)[i,j] ]
      year  = [ year,  data.(0)[0,j] ]
      month = [ month, i]
    ENDFOR
  ENDFOR
  
  ;=== Filter out all data before start_date if start_date has value
  IF (N_ELEMENTS(start_date) NE 0) THEN BEGIN
    IF (STRLEN(STRTRIM(start_date,2)) EQ 6) THEN BEGIN
      start_year  = start_date/100
      start_month = ROUND(((start_date/100.0)-year) * 100)
      id = WHERE(year EQ start_year AND month EQ start_month, CNT)
      IF (CNT EQ 1) THEN BEGIN 
        mei = mei[id:*] & year = year[id:*] & month = month[id:*]
      ENDIF
    ENDIF ELSE BEGIN
      id = WHERE(year GE start_date, CNT)
      IF (CNT NE 0) THEN BEGIN 
        mei = mei[id] & year = year[id] & month = month[id]
      ENDIF
    ENDELSE
  ENDIF
  ;=== Filter out all data after end_date if end_date has value
  IF (N_ELEMENTS(end_date) NE 0) THEN BEGIN
    IF (STRLEN(STRTRIM(end_date,2)) EQ 6) THEN BEGIN
      end_year  = end_date/100
      end_month = ROUND(((end_date/100.0)-year) * 100)
      id = WHERE(year EQ end_year AND month EQ end_month, CNT)
      IF (CNT EQ 1) THEN BEGIN 
        mei = mei[0:id] & year = year[0:id] & month = month[0:id]
      ENDIF
    ENDIF ELSE BEGIN
      id = WHERE(year GE end_date, CNT)
      IF (CNT NE 0) THEN BEGIN 
        mei = mei[id] & year = year[id] & month = month[id]
      ENDIF
    ENDELSE
  ENDIF
  RETURN, {MEI : mei, YEAR : year, MONTH : month}
END