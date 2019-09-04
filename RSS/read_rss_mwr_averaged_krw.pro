FUNCTION READ_RSS_MWR_AVERAGED_KRW, filename, $
  RRDAY  = rrday, $
  NO_GoM = no_gom

;+
; Name:
;   READ_RSS_MWR_AVERAGED_V2
; Purpose:
; A function that reads the RSS time_averaged bytemap files for:
;
;			 GMI, TMI, AMSR-2, AMSR-E
;
; The 3-day, weekly and monthly data files all have the same format.
;
; parameter 1 = filename (including path)
;
;   filenames have form:
;      f**_yyyymmddv*_d3d.gz     3-day   (mean of 3 days ending on file date)
;      f**_yyyymmddv*.gz         weekly  (mean of 7 days ending on Saturday file date)
;      f**_yyyymmv*.gz           monthly (mean of days in month)
;   where:
;      f**   = file descriptor
;      yyyy  = year
;      mm    = month
;      dd    = day
;      v*    = version
;
; parameters 2-6 = real number arrays sized (1440,720,2):
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
; Keywords:
;   RRDAY   : Set to return rain rate in mm/day. Default is mm/hr
;   NO_GoM  : Set to remove the Gulf of Mexico
;
; Notes:
; www.remss.com
; www.remss.com/support
;
; Adapted from READ_RSS_MWR_AVERAGED from Remote Sensing Systems
;-
COMPILE_OPT IDL2

;determine if file exists
exist = FINDFILE(filename, COUNT=num_found)
IF (num_found NE 1) THEN $
  MESSAGE, 'FILE NOT FOUND: ' + filename $
ELSE BEGIN

  ;open file, read byte data, close file
  If STRMATCH(filename, '*.gz', /FOLD_CASE) THEN $
    OPENR, file_ID, filename, /GET_LUN, ERROR=err, /compress $
  ELSE $
    OPENR, file_ID, filename, /GET_LUN, ERROR=err

  IF (err GT 0) THEN $
    MESSAGE, 'ERROR OPENING FILE: ', filename $
  ELSE BEGIN
    byte_data = BYTARR(1440, 720, 6, /NoZero)                                   ; Allocate byte data to read from file
    READU, file_ID, byte_data                                                   ; Read in the data from the file
    FREE_LUN, file_ID                                                           ; Close the file
  ENDELSE

  scale  = [ 0.15, 0.2, 0.2, 0.3,  0.01, 0.1]                                   ; Scale factors for the data
  offset = [-3.0,  0.0, 0.0, 0.0, -0.05, 0.0]                                   ; Offsets for the data
  out    = {LON     : 0.25 * (INDGEN(1440) + 1) -  0.125, $                     ; Initialize structure of data to return
            LAT     : 0.25 * (INDGEN(720)  + 1) - 90.125, $
            SST     : FLTARR(1440, 720, /NoZero),         $
            WIND_LF : FLTARR(1440, 720, /NoZero),         $
            WIND_MF : FLTARR(1440, 720, /NoZero),         $
            VAPOR   : FLTARR(1440, 720, /NoZero),         $
            CLOUD   : FLTARR(1440, 720, /NoZero),         $
            RAIN    : FLTARR(1440, 720, /NoZero)}
  FOR i = 0, 5 DO BEGIN                                                         ; Iterate over all the products in the files
    dat = byte_data[*,*,i]                                                      ; Get data for the ith product
    IF KEYWORD_SET(no_gom) THEN BEGIN
      ocean = CREATE_PACIFIC_OCEAN_MASK(/tmi)                                   ;Land ocean mask 
      bad = WHERE(dat GT 250 OR ocean EQ 1, COUNT) 
    ENDIF ELSE $
      bad = WHERE(dat GT 250, COUNT)                                            ; Find bad data in the ith product
    new = dat * scale[i] + offset[i]                                            ; Scale the ith product
    IF (COUNT GT 0) THEN new[bad] = !Values.F_NaN                               ; Replace missing values in the ith product with NaN characters
    IF (i EQ 5) AND KEYWORD_SET(rrday) THEN new = TEMPORARY(new) * 24.0         ; Convert rain rate to mm/day
    out.(i+2) = new                                                             ; Put the data into the correct location in the data structure
  ENDFOR ;i
ENDELSE

RETURN, out

END
