FUNCTION READ_CMAP_PENTAD_DATA, in_year, in_week, $
  IID   = iid, $
  LIMIT = limit

; To read in data from the CMAP Pentad file from OPeNDAP and read in
; a given week from a given year

file_open = (N_ELEMENTS(iid) NE 0) ? 1 : 0

IF NOT file_open THEN BEGIN
  url = 'http://www.esrl.noaa.gov/psd/thredds/dodsC/Datasets/cmap/enh/precip.pentad.mean.nc'
  iid = NCDF_OPEN(url, /NOWRITE)
ENDIF
  NCDF_VARGET, iid, 'lon', rr_lon
  NCDF_VARGET, iid, 'lat', rr_lat

  IF (N_ELEMENTS(limit) NE 0) THEN BEGIN
    lon_id = WHERE(rr_lon GE limit[1] AND rr_lon LE limit[3], nLon)
    lat_id = WHERE(rr_lat GE limit[0] AND rr_lat LE limit[2], nLat)
    IF (nLon EQ 0) OR (nLat EQ 0) THEN BEGIN
      MESSAGE, 'NO data found in lon/lat limit, reading all data...', /CONTINUE
      RETURN, -1
    ENDIF ELSE BEGIN
      rr_lon = TEMPORARY(rr_lon[lon_id])
      rr_lat = TEMPORARY(rr_lat[lat_id])
    ENDELSE
  ENDIF ELSE BEGIN
    lon_id = 0
    lat_id = 0
    nLon = N_ELEMENTS(rr_lon)
    nLat = N_ELEMENTS(rr_lat)
  ENDELSE
  
  NCDF_VARGET, iid, 'time', time
  jul_Time = JULDAY(1, 1, 1800, 0, 0, 0) + (time/24.0)
  CALDAT, jul_Time, mm, dd, yy
  t_ID = WHERE(yy EQ in_year, CNT)
  
  IF (CNT GT 0) THEN BEGIN
    rr_weeks = ROUND((jul_Time[t_ID]-JULDAY(1,1,in_Year))/5)+1
    id = WHERE(rr_weeks EQ in_week, CNT)
    IF (CNT EQ 1) THEN t_id = t_id[id[0]]
  ENDIF ELSE MESSAGE, 'Week NOT found in CMAP rain rate data!'
  
  NCDF_VARGET, iid, 'precip', rr_data, OFFSET=[lon_id[0],lat_id[0],t_id], COUNT=[nLon,nLat,1]
IF NOT file_open THEN NCDF_CLOSE, iid
  
RETURN, {LON : rr_lon, LAT : rr_lat, RAIN : rr_data}
END