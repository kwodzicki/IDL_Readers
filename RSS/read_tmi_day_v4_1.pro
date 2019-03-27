FUNCTION READ_TMI_DAY_V4_1, filename, PARAMETERS=parameters, $
								LAT_LON_ARRAY=lat_lon_array

;+
; Name:
;		READ_TMI_DAY_V4
; Purpose
; this routine will read the TMI daily bytemap files (version-4 released September 2006).
;
; arguments are:
;   filename :  name OF file to read complete with path
;   filenames have FORm TMI_yyyymmddv4.gz
;    WHERE yyyy     = year
;        	mm      = month
;        	dd      = day OF month
;
; The routiNE returns:
;   time, sst, w11, w37, vapor, cloud, rain real arrays sized (1440,320,2)
;   time  is the mean gmt time in fractional hours OF the observations within that grid cell
;   sst   is the sea surface temperature in degree Celcius, valid range=[-3.0,34.5]
;   w11   is the 10 meter surface wind speed in meters/second,  valid range=[0.,50.]  from 11 GHz channel
;   w37   is the 10 meter surface wind speed in meters/second,  valid range=[0.,50.]  from 37 GHz channel
;   vapor is the columnar atmospheric water vapor in millimeters,  valid range=[0.,75.]
;   cloud is the liquid cloud water in millimeters, valid range = [0.,2.5]
;   rain  is the derived radiometer rain rate in millimeters/hour,  valid range = [0.,25.]
;
; Longitude  is 0.25*(xdim+1)- 0.125     !IDL is zero based    East longitude
; Latitude   is 0.25*(ydim+1)-40.125
;
; Keywords:
;		PARAMETERS	: A single parameters or array of parameterss to return.
;						If not set, all parameterss returned.
;		LAT_LON_ARRAY: If lat/lon data is to returned in a 1440X320 array
;
; please read the description file on www.remss.com
; FOR infomation on the various fields, or contact
; support@remss.com with questions about the data.
; 
; MODIFIED 03 July 2014 by Kyle R. Wodzicki - Converted READ_TMI_DAY_V4 to a function
;												and added keyword to only return 
;												certain variables. Also added
;												lat/lon arrays and data return as
;												structure. Also added conversion of
;												bad data and land data to NaN values
;




;binary data in file
binarydata	= BYTARR(1440,320,7,2)

;output products (lon,lat,asc/dsc)
time	= FLTARR(1440,320,2)
sst		= FLTARR(1440,320,2)
w11		= FLTARR(1440,320,2)
w37		= FLTARR(1440,320,2)
vapor	= FLTARR(1440,320,2)
cloud	= FLTARR(1440,320,2)
rain	= FLTARR(1440,320,2)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;determine IF file exists
exist=FINDFILE(filename,COUNT=cnt)
IF (cnt NE 1) THEN BEGIN
  PRINT, 'FILE DOES NOT EXIST  or MORE THAN ONE FILE EXISTS!!'
ENDIF ELSE BEGIN

  ;open file, read binary data, CLOSE file
  CLOSE,2
  OPENR,2,filename, error=err;, /compress   ;compress keyword allows reading OF gzip file, remove IF data already unzipped
  IF (err GT 0) THEN BEGIN
    PRINT, 'ERROR OPENING FILE: ', filename
  ENDIF ELSE BEGIN
    READU,2,binarydata
    CLOSE,2
  ENDELSE

; multipliers to change binary data to real data
  xscale=[0.1, 0.15, 0.2, 0.2, 0.3, 0.01, 0.1]
  offset=[0.0, -3.0, 0.0, 0.0, 0.0, 0.0, 0.0]

; loop through asc/dsc  and all 7 variables
  FOR iasc=0,1 DO BEGIN
   FOR ivar=0,6 DO BEGIN

       ; extract 1 variable, scale and assign to real array
        dat	= binarydata[*,*,ivar,iasc]
        ok	= WHERE(dat LE 250, nOK, COMPLEMENT=bad, NCOMPLEMENT=nBad)
        dat	= FLOAT(TEMPORARY(dat))
        IF (nOK GT 0) THEN $
          dat[ok] = TEMPORARY(dat[ok])*xscale[ivar]+offset[ivar]
        IF (nBad GT 0) THEN $
          dat[bad]= !VALUES.F_NAN

        CASE ivar OF
            0: time[*,*,iasc] =dat
            1: sst [*,*,iasc] =dat
            2: w11 [*,*,iasc] =dat
			      3: w37 [*,*,iasc] =dat
            4: vapor[*,*,iasc]=dat
            5: cloud[*,*,iasc]=dat
            6: rain[*,*,iasc] =dat
       ENDCASE

    ENDFOR ;ivar
ENDFOR   ;iasc

ENDELSE

;Create latitude and longitude and shift
lon = 0.25*(FINDGEN(1441))- 0.125	& lon = lon[1:*]
lat = 0.25*(FINDGEN(321))-40.125	& lat = lat[1:*] 

IF KEYWORD_SET(lat_lon_array) THEN BEGIN
	lon = REBIN(lon, 1440, 320)						;Rebin to 1440 X 320 array
	lat = REBIN(TRANSPOSE(lat), 1440, 320)			;Rebin to 1440 X 320 array
ENDIF

IF KEYWORD_SET(parameters) THEN BEGIN
	out_data = {}
	FOR i = 0, N_ELEMENTS(parameters)-1 DO BEGIN
		parm = STRUPCASE(parameters[i])
		CASE parm OF
			'TIME'	: out_data = CREATE_STRUCT(out_data, 'TIME', time)
			'SST'		: out_data = CREATE_STRUCT(out_data, 'SST', sst)
			'W11'		: out_data = CREATE_STRUCT(out_data, 'W11', w11)
			'W37'		: out_data = CREATE_STRUCT(out_data, 'W37', w37)
			'VAPOR'	: out_data = CREATE_STRUCT(out_data, 'VAPOR', vapor)
			'CLOUD'	: out_data = CREATE_STRUCT(out_data, 'CLOUD', cloud)
			'RAIN'	: out_data = CREATE_STRUCT(out_data, 'RAIN', rain)
			ELSE	: MESSAGE, 'Input parameters(s) INVALID!'
		ENDCASE
	ENDFOR	
ENDIF ELSE BEGIN
	out_data = CREATE_STRUCT('TIME', time, $
								'SST', sst, $
								'W11',  w11, $
								'W37', w37, $
								'VAPOR', vapor, $
								'CLOUD', cloud, $
								'RAIN', rain)
ENDELSE

out_data = CREATE_STRUCT(out_data, 'LAT', lat, 'LON', lon)		;Append lat and lon data

RETURN, out_data

END