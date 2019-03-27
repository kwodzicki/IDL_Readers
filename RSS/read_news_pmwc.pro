pro read_news_pmwc, filename, wvtu, wvtv, wvtd, evap, prcp, wvap, iexist

;     this routine reads version-01 NEWS Passive Microwave Water Cycle (PMWC) data files
;     please contact Kyle Hilburn (hilburn@remss.com) with any questions or concerns
;
;     input:
;     filename: filename with path in form of NEWS_yyyy_mm_PMWC_V01.dat
;       where yyyy = four-digit year
;             mm   = two-digit month
;
;     output:
;       real arrays (1440 x 720):
;       wvtu,  water vapor transport zonal component      (mm m/s)
;       wvtv,  water vapor transport meridional component (mm m/s)
;       wvtd,  water vapor transport divergence           (mm/hour)
;       evap,  evaporation                                (mm/hour)
;       prcp,  precipitation                              (mm/hour)
;       wvap,  columnar water vapor                       (mm)
;
;     longitude is 0.25*(xdim+1)- 0.125   !IDL is zero based
;     latitude  is 0.25*(ydim+1)-90.125
;
;     this subroutine returns pmwc_data with the missing value -999.
;     in abuf, valid geophysical data fall between 0 and 255 with special values for:
;       252 = sea ice
;       254 = insufficient data
;       255 = land
;     scale factors for valid data (values 0 to 250) are:
;       abuf(:,:,1) = wvt speed:       x 2.4,          to range between:   0  to   600  mm m/s
;       abuf(:,:,2) = wvt direction:   x 1.5,          to range between:   0  to   360  degrees
;       abuf(:,:,3) = wvt divergence:  x 0.024 - 3.0,  to range between:  -3  to     3  mm/hour
;       abuf(:,:,4) = evaporation:     x 0.003,        to range between:   0  to  0.75  mm/hour
;       abuf(:,:,5) = precipitation:   x 0.012,        to range between:   0  to     3  mm/hour
;       abuf(:,:,6) = water vapor:     x 0.3,          to range between:   0  to    75  mm


wvtu=replicate(-999.,1440,720)
wvtv=replicate(-999.,1440,720)
wvtd=replicate(-999.,1440,720)
evap=replicate(-999.,1440,720)
prcp=replicate(-999.,1440,720)
wvap=replicate(-999.,1440,720)

exist=findfile(filename,count=cnt)
if (cnt ne 1) then begin
    print,'FILE DOES NOT EXIST  or  MORE THAN ONE FILE EXISTS: ', filename
    iexist=-1
    return
endif

abuf=bytarr(1440,720,6)
close,2
openr,2,filename,error=err,/compress  ;compress keyword allows reading of gzip file, remove if data already unzipped
if (err gt 0) then begin
    print, 'ERROR 1 WITH FILE: ', filename
    iexist=-1
    return
endif
readu,2,abuf
close,2

wspd=reform(abuf(*,*,0))
wdir=reform(abuf(*,*,1))  ;oceanographic convention
wvtu=(2.4*wspd)*sin((1.5*wdir)*!dtor)
wvtv=(2.4*wspd)*cos((1.5*wdir)*!dtor)
wvtd=reform(abuf(*,*,2))*0.024 - 3.0
evap=reform(abuf(*,*,3))*0.003
prcp=reform(abuf(*,*,4))*0.012
wvap=reform(abuf(*,*,5))*0.3

ibad=where(wspd gt 250,nbad)
if (nbad gt 0) then begin
    wvtu[ibad]=-999.
    wvtv[ibad]=-999.
    wvtd[ibad]=-999.
    evap[ibad]=-999.
    prcp[ibad]=-999.
    wvap[ibad]=-999.
endif

iexist=0

return
end