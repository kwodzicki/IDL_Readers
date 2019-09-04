FUNCTION READ_TMI_DAY_V4_KRW, filename, $
			PARAMETERS		= variables, $
			LAT_LON_ARRAY	= lat_lon_array

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
;		PARAMETERS	: A single variables or array of variabless to return.
;						If not set, all variabless returned.
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
;-


nx      = 1440
ny      =  320
nvars   =    7
nasc    =    2
dxy     =    0.25
xOffset =    0.125
yOffset =   40.125
binary  = BYTARR(nx, ny, nvars, nasc) 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;determine IF file exists
exist = FINDFILE(filename, COUNT=cnt)
IF (cnt NE 1) THEN $
  MESSAGE, 'FILE DOES NOT EXIST  or MORE THAN ONE FILE EXISTS!!'

;open file, read binary data, CLOSE file
CLOSE, 2
OPENR, 2, filename, ERROR = err, COMPRESS=STRMATCH(filename, '*.gz', /FOLD_CASE)   ;compress keyword allows reading OF gzip file, remove IF data already unzipped
IF (err GT 0) THEN $
  PRINT, 'ERROR OPENING FILE: ', filename $
ELSE BEGIN
  READU, 2, binarydata
  CLOSE, 2
ENDELSE

; multipliers to change binary data to real data
xscale = [0.1,  0.15, 0.2, 0.2, 0.3, 0.01, 0.1]
offset = [0.0, -3.00, 0.0, 0.0, 0.0, 0.00, 0.0]

binary = TRANSPOSE(binary, [0, 1, 3, 2])
bad    = WHERE(binary GT 250, nBad)
binary = FLOAT( binary )
; loop through asc/dsc  and all 7 variables
FOR ivar = 0, nvar-1 DO $
	binary[0,0,0,ivar] = binary[*,*,*,ivar] * xscale[ivar] + offset[ivar]
IF (nBad GT 0) THEN binary[bad] = !Values.F_NaN

;Create latitude and longitude and shift
lon = dxy * (FINDGEN(nx)+1) - xOffset
lat = dxy * (FINDGEN(ny)+1) - yOffset

IF KEYWORD_SET(lat_lon_array) THEN BEGIN
	lon = REBIN(lon, nx, ny)						;Rebin to 1440 X 320 array
	lat = REBIN(TRANSPOSE(lat), nx, ny)			;Rebin to 1440 X 320 array
ENDIF

IF N_ELEMENTS(variables) EQ 0 THEN $
	variables = ['TIME', 'SST', 'W11', 'W37', 'VAPOR', 'CLOUD', 'RAIN'] $
ELSE $
	FOR i = 0, N_ELEMENTS(variables)-1 DO $
		variables[i] = STRUPCASE(variables[i])

out_data = {LAT : lat, LON : lon}		;Append lat and lon data

FOR i = 0, N_ELEMENTS(variables)-1 DO $
	CASE variables[i] OF
			'TIME'	: out_data = CREATE_STRUCT(out_data, variables[i], binary[*,*,*,0])
			'SST'		: out_data = CREATE_STRUCT(out_data, variables[i], binary[*,*,*,1])
			'W11'		: out_data = CREATE_STRUCT(out_data, variables[i], binary[*,*,*,2])
			'W37'		: out_data = CREATE_STRUCT(out_data, variables[i], binary[*,*,*,3])
			'VAPOR'	: out_data = CREATE_STRUCT(out_data, variables[i], binary[*,*,*,4])
			'CLOUD'	: out_data = CREATE_STRUCT(out_data, variables[i], binary[*,*,*,5])
			'RAIN'	: out_data = CREATE_STRUCT(out_data, variables[i], binary[*,*,*,6])
			ELSE	: MESSAGE, 'Input variables(s) INVALID!'
	ENDCASE


RETURN, out_data

END
