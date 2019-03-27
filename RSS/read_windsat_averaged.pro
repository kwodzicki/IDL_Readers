FUNCTION READ_WINDSAT_AVERAGED, file_name, $
					PARAMETERS=parameters, $
					NO_LAND		=no_land, $
					NO_GOM		=no_gom, $
					LIMITS		=limits, $
					RRDAY			=rrday, $
					UV_WIND		=uv_wind
;+
; Name:
;		READ_WINDSAT_AVERAGED
; Purpose:
; 		this routine will read the WINDSAT time_averaged bytemap files (version-7).
; 		The  3-day, weekly and monthly data files all have the same format.
; Keywords:
;		UV_WIND		: Set to also return U and V components of wind
; arguments are:
;   file_name :  name of file to read complete with path
; 	filename  with path in forms:
;
;	wsat_yyyymmddv7.0.1_d3d.gz		3-day   (mean of 3 days ending on file date)
;   wsat_yyyymmddv7.0.1.gz			weekly  (mean of 7 days ending on Saturday file date)
;   wsat_yyyymmv7.0.1.gz			monthly (mean of days in month)
;
;	   yyyy		= year
;	   mm  		= month
;	   dd  		= day of month
;
; The routine returns:
;
;   sst, windLF, windMF, vapor, cloud, rain, windAW, wdir; real arrays sized (1440,720)

;	sst		sea surface temperature (6 GhZ, very low resolution) in deg Celsius
;	windLF	10m surface wind speed (10 Ghz, low frequency channel and above) in meters/second
;	windMF	10m surface wind speed (18 Ghz, medium frequency channel and above) in meters/second
;	vapor	columnar water vapor in millimeters
;	cloud	cloud liquid water in millimeters
;	rain	rain rate in millimeters/hour
;	windAW	all-weather 10m surface wind speed in meters/second
;	wdir   	direction the wind is flowing to (North is 0 degrees), oceanographic convention
; CONVERT THEM TO RADIANS
;
; Longitude  is 0.25*(xdim+1)-0.125		!IDL is zero based    East longitude
; Latitude   is 0.25*(ydim+1)-90.125
;
;
; Data from the daily files are scalar (wind speed) and vector (wind direction) averaged
; to produce the values in the time-averaged files.  A data value for a given cell is only provided in a
; time-averaged file if a minimum number of data exist within the time period being produced
; (3-day maps, 2 obs;  week maps, 5 obs;  month maps, 20 obs)
;
;  3-day   = (average of 3 days ending on file date)
;  weekly  = (average of 7 days ending on Saturday of file date)
;  monthly = (average of all days in month)
;
; FUNCTION IS MODIFIED VERSION OF READ_WINDSAT_AVERAGED_V7.0.1.
; MODIFIED BY KYLE R. WODZICKI ON 17 SEP. 2014.
;
; Details of the binary data file format is located at
; http://www.remss.com/windsat/windsat_data_description.html#binary_data_files
;
; To contact RSS support:
; http://www.remss.com/support



;binary data in file
binarydata= BYTARR(1440,720,8)

;output products (lon,lat)
sst     = FLTARR(1440,720)
windLF  = FLTARR(1440,720)
windMF  = FLTARR(1440,720)
vapor   = FLTARR(1440,720)
cloud   = FLTARR(1440,720)
rain    = FLTARR(1440,720)
windAW  = FLTARR(1440,720)
wdir    = FLTARR(1440,720)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;determine if file exists
exist=FINDFILE(file_name,COUNT=cnt)
IF (cnt NE 1) THEN $
		MESSAGE, 'FILE DOES NOT EXIST or MORE THAN ONE FILE EXISTS!!'

;open file, read binary data, close file
CLOSE,2
OPENR,2,file_name, error=err, /compress	;compress keyword allows reading of gzip file, do not use if file is unzipped
IF (err GT 0) THEN BEGIN
	PRINT, 'ERROR OPENING FILE: ', file_name
ENDIF ELSE BEGIN
	READU,2,binarydata
	CLOSE,2
ENDELSE

; multipliers to change binary data to real data
xscale =[ 0.15, 0.2, 0.2,  0.3, 0.01, 0.1,  0.2,  1.5]
xoffset=[ -3.0, 0.0, 0.0,  0.0,-0.05, 0.0,  0.0,  0.0]

; loop through 8 environmental parameters
FOR ivar=0,7 DO BEGIN

	dat	= binarydata[*,*,ivar]
	ok	= WHERE(dat LE 250, ok_CNT)																			;Indicies where data is ok
	IF ~KEYWORD_SET(no_gom) THEN BEGIN																	;If want data in Gulf of Mexico
		IF ~KEYWORD_SET(no_land) THEN BEGIN
			bad=WHERE(dat GT 250 AND dat LT 255, bad_CNT)										;Indicies where data is bad
		ENDIF ELSE bad=WHERE(dat GT 250, bad_CNT)
	ENDIF ELSE BEGIN
		ocean = CREATE_PACIFIC_OCEAN_MASK(/windsat)                       ;Land ocean mask 
		IF ~KEYWORD_SET(no_land) THEN BEGIN
			bad=WHERE((dat GT 250 AND dat LT 255) OR ocean EQ 1, bad_CNT)		;Indicies where data is bad
		ENDIF ELSE bad=WHERE(dat GT 250 OR ocean EQ 1, bad_CNT)
	ENDELSE
	dat	= FLOAT(dat)																										;Convert variabel to float
	IF (ok_CNT NE 0) THEN dat[ok] = dat[ok]*xscale[ivar]+xoffset[ivar]	;Scale good values
	IF (bad_CNT NE 0) THEN dat[bad]= !VALUES.F_NAN											;Replace bad values with NaN


	 CASE ivar OF
    0 : sst[*,*]    = dat
		1 : windLF[*,*] = dat
		2 : windMF[*,*] = dat
		3 : vapor[*,*]  = dat
		4 : cloud[*,*]  = dat
		5 : BEGIN
					IF ~KEYWORD_SET(rrday) THEN rain[*,*] = dat $
																 ELSE rain[*,*] = dat*24
				END
		6 : windAW[*,*] = dat
		7 : wdir[*,*]   = dat*!PI/180.0E0
 ENDCASE

ENDFOR	;ivar

;Create latitude and longitude and shift
lon = 0.25*(FINDGEN(1440)+1)- 0.125
lat = 0.25*(FINDGEN(720)+1) - 90.125

IF KEYWORD_SET(limits) THEN BEGIN
	IF (limits[3] LT 0) THEN limits[3]=limits[3]+360.0									;Convert to 360 degree not -180 to 180
	
	IF (limits[1] GT limits[3]) THEN BEGIN															;If crossing International date line
		lon_id = WHERE(lon GE limits[1] OR lon LE limits[3],lon_CNT)
	ENDIF ELSE BEGIN
		lon_id = WHERE(lon GE limits[1] AND lon LE limits[3],lon_CNT)
	ENDELSE
	lat_id = WHERE(lat GE limits[0] AND lat LE limits[2],lat_CNT)
ENDIF ELSE BEGIN
	lon_CNT = 0 
	lat_CNT = 0
ENDELSE

lon = REBIN(lon, 1440, 720)																						;Rebin to 1440 X 720 array
lat = REBIN(TRANSPOSE(lat), 1440, 720)																;Rebin to 1440 X 720 array

IF KEYWORD_SET(parameters) THEN BEGIN
	out_data = {}																												;Initialize out_data Struct
	FOR i = 0, N_ELEMENTS(parameters)-1 DO BEGIN												;Iterate over parameters
		parm = STRUPCASE(parameters[i])																		;Convert parameter name to Upper case
		CASE parm OF											
			'SST'		: out_data = CREATE_STRUCT(out_data, 'SST', sst)
			'WINDLF': out_data = CREATE_STRUCT(out_data, 'WINDLF', windMF)
			'WINDMF': out_data = CREATE_STRUCT(out_data, 'WINDMF', windMF)
			'VAPOR'	: out_data = CREATE_STRUCT(out_data, 'VAPOR', vapor)
			'CLOUD'	: out_data = CREATE_STRUCT(out_data, 'CLOUD', cloud)
			'RAIN'	: out_data = CREATE_STRUCT(out_data, 'RAIN', rain)
			'WINDAW': out_data = CREATE_STRUCT(out_data, 'WINDAW', windAW)
			'WDIR'	: out_data = CREATE_STRUCT(out_data, 'WDIR', wdir)
			ELSE	: MESSAGE, 'Input parameters(s) INVALID!'
		ENDCASE
	ENDFOR	
ENDIF ELSE BEGIN
	out_data = {SST		: sst, $
							WINDLF:	windLF, $
							WINDMF: windMF, $
							VAPOR	: vapor, $
							CLOUD	: cloud, $
							RAIN	: rain, $
							WINDAW: windAW, $
							WDIR	: wdir}
ENDELSE

IF KEYWORD_SET(uv_wind) THEN BEGIN
	out_data = CREATE_STRUCT(out_data, $
							'U_WIND', windAW*SIN(wdir), $
							'V_WIND', windAW*COS(wdir))
ENDIF

IF ~STRMATCH(file_name, '*REGRID*') THEN BEGIN												;If filename does NOT contain 'REGRID', add lat/lon
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

IF (lat_CNT NE 0 AND lat_CNT NE 720) THEN BEGIN												;IF are points to filter by but less than all points)
	tmp_data = {}
	tags = TAG_NAMES(out_data)
	FOR i = 0, N_TAGS(out_data)-1 DO BEGIN
		tmp_data=CREATE_STRUCT(tmp_data, tags[i], out_data.(i)[*,lat_id])
	ENDFOR
	out_data = tmp_data
ENDIF


RETURN, out_data
END