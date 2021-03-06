FUNCTION READ_TMI_AVERAGED_V4_KRW, filename, $
					PARAMETERS=parameters, $
					NO_LAND		=no_land, $
					NO_GOM		=no_gom, $
					LIMIT 		=limit, $
					RRDAY			=rrday

;+
; Name:
;		READ_TMI_AVERAGED_V4_KRW
; Purpose:
; this routine will read the TMI time_averaged bytemap files (version-4 released September 2006).
; The  3-day, weekly and monthly data files all have the same format.
;
; arguments are:
;   filename :  name of file to read complete with path
;   filename  with path in forms:
;     TMI_yyyymmddv4_d3d.gz     3-day   (mean of 3 days ending on file date)
;     TMI_yyyymmddv4.gz         weekly  (mean of 7 days ending on Saturday file date)
;     TMI_yyyymmv4.gz           monthly (mean of days in month)
;
;    where yyyy = year
;        mm     = month
;        dd     = day of month
;
; The routine returns:
;   sst, w11, w37, vapor, cloud, rain real arrays sized (1440,320)
;   sst   is the sea surface temperature in degree Celcius, 
;					valid range=[-3.0,34.5]
;   w11  is the 10 meter surface wind speed in meters/second,  
;					valid range=[0.,50.]  derived using the 11 GHz channel
;   w37  is the 10 meter surface wind speed in meters/second,  
;					valid range=[0.,50.]  derived using the 37 GHz channel
;   vapor is the columnar atmospheric water vapor in millimeters,  
;					valid range=[0.,75.]
;   cloud is the liquid cloud water in millimeters, 
;					valid range = [0.,2.5]
;   rain  is the derived radiometer rain rate in millimeters/hour,  
;					valid range = [0.,25.]
;
; Longitude  is 0.25*(xdim+1)-0.125   !IDL is zero based East longitude
; Latitude   is 0.25*(ydim+1)-40.125
;
;
; please read the description file on www.remss.com
; for infomation on the various fields, or contact
; support@remss.com with questions about the data.
;
; 		MODIFIED 03 July 2014 by Kyle R. Wodzicki:
;				Converted READ_TMI_AVERAGED_V4 to a function and added keyword
;				to only return certain variables. Also added lat/lon arrays
;				and data return as structure. Also added conversion of
;				bad data and land data to NaN values.
;			MODIFIED 21 July 2014 by Kyle R. Wodzicki:
;				Re-gridded TMI files already have lat/lon info in them.
;				Thus, only add lat/lon info if 'REGRID' is not present in the
;				file name. This can be found near bottom of code.
;			MODIFIED 13 Aug. 2014:
;				Added NO_LAND keyword and changed the handeling of the 
;				PARAMETERS KEYWORD.
;			MODIFIED 16 Sep. 2014:
;				ADDED NO_GOM keyword to remove the Gulf of Mexico from data.
;				ALSO added limit keyword to filter by map limit.
;				ALSO added RRDAY keyword to convert Rain Rate to mm/day.
;-

;binary data in file
binarydata = BYTARR(1440,320,6)

;output products (lon,lat,asc/dsc)
sst		= FLTARR(1440,320)
w11		= FLTARR(1440,320)
w37		= FLTARR(1440,320)
vapor	= FLTARR(1440,320)
cloud	= FLTARR(1440,320)
rain	= FLTARR(1440,320)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;determine if file exists
exist = FINDFILE(filename,COUNT=cnt)
IF (cnt NE 1) THEN $
	MESSAGE, 'FILE DOES NOT EXIST or MORE THAN ONE FILE EXISTS!!'

;open file, read binary data, close file
CLOSE, 2
OPENR, 2, filename, error=err;, /compress   												;compress keyword allows reading of gzip file, do not use if file is unzipped
IF (err GT 0) THEN BEGIN
	PRINT, 'ERROR OPENING FILE: ', filename
ENDIF ELSE BEGIN
	READU, 2, binarydata
		CLOSE, 2
ENDELSE

; multipliers to change binary data to real data
xscale	= [0.15, 0.2, 0.2, 0.3, 0.01, 0.1]
xoffset	= [-3.0, 0.0, 0.0, 0.0, 0.0, 0.0]


; loop through 6 geo parameters
FOR ivar=0, 5 DO BEGIN

; extract 1 variable, scale and assign to real array
	dat	= binarydata[*,*,ivar]
	ok	= WHERE(dat LE 250, ok_CNT)																			;Indicies where data is ok
	IF ~KEYWORD_SET(no_gom) THEN BEGIN																	;If want data in Gulf of Mexico
		IF ~KEYWORD_SET(no_land) THEN BEGIN
			bad=WHERE(dat GT 250 AND dat LT 255, bad_CNT)										;Indicies where data is bad
		ENDIF ELSE bad=WHERE(dat GT 250, bad_CNT)
	ENDIF ELSE BEGIN
		ocean = CREATE_PACIFIC_OCEAN_MASK(/tmi, /v4)                           ;Land ocean mask 
		IF ~KEYWORD_SET(no_land) THEN BEGIN
			bad=WHERE((dat GT 250 AND dat LT 255) OR ocean EQ 1, bad_CNT)		;Indicies where data is bad
		ENDIF ELSE bad=WHERE(dat GT 250 OR ocean EQ 1, bad_CNT)
	ENDELSE
	dat	= FLOAT(dat)																										;Convert variabel to float
	IF (ok_CNT NE 0) THEN dat[ok] = dat[ok]*xscale[ivar]+xoffset[ivar]	;Scale good values
	IF (bad_CNT NE 0) THEN dat[bad]= !VALUES.F_NAN											;Replace bad values with NaN
	
; Store data into proper variables
	CASE ivar OF
		0 : sst  [*,*] = dat
		1 : w11  [*,*] = dat
		2 : w37  [*,*] = dat
		3 : vapor[*,*] = dat
		4 : cloud[*,*] = dat
		5 : BEGIN
					IF ~KEYWORD_SET(rrday) THEN rain[*,*] = dat $
																 ELSE rain[*,*] = dat*24
				END
	ENDCASE

ENDFOR    ;ivar

;Create latitude and longitude and shift
lon = 0.25*(FINDGEN(1440)+1)-0.125
lat = 0.25*(FINDGEN(320)+1) -40.125

IF KEYWORD_SET(limit) THEN BEGIN
	IF (limit[3] LT 0) THEN limit[3]=limit[3]+360.0											;Convert to 360 degree not -180 to 180
	
	IF (limit[1] GT limit[3]) THEN BEGIN																;If crossing International date line
		lon_id = WHERE(lon GE limit[1] OR lon LE limit[3],lon_CNT)
	ENDIF ELSE BEGIN
		lon_id = WHERE(lon GE limit[1] AND lon LE limit[3],lon_CNT)
	ENDELSE
	lat_id = WHERE(lat GE limit[0] AND lat LE limit[2],lat_CNT)
ENDIF ELSE BEGIN
	lon_CNT = 0 
	lat_CNT = 0
ENDELSE

lon = REBIN(lon, 1440, 320)																						;Rebin to 1440 X 320 array
lat = REBIN(TRANSPOSE(lat), 1440, 320)																;Rebin to 1440 X 320 array

IF KEYWORD_SET(parameters) THEN BEGIN
	out_data = {}																												;Initialize out_data Struct
	FOR i = 0, N_ELEMENTS(parameters)-1 DO BEGIN												;Iterate over parameters
		parm = STRUPCASE(parameters[i])																		;Convert parameter name to Upper case
		CASE parm OF											
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
	out_data = CREATE_STRUCT('SST', sst, $
								'W11',  	w11, $
								'W37',		w37, $
								'VAPOR',	vapor, $
								'CLOUD',	cloud, $
								'RAIN',		rain)
ENDELSE

IF (NOT STRMATCH(filename, '*REGRID*')) THEN BEGIN										;If filename does NOT contain 'REGRID', add lat/lon
	out_data = CREATE_STRUCT(out_data, 'LAT', lat, 'LON', lon)					;Append lat and lon data
ENDIF

IF (lon_CNT NE 0 AND lon_CNT NE 1440) THEN BEGIN											;IF are points to filter by but less than all points
	tmp_data = {}
	tags = TAG_NAMES(out_data)
	FOR i = 0, N_TAGS(out_data)-1 DO BEGIN
		tmp_data=CREATE_STRUCT(tmp_data, tags[i], out_data.(i)[lon_id,*])
	ENDFOR
	out_data = tmp_data
ENDIF

IF (lat_CNT NE 0 AND lat_CNT NE 320) THEN BEGIN												;IF are points to filter by but less than all points)
	tmp_data = {}
	tags = TAG_NAMES(out_data)
	FOR i = 0, N_TAGS(out_data)-1 DO BEGIN
		tmp_data=CREATE_STRUCT(tmp_data, tags[i], out_data.(i)[*,lat_id])
	ENDFOR
	out_data = tmp_data
ENDIF

RETURN, out_data
END
