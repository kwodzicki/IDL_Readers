PRO read_tmi_day_v4, filename, time, sst, w11, w37, vapor, cloud, rain

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
;
; please read the description file on www.remss.com
; FOR infomation on the various fields, or contact
; support@remss.com with questions about the data.
; 
; MODIFIED 01 July 2014 by Kyle R. Wodzicki - Changed all IDL commands to upperCASE. 
;




;binary data in file
binarydata= BYTARR(1440,320,7,2)

;output products (lon,lat,asc/dsc)
time =FLTARR(1440,320,2)
sst  =FLTARR(1440,320,2)
w11  =FLTARR(1440,320,2)
w37  =FLTARR(1440,320,2)
vapor=FLTARR(1440,320,2)
cloud=FLTARR(1440,320,2)
rain =FLTARR(1440,320,2)

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
  xscale=[0.1,0.15,.2,.2,.3,.01,.1]
  OFfset=[0.,-3.,0.,0.,0.,0.,0.]

; loop through asc/dsc  and all 7 variables
  FOR iasc=0,1 DO BEGIN
   FOR ivar=0,6 DO BEGIN

       ; extract 1 variable, scale and assign to real array
        dat=binarydata[*,*,ivar,iasc]
        ok=WHERE(dat LE 250)
        dat=FLOAT(dat)
        dat[ok]=dat[ok]*xscale[ivar]+OFfset[ivar]

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


RETURN
END