FUNCTION READ_NEWS_PMWC_V2, filename

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
;
; Modified by Kyle R. Wodzicki 15 Jan. 2015 - Changed to function.
;-

wvtu=REPLICATE(-999.0, 1440, 720)
wvtv=REPLICATE(-999.0, 1440, 720)
wvtd=REPLICATE(-999.0, 1440, 720)
evap=REPLICATE(-999.0, 1440, 720)
prcp=REPLICATE(-999.0, 1440, 720)
wvap=REPLICATE(-999.0, 1440, 720)

exist=FINDFILE(filename,count=cnt)
IF (cnt NE 1) THEN BEGIN
    PRINT,'FILE DOES NOT EXIST  or  MORE THAN ONE FILE EXISTS: ', filename
    RETURN, -1
ENDIF

abuf=BYTARR(1440,720,6)
CLOSE,2
OPENR,2,filename,error=err,/compress  ;compress keyword allows reading of gzip file, remove if data already unzipped
IF (err GT 0) THEN BEGIN
    PRINT, 'ERROR 1 WITH FILE: ', filename
    RETURN, -1
ENDIF
READU,2,abuf
CLOSE,2

wspd=REFORM(abuf[*,*,0])
wdir=REFORM(abuf[*,*,1])  ;oceanographic convention
wvtu=(2.4 * wspd) * SIN((1.5 * wdir) * !DTOR)
wvtv=(2.4 * wspd) * COS((1.5 * wdir) * !DTOR)
wvtd=REFORM(abuf[*,*,2]) * 0.024 - 3.0
evap=REFORM(abuf[*,*,3]) * 0.003
prcp=REFORM(abuf[*,*,4]) * 0.012
wvap=REFORM(abuf[*,*,5]) * 0.3

ibad=WHERE(wspd GT 250, nbad)
IF (nbad GT 0) THEN BEGIN
    wvtu[ibad]=!VALUES.F_NaN
    wvtv[ibad]=!VALUES.F_NaN
    wvtd[ibad]=!VALUES.F_NaN
    evap[ibad]=!VALUES.F_NaN
    prcp[ibad]=!VALUES.F_NaN
    wvap[ibad]=!VALUES.F_NaN
ENDIF

RETURN, {LON   : 0.25*(FINDGEN(1440)+1)- 0.125, $
         LAT   : 0.25*(FINDGEN(720) +1)-90.125, $
         WVT_U : wvtu, $
         WVT_V : wvtv, $
         WVT_D : wvtd, $
         EVAP  : evap, $
         PRCP  : prcp, $
         WVAP  : wvap}
END