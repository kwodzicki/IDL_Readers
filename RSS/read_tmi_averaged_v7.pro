PRO read_tmi_averaged_v7, filename, sst, w11, w37, vapor, cloud, rain

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
binarydata= bytarr(1440,720,6)

;output products (lon,lat,asc/dsc)
sst  =fltarr(1440,720)
w11  =fltarr(1440,720)
w37  =fltarr(1440,720)
vapor=fltarr(1440,720)
cloud=fltarr(1440,720)
rain =fltarr(1440,720)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;determine if file exists
exist=findfile(filename,COUNT=cnt)
if (cnt ne 1) then begin
  print, 'FILE DOES NOT EXIST  or MORE THAN ONE FILE EXISTS!!'
endif else begin

  ;open file, read binary data, close file
  close,2
  openr,2,filename, error=err;, /compress   ;compress keyword allows reading of gzip file, do not use if file is unzipped
  if (err gt 0) then begin
    print, 'ERROR OPENING FILE: ', filename
  endif else begin
    readu,2,binarydata
    close,2
  endelse

; multipliers to change binary data to real data
  xscale=[0.15,.2,.2,.3,.01,.1]
  xoffset=[-3.0,0.,0.,0.,-0.05,0.]

; loop through 6 geo parameters
  for ivar=0,5 do begin

    ; extract 1 variable, scale and assign to real array
     dat=binarydata[*,*,ivar]
     ok=where(dat le 250)
     dat=float(dat)
     dat[ok]=dat[ok]*xscale[ivar]+xoffset[ivar]

     case ivar of
          0: sst  [*,*] =dat
          1: w11  [*,*] =dat
          2: w37  [*,*] =dat
          3: vapor[*,*] =dat
          4: cloud[*,*] =dat
          5: rain [*,*] =dat
     endcase

  endfor    ;ivar
endelse


return
END