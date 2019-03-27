PRO read_windsat_day_v7.0.1, file_name, time, sst, windLF, windMF, vapor, cloud, rain, windAW, wdir


; this routine will read the WINDSAT daily bytemap files (version-7).
;
; arguments are:
;   file_name :  name of file to read complete with path
; 	file_name has form wsat_yyyymmdd_v7.0.1.gz
;	     yyyy		= year
;		   mm  		= month
;		   dd 		= day of month
;
; The routine returns:
;
;   time, sst, windLF, windMF, vapor, cloud, rain, windAW, wdir; real arrays sized (1440,720,2)

;	time	time of measurement (Minute of day GMT)
;	sst		sea surface temperature (6 GhZ, very low resolution) at depth of about 1 mm in deg Celsius
;	windLF	10m surface wind speed (10 Ghz, low frequency channels and above) in meters/second
;	windMF	10m surface wind speed (18 Ghz, medium frequency channels and above) in meters/second
;	vapor	columnar atmospheric water vapor in millimeters
;	cloud	cloud liquid water in millimeters
;	rain	rain rate in millimeters/hour
;	windAW	all-weather 10m surface wind speed in meters/second made using 3 algorithms
;	wdir   	direction the wind is flowing to (North is 0 degrees), oceanographic convention

;  The 2 elements of the last index of array of data defines descending and ascending passes
;
; Longitude  is 0.25*(xdim+1)-0.125		!IDL is zero based    East longitude
; Latitude   is 0.25*(ydim+1)-90.125
;
;
; Details of the binary data file format is located at
; http://www.remss.com/windsat/windsat_data_description.html#binary_data_files
;
; To contact RSS support:
; http://www.remss.com/support

;binary data in file
binarydata= bytarr(1440,720,9,2)

;output products (lon,lat,asc/dsc)
time    = fltarr(1440,720,2)
sst     = fltarr(1440,720,2)
windLF  = fltarr(1440,720,2)
windMF  = fltarr(1440,720,2)
vapor   = fltarr(1440,720,2)
cloud   = fltarr(1440,720,2)
rain    = fltarr(1440,720,2)
windAW  = fltarr(1440,720,2)
wdir    = fltarr(1440,720,2)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;determine if file exists
exist=findfile(file_name,COUNT=cnt)
if (cnt ne 1) then begin
	print, 'FILE DOES NOT EXIST  or MORE THAN ONE FILE EXISTS!!'
endif else begin

  ;open file, read binary data, close file
  close,2
  openr,2,file_name, error=err, /compress	;compress keyword allows reading of gzip file, remove if data already unzipped
  if (err gt 0) then begin
  	print, 'ERROR OPENING FILE: ', file_name
  endif else begin
  	readu,2,binarydata
  	close,2
  endelse

; multipliers to change binary data to real data
xscale=[6.0, 0.15, 0.2, 0.2,  0.3, 0.01, 0.1,  0.2,  1.5]
offset=[0,  -3.0 , 0.0, 0.0,  0.0,-0.05, 0.0,  0.0,  0.0]

; loop through asc/dsc  and all 9 variables
for iasc=0,1 do begin
   for ivar=0,8 do begin

		; extract 1 variable, scale and assign to real array
        dat=binarydata[*,*,ivar,iasc]
		ok=where(dat le 250,complement=notok)
		dat=float(dat)
		dat[ok]=dat[ok]*xscale[ivar]+offset[ivar]
		dat[notok]=-999.0

        case ivar of
        	0: time[*,*,iasc]   = dat
			1: sst[*,*,iasc]    = dat
            2: windLF[*,*,iasc] = dat
            3: windMF[*,*,iasc] = dat
   			4: vapor[*,*,iasc]  = dat
            5: cloud[*,*,iasc]  = dat
			6: rain [*,*,iasc]  = dat
            7: windAW[*,*,iasc] = dat
            8: wdir[*,*,iasc]   = dat
		endcase

	endfor	;ivar
endfor		;iasc

endelse


return
END