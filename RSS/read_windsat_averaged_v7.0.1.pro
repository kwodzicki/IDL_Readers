PRO read_windsat_averaged_v7.0.1, file_name, sst, windLF, windMF, vapor, cloud, rain, windAW, wdir

; this routine will read the WINDSAT time_averaged bytemap files (version-7).
; The  3-day, weekly and monthly data files all have the same format.

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
; Details of the binary data file format is located at
; http://www.remss.com/windsat/windsat_data_description.html#binary_data_files
;
; To contact RSS support:
; http://www.remss.com/support



;binary data in file
binarydata= bytarr(1440,720,8)

;output products (lon,lat)
sst     = fltarr(1440,720)
windLF  = fltarr(1440,720)
windMF  = fltarr(1440,720)
vapor   = fltarr(1440,720)
cloud   = fltarr(1440,720)
rain    = fltarr(1440,720)
windAW  = fltarr(1440,720)
wdir    = fltarr(1440,720)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;determine if file exists
exist=findfile(file_name,COUNT=cnt)
if (cnt eq 1) then begin

  ;open file, read binary data, close file
  close,2
  openr,2,file_name, error=err, /compress	;compress keyword allows reading of gzip file, do not use if file is unzipped
  if (err gt 0) then begin
  	print, 'ERROR OPENING FILE: ', file_name
  endif else begin
  	readu,2,binarydata
  	close,2
  endelse

; multipliers to change binary data to real data
xscale=[ 0.15, 0.2, 0.2,  0.3, 0.01, 0.1,  0.2,  1.5]
offset=[ -3.0, 0.0, 0.0,  0.0,-0.05, 0.0,  0.0,  0.0]

; loop through 8 environmental parameters
  for ivar=0,7 do begin

	; extract 1 variable, scale and assign to real array
     dat=binarydata[*,*,ivar]
	 dat=float(dat)
	 ok=where(dat le 250,complement=notok)
     dat[ok]=dat[ok]*xscale[ivar]+offset[ivar]
     dat[notok]=-999.0

     case ivar of
     		0: sst[*,*]    = dat
            1: windLF[*,*] = dat
            2: windMF[*,*] = dat
            3: vapor[*,*]  = dat
			4: cloud[*,*]  = dat
			5: rain[*,*]   = dat
            6: windAW[*,*] = dat
            7: wdir[*,*]   = dat
	 endcase

  endfor	;ivar
endif


return
END