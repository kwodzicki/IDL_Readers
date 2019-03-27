pro read_rss_mwr_day, filename, time, sst, wind_lf, wind_mf, vapor, cloud, rain

; reads the RSS daily bytemap files for:
;
;			 GMI, TMI, AMSR-2, AMSR-E
;
; parameter 1 = filename (including path): f**_yyyymmddv*.gz, where
;      f**   = file descriptor
;      yyyy  = year
;      mm    = month
;      dd    = day
;      v*    = version
;
; parameters 2-7 = real number arrays sized (1440,720,2):
;   time    = UTC time of observation in fractional hours,  valid range=[ 0.0,  24.0 ]
;   sst     = sea surface temperature in degrees C,         valid range=[-3.0,  34.5 ]
;   wind_lf = 10 meter surface wind speed in meters/second, valid range=[ 0.,   50.0 ]  predominantly 11 GHz (lf = low frequency)
;   wind_mf = 10 meter surface wind speed in meters/second, valid range=[ 0.,   50.0 ]  predominantly 37 GHz (mf = medium frequency)
;   vapor   = atmospheric water vapor in millimeters,       valid range=[ 0.,   75.0 ]
;   cloud   = cloud liquid water in millimeters,            valid range=[-0.05,  2.45]
;   rain    = instantaneous rain rate in millimeters/hour,  valid range=[ 0.,   25.0 ]
;
;
; Geolocation is stored within the grid index:
; Longitude  is 0.25 * ( index_longitude + 1) -  0.125     !IDL is zero based    East longitude
; Latitude   is 0.25 * ( index_latitude  + 1) - 90.125
;
;
; www.remss.com
; www.remss.com/support



;allocate byte data to read from file
byte_data = bytarr(1440,720,7,2)

;output products[lon,lat,asc/dsc]
time    = make_array([1440,720,2], /float, value=!VALUES.F_NAN)
sst     = make_array([1440,720,2], /float, value=!VALUES.F_NAN)
wind_lf = make_array([1440,720,2], /float, value=!VALUES.F_NAN)
wind_mf = make_array([1440,720,2], /float, value=!VALUES.F_NAN)
vapor   = make_array([1440,720,2], /float, value=!VALUES.F_NAN)
cloud   = make_array([1440,720,2], /float, value=!VALUES.F_NAN)
rain    = make_array([1440,720,2], /float, value=!VALUES.F_NAN)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;determine if file exists
exist=findfile(filename,count=num_found)
if (num_found ne 1) then begin
  print, 'FILE NOT FOUND: ', filename
endif else begin

  ;open file, read byte data, close file
  if strpos(filename, '.gz', 2, /reverse_offset) gt 0 then begin
    openr, file_ID, /get_lun, filename, error=err, /compress
  endif else begin
    openr, file_ID, /get_lun, filename, error=err
  endelse

  if (err gt 0) then begin
    print, 'ERROR OPENING FILE: ', filename
  endif else begin
    readu, file_ID, byte_data
    close, file_ID
  endelse

  ; to decode byte data to real data
  scale  = [0.1, 0.15, .2, .2, .3,   .01, .1]
  offset = [0.0, -3.0, 0., 0., 0., -0.05, 0.]

  ;loop through asc/dsc passes and all 7 products
  for index_pass=0,1 do begin
    for index_product=0,6 do begin

      ;extract 1 product, scale and assign to real array
      dat = byte_data[*,*,index_product,index_pass]
      ok = where(dat le 250)
      dat = float(dat)
      dat[ok] = dat[ok] * scale[index_product] + offset[index_product]

      case index_product of
        0: time    [*,*,index_pass] = dat
        1: sst     [*,*,index_pass] = dat
        2: wind_lf [*,*,index_pass] = dat
        3: wind_mf [*,*,index_pass] = dat
        4: vapor   [*,*,index_pass] = dat
        5: cloud   [*,*,index_pass] = dat
        6: rain    [*,*,index_pass] = dat
      endcase

    endfor ;index_product
  endfor ;index_pass

endelse


return

end