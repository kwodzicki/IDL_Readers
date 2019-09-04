FUNCTION READ_RSS_MWR_DAY_KRW, filename, $
  NO_GoM = no_gom, $
  RR_DAY = rr_day

; reads the RSS daily bytemap files for:
;
;			 GMI, TMI, AMSR-2, AMSR-E
;
; parameter 1 = filename (including path): f**_yyyymmddv*.gz, where
;      f**   = file descriptor
;      yyyy  = year
;      mm    = month
;      dd    = day
;      v*    = version
;
; parameters 2-7 = real number arrays sized (1440,720,2):
;   time    = UTC time of observation in fractional hours,  valid range=[ 0.0,  24.0 ]
;   sst     = sea surface temperature in degrees C,         valid range=[-3.0,  34.5 ]
;   wind_lf = 10 meter surface wind speed in meters/second, valid range=[ 0.,   50.0 ]  predominantly 11 GHz (lf = low frequency)
;   wind_mf = 10 meter surface wind speed in meters/second, valid range=[ 0.,   50.0 ]  predominantly 37 GHz (mf = medium frequency)
;   vapor   = atmospheric water vapor in millimeters,       valid range=[ 0.,   75.0 ]
;   cloud   = cloud liquid water in millimeters,            valid range=[-0.05,  2.45]
;   rain    = instantaneous rain rate in millimeters/hour,  valid range=[ 0.,   25.0 ]
;
;
; Geolocation is stored within the grid index:
; Longitude  is 0.25 * ( index_longitude + 1) -  0.125     !IDL is zero based    East longitude
; Latitude   is 0.25 * ( index_latitude  + 1) - 90.125
;
;
; www.remss.com
; www.remss.com/support
; 
; Modified by Kyle R Wodzicki 05 Aug. 2016. Made function
COMPILE_OPT IDL2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;determine if file exists
exist = FINDFILE(filename, count=num_found)
IF (num_found NE 1) THEN $
  PRINT, 'FILE NOT FOUND: ', filename $
ELSE BEGIN
  IF STRMATCH(filename, '*.gz', /FOLD_CASE) THEN $
    OPENR, file_ID, filename, /GET_LUN, ERROR=err, /compress $
  ELSE $
    OPENR, file_ID, filename, /GET_LUN, ERROR=err

  IF (err GT 0) THEN $
    MESSAGE, 'ERROR OPENING FILE: ', filename $
  ELSE BEGIN
    byte_data = BYTARR(1440,720,7,2, /NoZero)                                   ; Allocate byte data to read from file
    READU, file_ID, byte_data                                                   ; Read in the data from the file
    FREE_LUN, file_ID                                                           ; Close the file
  ENDELSE

  ; to decode byte data to real data
  scale  = [0.1,  0.15, 0.2, 0.2, 0.3,  0.01, 0.1]
  offset = [0.0, -3.0,  0.0, 0.0, 0.0, -0.05, 0.0]

  out    = {LON     : 0.25 * (INDGEN(1440) + 1) -  0.125, $                     ; Initialize structure of data to return
            LAT     : 0.25 * (INDGEN(720)  + 1) - 90.125, $
           	time    : FLTARR(1440, 720, 2, /NoZero),      $
            SST     : FLTARR(1440, 720, 2, /NoZero),      $
            WIND_LF : FLTARR(1440, 720, 2, /NoZero),      $
            WIND_MF : FLTARR(1440, 720, 2, /NoZero),      $
            VAPOR   : FLTARR(1440, 720, 2, /NoZero),      $
            CLOUD   : FLTARR(1440, 720, 2, /NoZero),      $
            RAIN    : FLTARR(1440, 720, 2, /NoZero)}
  IF KEYWORD_SET(no_gom) THEN ocean = CREATE_PACIFIC_OCEAN_MASK(/tmi)           ;Land ocean mask 
  FOR i = 0, 6 DO BEGIN                                                         ; Iterate over all orbits and all products in the files
    dat = REFORM(byte_data[*,*,i,*])                                            ; Get data for the ith pass and jth product
    IF KEYWORD_SET(no_gom) THEN $           
      bad = WHERE(dat GT 250 OR ocean EQ 1, COUNT) $
    ELSE $
      bad = WHERE(dat GT 250, COUNT)                                            ; Find bad data in the ith product
    new = dat * scale[i] + offset[i]                                            ; Scale the ith product
    IF (COUNT GT 0) THEN new[bad] = !Values.F_NaN                               ; Replace missing values in the ith product with NaN characters
    IF (i EQ 5) AND KEYWORD_SET(rr_day) THEN new = TEMPORARY(new) * 24.0        ; Convert rain rate to mm/day
    out.(i+2) = new                                                             ; Put the data into the correct location in the data structure
  ENDFOR ;i
ENDELSE

RETURN, out

end
