FUNCTION READ_TMI_AVERAGED_V7_2, filename, $
					PARAMETERS=parameters, $
					NO_LAND		=no_land, $
					NO_GOM		=no_gom, $
					LIMIT 		=limit, $
					RRDAY			=rrday

; this routine will read the TMI time_averaged bytemap files (version-7.1 released January 2015).
; The  3-day, weekly and monthly data files all have the same format.

; arguments are:
;   filename :  name of file to read complete with path
;   filename  with path in forms:
;     TMI_yyyymmddv7.1_d3d.gz     3-day   (mean of 3 days ending on file date)
;     TMI_yyyymmddv7.1.gz         weekly  (mean of 7 days ending on Saturday file date)
;     TMI_yyyymmv7.1.gz           monthly (mean of days in month)
;
;    where yyyy = year
;        mm     = month
;        dd     = day of month
;
; The routine returns:
;   sst, w11, w37, vapor, cloud, rain real arrays sized (1440,720)
;   
;   sst   is the sea surface temperature in degree Celcius, valid range=[-3.0,34.5]
;   w11   is the 10 meter surface wind speed in meters/second,  valid range=[0.,50.]  derived using the 11 GHz channel
;   w37   is the 10 meter surface wind speed in meters/second,  valid range=[0.,50.]  derived using the 37 GHz channel
;   vapor is the columnar atmospheric water vapor in millimeters,  valid range=[0.,75.]
;   cloud is the liquid cloud water in millimeters, valid range = [-0.05,2.45]
;   rain  is the derived radiometer rain rate in millimeters/hour,  valid range = [0.,25.]
;
; Longitude  is 0.25*(xdim+1)-0.125     !IDL is zero based    East longitude
; Latitude   is 0.25*(ydim+1)-90.125
;
;
; please read the description file on www.remss.com
; for infomation on the various fields, or contact
; support@remss.com with questions about the data.
;

;binary data in file
binary = BYTARR(1440,720,6)


;determine if file exists
exist = FINDFILE(filename,COUNT=cnt)
IF (cnt NE 1) THEN $
	MESSAGE, 'FILE DOES NOT EXIST or MORE THAN ONE FILE EXISTS!!'

;open file, read binary data, close file
CLOSE, 2
OPENR, 2, filename, ERROR=err, COMPRESS=STRMATCH(filename, '*.gz', /FOLD_CASE)  ;compress keyword allows reading of gzip file, do not use if file is unzipped
IF (err GT 0) THEN BEGIN
	PRINT, 'ERROR OPENING FILE: ', filename
ENDIF ELSE BEGIN
	READU, 2, binary
	CLOSE, 2
ENDELSE

; multipliers to change binary data to real data
xscale =[0.15, 0.2, 0.2, 0.3, 0.01, 0.1]
xoffset=[-3.0, 0.0, 0.0, 0.0, -0.05, 0.0]

;Create latitude and longitude and shift
lon = 0.25*(FINDGEN(1440)+1) - 0.125
lat = 0.25*(FINDGEN(720) +1) -90.125

IF N_ELEMENTS(limit) GT 0 THEN BEGIN
	IF (limit[3] LT 0) THEN limit[3]=limit[3]+360.0											;Convert to 360 degree not -180 to 180
	lat_id = WHERE(lat GE limit[0] AND lat LE limit[2],lat_CNT)
	IF (limit[1] GT limit[3]) THEN $        																;If crossing International date line
		lon_id = WHERE(lon GE limit[1] OR  lon LE limit[3],lon_CNT) $
	ELSE $
		lon_id = WHERE(lon GE limit[1] AND lon LE limit[3],lon_CNT)
ENDIF ELSE BEGIN
	lon_CNT = 0 
	lat_CNT = 0
ENDELSE

IF (lon_CNT GT 0 AND lon_CNT LT 1440) THEN BEGIN											;IF are points to filter by but less than all points
  binary = binary[lon_id,*,*]
  lon    = lon[lon_id]
ENDIF
IF (lat_CNT GT 0 AND lat_CNT LT 720) THEN BEGIN												;IF are points to filter by but less than all points)
  binary = binary[*,lat_id,*]
  lat    = lat[lat_id]
ENDIF

nLon = N_ELEMENTS(lon)
nLat = N_ELEMENTS(lat)
lon = REBIN(lon, nLon, nLat)														        								;Rebin to 1440 X 320 array
lat = REBIN(REFORM(lat, 1, nLat), nLon, nLat)										    						;Rebin to 1440 X 320 array

IF KEYWORD_SET(no_land) THEN $
  land_cnt = 0 $
ELSE $
  land = WHERE(binary EQ 255, land_CNT)                                         ; Locate land
  
IF KEYWORD_SET(no_gom) THEN $           														    			  ; If want data in Gulf of Mexico
	bad = WHERE(binary GT 250 OR CREATE_PACIFIC_OCEAN_MASK(/TMI) EQ 1, bad_CNT) $
ELSE $
	bad = WHERE(binary GT 250, bad_CNT)

binary = FLOAT(binary)                                                          ; Convert binary to float
IF bad_CNT GT 0 THEN binary[bad] = !VALUES.F_NaN											          ; Replace bad values with NaN
FOR i = 0, 5 DO binary[0,0,i] = binary[*,*,i] * xscale[i] + xoffset[i]
IF KEYWORD_SET(rrday) THEN binary[*,*,-1] *= 24

IF land_CNT GT 0 THEN binary[land] = 255.0


IF N_ELEMENTS(parameters) EQ 0 THEN $
  parameters = ['SST', 'W11', 'W37', 'VAPOR', 'CLOUD', 'RAIN']
out_data = {}																									       			;Initialize out_data Struct
FOR i = 0, N_ELEMENTS(parameters)-1 DO $												     ;Iterate over parameters
	CASE STRUPCASE(parameters[i]) OF											
		'SST'		: out_data = CREATE_STRUCT(out_data, 'SST',   binary[*,*,0])
		'W11'		: out_data = CREATE_STRUCT(out_data, 'W11',   binary[*,*,1])
		'W37'		: out_data = CREATE_STRUCT(out_data, 'W37',   binary[*,*,2])
		'VAPOR'	: out_data = CREATE_STRUCT(out_data, 'VAPOR', binary[*,*,3])
		'CLOUD'	: out_data = CREATE_STRUCT(out_data, 'CLOUD', binary[*,*,4])
		'RAIN'	: out_data = CREATE_STRUCT(out_data, 'RAIN',  binary[*,*,5])
		ELSE	: MESSAGE, 'Input parameters(s) INVALID!'
	ENDCASE
	

IF (NOT STRMATCH(filename, '*REGRID*')) THEN BEGIN										;If filename does NOT contain 'REGRID', add lat/lon
	out_data = CREATE_STRUCT(out_data, 'LAT', lat, 'LON', lon)					;Append lat and lon data
ENDIF

RETURN, out_data
END